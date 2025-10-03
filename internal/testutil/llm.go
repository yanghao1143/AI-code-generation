package testutil

import (
	"net/http"
	"os"
	"testing"

	"github.com/gin-gonic/gin"
	"xingzuo/internal/middleware"
)

// SetupRouterWith initializes a test router and lets caller register routes under given group path.
func SetupRouterWith(t *testing.T, groupPath string, register func(*gin.RouterGroup)) *gin.Engine {
	t.Helper()
	gin.SetMode(gin.TestMode)
	// Ensure dev token is allowed
	_ = os.Setenv("AUTH_TOKENS", "dev-token")

	r := gin.New()
	r.Use(middleware.RequestID(), middleware.ErrorHandler())
	v1 := r.Group("/api/v1")
	v1.Use(middleware.Auth(), middleware.RateLimit())
	register(v1.Group(groupPath))
	return r
}

// AuthHeaders applies standard auth and permission headers for LLM tests.
func AuthHeaders(req *http.Request) {
	req.Header.Set("Authorization", "Bearer dev-token")
	req.Header.Set("X-User-Permissions", "llm")
	req.Header.Set("Content-Type", "application/json")
}
