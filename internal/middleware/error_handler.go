package middleware

import (
	"github.com/gin-gonic/gin"
	"xingzuo/internal/api"
)

// ErrorHandler standardizes error responses when handlers set c.Errors.
func ErrorHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Next()
		if len(c.Errors) > 0 {
			rid := c.GetString("request_id")
			last := c.Errors.Last()
			c.JSON(500, api.Err(rid, "E3000", "InternalError", "请稍后重试或联系支持", "error", gin.H{"error": last.Error()}))
		}
	}
}
