package frontend

import (
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"xingzuo/internal/api"
	"xingzuo/internal/middleware"
	"xingzuo/internal/validation"
)

func RegisterRoutes(r *gin.RouterGroup) {
	r.Use(middleware.RequirePermission("ai.frontend"))
	r.POST("/generate", func(c *gin.Context) {
		rid := c.GetString("request_id")
		var req GenerateRequest
		if !validation.BindJSON(c, &req) {
			return
		}
		snapshotID := "snap_" + uuid.NewString()
		c.JSON(200, api.OK(rid, gin.H{"snapshotId": snapshotID, "name": req.Name, "template": req.Template}))
	})
	r.POST("/validate", func(c *gin.Context) {
		rid := c.GetString("request_id")
		var req ValidateRequest
		if !validation.BindJSON(c, &req) {
			return
		}
		// placeholder: always valid
		c.JSON(200, api.OK(rid, gin.H{"valid": true, "issues": []string{}}))
	})
	r.GET("/templates", func(c *gin.Context) {
		rid := c.GetString("request_id")
		c.JSON(200, api.OK(rid, gin.H{"templates": []string{"basic-page", "form-list"}}))
	})
	r.POST("/commit", func(c *gin.Context) {
		rid := c.GetString("request_id")
		var req CommitRequest
		if !validation.BindJSON(c, &req) {
			return
		}
		commitID := "cmt_" + uuid.NewString()
		c.JSON(200, api.OK(rid, gin.H{"commitId": commitID, "snapshotId": req.SnapshotID, "message": req.Message}))
	})
}
