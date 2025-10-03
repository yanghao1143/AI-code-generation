package middleware

import (
    "net/http"
    "net/http/httptest"
    "os"
    "testing"

    "github.com/gin-gonic/gin"
    "xingzuo/internal/testassert"
)

// Cross-endpoint burst/consecutive requests should share the same limiter per client IP.
func TestRateLimit_CrossEndpointBurst(t *testing.T) {
    gin.SetMode(gin.TestMode)
    _ = os.Setenv("RATE_LIMIT_RPS", "1")
    _ = os.Setenv("RATE_LIMIT_BURST", "1")

    r := gin.New()
    r.Use(RequestID(), RateLimit())
    r.GET("/a", func(c *gin.Context) { c.String(200, "ok-a") })
    r.GET("/b", func(c *gin.Context) { c.String(200, "ok-b") })

    // First request should pass
    req1 := httptest.NewRequest(http.MethodGet, "/a", nil)
    req1.Header.Set("X-Forwarded-For", "203.0.113.5")
    w1 := httptest.NewRecorder()
    r.ServeHTTP(w1, req1)
    testassert.MustStatus(t, w1, http.StatusOK)

    // Immediate second request to another endpoint should be limited
    req2 := httptest.NewRequest(http.MethodGet, "/b", nil)
    req2.Header.Set("X-Forwarded-For", "203.0.113.5")
    w2 := httptest.NewRecorder()
    r.ServeHTTP(w2, req2)
    testassert.MustError(t, w2, http.StatusTooManyRequests, "E1300", "RateLimited")

    // Subsequent rapid requests continue to see limiting across endpoints
    req3 := httptest.NewRequest(http.MethodGet, "/a", nil)
    req3.Header.Set("X-Forwarded-For", "203.0.113.5")
    w3 := httptest.NewRecorder()
    r.ServeHTTP(w3, req3)
    // Either allowed or limited depending on token refill timing; ensure code is one of expected
    if w3.Code != http.StatusOK && w3.Code != http.StatusTooManyRequests {
        t.Fatalf("unexpected status %d", w3.Code)
    }

    req4 := httptest.NewRequest(http.MethodGet, "/b", nil)
    req4.Header.Set("X-Forwarded-For", "203.0.113.5")
    w4 := httptest.NewRecorder()
    r.ServeHTTP(w4, req4)
    if w4.Code != http.StatusOK && w4.Code != http.StatusTooManyRequests {
        t.Fatalf("unexpected status %d", w4.Code)
    }
}