package middleware

import (
    "crypto/hmac"
    "crypto/sha256"
    "encoding/base64"
    "encoding/json"
    "os"
    "strings"
    "time"

    "github.com/gin-gonic/gin"
    "xingzuo/internal/api"
)

// Auth enforces Bearer token authentication for API access.
// Allowed tokens come from env AUTH_TOKENS (comma-separated). If empty, defaults to "dev-token".
func Auth() gin.HandlerFunc {
    return func(c *gin.Context) {
        rid := c.GetString("request_id")
        auth := c.GetHeader("Authorization")
        if auth == "" {
            // WebSocket fallback: allow token/perms via Sec-WebSocket-Protocol
            // Browser WS cannot set arbitrary headers; we accept subprotocols: [token, permissions]
            // This applies only when the request is upgrading to WebSocket.
            connHdr := strings.ToLower(c.GetHeader("Connection"))
            upgrHdr := strings.ToLower(c.GetHeader("Upgrade"))
            if strings.Contains(connHdr, "upgrade") && upgrHdr == "websocket" {
                proto := c.GetHeader("Sec-WebSocket-Protocol")
                if proto != "" {
                    // e.g., "dev-token, ai.clarify"
                    parts := strings.Split(proto, ",")
                    token := strings.TrimSpace(parts[0])
                    perms := ""
                    if len(parts) > 1 {
                        perms = strings.TrimSpace(parts[1])
                    }
                    // Validate token against allowed list or dev-token
                    allowed := loadTokens()
                    if len(allowed) == 0 {
                        if token != "dev-token" {
                            c.JSON(401, api.Err(rid, "E1100", "AuthFailed", "无效token(WebSocket)", "warning", nil))
                            c.Abort()
                            return
                        }
                    } else {
                        ok := false
                        for _, t := range allowed {
                            if t == token {
                                ok = true
                                break
                            }
                        }
                        if !ok {
                            c.JSON(401, api.Err(rid, "E1100", "AuthFailed", "无效token(WebSocket)", "warning", nil))
                            c.Abort()
                            return
                        }
                    }
                    c.Set("auth_token", token)
                    if perms != "" {
                        c.Set("user_permissions", perms)
                    }
                    // Proceed without Bearer header
                    c.Next()
                    return
                }
            }
            c.JSON(401, api.Err(rid, "E1100", "AuthFailed", "请提供Authorization: Bearer <token>", "warning", nil))
            c.Abort()
            return
        }
        parts := strings.SplitN(auth, " ", 2)
        if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
            c.JSON(401, api.Err(rid, "E1100", "AuthFailed", "Authorization格式错误，应为Bearer", "warning", nil))
            c.Abort()
            return
        }
        token := strings.TrimSpace(parts[1])

        // If token looks like JWT (3 parts), validate HS256 signature and exp
        if looksLikeJWT(token) {
            if ok := validateJWT(c, token); !ok {
                // Invalid JWT should be rejected
                c.JSON(401, api.Err(rid, "E1100", "AuthFailed", "JWT 无效或已过期", "warning", nil))
                c.Abort()
                return
            }
            c.Set("auth_token", token)
            c.Next()
            return
        }

        // Fallback: opaque bearer token list (AUTH_TOKENS) and dev-token for local
        allowed := loadTokens()
        if len(allowed) == 0 {
            if token != "dev-token" {
                c.JSON(401, api.Err(rid, "E1100", "AuthFailed", "无效token", "warning", nil))
                c.Abort()
                return
            }
        } else {
            ok := false
            for _, t := range allowed {
                if t == token {
                    ok = true
                    break
                }
            }
            if !ok {
                c.JSON(401, api.Err(rid, "E1100", "AuthFailed", "无效token", "warning", nil))
                c.Abort()
                return
            }
        }
        c.Set("auth_token", token)
        c.Next()
    }
}

// looksLikeJWT performs a cheap check for JWT structure (three dot-separated parts)
func looksLikeJWT(tok string) bool {
    parts := strings.Split(tok, ".")
    return len(parts) == 3
}

// validateJWT validates HS256-signed JWT and sets context: user_id, user_permissions
func validateJWT(c *gin.Context, tok string) bool {
    parts := strings.Split(tok, ".")
    if len(parts) != 3 {
        return false
    }
    headerB64, payloadB64, sigB64 := parts[0], parts[1], parts[2]
    secret := os.Getenv("JWT_SECRET")
    if secret == "" {
        secret = "dev-secret"
    }
    mac := hmac.New(sha256.New, []byte(secret))
    mac.Write([]byte(headerB64 + "." + payloadB64))
    expected := base64.RawURLEncoding.EncodeToString(mac.Sum(nil))
    if !hmac.Equal([]byte(expected), []byte(sigB64)) {
        return false
    }
    // Decode payload
    payloadJSON, err := base64.RawURLEncoding.DecodeString(payloadB64)
    if err != nil {
        return false
    }
    var payload map[string]interface{}
    if err := json.Unmarshal(payloadJSON, &payload); err != nil {
        return false
    }
    // exp check
    if v, ok := payload["exp"].(float64); ok {
        if int64(v) <= time.Now().Unix() {
            return false
        }
    }
    // sub/userId
    if v, ok := payload["sub"].(string); ok && v != "" {
        c.Set("user_id", v)
    } else if v, ok := payload["userId"].(string); ok && v != "" {
        c.Set("user_id", v)
    }
    // permissions could be array or string
    if arr, ok := payload["permissions"].([]interface{}); ok {
        list := make([]string, 0, len(arr))
        for _, it := range arr {
            if s, ok := it.(string); ok && strings.TrimSpace(s) != "" {
                list = append(list, strings.TrimSpace(s))
            }
        }
        if len(list) > 0 {
            c.Set("user_permissions", strings.Join(list, ","))
        }
    } else if s, ok := payload["permissions"].(string); ok {
        c.Set("user_permissions", strings.TrimSpace(s))
    }
    return true
}

func loadTokens() []string {
    raw := os.Getenv("AUTH_TOKENS")
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
