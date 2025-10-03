package llm

import (
	"encoding/json"
	"os"
	"strings"
	"sync"
)

var (
	cfgOnce   sync.Once
	providers []ProviderInfo
	models    []ModelInfo
)

// initConfig loads providers and models from environment variables, with sensible defaults.
func initConfig() {
	// Providers: prefer JSON via LLM_PROVIDERS_JSON, fallback to CSV via LLM_PROVIDERS (id:name:status;...)
	if pj := os.Getenv("LLM_PROVIDERS_JSON"); pj != "" {
		_ = json.Unmarshal([]byte(pj), &providers)
	}
	if len(providers) == 0 {
		if pv := os.Getenv("LLM_PROVIDERS"); pv != "" {
			// Format: id:name:status;id:name:status
			parts := strings.Split(pv, ";")
			for _, p := range parts {
				fields := strings.Split(p, ":")
				if len(fields) >= 2 {
					status := "enabled"
					if len(fields) >= 3 {
						status = fields[2]
					}
					providers = append(providers, ProviderInfo{ID: fields[0], Name: fields[1], Status: status})
				}
			}
		}
	}
	if len(providers) == 0 {
		// Defaults align with earlier placeholders
		providers = []ProviderInfo{
			{ID: "baidu", Name: "Baidu ERNIE", Status: "enabled"},
			{ID: "ali", Name: "Ali Qwen", Status: "enabled"},
			{ID: "tencent", Name: "Tencent Hunyuan", Status: "enabled"},
		}
	}

	// Models: prefer JSON via LLM_MODELS_JSON
	if mj := os.Getenv("LLM_MODELS_JSON"); mj != "" {
		_ = json.Unmarshal([]byte(mj), &models)
	}
	if len(models) == 0 {
		// Defaults
		models = []ModelInfo{
			{ProviderID: "baidu", ModelID: "ernie-4.0", Capabilities: []string{"text"}},
			{ProviderID: "ali", ModelID: "qwen-turbo", Capabilities: []string{"text"}},
			{ProviderID: "tencent", ModelID: "hunyuan-lite", Capabilities: []string{"text"}},
		}
	}
}

// Providers returns configured LLM providers.
func Providers() []ProviderInfo {
	cfgOnce.Do(initConfig)
	return providers
}

// Models returns configured LLM models.
func Models() []ModelInfo {
	cfgOnce.Do(initConfig)
	return models
}
