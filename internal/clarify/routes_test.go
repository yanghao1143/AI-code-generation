package clarify

import (
    "net/http"
    "net/http/httptest"
    "strings"
    "testing"

    "github.com/gorilla/websocket"
    "xingzuo/internal/testassert"
    "xingzuo/internal/testutil"
)

// sseRecorder wraps ResponseRecorder and implements http.Flusher for SSE tests.
type sseRecorder struct{ *httptest.ResponseRecorder }

func (s sseRecorder) Flush() {}

func TestClarify_Stream_SSE(t *testing.T) {
    r := testutil.SetupRouterWith(t, "/ai/clarify", RegisterRoutes)

    req := httptest.NewRequest(http.MethodGet, "/api/v1/ai/clarify/stream?prompt=clarify-sse-test&language=zh-CN", nil)
    testutil.AuthHeaders(req)
    req.Header.Set("X-User-Permissions", "ai.clarify")
    w := sseRecorder{httptest.NewRecorder()}
    r.ServeHTTP(w, req)

    testassert.MustStatus(t, w.ResponseRecorder, http.StatusOK)

    ct := w.Header().Get("Content-Type")
    if ct != "text/event-stream" {
        t.Fatalf("expected content-type text/event-stream, got %s", ct)
    }

    body := w.Body.String()
    // Expect three data frames and a terminal done event
    iReq := strings.Index(body, "\"requirements\"")
    iDes := strings.Index(body, "\"design\"")
    iTasks := strings.Index(body, "\"tasks\"")
    iDone := strings.Index(body, "event: done")
    if iReq < 0 || iDes < 0 || iTasks < 0 || iDone < 0 {
        t.Fatalf("expected requirements/design/tasks frames and done event; body=%s", body)
    }
    if !(iReq < iDes && iDes < iTasks && iTasks < iDone) {
        t.Fatalf("events out of order: %d %d %d %d; body=%s", iReq, iDes, iTasks, iDone, body)
    }
}

func TestClarify_Stream_WS(t *testing.T) {
    r := testutil.SetupRouterWith(t, "/ai/clarify", RegisterRoutes)
    srv := httptest.NewServer(r)
    defer srv.Close()

    // Build ws URL from test server URL
    wsURL := "ws" + strings.TrimPrefix(srv.URL, "http") + "/api/v1/ai/clarify/stream/ws?prompt=clarify-ws-test&language=zh-CN"

    // Pass auth and permissions via headers during handshake
    header := http.Header{}
    header.Set("Authorization", "Bearer dev-token")
    header.Set("X-User-Permissions", "ai.clarify")

    conn, resp, err := websocket.DefaultDialer.Dial(wsURL, header)
    if err != nil {
        t.Fatalf("websocket dial error: %v", err)
    }
    if resp != nil && resp.StatusCode != http.StatusSwitchingProtocols {
        t.Fatalf("unexpected handshake status: %d", resp.StatusCode)
    }
    defer conn.Close()

    type frame struct {
        Type  string      `json:"type,omitempty"`
        Event string      `json:"event,omitempty"`
        Data  interface{} `json:"data,omitempty"`
    }

    // Expect 3 data frames and a terminal done event
    var got []frame
    for i := 0; i < 4; i++ {
        var f frame
        if err := conn.ReadJSON(&f); err != nil {
            t.Fatalf("read json frame error: %v", err)
        }
        got = append(got, f)
    }

    if got[0].Type == "" || got[1].Type == "" || got[2].Type == "" {
        t.Fatalf("expected first three frames to have type, got: %+v", got[:3])
    }
    if got[3].Event != "done" {
        t.Fatalf("expected terminal frame event=done, got: %+v", got[3])
    }
}