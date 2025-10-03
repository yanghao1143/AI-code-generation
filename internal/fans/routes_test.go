package fans

import (
    "net/http"
    "net/http/httptest"
    "strings"
    "testing"

    "github.com/gin-gonic/gin"
    "xingzuo/internal/testassert"
    "xingzuo/internal/testutil"
)

// setupRouter initializes a test router with fans routes.
func setupRouter(t *testing.T) *gin.Engine {
    return testutil.SetupRouterWith(t, "/fans", RegisterRoutes)
}

// auth headers for fans module
func authHeaders(req *http.Request) {
    req.Header.Set("Authorization", "Bearer dev-token")
    req.Header.Set("X-User-Permissions", "fans")
    req.Header.Set("Content-Type", "application/json")
}

func TestFans_ActiveConversation_BasicFlow(t *testing.T) {
    r := setupRouter(t)

    // Initial GET should return empty conversationId
    req := httptest.NewRequest(http.MethodGet, "/api/v1/fans/f_001/active_conversation", nil)
    authHeaders(req)
    w := httptest.NewRecorder()
    r.ServeHTTP(w, req)
    testassert.MustStatus(t, w, http.StatusOK)
    body := testassert.MustJSON(t, w)
    data := testassert.DataOf(t, body)
    if v, _ := data["conversationId"].(string); v != "" {
        t.Fatalf("expected empty conversationId, got %v", v)
    }

    // Set active conversation
    payload := `{"conversationId":"c1"}`
    req2 := httptest.NewRequest(http.MethodPost, "/api/v1/fans/f_001/active_conversation", strings.NewReader(payload))
    authHeaders(req2)
    w2 := httptest.NewRecorder()
    r.ServeHTTP(w2, req2)
    testassert.MustStatus(t, w2, http.StatusOK)
    body2 := testassert.MustJSON(t, w2)
    data2 := testassert.DataOf(t, body2)
    if v, _ := data2["conversationId"].(string); v != "c1" {
        t.Fatalf("expected conversationId c1, got %v", v)
    }

    // GET should now return c1
    req3 := httptest.NewRequest(http.MethodGet, "/api/v1/fans/f_001/active_conversation", nil)
    authHeaders(req3)
    w3 := httptest.NewRecorder()
    r.ServeHTTP(w3, req3)
    testassert.MustStatus(t, w3, http.StatusOK)
    body3 := testassert.MustJSON(t, w3)
    data3 := testassert.DataOf(t, body3)
    if v, _ := data3["conversationId"].(string); v != "c1" {
        t.Fatalf("expected conversationId c1 after set, got %v", v)
    }

    // Conflict when setting different conversationId
    payloadConflict := `{"conversationId":"c2"}`
    req4 := httptest.NewRequest(http.MethodPost, "/api/v1/fans/f_001/active_conversation", strings.NewReader(payloadConflict))
    authHeaders(req4)
    w4 := httptest.NewRecorder()
    r.ServeHTTP(w4, req4)
    testassert.MustError(t, w4, http.StatusConflict, "E1400", "Conflict")

    // Clear active conversation
    req5 := httptest.NewRequest(http.MethodDelete, "/api/v1/fans/f_001/active_conversation", nil)
    authHeaders(req5)
    w5 := httptest.NewRecorder()
    r.ServeHTTP(w5, req5)
    testassert.MustStatus(t, w5, http.StatusOK)
    body5 := testassert.MustJSON(t, w5)
    data5 := testassert.DataOf(t, body5)
    if ok, _ := data5["cleared"].(bool); !ok {
        t.Fatalf("expected cleared true")
    }

    // GET should be empty again
    req6 := httptest.NewRequest(http.MethodGet, "/api/v1/fans/f_001/active_conversation", nil)
    authHeaders(req6)
    w6 := httptest.NewRecorder()
    r.ServeHTTP(w6, req6)
    testassert.MustStatus(t, w6, http.StatusOK)
    body6 := testassert.MustJSON(t, w6)
    data6 := testassert.DataOf(t, body6)
    if v, _ := data6["conversationId"].(string); v != "" {
        t.Fatalf("expected empty conversationId after clear, got %v", v)
    }
}