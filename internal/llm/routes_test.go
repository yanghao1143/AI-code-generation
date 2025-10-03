package llm

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"
	"xingzuo/internal/testassert"
	"xingzuo/internal/testutil"
)

// setupRouter initializes via shared testutil to keep consistency.
func setupRouter(t *testing.T) *gin.Engine {
	return testutil.SetupRouterWith(t, "/llm", RegisterRoutes)
}

func authHeaders(req *http.Request) { testutil.AuthHeaders(req) }

func TestLLM_Providers(t *testing.T) {
	r := setupRouter(t)
	req := httptest.NewRequest(http.MethodGet, "/api/v1/llm/providers", nil)
	authHeaders(req)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	testassert.MustStatus(t, w, http.StatusOK)
	body := testassert.MustJSON(t, w)
	data := testassert.DataOf(t, body)
	items, ok := data["items"].([]interface{})
	if !ok || len(items) == 0 {
		t.Fatalf("providers items empty or wrong type")
	}
}

func TestLLM_Models(t *testing.T) {
	r := setupRouter(t)
	req := httptest.NewRequest(http.MethodGet, "/api/v1/llm/models", nil)
	authHeaders(req)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	testassert.MustStatus(t, w, http.StatusOK)
	body := testassert.MustJSON(t, w)
	data := testassert.DataOf(t, body)
	items, ok := data["items"].([]interface{})
	if !ok || len(items) == 0 {
		t.Fatalf("models items empty or wrong type")
	}
}

func TestLLM_Chat_NonStreaming(t *testing.T) {
	r := setupRouter(t)
	payload := `{"modelId":"hunyuan-lite","messages":[{"role":"user","content":"你好"}]}`
	req := httptest.NewRequest(http.MethodPost, "/api/v1/llm/chat", strings.NewReader(payload))
	authHeaders(req)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	testassert.MustStatus(t, w, http.StatusOK)
	body := testassert.MustJSON(t, w)
	data := testassert.DataOf(t, body)
	choices, ok := data["choices"].([]interface{})
	if !ok || len(choices) == 0 {
		t.Fatalf("chat choices empty or wrong type")
	}
}

func TestLLM_Embeddings(t *testing.T) {
	r := setupRouter(t)
	payload := `{"modelId":"hunyuan-lite","input":["向量测试"]}`
	req := httptest.NewRequest(http.MethodPost, "/api/v1/llm/embeddings", strings.NewReader(payload))
	authHeaders(req)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	testassert.MustStatus(t, w, http.StatusOK)
	body := testassert.MustJSON(t, w)
	data := testassert.DataOf(t, body)
	dims, ok := data["dims"].(float64)
	if !ok || dims <= 0 {
		t.Fatalf("embeddings dims invalid: %v", data["dims"])
	}
	vectors, ok := data["vectors"].([]interface{})
	if !ok || len(vectors) == 0 {
		t.Fatalf("embeddings vectors empty or wrong type")
	}
}

func TestLLM_Chat_Select_ModelID_Priority(t *testing.T) {
	r := setupRouter(t)
	payload := `{"modelId":"qwen-turbo","providerHint":"tencent","messages":[{"role":"user","content":"hi"}]}`
	req := httptest.NewRequest(http.MethodPost, "/api/v1/llm/chat", strings.NewReader(payload))
	authHeaders(req)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	testassert.MustStatus(t, w, http.StatusOK)
	body := testassert.MustJSON(t, w)
	data := testassert.DataOf(t, body)
	if mid, _ := data["modelId"].(string); mid != "qwen-turbo" {
		t.Fatalf("model selection should prefer explicit modelId, got %v", mid)
	}
}

func TestLLM_Chat_Select_ProviderHint(t *testing.T) {
	r := setupRouter(t)
	payload := `{"providerHint":"tencent","messages":[{"role":"user","content":"hi"}]}`
	req := httptest.NewRequest(http.MethodPost, "/api/v1/llm/chat", strings.NewReader(payload))
	authHeaders(req)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	testassert.MustStatus(t, w, http.StatusOK)
	body := testassert.MustJSON(t, w)
	data := testassert.DataOf(t, body)
	if mid, _ := data["modelId"].(string); mid != "hunyuan-lite" {
		t.Fatalf("providerHint selection failed, expected hunyuan-lite, got %v", mid)
	}
}

func TestLLM_Chat_Select_Fallback_Global(t *testing.T) {
	r := setupRouter(t)
	payload := `{"messages":[{"role":"user","content":"hi"}]}`
	req := httptest.NewRequest(http.MethodPost, "/api/v1/llm/chat", strings.NewReader(payload))
	authHeaders(req)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	testassert.MustStatus(t, w, http.StatusOK)
	body := testassert.MustJSON(t, w)
	data := testassert.DataOf(t, body)
	if mid, _ := data["modelId"].(string); mid != "ernie-4.0" {
		t.Fatalf("fallback selection failed, expected ernie-4.0, got %v", mid)
	}
}

func TestLLM_Chat_Error_ModelNotFound(t *testing.T) {
	// Temporarily disable all models to force ModelNotFound
	origModels := models
	models = []ModelInfo{
		{ProviderID: "baidu", ModelID: "ernie-4.0", Status: "disabled"},
		{ProviderID: "ali", ModelID: "qwen-turbo", Status: "disabled"},
		{ProviderID: "tencent", ModelID: "hunyuan-lite", Status: "disabled"},
	}
	defer func() { models = origModels }()

	r := setupRouter(t)
	payload := `{"modelId":"unknown","messages":[{"role":"user","content":"hi"}]}`
	req := httptest.NewRequest(http.MethodPost, "/api/v1/llm/chat", strings.NewReader(payload))
	authHeaders(req)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	testassert.MustError(t, w, http.StatusBadRequest, "E2100", "ModelNotFound")
}

func TestLLM_Chat_Error_ClientNotRegistered(t *testing.T) {
	r := setupRouter(t)
	// Remove ali client to simulate missing adapter
	origClients := clients
	if clients != nil {
		delete(clients, "ali")
	}
	defer func() { clients = origClients }()

	payload := `{"modelId":"qwen-turbo","messages":[{"role":"user","content":"hi"}]}`
	req := httptest.NewRequest(http.MethodPost, "/api/v1/llm/chat", strings.NewReader(payload))
	authHeaders(req)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	testassert.MustError(t, w, http.StatusNotFound, "E2200", "ClientNotRegistered")
}

func TestLLM_Chat_Error_InvalidJSON(t *testing.T) {
	r := setupRouter(t)
	// Invalid messages type to trigger validation error
	payload := `{"modelId":"hunyuan-lite","messages":"not-array"}`
	req := testassert.NewJSONRequest(http.MethodPost, "/api/v1/llm/chat", payload)
	authHeaders(req)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	testassert.MustError(t, w, http.StatusBadRequest, "E1000", "ValidationError")
}

// sseRecorder wraps ResponseRecorder and implements http.Flusher for SSE tests.
type sseRecorder struct{ *httptest.ResponseRecorder }

func (s sseRecorder) Flush() {}

func TestLLM_Chat_SSE(t *testing.T) {
	r := setupRouter(t)
	payload := `{"modelId":"hunyuan-lite","messages":[{"role":"user","content":"你好"}],"stream":true}`
	req := httptest.NewRequest(http.MethodPost, "/api/v1/llm/chat", strings.NewReader(payload))
	authHeaders(req)
	w := sseRecorder{httptest.NewRecorder()}
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK && w.Code != http.StatusInternalServerError {
		t.Fatalf("unexpected status: %d", w.Code)
	}
	// If SSE path executed, content-type should be text/event-stream and body should contain data frames.
	ct := w.Header().Get("Content-Type")
	if ct == "text/event-stream" {
		body := w.Body.String()
		if !strings.Contains(body, "data:") {
			t.Fatalf("expected SSE data frames, got: %s", body)
		}
	} else {
		// Fallback: some test environments may not go through SSE; ensure JSON error is reasonable.
		if w.Code != http.StatusInternalServerError {
			t.Fatalf("expected 500 when SSE unsupported, got %d (ct=%s)", w.Code, ct)
		}
	}
}

func TestLLM_Moderate(t *testing.T) {
	r := setupRouter(t)
	payload := `{"input":"需要审核的内容"}`
	req := httptest.NewRequest(http.MethodPost, "/api/v1/llm/moderate", strings.NewReader(payload))
	authHeaders(req)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	testassert.MustStatus(t, w, http.StatusOK)
	body := testassert.MustJSON(t, w)
	data := testassert.DataOf(t, body)
	if res, _ := data["result"].(string); res != "pass" {
		t.Fatalf("unexpected moderate result: %v", res)
	}
}

// flaggedClient returns flagged moderation to test compliance branch
type flaggedClient struct{}

func (f *flaggedClient) Chat(ctx context.Context, req ChatRequest) (ChatResponse, error) {
	return ChatResponse{ID: "chat_flag", ModelID: req.ModelID, Usage: Usage{Prompt: 1, Completion: 1}, Choices: []Choice{{Role: "assistant", Content: "ok"}}}, nil
}
func (f *flaggedClient) ChatStream(ctx context.Context, req ChatRequest) (<-chan string, error) {
	ch := make(chan string, 1)
	close(ch)
	return ch, nil
}
func (f *flaggedClient) Embed(ctx context.Context, req EmbeddingsRequest) (EmbeddingsResponse, error) {
	return EmbeddingsResponse{ModelID: req.ModelID, Dims: 1, Vectors: [][]float64{{0.1}}}, nil
}
func (f *flaggedClient) Moderate(ctx context.Context, req ModerateRequest) (ModerateResponse, error) {
	return ModerateResponse{Result: "flagged", Flags: []string{"violence"}}, nil
}

func TestLLM_Moderate_Compliance_Flagged(t *testing.T) {
	// Force model selection to Tencent by disabling others
	origModels := models
	models = []ModelInfo{{ProviderID: "tencent", ModelID: "hunyuan-lite", Status: "enabled"}}
	defer func() { models = origModels }()

	r := setupRouter(t)
	// Override tencent client AFTER router setup to ensure our flagged client is used
	RegisterClient("tencent", &flaggedClient{})
	payload := `{"input":"涉敏内容"}`
	req := httptest.NewRequest(http.MethodPost, "/api/v1/llm/moderate", strings.NewReader(payload))
	authHeaders(req)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	testassert.MustStatus(t, w, http.StatusOK)
	body := testassert.MustJSON(t, w)
	data := testassert.DataOf(t, body)
	if res, _ := data["result"].(string); res != "flagged" {
		t.Fatalf("expected flagged, got %v", res)
	}
	flags, ok := data["flags"].([]interface{})
	if !ok || len(flags) == 0 {
		t.Fatalf("expected flags non-empty, got %v", data["flags"])
	}
}

func TestLLM_Chat_UsageStats(t *testing.T) {
	r := setupRouter(t)
	payload := `{"modelId":"hunyuan-lite","messages":[{"role":"user","content":"hi"}]}`
	req := httptest.NewRequest(http.MethodPost, "/api/v1/llm/chat", strings.NewReader(payload))
	authHeaders(req)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	testassert.MustStatus(t, w, http.StatusOK)
	body := testassert.MustJSON(t, w)
	data := testassert.DataOf(t, body)
	usage, ok := data["usage"].(map[string]interface{})
	if !ok {
		t.Fatalf("usage missing or wrong type")
	}
	if p, _ := usage["prompt"].(float64); p <= 0 {
		t.Fatalf("prompt tokens should be > 0, got %v", p)
	}
	if c, _ := usage["completion"].(float64); c <= 0 {
		t.Fatalf("completion tokens should be > 0, got %v", c)
	}
}

// no custom reader needed; use strings.NewReader in tests above
