package integration

import (
	"github.com/gin-gonic/gin"
	"xingzuo/internal/api"
	"xingzuo/internal/middleware"
)

func RegisterRoutes(r *gin.RouterGroup) {
	r.Use(middleware.RequirePermission("ai.integration"))
	r.POST("/test", func(c *gin.Context) {
		rid := c.GetString("request_id")
		c.JSON(200, api.OK(rid, gin.H{"reportId": "rpt_0001"}))
	})
	r.POST("/diagnose", func(c *gin.Context) {
		rid := c.GetString("request_id")
		c.JSON(200, api.OK(rid, gin.H{"issues": []string{"schema.mismatch", "auth.missing"}}))
	})
	r.POST("/patch", func(c *gin.Context) {
		rid := c.GetString("request_id")
		c.JSON(200, api.OK(rid, gin.H{"patchId": "pch_0001"}))
	})
	r.GET("/reports", func(c *gin.Context) {
		rid := c.GetString("request_id")
		c.JSON(200, api.OK(rid, gin.H{"items": []gin.H{}}))
	})
}
