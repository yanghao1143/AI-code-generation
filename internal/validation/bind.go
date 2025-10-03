package validation

import (
	"github.com/gin-gonic/gin"
	"xingzuo/internal/api"
)

// BindJSON binds request body to obj. On error, writes a standardized error response and returns false.
func BindJSON(c *gin.Context, obj interface{}) bool {
	if err := c.ShouldBindJSON(obj); err != nil {
		rid := c.GetString("request_id")
		c.JSON(400, api.Err(rid, "E1000", "ValidationError", "请求体解析失败，请检查JSON格式与字段", "warning", gin.H{"error": err.Error()}))
		return false
	}
	return true
}
