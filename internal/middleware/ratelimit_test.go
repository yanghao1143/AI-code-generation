package middleware

import (
	"net/http"
	"net/http/httptest"
	"os"
	"testing"

	"github.com/gin-gonic/gin"
	"xingzuo/internal/testassert"
)

func TestRateLimit_Trigger429(t *testing.T) {
	gin.SetMode(gin.TestMode)
	// Tight limits to reliably trigger rate limiting
	_ = os.Setenv("RATE_LIMIT_RPS", "1")
	_ = os.Setenv("RATE_LIMIT_BURST", "1")

	r := gin.New()
	r.Use(RequestID(), RateLimit())
	r.GET("/rl", func(c *gin.Context) { c.String(200, "ok") })

	// First request should pass
	req1 := httptest.NewRequest(http.MethodGet, "/rl", nil)
	w1 := httptest.NewRecorder()
	r.ServeHTTP(w1, req1)
	testassert.MustStatus(t, w1, http.StatusOK)

	// Second immediate request should be limited
	req2 := httptest.NewRequest(http.MethodGet, "/rl", nil)
	w2 := httptest.NewRecorder()
	r.ServeHTTP(w2, req2)
	testassert.MustError(t, w2, http.StatusTooManyRequests, "E1300", "RateLimited")
}
