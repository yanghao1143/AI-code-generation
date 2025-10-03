package main

import (
    "context"
    "os"
    "path/filepath"
    "strings"
    "time"

    "github.com/gin-gonic/gin"

    appcfg "xingzuo/backend/config"
    authPub "xingzuo/internal/auth"
    aiBackend "xingzuo/internal/ai/backend"
    aiFrontend "xingzuo/internal/ai/frontend"
    aiIntegration "xingzuo/internal/ai/integration"
    aiSpecs "xingzuo/internal/ai/specs"
    clarify "xingzuo/internal/clarify"
    "xingzuo/internal/api"
    "xingzuo/internal/articles"
    "xingzuo/internal/billing"
    "xingzuo/internal/fans"
    dbpkg "xingzuo/internal/db"
    llm "xingzuo/internal/llm"
    "xingzuo/internal/middleware"
    "xingzuo/internal/nlp"
    "xingzuo/internal/observe"
    "xingzuo/internal/replytemplates"
    "xingzuo/internal/registry"
    m "xingzuo/internal/model"
)

func main() {
    // Load global configuration (per APP_ENV), available via appcfg.Current()
    _ = appcfg.Load()
    // Initialize DB connection pool (from env), non-fatal if unavailable; /health/db will reflect status
    _, _ = dbpkg.InitFromEnv()

	r := gin.New()
	_ = r.SetTrustedProxies([]string{"127.0.0.1"})
	r.Use(gin.Logger(), gin.Recovery(), middleware.RequestID(), middleware.ErrorHandler())

    r.GET("/healthz", func(c *gin.Context) { c.String(200, "ok") })
    r.GET("/health/db", func(c *gin.Context) {
        ctx, cancel := context.WithTimeout(c.Request.Context(), 1500*time.Millisecond)
        defer cancel()
        if err := dbpkg.Health(ctx); err != nil {
            // Try lazy init if not initialized or previous ping failed
            if _, ierr := dbpkg.InitFromEnv(); ierr != nil {
                c.JSON(503, gin.H{"status": "unhealthy", "error": ierr.Error()})
                return
            }
            // Re-check after init
            if err2 := dbpkg.Health(ctx); err2 != nil {
                c.JSON(503, gin.H{"status": "unhealthy", "error": err2.Error()})
                return
            }
        }
        c.JSON(200, gin.H{"status": "ok"})
    })

	r.NoRoute(func(c *gin.Context) {
		rid := c.GetString("request_id")
		c.JSON(404, api.Err(rid, "E404", "NotFound", "检查路径或方法是否正确", "warning", gin.H{"path": c.Request.URL.Path}))
	})
	r.NoMethod(func(c *gin.Context) {
		rid := c.GetString("request_id")
		c.JSON(405, api.Err(rid, "E405", "MethodNotAllowed", "检查HTTP方法是否正确", "warning", gin.H{"method": c.Request.Method}))
	})

	v1 := r.Group("/api/v1")
	// Attach authentication and rate limit to API v1 group
	v1.Use(middleware.Auth(), middleware.RateLimit())
    aiFrontend.RegisterRoutes(v1.Group("/ai/frontend"))
    aiBackend.RegisterRoutes(v1.Group("/ai/backend"))
    aiIntegration.RegisterRoutes(v1.Group("/ai/integration"))
    aiSpecs.RegisterRoutes(v1.Group("/ai/specs"))
    clarify.RegisterRoutes(v1.Group("/ai/clarify"))
    llm.RegisterRoutes(v1.Group("/llm"))
    articles.RegisterRoutes(v1.Group("/articles"))
    // Fans: existing conversation routes + new CRUD routes
    fans.RegisterRoutes(v1.Group("/fans"))
    fans.RegisterCRUDRoutes(v1.Group("/fans"))
    billing.RegisterRoutes(v1.Group("/billing"))
    observe.RegisterRoutes(v1.Group("/observe"))
    replytemplates.RegisterRoutes(v1.Group("/reply_templates"))
    registry.RegisterRoutes(v1)

    // Alias API group for Clarify under /api/clarify (compat with spec tasks)
    // Attach same Auth + RateLimit middlewares as /api/v1
    api := r.Group("/api")
    api.Use(middleware.Auth(), middleware.RateLimit())
    clarify.RegisterRoutes(api.Group("/clarify"))

    // Optional: auto-register CRUD placeholders from DomainModel
    // Enable via env AUTO_CRUD_ENABLE=true (or 1)
    // Optionally derive DomainModel from planning doc when AUTO_CRUD_FROM_PRD=true
    if func() bool { v := os.Getenv("AUTO_CRUD_ENABLE"); return strings.EqualFold(v, "true") || v == "1" }() {
        var dm m.DomainModel
        if strings.EqualFold(os.Getenv("AUTO_CRUD_FROM_PRD"), "true") {
            if wd, err := os.Getwd(); err == nil {
                src := filepath.Join(wd, ".spec-workflow", "sources", "策划.md")
                if data, err := os.ReadFile(src); err == nil {
                    if parsed, _ := nlp.Parse(string(data)); len(parsed.Entities) > 0 {
                        dm = parsed
                    }
                }
            }
        }
        registry.RegisterAutoCRUD(v1, dm)
    }

	// Public endpoints (no Auth middleware): login issuing JWT
	public := r.Group("/api/public")
	authPub.RegisterRoutes(public.Group("/auth"))

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	_ = r.Run(":" + port)
}
