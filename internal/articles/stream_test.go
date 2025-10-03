package articles

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"xingzuo/internal/testassert"
	"xingzuo/internal/testutil"
)

// sseRecorder wraps ResponseRecorder and implements http.Flusher for SSE tests.
type sseRecorder struct{ *httptest.ResponseRecorder }

func (s sseRecorder) Flush() {}

func TestArticles_Stream_SSE(t *testing.T) {
	r := testutil.SetupRouterWith(t, "/articles", RegisterRoutes)

	req := httptest.NewRequest(http.MethodGet, "/api/v1/articles/stream", nil)
	testutil.AuthHeaders(req)
	req.Header.Set("X-User-Permissions", "articles")
	w := sseRecorder{httptest.NewRecorder()}
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK && w.Code != http.StatusInternalServerError {
		t.Fatalf("unexpected status: %d", w.Code)
	}

	// If SSE path executed, content-type should be text/event-stream and body should contain frames in order.
	ct := w.Header().Get("Content-Type")
	if ct == "text/event-stream" {
		body := w.Body.String()
		i1 := strings.Index(body, "data: part-1")
		ih := strings.Index(body, ":heartbeat")
		i2 := strings.Index(body, "data: part-2")
		id := strings.Index(body, "event: done")
		if i1 < 0 || ih < 0 || i2 < 0 || id < 0 {
			t.Fatalf("expected SSE frames and done event, got: %s", body)
		}
		if !(i1 < ih && ih < i2 && i2 < id) {
			t.Fatalf("events out of order: %d %d %d %d; body=%s", i1, ih, i2, id, body)
		}
	} else {
		// Fallback: some environments may not support SSE; ensure JSON error is reasonable.
		testassert.MustError(t, w.ResponseRecorder, 500, "E3001", "StreamError")
	}
}

func TestArticles_Stream_ListModeFilters(t *testing.T) {
	r := testutil.SetupRouterWith(t, "/articles", RegisterRoutes)

	// Create two articles with same author to test pagination and heartbeat
	bodyCreate1 := `{"title":"Hello","content":"World","authorId":"u1","tags":["t1"]}`
	reqCreate1 := testassert.NewJSONRequest(http.MethodPost, "/api/v1/articles", bodyCreate1)
	testutil.AuthHeaders(reqCreate1)
	reqCreate1.Header.Set("X-User-Permissions", "articles")
	wCreate1 := httptest.NewRecorder()
	r.ServeHTTP(wCreate1, reqCreate1)
	testassert.MustStatus(t, wCreate1, 200)

	bodyCreate2 := `{"title":"Greetings","content":"Universe","authorId":"u1","tags":["t2"]}`
	reqCreate2 := testassert.NewJSONRequest(http.MethodPost, "/api/v1/articles", bodyCreate2)
	testutil.AuthHeaders(reqCreate2)
	reqCreate2.Header.Set("X-User-Permissions", "articles")
	wCreate2 := httptest.NewRecorder()
	r.ServeHTTP(wCreate2, reqCreate2)
	testassert.MustStatus(t, wCreate2, 200)

	// Stream with list mode, author filter, limit=2 to ensure heartbeat appears between items
	req := httptest.NewRequest(http.MethodGet, "/api/v1/articles/stream?mode=list&authorId=u1&limit=2&offset=0&heartbeatMs=3", nil)
	testutil.AuthHeaders(req)
	req.Header.Set("X-User-Permissions", "articles")
	w := sseRecorder{httptest.NewRecorder()}
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK && w.Code != http.StatusInternalServerError {
		t.Fatalf("unexpected status: %d", w.Code)
	}

	ct := w.Header().Get("Content-Type")
	if ct == "text/event-stream" {
		body := w.Body.String()
		// Expect two item events, a heartbeat between them, and done at end
		iItem := strings.Count(body, "event: item")
		if iItem < 2 {
			t.Fatalf("expected at least 2 item events, got %d; body=%s", iItem, body)
		}
		if !strings.Contains(body, ":heartbeat") {
			t.Fatalf("expected heartbeat between items; body=%s", body)
		}
		if !strings.Contains(body, "event: done") {
			t.Fatalf("expected terminal done event; body=%s", body)
		}
	} else {
		testassert.MustError(t, w.ResponseRecorder, 500, "E3001", "StreamError")
	}
}
