package audit

import (
    "encoding/json"
    "io"
    "net/http"
    "net/http/httptest"
    "os"
    "testing"
    "time"
)

// Verify forwarding without gin.Context works with headers and retry logic.
func TestForwardNoContext_RetryAndHeaders(t *testing.T) {
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

    ev := Event{
        Action:    "cli_forward_test",
        UserID:    "u1",
        Timestamp: time.Now().UTC(),
        Detail:    map[string]interface{}{"k": "v"},
    }
    ForwardNoContext(ev)

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
    if gotMsg != "cli_forward_test" {
        t.Fatalf("expected message cli_forward_test, got %s", gotMsg)
    }
}

// Verify LogAICodegenRun sends event with correct message and user id, forwarding via ForwardNoContext.
func TestLogAICodegenRun_Forwarded(t *testing.T) {
    hits := 0
    var gotMsg, gotUser string
    var gotOutSpec string
    var gotApply bool
    ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        hits++
        b, _ := io.ReadAll(r.Body)
        _ = r.Body.Close()
        var payload map[string]any
        _ = json.Unmarshal(b, &payload)
        if v, _ := payload["message"].(string); v != "" { gotMsg = v }
        if v, _ := payload["userId"].(string); v != "" { gotUser = v }
        if d, ok := payload["detail"].(map[string]any); ok {
            if v, _ := d["outSpec"].(string); v != "" { gotOutSpec = v }
            if v, ok2 := d["applyDB"].(bool); ok2 { gotApply = v }
        }
        w.WriteHeader(http.StatusOK)
        _, _ = w.Write([]byte(`{"accepted":true}`))
    }))
    defer ts.Close()

    _ = os.Setenv("AUDIT_FORWARD_ENABLE", "true")
    _ = os.Setenv("OBSERVE_ENDPOINT", ts.URL+"/api/v1/observe/events")
    _ = os.Setenv("OBSERVE_TOKEN", "dev-token")
    _ = os.Setenv("AUDIT_USER_ID", "cli-user")

    detail := map[string]interface{}{
        "outSpec": "ai-codegen",
        "applyDB": false,
    }
    LogAICodegenRun(detail, "REQ-1")

    // Allow goroutine to send
    time.Sleep(200 * time.Millisecond)

    if hits < 1 {
        t.Fatalf("expected at least 1 forwarded request, got %d", hits)
    }
    if gotMsg != "aicodegen_run" {
        t.Fatalf("expected message aicodegen_run, got %s", gotMsg)
    }
    if gotUser != "cli-user" {
        t.Fatalf("expected userId cli-user, got %s", gotUser)
    }
    if gotOutSpec != "ai-codegen" {
        t.Fatalf("expected detail.outSpec ai-codegen, got %s", gotOutSpec)
    }
    if gotApply != false {
        t.Fatalf("expected detail.applyDB=false, got %v", gotApply)
    }
}