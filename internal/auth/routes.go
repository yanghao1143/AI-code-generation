package auth

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
    "xingzuo/internal/validation"
)

type LoginRequest struct {
    UserID       string   `json:"userId"`
    Permissions  []string `json:"permissions"`
    ExpiresInSec int      `json:"expiresInSec"`
}

type LoginResponse struct {
    Token       string   `json:"token"`
    UserID      string   `json:"userId"`
    Permissions []string `json:"permissions"`
    ExpiresAt   int64    `json:"expiresAt"`
}

func base64url(b []byte) string {
    return base64.RawURLEncoding.EncodeToString(b)
}

func signHS256(header, payload []byte, secret string) string {
    signingInput := base64url(header) + "." + base64url(payload)
    mac := hmac.New(sha256.New, []byte(secret))
    mac.Write([]byte(signingInput))
    sig := mac.Sum(nil)
    return signingInput + "." + base64url(sig)
}

// RegisterRoutes registers public auth endpoints under /api/public/auth
// POST /login -> issues HS256 JWT with sub, permissions, exp
func RegisterRoutes(r *gin.RouterGroup) {
    r.POST("/login", func(c *gin.Context) {
        rid := c.GetString("request_id")
        var req LoginRequest
        if !validation.BindJSON(c, &req) {
            return
        }
        uid := strings.TrimSpace(req.UserID)
        if uid == "" {
            uid = "u1"
        }
        perms := req.Permissions
        if len(perms) == 0 {
            perms = []string{"articles"}
        }
        expires := req.ExpiresInSec
        if expires <= 0 {
            expires = 3600
        }
        exp := time.Now().Add(time.Duration(expires) * time.Second).Unix()

        // Build header and payload
        header := map[string]string{"alg": "HS256", "typ": "JWT"}
        payload := map[string]interface{}{"sub": uid, "permissions": perms, "exp": exp}
        hb, _ := json.Marshal(header)
        pb, _ := json.Marshal(payload)

        secret := os.Getenv("JWT_SECRET")
        if secret == "" {
            secret = "dev-secret"
        }
        token := signHS256(hb, pb, secret)

        c.JSON(200, api.OK(rid, LoginResponse{Token: token, UserID: uid, Permissions: perms, ExpiresAt: exp}))
    })
}