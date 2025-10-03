package replytemplates

import (
    "github.com/gin-gonic/gin"
    "xingzuo/internal/api"
    "xingzuo/internal/middleware"
    "xingzuo/internal/validation"
)

type PreviewRequest struct {
    Content string                 `json:"content"`
    Vars    map[string]interface{} `json:"vars"`
    Schema  VarSchema              `json:"schema"`
    Strict  bool                   `json:"strict"`
}

func RegisterRoutes(r *gin.RouterGroup) {
    r.Use(middleware.RequirePermission("reply_templates"))
    r.POST("/preview", func(c *gin.Context) {
        rid := c.GetString("request_id")
        var req PreviewRequest
        if !validation.BindJSON(c, &req) {
            return
        }
        valid, issues := ValidateVars(req.Schema, req.Vars)
        preview := RenderPreview(req.Content, req.Vars)
        // If strict mode and invalid, return warning severity with issues
        if req.Strict && !valid {
            c.JSON(400, api.Err(rid, "E1000", "ValidationError", "变量校验失败", "warning", gin.H{"issues": issues}))
            return
        }
        c.JSON(200, api.OK(rid, gin.H{
            "valid":   valid,
            "issues":  issues,
            "preview": preview,
        }))
    })
}