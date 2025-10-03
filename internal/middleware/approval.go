package middleware

import (
    "os"
    "strings"

    "github.com/gin-gonic/gin"
    "xingzuo/internal/api"
)

// RequireApprovalTicket enforces unified export/critical action gate across all environments.
// Clients must provide X-Approval-Ticket header; when APPROVAL_TICKETS env is set (CSV),
// the header must match one of allowed tickets.
func RequireApprovalTicket() gin.HandlerFunc {
    return func(c *gin.Context) {
        rid := c.GetString("request_id")
        ticket := strings.TrimSpace(c.GetHeader("X-Approval-Ticket"))
        if ticket == "" {
            c.JSON(403, api.Err(rid, "E1400", "ApprovalRequired", "缺少审批票据：请在请求头添加 X-Approval-Ticket", "warning", nil))
            c.Abort()
            return
        }
        allowed := loadApprovalTickets()
        if len(allowed) > 0 {
            ok := false
            for _, t := range allowed {
                if t == ticket {
                    ok = true
                    break
                }
            }
            if !ok {
                c.JSON(403, api.Err(rid, "E1401", "ApprovalInvalid", "审批票据无效或不在允许列表", "warning", nil))
                c.Abort()
                return
            }
        }
        c.Next()
    }
}

func loadApprovalTickets() []string {
    raw := os.Getenv("APPROVAL_TICKETS")
    if raw == "" {
        return nil
    }
    parts := strings.Split(raw, ",")
    out := make([]string, 0, len(parts))
    for _, p := range parts {
        p = strings.TrimSpace(p)
        if p != "" {
            out = append(out, p)
        }
    }
    return out
}