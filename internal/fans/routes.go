package fans

import (
    "net/http"

    "github.com/gin-gonic/gin"
    "xingzuo/internal/api"
    "xingzuo/internal/audit"
    "xingzuo/internal/middleware"
    "xingzuo/internal/validation"
)

// ActiveConversationRequest represents the payload to set active conversation.
type ActiveConversationRequest struct {
    ConversationID string `json:"conversationId"`
}

// RegisterRoutes registers fans endpoints.
func RegisterRoutes(r *gin.RouterGroup) {
    r.Use(middleware.RequirePermission("fans"))

    // Get current active conversation for a fan
    r.GET("/:fanId/active_conversation", func(c *gin.Context) {
        rid := c.GetString("request_id")
        fanId := c.Param("fanId")
        if v, ok := defaultSessions.GetActive(fanId); ok {
            c.JSON(http.StatusOK, api.OK(rid, gin.H{"conversationId": v}))
            return
        }
        c.JSON(http.StatusOK, api.OK(rid, gin.H{"conversationId": ""}))
    })

    // Set active conversation if not conflicting
    r.POST("/:fanId/active_conversation", func(c *gin.Context) {
        rid := c.GetString("request_id")
        fanId := c.Param("fanId")
        var req ActiveConversationRequest
        if !validation.BindJSON(c, &req) {
            return
        }
        if req.ConversationID == "" {
            c.JSON(http.StatusBadRequest, api.Err(rid, "E1401", "InvalidArgument", "conversationId不能为空", "warning", nil))
            return
        }
        if ok := defaultSessions.SetActive(fanId, req.ConversationID); !ok {
            c.JSON(http.StatusConflict, api.Err(rid, "E1400", "Conflict", "当前会话已占用", "warning", gin.H{"fanId": fanId}))
            return
        }
        audit.LogFanSessionSet(c, fanId, req.ConversationID)
        c.JSON(http.StatusOK, api.OK(rid, gin.H{"conversationId": req.ConversationID}))
    })

    // Clear active conversation
    r.DELETE("/:fanId/active_conversation", func(c *gin.Context) {
        rid := c.GetString("request_id")
        fanId := c.Param("fanId")
        defaultSessions.ClearActive(fanId)
        audit.LogFanSessionClear(c, fanId)
        c.JSON(http.StatusOK, api.OK(rid, gin.H{"cleared": true}))
    })
}