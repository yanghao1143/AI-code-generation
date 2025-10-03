package middleware

import (
    "fmt"
    "time"

    "github.com/gin-gonic/gin"
    "xingzuo/internal/audit"
)

// HTTPAudit provides unified Web/API operation audit logging.
// It records action, userId, approval ticket, and request details (path/method/status/duration/requestId).
// The service parameter is used to tag the module (e.g., "ai.clarify").
func HTTPAudit(service string) gin.HandlerFunc {
    return func(c *gin.Context) {
        start := time.Now()
        c.Next()
        dur := time.Since(start)

        rid := c.GetString("request_id")
        user := c.GetString("user_id")
        status := c.Writer.Status()
        // Compose action name with module and method
        action := service + ":" + c.Request.Method
        // Optional WS streaming metrics injected by handlers
        wsFramesSent, _ := c.Get("ws_frames_sent")
        wsDurationMs, _ := c.Get("ws_duration_ms")
        wsCloseReason, _ := c.Get("ws_close_reason")

        ev := audit.Event{
            Action:         action,
            UserID:         user,
            ApprovalTicket: c.GetHeader("X-Approval-Ticket"),
            Timestamp:      time.Now().UTC(),
            Detail: map[string]interface{}{
                "requestId":   rid,
                "path":        c.FullPath(),
                "method":      c.Request.Method,
                "status":      status,
                "durationMs":  dur.Milliseconds(),
                "contentType": c.GetHeader("Content-Type"),
                // WS vendor metrics (if present)
                "wsFramesSent": wsFramesSent,
                "wsDurationMs": wsDurationMs,
                "wsCloseReason": wsCloseReason,
            },
        }
        // stdout + optional forward to Observe + optional JSONL append
        fmt.Printf("[AUDIT] action=%s user=%s ticket=%s ts=%s detail=%v\n", ev.Action, ev.UserID, ev.ApprovalTicket, ev.Timestamp.Format(time.RFC3339), ev.Detail)
        // Forward uses RBAC=observe and Authorization if available.
        go audit.Forward(c, ev)
        go audit.AppendJSONL(ev)
    }
}