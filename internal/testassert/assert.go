package testassert

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

// MustStatus asserts the response status code matches expected.
func MustStatus(t *testing.T, w *httptest.ResponseRecorder, expected int) {
	t.Helper()
	if w.Code != expected {
		t.Fatalf("expected %d, got %d", expected, w.Code)
	}
}

// MustJSON parses response body as JSON and returns the object.
func MustJSON(t *testing.T, w *httptest.ResponseRecorder) map[string]interface{} {
	t.Helper()
	var body map[string]interface{}
	if err := json.Unmarshal(w.Body.Bytes(), &body); err != nil {
		t.Fatalf("invalid json: %v", err)
	}
	return body
}

// DataOf extracts the "data" object from standard OK response.
func DataOf(t *testing.T, m map[string]interface{}) map[string]interface{} {
	t.Helper()
	data, ok := m["data"].(map[string]interface{})
	if !ok {
		t.Fatalf("response missing data")
	}
	return data
}

// MustError asserts a standardized error response with code/message and status.
func MustError(t *testing.T, w *httptest.ResponseRecorder, expectedStatus int, code, message string) {
	t.Helper()
	MustStatus(t, w, expectedStatus)
	var body map[string]interface{}
	if err := json.Unmarshal(w.Body.Bytes(), &body); err != nil {
		t.Fatalf("invalid json: %v", err)
	}
	if c, _ := body["code"].(string); c != code {
		t.Fatalf("expected code %s, got %v", code, c)
	}
	if msg, _ := body["message"].(string); msg != message {
		t.Fatalf("expected message %s, got %v", message, msg)
	}
}

// NewJSONRequest creates a standard JSON request with content-type header set.
func NewJSONRequest(method, url string, body string) *http.Request {
	req := httptest.NewRequest(method, url, strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	return req
}
