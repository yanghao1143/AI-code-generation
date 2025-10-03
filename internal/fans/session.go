package fans

import (
    "context"
    "sync"
    "time"

    redis "github.com/redis/go-redis/v9"
    "xingzuo/backend/config"
)

// ActiveSessionStore defines the persistence operations for fan active conversations.
// Implementations must ensure concurrency-safe, atomic acquisition semantics.
type ActiveSessionStore interface {
    // GetActive returns the current active conversationId for a fan, or false if none.
    GetActive(fanId string) (string, bool)
    // SetActive attempts to set conversationId as active for the fan.
    // Returns true on success or idempotent same-value set; false on conflict or error.
    SetActive(fanId, conversationId string) bool
    // ClearActive releases any active conversation for the fan (idempotent).
    ClearActive(fanId string)
}

// MemorySessionStore: thread-safe in-memory store (default fallback).
type MemorySessionStore struct {
    mu sync.RWMutex
    m  map[string]string
}

func newMemorySessionStore() *MemorySessionStore {
    return &MemorySessionStore{m: make(map[string]string)}
}

func (s *MemorySessionStore) GetActive(fanId string) (string, bool) {
    s.mu.RLock()
    defer s.mu.RUnlock()
    v, ok := s.m[fanId]
    return v, ok
}

func (s *MemorySessionStore) SetActive(fanId, conversationId string) bool {
    s.mu.Lock()
    defer s.mu.Unlock()
    if existing, ok := s.m[fanId]; ok && existing != "" && existing != conversationId {
        return false
    }
    s.m[fanId] = conversationId
    return true
}

func (s *MemorySessionStore) ClearActive(fanId string) {
    s.mu.Lock()
    defer s.mu.Unlock()
    delete(s.m, fanId)
}

// RedisSessionStore: persistence using Redis with atomic acquisition via SET NX PX TTL.
type RedisSessionStore struct {
    cli      *redis.Client
    prefix   string
    ttl      time.Duration
    ctx      context.Context
}

func newRedisSessionStore(addr, password string, db int, prefix string, ttlMs int) *RedisSessionStore {
    if ttlMs <= 0 {
        ttlMs = 600000 // default 10 minutes
    }
    return &RedisSessionStore{
        cli: redis.NewClient(&redis.Options{Addr: addr, Password: password, DB: db}),
        prefix: prefix,
        ttl: time.Duration(ttlMs) * time.Millisecond,
        ctx: context.Background(),
    }
}

func (r *RedisSessionStore) key(fanId string) string { return r.prefix + fanId }

func (r *RedisSessionStore) GetActive(fanId string) (string, bool) {
    val, err := r.cli.Get(r.ctx, r.key(fanId)).Result()
    if err == redis.Nil {
        return "", false
    }
    if err != nil {
        return "", false
    }
    return val, true
}

func (r *RedisSessionStore) SetActive(fanId, conversationId string) bool {
    key := r.key(fanId)
    // First try atomic acquire with TTL
    ok, err := r.cli.SetNX(r.ctx, key, conversationId, r.ttl).Result()
    if err == nil && ok {
        return true
    }
    // If already exists with same value, treat as idempotent success and refresh TTL
    val, err := r.cli.Get(r.ctx, key).Result()
    if err == nil && val == conversationId {
        _ = r.cli.Expire(r.ctx, key, r.ttl).Err()
        return true
    }
    // Conflict or error
    return false
}

func (r *RedisSessionStore) ClearActive(fanId string) {
    _ = r.cli.Del(r.ctx, r.key(fanId)).Err()
}

// defaultSessions holds the chosen implementation based on backend config.
var defaultSessions ActiveSessionStore = chooseSessionStore()

func chooseSessionStore() ActiveSessionStore {
    cfg := config.Current()
    backend := "memory"
    prefix := "sessions:active:"
    ttlMs := 600000
    if cfg != nil {
        if cfg.Sessions.Backend != "" {
            backend = cfg.Sessions.Backend
        }
        if cfg.Sessions.KeyPrefix != "" {
            prefix = cfg.Sessions.KeyPrefix
        }
        if cfg.Sessions.ActiveTTLMs > 0 {
            ttlMs = cfg.Sessions.ActiveTTLMs
        }
        // If backend not explicitly set but Redis addr provided, prefer redis
        if backend == "" && cfg.Sessions.RedisAddr != "" {
            backend = "redis"
        }
        if backend == "redis" && cfg.Sessions.RedisAddr != "" {
            return newRedisSessionStore(cfg.Sessions.RedisAddr, cfg.Sessions.RedisPassword, cfg.Sessions.RedisDB, prefix, ttlMs)
        }
    }
    return newMemorySessionStore()
}