package middleware

import (
	"net/http"
	"net/http/httptest"
	"os"
	"testing"

	"github.com/gin-gonic/gin"
	"xingzuo/internal/testassert"
)

func TestAuth_MissingHeader(t *testing.T) {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.Use(RequestID(), Auth())
	r.GET("/secure", func(c *gin.Context) { c.String(200, "ok") })

	// Ensure dev token is recognized when provided, but here we omit header to test failure
	_ = os.Setenv("AUTH_TOKENS", "dev-token")

	req := httptest.NewRequest(http.MethodGet, "/secure", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	testassert.MustError(t, w, http.StatusUnauthorized, "E1100", "AuthFailed")
}

func TestAuth_WrongFormat(t *testing.T) {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.Use(RequestID(), Auth())
	r.GET("/secure", func(c *gin.Context) { c.String(200, "ok") })

	_ = os.Setenv("AUTH_TOKENS", "dev-token")

	req := httptest.NewRequest(http.MethodGet, "/secure", nil)
	// Wrong scheme should trigger format error
	req.Header.Set("Authorization", "Basic dev-token")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	testassert.MustError(t, w, http.StatusUnauthorized, "E1100", "AuthFailed")
}
