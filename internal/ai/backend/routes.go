package backend

import (
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"xingzuo/internal/api"
	"xingzuo/internal/middleware"
	"xingzuo/internal/validation"
)

func RegisterRoutes(r *gin.RouterGroup) {
	r.Use(middleware.RequirePermission("ai.backend"))
	r.POST("/generate", func(c *gin.Context) {
		rid := c.GetString("request_id")
		var req GenerateRequest
		if !validation.BindJSON(c, &req) {
			return
		}
		genID := "gen_" + uuid.NewString()
		c.JSON(200, api.OK(rid, gin.H{"generateId": genID, "name": req.Name}))
	})
	r.POST("/scaffold", func(c *gin.Context) {
		rid := c.GetString("request_id")
		var req ScaffoldRequest
		if !validation.BindJSON(c, &req) {
			return
		}
		scID := "scf_" + uuid.NewString()
		c.JSON(200, api.OK(rid, gin.H{"scaffoldId": scID, "serviceName": req.ServiceName}))
	})
	r.POST("/fix", func(c *gin.Context) {
		rid := c.GetString("request_id")
		var req FixRequest
		if !validation.BindJSON(c, &req) {
			return
		}
		fixID := "fix_" + uuid.NewString()
		c.JSON(200, api.OK(rid, gin.H{"fixId": fixID, "reportId": req.ReportID}))
	})
	r.GET("/templates", func(c *gin.Context) {
		rid := c.GetString("request_id")
		c.JSON(200, api.OK(rid, gin.H{"templates": []string{"gin-handler", "repo-service"}}))
	})
}
