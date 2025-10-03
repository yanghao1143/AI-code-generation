package config

import (
    "encoding/json"
    "os"
    "path/filepath"
    "strconv"
    "sync"
)

// Config represents global, per-environment configuration loaded at startup.
type Config struct {
    Env      string       `json:"env"`
    Articles ArticlesConf `json:"articles"`
    Sessions SessionsConf `json:"sessions"`
}

// ArticlesConf holds Articles module tuning knobs.
type ArticlesConf struct {
    HeartbeatDefaultMs    int `json:"heartbeatDefaultMs"`
    HeartbeatMinMs        int `json:"heartbeatMinMs"`
    HeartbeatMaxMs        int `json:"heartbeatMaxMs"`
    ListPageSizeDefault   int `json:"listPageSizeDefault"`
    ListPageSizeMin       int `json:"listPageSizeMin"`
    ListPageSizeMax       int `json:"listPageSizeMax"`
    FollowMaxMsDefault    int `json:"followMaxMsDefault"`
    FollowMaxMsMin        int `json:"followMaxMsMin"`
    FollowMaxMsMax        int `json:"followMaxMsMax"`
    FollowBufferMsDefault int `json:"followBufferMsDefault"`
    FollowBatchMaxDefault int `json:"followBatchMaxDefault"`
}

// SessionsConf holds Fan Session Uniqueness persistence settings.
// Backend options: "memory" (default) or "redis".
// Redis connection parameters are shared via REDIS_* envs.
type SessionsConf struct {
    Backend       string `json:"backend"`
    ActiveTTLMs   int    `json:"activeTTLMs"`
    KeyPrefix     string `json:"keyPrefix"`
    RedisAddr     string `json:"redisAddr"`
    RedisPassword string `json:"redisPassword"`
    RedisDB       int    `json:"redisDb"`
}

var (
	current *Config
	once    sync.Once
)

// Current returns the loaded global configuration (may be nil if Load was not called).
func Current() *Config { return current }

// Load reads configuration from backend/config/<env>.json if present and overlays with env vars.
// Env is selected via APP_ENV (dev|staging|prod), default "dev".
func Load() *Config {
    once.Do(func() {
        env := os.Getenv("APP_ENV")
        if env == "" {
            env = "dev"
        }
        cfg := &Config{Env: env}

		// Attempt to read JSON file
		p := filepath.Join("backend", "config", env+".json")
		if b, err := os.ReadFile(p); err == nil && len(b) > 0 {
			_ = json.Unmarshal(b, cfg)
		}

        // Overlay with env vars if provided
        setInt := func(key string, dst *int) {
            if v := os.Getenv(key); v != "" {
                if iv, err := strconv.Atoi(v); err == nil {
                    *dst = iv
                }
            }
        }
        setStr := func(key string, dst *string) {
            if v := os.Getenv(key); v != "" {
                *dst = v
            }
        }

        setInt("ARTICLES_HEARTBEAT_DEFAULT_MS", &cfg.Articles.HeartbeatDefaultMs)
        setInt("ARTICLES_HEARTBEAT_MIN_MS", &cfg.Articles.HeartbeatMinMs)
        setInt("ARTICLES_HEARTBEAT_MAX_MS", &cfg.Articles.HeartbeatMaxMs)
        setInt("ARTICLES_LIST_PAGESIZE_DEFAULT", &cfg.Articles.ListPageSizeDefault)
        setInt("ARTICLES_LIST_PAGESIZE_MIN", &cfg.Articles.ListPageSizeMin)
        setInt("ARTICLES_LIST_PAGESIZE_MAX", &cfg.Articles.ListPageSizeMax)
        setInt("ARTICLES_FOLLOW_MAX_MS_DEFAULT", &cfg.Articles.FollowMaxMsDefault)
        setInt("ARTICLES_FOLLOW_MAX_MS_MIN", &cfg.Articles.FollowMaxMsMin)
        setInt("ARTICLES_FOLLOW_MAX_MS_MAX", &cfg.Articles.FollowMaxMsMax)
        setInt("ARTICLES_FOLLOW_BUFFER_MS_DEFAULT", &cfg.Articles.FollowBufferMsDefault)
        setInt("ARTICLES_FOLLOW_BATCH_MAX_DEFAULT", &cfg.Articles.FollowBatchMaxDefault)

        // Fan Session Uniqueness persistence config
        setStr("SESSION_BACKEND", &cfg.Sessions.Backend)
        setInt("SESSION_ACTIVE_TTL_MS", &cfg.Sessions.ActiveTTLMs)
        setStr("SESSION_KEY_PREFIX", &cfg.Sessions.KeyPrefix)
        // Shared Redis connection (reused by sessions)
        setStr("REDIS_ADDR", &cfg.Sessions.RedisAddr)
        setStr("REDIS_PASSWORD", &cfg.Sessions.RedisPassword)
        setInt("REDIS_DB", &cfg.Sessions.RedisDB)

        current = cfg
    })
    return current
}
