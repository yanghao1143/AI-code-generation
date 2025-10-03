package llm

import (
	"context"
	"sync"
)

var (
	regOnce sync.Once
	clients map[string]LLMClient
)

func initRegistry() {
	clients = make(map[string]LLMClient)
	// Register clients per provider. Prefer real client if credentials available.
	for _, p := range Providers() {
		if p.Status == "disabled" {
			continue
		}
		if p.ID == "tencent" {
			if hc, ok := NewHunyuanClientFromEnv(); ok {
				clients[p.ID] = hc
				continue
			}
		}
		// Fallback to dummy client
		clients[p.ID] = &DummyClient{}
	}
}

// RegisterClient registers an LLM client under provider ID.
func RegisterClient(providerID string, client LLMClient) {
	regOnce.Do(initRegistry)
	clients[providerID] = client
}

// ClientFor returns the client for the given provider ID.
func ClientFor(providerID string) (LLMClient, bool) {
	regOnce.Do(initRegistry)
	c, ok := clients[providerID]
	return c, ok
}

// DummyClient implements LLMClient with placeholder behavior.
type DummyClient struct{}

func (d *DummyClient) Chat(ctx context.Context, req ChatRequest) (ChatResponse, error) {
	return ChatResponse{
		ID:      "chat_dummy",
		ModelID: req.ModelID,
		Usage:   Usage{Prompt: 10, Completion: 20},
		Choices: []Choice{{Role: "assistant", Content: "占位回复（dummy），model=" + req.ModelID}},
	}, nil
}

func (d *DummyClient) ChatStream(ctx context.Context, req ChatRequest) (<-chan string, error) {
	ch := make(chan string, 4)
	go func() {
		defer close(ch)
		parts := []string{"占位", "流式", "回复", "（dummy）"}
		for _, p := range parts {
			ch <- p
		}
	}()
	return ch, nil
}

func (d *DummyClient) Embed(ctx context.Context, req EmbeddingsRequest) (EmbeddingsResponse, error) {
	return EmbeddingsResponse{ModelID: req.ModelID, Dims: 1536, Vectors: [][]float64{{0.1, 0.2, 0.3}}}, nil
}

func (d *DummyClient) Moderate(ctx context.Context, req ModerateRequest) (ModerateResponse, error) {
	return ModerateResponse{Result: "pass", Flags: []string{}}, nil
}
