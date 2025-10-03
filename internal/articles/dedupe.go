package articles

import (
	"context"
	"os"
	"strconv"
	"sync"
	"time"

	redis "github.com/redis/go-redis/v9"
)

// Deduper defines a pluggable store for cross-instance de-duplication.
type Deduper interface {
	Seen(id string) bool
	Mark(id string)
	Close() error
}

// MemoryDeduper implements Deduper with in-process memory.
type MemoryDeduper struct {
	mu   sync.RWMutex
	seen map[string]struct{}
}

func NewMemoryDeduper() *MemoryDeduper { return &MemoryDeduper{seen: map[string]struct{}{}} }

func (m *MemoryDeduper) Seen(id string) bool {
	m.mu.RLock()
	_, ok := m.seen[id]
	m.mu.RUnlock()
	return ok
}

func (m *MemoryDeduper) Mark(id string) {
	m.mu.Lock()
	m.seen[id] = struct{}{}
	m.mu.Unlock()
}

func (m *MemoryDeduper) Close() error { return nil }

// RedisDeduper implements Deduper using Redis SETNX with TTL for multi-instance scaling.
type RedisDeduper struct {
	cli *redis.Client
	ttl time.Duration
	pfx string
}

func NewRedisDeduper(addr string, password string, db int, ttlMs int, keyPrefix string) *RedisDeduper {
	cli := redis.NewClient(&redis.Options{Addr: addr, Password: password, DB: db})
	ttl := time.Duration(ttlMs) * time.Millisecond
	if ttl <= 0 {
		ttl = 10 * time.Minute
	}
	if keyPrefix == "" {
		keyPrefix = "articles:seen:"
	}
	return &RedisDeduper{cli: cli, ttl: ttl, pfx: keyPrefix}
}

func NewRedisDeduperFromEnv() (*RedisDeduper, error) {
	addr := os.Getenv("REDIS_ADDR")
	if addr == "" {
		return nil, os.ErrNotExist
	}
	pwd := os.Getenv("REDIS_PASSWORD")
	db := 0
	if v := os.Getenv("REDIS_DB"); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			db = n
		}
	}
	ttlMs := 600000
	if v := os.Getenv("ARTICLES_DEDUP_TTL_MS"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 {
			ttlMs = n
		}
	}
	pfx := os.Getenv("ARTICLES_DEDUP_KEY_PREFIX")
	d := NewRedisDeduper(addr, pwd, db, ttlMs, pfx)
	// simple ping to validate connectivity; ignore error to allow lazy init
	_ = d.cli.Ping(context.Background()).Err()
	return d, nil
}

func (r *RedisDeduper) key(id string) string { return r.pfx + id }

func (r *RedisDeduper) Seen(id string) bool {
	cnt, err := r.cli.Exists(context.Background(), r.key(id)).Result()
	if err != nil {
		// On error, fallback to not seen to avoid dropping events
		return false
	}
	return cnt > 0
}

func (r *RedisDeduper) Mark(id string) {
	// SETNX key to avoid races across instances
	_, _ = r.cli.SetNX(context.Background(), r.key(id), 1, r.ttl).Result()
}

func (r *RedisDeduper) Close() error { return r.cli.Close() }
