package llm

import (
	"fmt"
	"net/http"

	"github.com/gin-gonic/gin"
	"xingzuo/internal/api"
	"xingzuo/internal/middleware"
	"xingzuo/internal/validation"
)

// RegisterRoutes registers unified LLM endpoints (placeholders).
func RegisterRoutes(r *gin.RouterGroup) {
	r.Use(middleware.RequirePermission("llm"))

	r.GET("/providers", func(c *gin.Context) {
		rid := c.GetString("request_id")
		c.JSON(200, api.OK(rid, gin.H{
			"items": Providers(),
		}))
	})

	r.GET("/models", func(c *gin.Context) {
		rid := c.GetString("request_id")
		c.JSON(200, api.OK(rid, gin.H{
			"items": Models(),
		}))
	})

	r.POST("/chat", func(c *gin.Context) {
		rid := c.GetString("request_id")
		var req ChatRequest
		if !validation.BindJSON(c, &req) {
			return
		}
		// Select model by request hint/explicit id, otherwise return 400
		sel, ok := SelectModel(req)
		if !ok {
			c.JSON(400, api.Err(rid, "E2100", "ModelNotFound", "请检查modelId或providerHint", "warning", gin.H{
				"providers": Providers(),
				"models":    Models(),
			}))
			return
		}
		// Ensure request uses selected model
		req.ModelID = sel.ModelID
		client, ok := ClientFor(sel.ProviderID)
		if !ok {
			c.JSON(404, api.Err(rid, "E2200", "ClientNotRegistered", "未找到对应厂商适配器", "warning", gin.H{"providerId": sel.ProviderID}))
			return
		}

		if req.Stream {
			// SSE stream
			c.Writer.Header().Set("Content-Type", "text/event-stream")
			c.Writer.Header().Set("Cache-Control", "no-cache")
			c.Writer.Header().Set("Connection", "keep-alive")
			if flusher, ok := c.Writer.(http.Flusher); ok {
				ch, err := client.ChatStream(c.Request.Context(), req)
				if err != nil {
					c.JSON(500, api.Err(rid, "E3001", "StreamError", "流式输出失败", "error", gin.H{"error": err.Error()}))
					return
				}
				for token := range ch {
					fmt.Fprintf(c.Writer, "data: %s\n\n", token)
					flusher.Flush()
				}
				// optional done event
				fmt.Fprint(c.Writer, "event: done\n\n")
				flusher.Flush()
				return
			}
			c.JSON(500, api.Err(rid, "E3001", "StreamError", "SSE不支持", "error", nil))
			return
		}

		// Non-streaming chat
		resp, err := client.Chat(c.Request.Context(), req)
		if err != nil {
			c.JSON(500, api.Err(rid, "E3002", "ChatError", "对话生成失败", "error", gin.H{"error": err.Error()}))
			return
		}
		c.JSON(200, api.OK(rid, resp))
	})

	r.POST("/embeddings", func(c *gin.Context) {
		rid := c.GetString("request_id")
		var req EmbeddingsRequest
		if !validation.BindJSON(c, &req) {
			return
		}
		// Select model (using modelId only for now)
		chSel, ok := SelectModel(ChatRequest{ModelID: req.ModelID})
		if !ok {
			c.JSON(400, api.Err(rid, "E2100", "ModelNotFound", "请检查modelId", "warning", gin.H{"models": Models()}))
			return
		}
		req.ModelID = chSel.ModelID
		client, ok := ClientFor(chSel.ProviderID)
		if !ok {
			c.JSON(404, api.Err(rid, "E2200", "ClientNotRegistered", "未找到对应厂商适配器", "warning", gin.H{"providerId": chSel.ProviderID}))
			return
		}
		resp, err := client.Embed(c.Request.Context(), req)
		if err != nil {
			c.JSON(500, api.Err(rid, "E3003", "EmbeddingsError", "向量生成失败", "error", gin.H{"error": err.Error()}))
			return
		}
		c.JSON(200, api.OK(rid, resp))
	})

	r.POST("/moderate", func(c *gin.Context) {
		rid := c.GetString("request_id")
		var req ModerateRequest
		if !validation.BindJSON(c, &req) {
			return
		}
		// For moderation, choose first enabled model (no modelId provided)
		chSel, ok := SelectModel(ChatRequest{})
		if !ok {
			c.JSON(400, api.Err(rid, "E2100", "ModelNotFound", "未配置可用模型", "warning", gin.H{"models": Models()}))
			return
		}
		client, ok := ClientFor(chSel.ProviderID)
		if !ok {
			c.JSON(404, api.Err(rid, "E2200", "ClientNotRegistered", "未找到对应厂商适配器", "warning", gin.H{"providerId": chSel.ProviderID}))
			return
		}
		resp, err := client.Moderate(c.Request.Context(), req)
		if err != nil {
			c.JSON(500, api.Err(rid, "E3004", "ModerateError", "内容审核失败", "error", gin.H{"error": err.Error()}))
			return
		}
		c.JSON(200, api.OK(rid, resp))
	})
}
