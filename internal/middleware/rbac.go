package middleware

import (
    "strings"

    "github.com/gin-gonic/gin"
    "xingzuo/internal/api"
)

// RequirePermission enforces a simple header-based RBAC using X-User-Permissions (CSV).
func RequirePermission(required string) gin.HandlerFunc {
    return func(c *gin.Context) {
        perms := c.GetHeader("X-User-Permissions")
        if perms == "" {
            // Fallback to permissions extracted from JWT by Auth middleware
            if v, ok := c.Get("user_permissions"); ok {
                if s, ok := v.(string); ok {
                    perms = s
                }
            }
        }
        rid := c.GetString("request_id")
        if perms == "" {
            c.JSON(403, api.Err(rid, "E1200", "PermissionDenied", "缺少必要权限", "warning", gin.H{"required": required}))
            c.Abort()
            return
        }
        has := false
        for _, p := range strings.Split(perms, ",") {
            if strings.TrimSpace(p) == required {
                has = true
                break
            }
        }
        if !has {
            c.JSON(403, api.Err(rid, "E1200", "PermissionDenied", "权限不足", "warning", gin.H{"required": required}))
            c.Abort()
            return
        }
        c.Next()
    }
}
