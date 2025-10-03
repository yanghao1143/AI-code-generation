package llm

import "context"

// Message represents a single chat message.
type Message struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

// ChatRequest is the unified chat request payload.
type ChatRequest struct {
	ProviderHint string    `json:"providerHint,omitempty"`
	ModelID      string    `json:"modelId"`
	Messages     []Message `json:"messages"`
	Stream       bool      `json:"stream,omitempty"`
	Temperature  float64   `json:"temperature,omitempty"`
	TopP         float64   `json:"topP,omitempty"`
}

// Usage captures token usage metrics.
type Usage struct {
	Prompt     int `json:"prompt"`
	Completion int `json:"completion"`
}

// Choice represents a single assistant choice.
type Choice struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

// ChatResponse is the unified chat response payload.
type ChatResponse struct {
	ID      string   `json:"id"`
	ModelID string   `json:"modelId"`
	Usage   Usage    `json:"usage"`
	Choices []Choice `json:"choices"`
}

// EmbeddingsRequest represents an embeddings generation request.
type EmbeddingsRequest struct {
	ModelID string   `json:"modelId"`
	Input   []string `json:"input"`
}

// EmbeddingsResponse represents the embeddings generation result.
type EmbeddingsResponse struct {
	ModelID string      `json:"modelId"`
	Dims    int         `json:"dims"`
	Vectors [][]float64 `json:"vectors"`
}

// ModerateRequest represents a content moderation request.
type ModerateRequest struct {
	Input string `json:"input"`
}

// ModerateResponse represents a content moderation result.
type ModerateResponse struct {
	Result string   `json:"result"`
	Flags  []string `json:"flags"`
}

// ModelInfo describes an available model and its capabilities.
type ModelInfo struct {
	ProviderID      string   `json:"providerId"`
	ModelID         string   `json:"modelId"`
	Capabilities    []string `json:"capabilities,omitempty"`
	MaxTokens       int      `json:"maxTokens,omitempty"`
	CostPer1KTokens float64  `json:"costPer1KTokens,omitempty"`
	Status          string   `json:"status,omitempty"`
}

// ProviderInfo describes an LLM provider.
type ProviderInfo struct {
	ID     string `json:"id"`
	Name   string `json:"name"`
	Status string `json:"status"` // enabled|disabled
}

// LLMClient defines the unified LLM interface.
type LLMClient interface {
	Chat(ctx context.Context, req ChatRequest) (ChatResponse, error)
	ChatStream(ctx context.Context, req ChatRequest) (<-chan string, error)
	Embed(ctx context.Context, req EmbeddingsRequest) (EmbeddingsResponse, error)
	Moderate(ctx context.Context, req ModerateRequest) (ModerateResponse, error)
}
