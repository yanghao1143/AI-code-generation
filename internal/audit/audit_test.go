package audit

import (
    "encoding/json"
    "io"
    "net/http"
    "net/http/httptest"
    "os"
    "testing"
    "time"

    "github.com/gin-gonic/gin"
)

func TestAuditForward_RetryAndHeaders(t *testing.T) {
    gin.SetMode(gin.TestMode)
    hits := 0
    var gotAuth, gotPerms, gotCT, gotMsg string
    ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        hits++
        gotAuth = r.Header.Get("Authorization")
        gotPerms = r.Header.Get("X-User-Permissions")
        gotCT = r.Header.Get("Content-Type")
        b, _ := io.ReadAll(r.Body)
        _ = r.Body.Close()
        var payload map[string]any
        _ = json.Unmarshal(b, &payload)
        if v, _ := payload["message"].(string); v != "" { gotMsg = v }
        if hits == 1 {
            w.WriteHeader(http.StatusInternalServerError)
            return
        }
        w.WriteHeader(http.StatusOK)
        _, _ = w.Write([]byte(`{"accepted":true}`))
    }))
    defer ts.Close()

    _ = os.Setenv("AUDIT_FORWARD_ENABLE", "true")
    _ = os.Setenv("OBSERVE_ENDPOINT", ts.URL+"/api/v1/observe/events")
    _ = os.Setenv("OBSERVE_TOKEN", "dev-token")

    w := httptest.NewRecorder()
    c, _ := gin.CreateTestContext(w)

    ev := Event{
        Action:    "fan_session_set",
        UserID:    "u1",
        Timestamp: time.Now().UTC(),
        Detail: map[string]interface{}{
            "fanId":          "f1",
            "conversationId": "c1",
            "requestId":      "r1",
        },
    }
    Forward(c, ev)

    if hits != 2 {
        t.Fatalf("expected 2 attempts (retry once), got %d", hits)
    }
    if gotPerms != "observe" {
        t.Fatalf("expected X-User-Permissions=observe, got %s", gotPerms)
    }
    if gotAuth != "Bearer dev-token" {
        t.Fatalf("expected Authorization Bearer dev-token, got %s", gotAuth)
    }
    if gotCT != "application/json" {
        t.Fatalf("expected Content-Type application/json, got %s", gotCT)
    }
    if gotMsg != "fan_session_set" {
        t.Fatalf("expected message fan_session_set, got %s", gotMsg)
    }
}