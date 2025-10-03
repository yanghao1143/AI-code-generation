package middleware

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
)

func TestErrorHandler_ReturnsStandardError(t *testing.T) {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.Use(RequestID(), ErrorHandler())

	r.GET("/boom", func(c *gin.Context) {
		c.Error(gin.Error{Err: assertErr("boom")}.Err)
	})

	req := httptest.NewRequest(http.MethodGet, "/boom", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusInternalServerError {
		t.Fatalf("expected 500, got %d", w.Code)
	}
	var body map[string]interface{}
	if err := json.Unmarshal(w.Body.Bytes(), &body); err != nil {
		t.Fatalf("invalid json: %v", err)
	}
	if body["code"] != "E3000" {
		t.Fatalf("expected code E3000, got %v", body["code"])
	}
}

// assertErr returns an error with the given message without extra stack info.
func assertErr(msg string) error { return &simpleErr{msg: msg} }

type simpleErr struct{ msg string }

func (e *simpleErr) Error() string { return e.msg }
