package middleware

import (
	"net"
	"os"
	"strconv"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"golang.org/x/time/rate"
	"xingzuo/internal/api"
)

type limiterEntry struct {
	limiter *rate.Limiter
	last    time.Time
}

var (
	mu       sync.Mutex
	limiters = make(map[string]*limiterEntry)
)

// RateLimit provides simple token-bucket rate limiting per client IP.
// Config via env: RATE_LIMIT_RPS (default 10), RATE_LIMIT_BURST (default 20).
func RateLimit() gin.HandlerFunc {
	rps := parseEnvInt("RATE_LIMIT_RPS", 10)
	burst := parseEnvInt("RATE_LIMIT_BURST", 20)
	cleanupTTL := 5 * time.Minute

	return func(c *gin.Context) {
		rid := c.GetString("request_id")
		ip := clientIP(c)
		limiter := getLimiter(ip, rps, burst)
		if !limiter.Allow() {
			c.JSON(429, api.Err(rid, "E1300", "RateLimited", "触发限流，请稍后重试", "warning", gin.H{"ip": ip}))
			c.Abort()
			return
		}
		// best-effort cleanup
		go cleanupOld(limiters, cleanupTTL)
		c.Next()
	}
}

func getLimiter(key string, rps, burst int) *rate.Limiter {
	mu.Lock()
	defer mu.Unlock()
	if e, ok := limiters[key]; ok {
		e.last = time.Now()
		return e.limiter
	}
	l := rate.NewLimiter(rate.Limit(rps), burst)
	limiters[key] = &limiterEntry{limiter: l, last: time.Now()}
	return l
}

func cleanupOld(m map[string]*limiterEntry, ttl time.Duration) {
	mu.Lock()
	defer mu.Unlock()
	now := time.Now()
	for k, e := range m {
		if now.Sub(e.last) > ttl {
			delete(m, k)
		}
	}
}

func clientIP(c *gin.Context) string {
	ip := c.ClientIP()
	// Normalize to host without port if any
	host, _, err := net.SplitHostPort(ip)
	if err == nil && host != "" {
		return host
	}
	return ip
}

func parseEnvInt(name string, def int) int {
	v := os.Getenv(name)
	if v == "" {
		return def
	}
	n, err := strconv.Atoi(v)
	if err != nil || n <= 0 {
		return def
	}
	return n
}
