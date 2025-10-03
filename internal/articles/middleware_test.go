package articles

import (
    "net/http"
    "net/http/httptest"
    "os"
    "testing"

    "xingzuo/internal/testassert"
    "xingzuo/internal/testutil"
)

func TestArticles_MW_AuthMissing(t *testing.T) {
    r := testutil.SetupRouterWith(t, "/articles", RegisterRoutes)
    req := httptest.NewRequest(http.MethodGet, "/api/v1/articles", nil)
    w := httptest.NewRecorder()
    r.ServeHTTP(w, req)
    testassert.MustError(t, w, http.StatusUnauthorized, "E1100", "AuthFailed")
}

func TestArticles_MW_AuthWrongScheme(t *testing.T) {
    r := testutil.SetupRouterWith(t, "/articles", RegisterRoutes)
    req := httptest.NewRequest(http.MethodGet, "/api/v1/articles", nil)
    req.Header.Set("Authorization", "Basic dev-token")
    w := httptest.NewRecorder()
    r.ServeHTTP(w, req)
    testassert.MustError(t, w, http.StatusUnauthorized, "E1100", "AuthFailed")
}

func TestArticles_MW_RBACMissing(t *testing.T) {
    r := testutil.SetupRouterWith(t, "/articles", RegisterRoutes)
    req := httptest.NewRequest(http.MethodGet, "/api/v1/articles", nil)
    req.Header.Set("Authorization", "Bearer dev-token")
    w := httptest.NewRecorder()
    r.ServeHTTP(w, req)
    testassert.MustError(t, w, http.StatusForbidden, "E1200", "PermissionDenied")
}

func TestArticles_MW_RBACInsufficient(t *testing.T) {
    r := testutil.SetupRouterWith(t, "/articles", RegisterRoutes)
    req := httptest.NewRequest(http.MethodGet, "/api/v1/articles", nil)
    req.Header.Set("Authorization", "Bearer dev-token")
    req.Header.Set("X-User-Permissions", "billing")
    w := httptest.NewRecorder()
    r.ServeHTTP(w, req)
    testassert.MustError(t, w, http.StatusForbidden, "E1200", "PermissionDenied")
}

func TestArticles_MW_RateLimit429(t *testing.T) {
    // Tighten limits to trigger rate limiting reliably
    _ = os.Setenv("RATE_LIMIT_RPS", "1")
    _ = os.Setenv("RATE_LIMIT_BURST", "1")

    r := testutil.SetupRouterWith(t, "/articles", RegisterRoutes)

    // First request with proper headers should pass
    req1 := httptest.NewRequest(http.MethodGet, "/api/v1/articles", nil)
    req1.Header.Set("Authorization", "Bearer dev-token")
    req1.Header.Set("X-User-Permissions", "articles")
    // Use a fixed client IP to ensure a fresh limiter with tight settings
    req1.Header.Set("X-Forwarded-For", "198.51.100.8")
    w1 := httptest.NewRecorder()
    r.ServeHTTP(w1, req1)
    testassert.MustStatus(t, w1, http.StatusOK)

    // Second immediate request should be limited for same client IP
    req2 := httptest.NewRequest(http.MethodGet, "/api/v1/articles", nil)
    req2.Header.Set("Authorization", "Bearer dev-token")
    req2.Header.Set("X-User-Permissions", "articles")
    req2.Header.Set("X-Forwarded-For", "198.51.100.8")
    w2 := httptest.NewRecorder()
    r.ServeHTTP(w2, req2)
    testassert.MustError(t, w2, http.StatusTooManyRequests, "E1300", "RateLimited")
}