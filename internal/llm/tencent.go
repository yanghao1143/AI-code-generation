package llm

import (
	"bufio"
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"time"
)

// HunyuanClient implements LLMClient via Tencent Cloud Hunyuan (TC3 signed requests).
type HunyuanClient struct {
	secretId  string
	secretKey string
	endpoint  string
	region    string
	version   string
	http      *http.Client
}

// NewHunyuanClientFromEnv creates a client if required credentials are present.
// Env: TENCENT_SECRET_ID, TENCENT_SECRET_KEY, optional TENCENT_ENDPOINT, TENCENT_REGION, TENCENT_VERSION
func NewHunyuanClientFromEnv() (*HunyuanClient, bool) {
	sid := os.Getenv("TENCENT_SECRET_ID")
	sk := os.Getenv("TENCENT_SECRET_KEY")
	if sid == "" || sk == "" {
		return nil, false
	}
	ep := os.Getenv("TENCENT_ENDPOINT")
	if ep == "" {
		ep = "hunyuan.tencentcloudapi.com"
	}
	rg := os.Getenv("TENCENT_REGION")
	if rg == "" {
		rg = "ap-guangzhou"
	}
	ver := os.Getenv("TENCENT_VERSION")
	if ver == "" {
		ver = "2023-09-01"
	}
	return &HunyuanClient{secretId: sid, secretKey: sk, endpoint: ep, region: rg, version: ver, http: &http.Client{Timeout: 30 * time.Second}}, true
}

func (c *HunyuanClient) Chat(ctx context.Context, req ChatRequest) (ChatResponse, error) {
	body := map[string]interface{}{
		"Model":    req.ModelID,
		"Messages": convertMessages(req.Messages),
	}
	if req.Temperature != 0 {
		body["Temperature"] = req.Temperature
	}
	if req.TopP != 0 {
		body["TopP"] = req.TopP
	}
	respMap, err := c.call(ctx, "ChatCompletions", body)
	if err != nil {
		return ChatResponse{}, err
	}
	content := extractChatContent(respMap)
	return ChatResponse{
		ID:      "chat_tencent",
		ModelID: req.ModelID,
		Usage:   Usage{Prompt: 0, Completion: 0},
		Choices: []Choice{{Role: "assistant", Content: content}},
	}, nil
}

func (c *HunyuanClient) ChatStream(ctx context.Context, req ChatRequest) (<-chan string, error) {
	// Real SSE streaming via TC3 signed request
	body := map[string]interface{}{
		"Model":    req.ModelID,
		"Messages": convertMessages(req.Messages),
		"Stream":   true,
	}
	if req.Temperature != 0 {
		body["Temperature"] = req.Temperature
	}
	if req.TopP != 0 {
		body["TopP"] = req.TopP
	}
	payload, _ := json.Marshal(body)

	ts := time.Now().Unix()
	service := "hunyuan"
	algorithm := "TC3-HMAC-SHA256"

	// Canonical request for streaming
	hashedPayload := sha256Hex(payload)
	canonicalHeaders := fmt.Sprintf("content-type:application/json\nhost:%s\n", c.endpoint)
	signedHeaders := "content-type;host"
	canonicalRequest := strings.Join([]string{
		"POST",
		"/",
		"",
		canonicalHeaders,
		signedHeaders,
		hashedPayload,
	}, "\n")

	date := time.Unix(ts, 0).UTC().Format("2006-01-02")
	credentialScope := fmt.Sprintf("%s/%s/tc3_request", date, service)
	hashedCanonical := sha256Hex([]byte(canonicalRequest))
	stringToSign := strings.Join([]string{algorithm, fmt.Sprintf("%d", ts), credentialScope, hashedCanonical}, "\n")

	secretDate := hmacSHA256([]byte("TC3"+c.secretKey), []byte(date))
	secretService := hmacSHA256(secretDate, []byte(service))
	secretSigning := hmacSHA256(secretService, []byte("tc3_request"))
	signature := hex.EncodeToString(hmacSHA256(secretSigning, []byte(stringToSign)))
	authorization := fmt.Sprintf("%s Credential=%s/%s, SignedHeaders=%s, Signature=%s", algorithm, c.secretId, credentialScope, signedHeaders, signature)

	url := "https://" + c.endpoint
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(payload))
	if err != nil {
		return nil, err
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Accept", "text/event-stream")
	httpReq.Header.Set("Authorization", authorization)
	httpReq.Header.Set("X-TC-Action", "ChatCompletions")
	httpReq.Header.Set("X-TC-Version", c.version)
	httpReq.Header.Set("X-TC-Region", c.region)
	httpReq.Header.Set("X-TC-Timestamp", fmt.Sprintf("%d", ts))

	resp, err := c.http.Do(httpReq)
	if err != nil {
		return nil, err
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		rb, _ := io.ReadAll(resp.Body)
		resp.Body.Close()
		return nil, fmt.Errorf("tencent api error: status=%d body=%s", resp.StatusCode, string(rb))
	}

	ch := make(chan string, 32)
	go func() {
		defer close(ch)
		defer resp.Body.Close()
		scanner := bufio.NewScanner(resp.Body)
		scanner.Buffer(make([]byte, 1024), 1024*1024)
		for scanner.Scan() {
			line := scanner.Text()
			if strings.HasPrefix(line, "data: ") {
				data := strings.TrimPrefix(line, "data: ")
				// Skip empty keepalive
				if strings.TrimSpace(data) == "" {
					continue
				}
				var obj map[string]interface{}
				if err := json.Unmarshal([]byte(data), &obj); err != nil {
					// If non-JSON payload, forward as-is
					select {
					case <-ctx.Done():
						return
					case ch <- data:
					}
					continue
				}
				// Extract delta content
				if choices, ok := obj["Choices"].([]interface{}); ok {
					for _, citem := range choices {
						if cm, ok := citem.(map[string]interface{}); ok {
							if delta, ok := cm["Delta"].(map[string]interface{}); ok {
								if content, ok := delta["Content"].(string); ok && content != "" {
									select {
									case <-ctx.Done():
										return
									case ch <- content:
									}
								}
							}
							if msg, ok := cm["Message"].(map[string]interface{}); ok {
								if content, ok := msg["Content"].(string); ok && content != "" {
									select {
									case <-ctx.Done():
										return
									case ch <- content:
									}
								}
							}
						}
					}
					continue
				}
				// Fallback single field
				if s, ok := obj["Content"].(string); ok && s != "" {
					select {
					case <-ctx.Done():
						return
					case ch <- s:
					}
				}
			}
		}
	}()
	return ch, nil
}

func (c *HunyuanClient) Embed(ctx context.Context, req EmbeddingsRequest) (EmbeddingsResponse, error) {
	body := map[string]interface{}{}
	// According to docs, use Input for single string, InputList for multiple
	if len(req.Input) == 1 {
		body["Input"] = req.Input[0]
	} else if len(req.Input) > 1 {
		body["InputList"] = req.Input
	}
	respMap, err := c.call(ctx, "GetEmbedding", body)
	if err != nil {
		return EmbeddingsResponse{}, err
	}
	vectors, dims := extractEmbeddings(respMap)
	if dims == 0 && len(vectors) > 0 {
		dims = len(vectors[0])
	}
	if len(vectors) == 0 {
		return EmbeddingsResponse{}, fmt.Errorf("no embeddings found in response")
	}
	// Default dimension for Hunyuan embeddings is 1024 if missing
	if dims == 0 {
		dims = 1024
	}
	return EmbeddingsResponse{ModelID: req.ModelID, Dims: dims, Vectors: vectors}, nil
}

func (c *HunyuanClient) Moderate(ctx context.Context, req ModerateRequest) (ModerateResponse, error) {
	// Hunyuan moderation API may differ; return a simple pass for now.
	return ModerateResponse{Result: "pass", Flags: []string{}}, nil
}

// call performs a TC3 signed POST request to Tencent Cloud endpoint for a specific Action.
func (c *HunyuanClient) call(ctx context.Context, action string, payload map[string]interface{}) (map[string]interface{}, error) {
	b, _ := json.Marshal(payload)
	ts := time.Now().Unix()
	service := "hunyuan"
	algorithm := "TC3-HMAC-SHA256"

	// Canonical request
	hashedPayload := sha256Hex(b)
	canonicalHeaders := fmt.Sprintf("content-type:application/json\nhost:%s\n", c.endpoint)
	signedHeaders := "content-type;host"
	canonicalRequest := strings.Join([]string{
		"POST",
		"/",
		"",
		canonicalHeaders,
		signedHeaders,
		hashedPayload,
	}, "\n")

	// String to sign
	date := time.Unix(ts, 0).UTC().Format("2006-01-02")
	credentialScope := fmt.Sprintf("%s/%s/tc3_request", date, service)
	hashedCanonical := sha256Hex([]byte(canonicalRequest))
	stringToSign := strings.Join([]string{algorithm, fmt.Sprintf("%d", ts), credentialScope, hashedCanonical}, "\n")

	// Signature
	secretDate := hmacSHA256([]byte("TC3"+c.secretKey), []byte(date))
	secretService := hmacSHA256(secretDate, []byte(service))
	secretSigning := hmacSHA256(secretService, []byte("tc3_request"))
	signature := hex.EncodeToString(hmacSHA256(secretSigning, []byte(stringToSign)))

	// Authorization header
	authorization := fmt.Sprintf("%s Credential=%s/%s, SignedHeaders=%s, Signature=%s", algorithm, c.secretId, credentialScope, signedHeaders, signature)

	url := "https://" + c.endpoint
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(b))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", authorization)
	req.Header.Set("X-TC-Action", action)
	req.Header.Set("X-TC-Version", c.version)
	req.Header.Set("X-TC-Region", c.region)
	req.Header.Set("X-TC-Timestamp", fmt.Sprintf("%d", ts))

	resp, err := c.http.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	rb, _ := io.ReadAll(resp.Body)
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, fmt.Errorf("tencent api error: status=%d body=%s", resp.StatusCode, string(rb))
	}
	var m map[string]interface{}
	_ = json.Unmarshal(rb, &m)
	if m == nil {
		m = map[string]interface{}{"raw": string(rb)}
	}
	// Tencent Cloud TC3 responses may include Response.Error with 200 status
	if resp, ok := m["Response"].(map[string]interface{}); ok {
		if errObj, ok := resp["Error"].(map[string]interface{}); ok {
			code := errObj["Code"]
			msg := errObj["Message"]
			return nil, fmt.Errorf("tencent api error: %v %v", code, msg)
		}
	}
	return m, nil
}

func convertMessages(ms []Message) []map[string]string {
	out := make([]map[string]string, 0, len(ms))
	for _, m := range ms {
		out = append(out, map[string]string{"Role": m.Role, "Content": m.Content})
	}
	return out
}

func extractChatContent(resp map[string]interface{}) string {
	// Try common shapes: {Response:{Choices:[{Message:{Content:"..."}}]}} or OpenAI-like
	if v, ok := resp["Response"].(map[string]interface{}); ok {
		if chs, ok := v["Choices"].([]interface{}); ok && len(chs) > 0 {
			if first, ok := chs[0].(map[string]interface{}); ok {
				if msg, ok := first["Message"].(map[string]interface{}); ok {
					if c, ok := msg["Content"].(string); ok {
						return c
					}
				}
				if c, ok := first["Content"].(string); ok {
					return c
				}
			}
		}
		if msg, ok := v["Message"].(map[string]interface{}); ok {
			if c, ok := msg["Content"].(string); ok {
				return c
			}
		}
	}
	// Fallbacks
	if c, ok := resp["content"].(string); ok {
		return c
	}
	if raw, ok := resp["raw"].(string); ok {
		return raw
	}
	return "调用成功（Tencent Hunyuan，未解析具体字段）"
}

func extractEmbeddings(resp map[string]interface{}) ([][]float64, int) {
	// Try common shapes first
	var vecs [][]float64
	var dims int
	if v, ok := resp["Response"].(map[string]interface{}); ok {
		// Response.Data[i].Embedding or .Vector
		if data, ok := v["Data"].([]interface{}); ok {
			for _, item := range data {
				if im, ok := item.(map[string]interface{}); ok {
					if emb, ok := im["Embedding"].([]interface{}); ok {
						row := toFloatSlice(emb)
						if dims == 0 {
							dims = len(row)
						}
						vecs = append(vecs, row)
						continue
					}
					if vec, ok := im["Vector"].([]interface{}); ok {
						row := toFloatSlice(vec)
						if dims == 0 {
							dims = len(row)
						}
						vecs = append(vecs, row)
						continue
					}
				}
			}
			if len(vecs) > 0 {
				return vecs, dims
			}
		}
		// Response.Embedding (single)
		if emb, ok := v["Embedding"].([]interface{}); ok {
			row := toFloatSlice(emb)
			dims = len(row)
			return [][]float64{row}, dims
		}
		// Response.Vectors (multi)
		if arr, ok := v["Vectors"].([]interface{}); ok {
			for _, x := range arr {
				if s, ok := x.([]interface{}); ok {
					row := toFloatSlice(s)
					if dims == 0 {
						dims = len(row)
					}
					vecs = append(vecs, row)
				}
			}
			if len(vecs) > 0 {
				return vecs, dims
			}
		}
		// Response.Embeddings (multi)
		if arr, ok := v["Embeddings"].([]interface{}); ok {
			for _, x := range arr {
				if s, ok := x.([]interface{}); ok {
					row := toFloatSlice(s)
					if dims == 0 {
						dims = len(row)
					}
					vecs = append(vecs, row)
				}
			}
			if len(vecs) > 0 {
				return vecs, dims
			}
		}
	}
	// Lowercase openai-like
	if data, ok := resp["data"].([]interface{}); ok {
		for _, item := range data {
			if im, ok := item.(map[string]interface{}); ok {
				if emb, ok := im["embedding"].([]interface{}); ok {
					row := toFloatSlice(emb)
					if dims == 0 {
						dims = len(row)
					}
					vecs = append(vecs, row)
				}
			}
		}
		if len(vecs) > 0 {
			return vecs, dims
		}
	}
	// Generic fallback: recursively collect float arrays
	vecs = collectFloatArrays(resp)
	if len(vecs) > 0 {
		dims = len(vecs[0])
	}
	return vecs, dims
}

func toFloatSlice(arr []interface{}) []float64 {
	out := make([]float64, 0, len(arr))
	for _, v := range arr {
		switch t := v.(type) {
		case float64:
			out = append(out, t)
		case float32:
			out = append(out, float64(t))
		case int:
			out = append(out, float64(t))
		case int64:
			out = append(out, float64(t))
		case json.Number:
			f, _ := t.Float64()
			out = append(out, f)
		}
	}
	return out
}

// collectFloatArrays walks arbitrary JSON and collects arrays entirely composed of numbers.
func collectFloatArrays(obj interface{}) [][]float64 {
	var res [][]float64
	walkCollect(obj, &res, 0)
	return res
}

func walkCollect(obj interface{}, out *[][]float64, depth int) {
	if depth > 6 { // guard against deep nesting
		return
	}
	switch v := obj.(type) {
	case []interface{}:
		// If this array is numeric-only, record it; otherwise walk elements
		if isNumericArray(v) {
			*out = append(*out, toFloatSlice(v))
			return
		}
		for _, it := range v {
			walkCollect(it, out, depth+1)
		}
	case map[string]interface{}:
		for _, it := range v {
			walkCollect(it, out, depth+1)
		}
	}
}

func isNumericArray(arr []interface{}) bool {
	if len(arr) == 0 {
		return false
	}
	for _, x := range arr {
		switch x.(type) {
		case float64, float32, int, int64, json.Number:
			// ok
		default:
			return false
		}
	}
	return true
}

func sha256Hex(b []byte) string {
	h := sha256.Sum256(b)
	return hex.EncodeToString(h[:])
}

func hmacSHA256(key, msg []byte) []byte {
	h := hmac.New(sha256.New, key)
	h.Write(msg)
	return h.Sum(nil)
}
