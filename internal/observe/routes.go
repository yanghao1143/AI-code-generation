package observe

import (
	"github.com/gin-gonic/gin"
	"xingzuo/internal/api"
	"xingzuo/internal/middleware"
	"xingzuo/internal/validation"
)

func RegisterRoutes(r *gin.RouterGroup) {
	r.Use(middleware.RequirePermission("observe"))

	r.GET("/metrics", func(c *gin.Context) {
		rid := c.GetString("request_id")
		c.JSON(200, api.OK(rid, gin.H{"p99": 280, "errorBudget": 0.15, "uptime": "99.95%"}))
	})

	r.GET("/traces", func(c *gin.Context) {
		rid := c.GetString("request_id")
		c.JSON(200, api.OK(rid, gin.H{"traces": []string{"trace_001", "trace_002"}}))
	})

	r.POST("/events", func(c *gin.Context) {
		rid := c.GetString("request_id")
		var req EventRequest
		if !validation.BindJSON(c, &req) {
			return
		}
		c.JSON(200, api.OK(rid, gin.H{"accepted": true, "type": req.Type, "severity": req.Severity}))
	})
}
