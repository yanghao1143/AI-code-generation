package audit

import (
    "bytes"
    "encoding/json"
    "fmt"
    "net/http"
    "os"
    "strings"
    "time"

    "github.com/gin-gonic/gin"
)

// Event represents a unified audit event.
type Event struct {
    Action         string                 `json:"action"`
    UserID         string                 `json:"userId"`
    ApprovalTicket string                 `json:"approvalTicket"`
    Timestamp      time.Time              `json:"timestamp"`
    Detail         map[string]interface{} `json:"detail"`
}

// LogFansExport records an audit event for fans batch export.
// It currently logs to stdout; can be extended to persist to DB or forward to Observe.
func LogFansExport(c *gin.Context, filters map[string]interface{}, itemCount int) {
    ev := Event{
        Action:         "fans_export",
        UserID:         c.GetString("user_id"),
        ApprovalTicket: c.GetHeader("X-Approval-Ticket"),
        Timestamp:      time.Now().UTC(),
        Detail: map[string]interface{}{
            "filters":   filters,
            "itemCount": itemCount,
            "requestId": c.GetString("request_id"),
            "path":      c.FullPath(),
            "method":    c.Request.Method,
        },
    }
    fmt.Printf("[AUDIT] action=%s user=%s ticket=%s ts=%s detail=%v\n", ev.Action, ev.UserID, ev.ApprovalTicket, ev.Timestamp.Format(time.RFC3339), ev.Detail)
    go Forward(c, ev)
}

// LogFanSessionSet records an audit event when setting a fan's active conversation.
func LogFanSessionSet(c *gin.Context, fanId string, conversationId string) {
    ev := Event{
        Action:    "fan_session_set",
        UserID:    c.GetString("user_id"),
        Timestamp: time.Now().UTC(),
        Detail: map[string]interface{}{
            "fanId":          fanId,
            "conversationId": conversationId,
            "requestId":      c.GetString("request_id"),
            "path":           c.FullPath(),
            "method":         c.Request.Method,
        },
    }
    fmt.Printf("[AUDIT] action=%s user=%s ts=%s detail=%v\n", ev.Action, ev.UserID, ev.Timestamp.Format(time.RFC3339), ev.Detail)
    go Forward(c, ev)
}

// LogFanSessionClear records an audit event when clearing a fan's active conversation.
func LogFanSessionClear(c *gin.Context, fanId string) {
    ev := Event{
        Action:    "fan_session_clear",
        UserID:    c.GetString("user_id"),
        Timestamp: time.Now().UTC(),
        Detail: map[string]interface{}{
            "fanId":     fanId,
            "requestId": c.GetString("request_id"),
            "path":      c.FullPath(),
            "method":    c.Request.Method,
        },
    }
    fmt.Printf("[AUDIT] action=%s user=%s ts=%s detail=%v\n", ev.Action, ev.UserID, ev.Timestamp.Format(time.RFC3339), ev.Detail)
    go Forward(c, ev)
}

// Forward sends audit event to Observe service (/api/v1/observe/events) with simple retry.
// Controlled by env AUDIT_FORWARD_ENABLE=true. Endpoint derived from OBSERVE_ENDPOINT or local PORT.
func Forward(c *gin.Context, ev Event) {
    if !strings.EqualFold(os.Getenv("AUDIT_FORWARD_ENABLE"), "true") {
        return
    }
    endpoint := os.Getenv("OBSERVE_ENDPOINT")
    if endpoint == "" {
        port := os.Getenv("PORT")
        if port == "" {
            port = "8080"
        }
        endpoint = "http://127.0.0.1:" + port + "/api/v1/observe/events"
    }
    // Build payload compatible with observe.EventRequest, extra fields tolerated
    payload := map[string]interface{}{
        "type":     "audit",
        "severity": "info",
        "message":  ev.Action,
        "detail":   ev.Detail,
        "timestamp": ev.Timestamp.Format(time.RFC3339),
        "userId":    ev.UserID,
    }
    body, _ := json.Marshal(payload)
    // Authorization: prefer request token; otherwise use OBSERVE_TOKEN
    auth := c.GetString("auth_token")
    if auth == "" {
        tok := os.Getenv("OBSERVE_TOKEN")
        if tok != "" {
            auth = tok
        }
    }
    // Retry with backoff
    for i := 0; i < 3; i++ {
        req, _ := http.NewRequest(http.MethodPost, endpoint, bytes.NewReader(body))
        req.Header.Set("Content-Type", "application/json")
        // Ensure RBAC passes for observe
        req.Header.Set("X-User-Permissions", "observe")
        if auth != "" {
            req.Header.Set("Authorization", "Bearer "+auth)
        }
        resp, err := http.DefaultClient.Do(req)
        if err == nil && resp != nil {
            if resp.Body != nil { _ = resp.Body.Close() }
            if resp.StatusCode >= 200 && resp.StatusCode < 300 {
                return
            }
        }
        time.Sleep(time.Duration(100*(i+1)) * time.Millisecond)
    }
}

// ForwardNoContext sends audit event without gin.Context (for CLI/background usage).
// Controlled by env AUDIT_FORWARD_ENABLE=true. Endpoint derived from OBSERVE_ENDPOINT or local PORT.
func ForwardNoContext(ev Event) {
    if !strings.EqualFold(os.Getenv("AUDIT_FORWARD_ENABLE"), "true") {
        return
    }
    endpoint := os.Getenv("OBSERVE_ENDPOINT")
    if endpoint == "" {
        port := os.Getenv("PORT")
        if port == "" {
            port = "8080"
        }
        endpoint = "http://127.0.0.1:" + port + "/api/v1/observe/events"
    }
    payload := map[string]interface{}{
        "type":      "audit",
        "severity":  "info",
        "message":   ev.Action,
        "detail":    ev.Detail,
        "timestamp": ev.Timestamp.Format(time.RFC3339),
        "userId":    ev.UserID,
    }
    body, _ := json.Marshal(payload)
    auth := os.Getenv("OBSERVE_TOKEN")
    for i := 0; i < 3; i++ {
        req, _ := http.NewRequest(http.MethodPost, endpoint, bytes.NewReader(body))
        req.Header.Set("Content-Type", "application/json")
        req.Header.Set("X-User-Permissions", "observe")
        if auth != "" {
            req.Header.Set("Authorization", "Bearer "+auth)
        }
        resp, err := http.DefaultClient.Do(req)
        if err == nil && resp != nil {
            if resp.Body != nil { _ = resp.Body.Close() }
            if resp.StatusCode >= 200 && resp.StatusCode < 300 {
                return
            }
        }
        time.Sleep(time.Duration(100*(i+1)) * time.Millisecond)
    }
}

// LogAICodegenRun records an audit event for aicodegen CLI runs.
// Include parameters, outputs, and optional approval ticket for DB change.
func LogAICodegenRun(detail map[string]interface{}, approvalTicket string) {
    ev := Event{
        Action:         "aicodegen_run",
        UserID:         os.Getenv("AUDIT_USER_ID"),
        ApprovalTicket: approvalTicket,
        Timestamp:      time.Now().UTC(),
        Detail:         detail,
    }
    fmt.Printf("[AUDIT] action=%s user=%s ticket=%s ts=%s detail=%v\n", ev.Action, ev.UserID, ev.ApprovalTicket, ev.Timestamp.Format(time.RFC3339), ev.Detail)
    go ForwardNoContext(ev)
}