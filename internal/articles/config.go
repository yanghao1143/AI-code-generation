package articles

import (
	"os"
	"strconv"
	appcfg "xingzuo/backend/config"
)

// Centralized configuration for Articles SSE and listing behavior.
// Keeping small, explicit defaults to make tests and preview snappy.

const (
	// Heartbeat interval bounds (milliseconds)
	HeartbeatDefaultMs = 5
	HeartbeatMinMs     = 1
	HeartbeatMaxMs     = 10000

	// List pagination defaults and bounds
	ListPageSizeDefault = 10
	ListPageSizeMin     = 1
	ListPageSizeMax     = 1000

	// Follow mode max streaming duration (milliseconds)
	// Default is short to avoid hanging previews/tests; clients can override.
	FollowMaxMsDefault = 2000
	FollowMaxMsMin     = 1
	FollowMaxMsMax     = 60000

	// Follow buffering configuration
	FollowBufferMsDefault = 10  // aggregate new items within buffer window before flushing
	FollowBatchMaxDefault = 100 // max items per flush batch
)

// Env-driven getters for ops adjustable configuration.
// Each getter clamps values within safe bounds.

func CfgHeartbeatDefaultMs() int {
	if cfg := appcfg.Current(); cfg != nil && cfg.Articles.HeartbeatDefaultMs > 0 {
		return clamp(cfg.Articles.HeartbeatDefaultMs, CfgHeartbeatMinMs(), CfgHeartbeatMaxMs())
	}
	if v := getenvInt("ARTICLES_HEARTBEAT_DEFAULT_MS"); v > 0 {
		return clamp(v, CfgHeartbeatMinMs(), CfgHeartbeatMaxMs())
	}
	return HeartbeatDefaultMs
}

func CfgHeartbeatMinMs() int {
	if cfg := appcfg.Current(); cfg != nil && cfg.Articles.HeartbeatMinMs > 0 {
		return cfg.Articles.HeartbeatMinMs
	}
	if v := getenvInt("ARTICLES_HEARTBEAT_MIN_MS"); v > 0 {
		return v
	}
	return HeartbeatMinMs
}

func CfgHeartbeatMaxMs() int {
	if cfg := appcfg.Current(); cfg != nil && cfg.Articles.HeartbeatMaxMs > 0 {
		return cfg.Articles.HeartbeatMaxMs
	}
	if v := getenvInt("ARTICLES_HEARTBEAT_MAX_MS"); v > 0 {
		return v
	}
	return HeartbeatMaxMs
}

func CfgListPageSizeDefault() int {
	if cfg := appcfg.Current(); cfg != nil && cfg.Articles.ListPageSizeDefault > 0 {
		return clamp(cfg.Articles.ListPageSizeDefault, CfgListPageSizeMin(), CfgListPageSizeMax())
	}
	if v := getenvInt("ARTICLES_LIST_PAGESIZE_DEFAULT"); v > 0 {
		return clamp(v, CfgListPageSizeMin(), CfgListPageSizeMax())
	}
	return ListPageSizeDefault
}

func CfgListPageSizeMin() int {
	if cfg := appcfg.Current(); cfg != nil && cfg.Articles.ListPageSizeMin > 0 {
		return cfg.Articles.ListPageSizeMin
	}
	if v := getenvInt("ARTICLES_LIST_PAGESIZE_MIN"); v > 0 {
		return v
	}
	return ListPageSizeMin
}

func CfgListPageSizeMax() int {
	if cfg := appcfg.Current(); cfg != nil && cfg.Articles.ListPageSizeMax > 0 {
		return cfg.Articles.ListPageSizeMax
	}
	if v := getenvInt("ARTICLES_LIST_PAGESIZE_MAX"); v > 0 {
		return v
	}
	return ListPageSizeMax
}

func CfgFollowMaxMsDefault() int {
	if cfg := appcfg.Current(); cfg != nil && cfg.Articles.FollowMaxMsDefault > 0 {
		return clamp(cfg.Articles.FollowMaxMsDefault, CfgFollowMaxMsMin(), CfgFollowMaxMsMax())
	}
	if v := getenvInt("ARTICLES_FOLLOW_MAX_MS_DEFAULT"); v > 0 {
		return clamp(v, CfgFollowMaxMsMin(), CfgFollowMaxMsMax())
	}
	return FollowMaxMsDefault
}

func CfgFollowMaxMsMin() int {
	if cfg := appcfg.Current(); cfg != nil && cfg.Articles.FollowMaxMsMin > 0 {
		return cfg.Articles.FollowMaxMsMin
	}
	if v := getenvInt("ARTICLES_FOLLOW_MAX_MS_MIN"); v > 0 {
		return v
	}
	return FollowMaxMsMin
}

func CfgFollowMaxMsMax() int {
	if cfg := appcfg.Current(); cfg != nil && cfg.Articles.FollowMaxMsMax > 0 {
		return cfg.Articles.FollowMaxMsMax
	}
	if v := getenvInt("ARTICLES_FOLLOW_MAX_MS_MAX"); v > 0 {
		return v
	}
	return FollowMaxMsMax
}

func CfgFollowBufferMsDefault() int {
	if cfg := appcfg.Current(); cfg != nil && cfg.Articles.FollowBufferMsDefault > 0 {
		return cfg.Articles.FollowBufferMsDefault
	}
	if v := getenvInt("ARTICLES_FOLLOW_BUFFER_MS_DEFAULT"); v > 0 {
		return v
	}
	return FollowBufferMsDefault
}

func CfgFollowBatchMaxDefault() int {
	if cfg := appcfg.Current(); cfg != nil && cfg.Articles.FollowBatchMaxDefault > 0 {
		return cfg.Articles.FollowBatchMaxDefault
	}
	if v := getenvInt("ARTICLES_FOLLOW_BATCH_MAX_DEFAULT"); v > 0 {
		return v
	}
	return FollowBatchMaxDefault
}

// helpers
func getenvInt(key string) int {
	if s := os.Getenv(key); s != "" {
		if v, err := strconv.Atoi(s); err == nil {
			return v
		}
	}
	return 0
}

func clamp(v, min, max int) int {
	if v < min {
		return min
	}
	if v > max {
		return max
	}
	return v
}
