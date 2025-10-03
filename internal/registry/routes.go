package registry

import (
	"github.com/gin-gonic/gin"
	"os"
	"runtime"
	"runtime/debug"
	"strconv"
	"time"
	appcfg "xingzuo/backend/config"
	"xingzuo/internal/api"
	art "xingzuo/internal/articles"
)

// processStart records the approximate service start time for uptime reporting.
var processStart = time.Now()

// RegisterRoutes registers the unified API registry endpoint.
func RegisterRoutes(r *gin.RouterGroup) {
    // OpenAPI spec (runtime generated)
    r.GET("/openapi", func(c *gin.Context) {
        rid := c.GetString("request_id")
        spec := BuildOpenAPISpec()
        c.JSON(200, api.OK(rid, spec))
    })

    r.GET("/registry", func(c *gin.Context) {
        rid := c.GetString("request_id")
        cfg := appcfg.Current()
		// Collect lightweight runtime metrics
		var ms runtime.MemStats
		runtime.ReadMemStats(&ms)
		// Collect build metadata (Go module info and optional env overrides)
		info, ok := debug.ReadBuildInfo()
		var goVer, modMain, vcsRev, vcsTime string
		var vcsMod bool
		var depsCount int
		if ok && info != nil {
			goVer = info.GoVersion
			modMain = info.Main.Path
			depsCount = len(info.Deps)
			for _, s := range info.Settings {
				switch s.Key {
				case "vcs.revision":
					vcsRev = s.Value
				case "vcs.time":
					vcsTime = s.Value
				case "vcs.modified":
					vcsMod = (s.Value == "true")
				}
			}
		} else {
			goVer = runtime.Version()
		}
		now := time.Now()
		c.JSON(200, api.OK(rid, gin.H{
			"version": "v1",
			"env": func() string {
				if cfg != nil {
					return cfg.Env
				}
				return "dev"
			}(),
			"build": gin.H{
				"version":    os.Getenv("BUILD_VERSION"),
				"gitSha":     os.Getenv("GIT_SHA"),
				"buildTime":  os.Getenv("BUILD_TIME"),
				"goVersion":  goVer,
				"moduleMain": modMain,
				"deps":       depsCount,
				"vcs": gin.H{
					"revision": vcsRev,
					"time":     vcsTime,
					"modified": vcsMod,
				},
			},
			"config": gin.H{
				"articles": gin.H{
					"heartbeatDefaultMs": func() int {
						if cfg != nil {
							return cfg.Articles.HeartbeatDefaultMs
						}
						return 0
					}(),
					"heartbeatMinMs": func() int {
						if cfg != nil {
							return cfg.Articles.HeartbeatMinMs
						}
						return 0
					}(),
					"heartbeatMaxMs": func() int {
						if cfg != nil {
							return cfg.Articles.HeartbeatMaxMs
						}
						return 0
					}(),
					"listPageSizeDefault": func() int {
						if cfg != nil {
							return cfg.Articles.ListPageSizeDefault
						}
						return 0
					}(),
					"listPageSizeMin": func() int {
						if cfg != nil {
							return cfg.Articles.ListPageSizeMin
						}
						return 0
					}(),
					"listPageSizeMax": func() int {
						if cfg != nil {
							return cfg.Articles.ListPageSizeMax
						}
						return 0
					}(),
					"followMaxMsDefault": func() int {
						if cfg != nil {
							return cfg.Articles.FollowMaxMsDefault
						}
						return 0
					}(),
					"followMaxMsMin": func() int {
						if cfg != nil {
							return cfg.Articles.FollowMaxMsMin
						}
						return 0
					}(),
					"followMaxMsMax": func() int {
						if cfg != nil {
							return cfg.Articles.FollowMaxMsMax
						}
						return 0
					}(),
					"followBufferMsDefault": func() int {
						if cfg != nil {
							return cfg.Articles.FollowBufferMsDefault
						}
						return 0
					}(),
					"followBatchMaxDefault": func() int {
						if cfg != nil {
							return cfg.Articles.FollowBatchMaxDefault
						}
						return 0
					}(),
					// Dedupe runtime/config snapshot
					"dedupe": gin.H{
						"backend": func() string {
							if v := os.Getenv("DEDUPER_BACKEND"); v != "" {
								return v
							}
							if os.Getenv("REDIS_ADDR") != "" {
								return "redis"
							}
							return "memory"
						}(),
						"ttlMs": func() int {
							if v := os.Getenv("ARTICLES_DEDUP_TTL_MS"); v != "" {
								if n, err := strconv.Atoi(v); err == nil && n > 0 {
									return n
								}
							}
							return 600000 // default aligns with RedisDeduper
						}(),
						"keyPrefix": func() string {
							if v := os.Getenv("ARTICLES_DEDUP_KEY_PREFIX"); v != "" {
								return v
							}
							return "articles:seen:"
						}(),
						"redis": gin.H{
							"addr":        os.Getenv("REDIS_ADDR"),
							"passwordSet": func() bool { return os.Getenv("REDIS_PASSWORD") != "" }(),
							"db": func() int {
								if v := os.Getenv("REDIS_DB"); v != "" {
									if n, err := strconv.Atoi(v); err == nil {
										return n
									}
								}
								return 0
							}(),
						},
					},
				},
				// Runtime snapshot
				"runtime": gin.H{
					"port": func() string {
						if v := os.Getenv("PORT"); v != "" {
							return v
						}
						return "8080"
					}(),
					"rateLimit": gin.H{
						"rps": func() int {
							if v := os.Getenv("RATE_LIMIT_RPS"); v != "" {
								if n, err := strconv.Atoi(v); err == nil && n > 0 {
									return n
								}
							}
							return 5
						}(),
						"burst": func() int {
							if v := os.Getenv("RATE_LIMIT_BURST"); v != "" {
								if n, err := strconv.Atoi(v); err == nil && n > 0 {
									return n
								}
							}
							return 10
						}(),
					},
					// Effective SSE heartbeat settings (env-resolved and clamped)
					"sse": gin.H{
						"heartbeat": gin.H{
							"defaultMs": art.CfgHeartbeatDefaultMs(),
							"minMs":     art.CfgHeartbeatMinMs(),
							"maxMs":     art.CfgHeartbeatMaxMs(),
						},
					},
					// Process metrics for quick ops observability
					"metrics": gin.H{
						"startTime":  processStart.UTC().Format(time.RFC3339),
						"uptimeMs":   now.Sub(processStart).Milliseconds(),
						"goroutines": runtime.NumGoroutine(),
						"memory": gin.H{
							"allocBytes": ms.Alloc,
							"sysBytes":   ms.Sys,
							"numGC":      ms.NumGC,
						},
					},
				},
			},
            "services": gin.H{
                "ai.clarify": gin.H{
                    "endpoints": []string{
                        "/api/v1/ai/clarify/generate",
                        "/api/v1/ai/clarify/stream",
                        "/api/v1/ai/clarify/stream/ws",
                        "/api/v1/ai/clarify/export",
                        "/api/v1/ai/clarify/export/pdf",
                        "/api/v1/ai/clarify/export/docx",
                        "/api/v1/ai/clarify/docs/:name",
                    },
                },
                // Alias service entry to surface /api/clarify* endpoints
                "clarify": gin.H{
                    "endpoints": []string{
                        "/api/clarify/generate",
                        "/api/clarify/stream",
                        "/api/clarify/stream/ws",
                        "/api/clarify/export",
                        "/api/clarify/export/pdf",
                        "/api/clarify/export/docx",
                        "/api/clarify/docs/:name",
                    },
                },
                "ai.frontend": gin.H{
                    "endpoints": []string{"/api/v1/ai/frontend/generate", "/api/v1/ai/frontend/validate", "/api/v1/ai/frontend/templates", "/api/v1/ai/frontend/commit"},
                },
                "ai.backend": gin.H{
                    "endpoints": []string{"/api/v1/ai/backend/generate", "/api/v1/ai/backend/scaffold", "/api/v1/ai/backend/fix", "/api/v1/ai/backend/templates"},
                },
                "ai.integration": gin.H{
                    "endpoints": []string{"/api/v1/ai/integration/test", "/api/v1/ai/integration/diagnose", "/api/v1/ai/integration/patch", "/api/v1/ai/integration/reports"},
                },
                "ai.specs": gin.H{
                    "endpoints": []string{"/api/v1/ai/specs/generate"},
                },
                "llm": gin.H{
                    "endpoints": []string{"/api/v1/llm/providers", "/api/v1/llm/models", "/api/v1/llm/chat", "/api/v1/llm/embeddings", "/api/v1/llm/moderate"},
                },
                "articles": gin.H{
                    "endpoints": []string{"/api/v1/articles", "/api/v1/articles/:id", "/api/v1/articles/stream"},
				},
				"billing": gin.H{
					"endpoints": []string{"/api/v1/billing/orders", "/api/v1/billing/payments", "/api/v1/billing/plans", "/api/v1/billing/invoices"},
				},
				"observe": gin.H{
					"endpoints": []string{"/api/v1/observe/metrics", "/api/v1/observe/traces", "/api/v1/observe/events"},
				},
			},
		}))
	})

	// Provide an OpenAPI 3.0 spec reflecting current endpoints using builder
	r.GET("/registry/openapi", func(c *gin.Context) {
		rid := c.GetString("request_id")
		spec := BuildOpenAPISpec()
		c.JSON(200, api.OK(rid, spec))
	})
}
