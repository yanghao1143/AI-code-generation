package articles

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"

	"xingzuo/internal/testassert"
	"xingzuo/internal/testutil"
)

// Test basic CRUD flow on /api/v1/articles endpoints
func TestArticlesCRUD(t *testing.T) {
	r := testutil.SetupRouterWith(t, "/articles", RegisterRoutes)

	// List initially empty
	reqList := httptest.NewRequest(http.MethodGet, "/api/v1/articles", nil)
	testutil.AuthHeaders(reqList)
	reqList.Header.Set("X-User-Permissions", "articles")
	wList := httptest.NewRecorder()
	r.ServeHTTP(wList, reqList)
	testassert.MustStatus(t, wList, 200)
	data := testassert.DataOf(t, testassert.MustJSON(t, wList))
	if items, ok := data["items"].([]interface{}); !ok || len(items) != 0 {
		t.Fatalf("expected empty items, got %v", data["items"])
	}

	// Create an article
	bodyCreate := `{"title":"Hello","content":"World","authorId":"u1","tags":["t1","t2"]}`
	reqCreate := testassert.NewJSONRequest(http.MethodPost, "/api/v1/articles", bodyCreate)
	testutil.AuthHeaders(reqCreate)
	reqCreate.Header.Set("X-User-Permissions", "articles")
	wCreate := httptest.NewRecorder()
	r.ServeHTTP(wCreate, reqCreate)
	testassert.MustStatus(t, wCreate, 200)
	createData := testassert.DataOf(t, testassert.MustJSON(t, wCreate))
	id, _ := createData["id"].(string)
	if id == "" {
		t.Fatalf("expected id in create response")
	}

	// Get the article
	reqGet := httptest.NewRequest(http.MethodGet, fmt.Sprintf("/api/v1/articles/%s", id), nil)
	testutil.AuthHeaders(reqGet)
	reqGet.Header.Set("X-User-Permissions", "articles")
	wGet := httptest.NewRecorder()
	r.ServeHTTP(wGet, reqGet)
	testassert.MustStatus(t, wGet, 200)
	getData := testassert.DataOf(t, testassert.MustJSON(t, wGet))
	if title, _ := getData["title"].(string); title != "Hello" {
		t.Fatalf("expected title Hello, got %v", title)
	}

	// Update the article
	bodyUpdate := `{"title":"Updated"}`
	reqUpdate := testassert.NewJSONRequest(http.MethodPut, fmt.Sprintf("/api/v1/articles/%s", id), bodyUpdate)
	testutil.AuthHeaders(reqUpdate)
	reqUpdate.Header.Set("X-User-Permissions", "articles")
	wUpdate := httptest.NewRecorder()
	r.ServeHTTP(wUpdate, reqUpdate)
	testassert.MustStatus(t, wUpdate, 200)
	updData := testassert.DataOf(t, testassert.MustJSON(t, wUpdate))
	if title, _ := updData["title"].(string); title != "Updated" {
		t.Fatalf("expected title Updated, got %v", title)
	}

	// Delete the article
	reqDel := httptest.NewRequest(http.MethodDelete, fmt.Sprintf("/api/v1/articles/%s", id), nil)
	testutil.AuthHeaders(reqDel)
	reqDel.Header.Set("X-User-Permissions", "articles")
	wDel := httptest.NewRecorder()
	r.ServeHTTP(wDel, reqDel)
	testassert.MustStatus(t, wDel, 200)

	// Confirm deletion returns 404
	reqGet2 := httptest.NewRequest(http.MethodGet, fmt.Sprintf("/api/v1/articles/%s", id), nil)
	testutil.AuthHeaders(reqGet2)
	reqGet2.Header.Set("X-User-Permissions", "articles")
	wGet2 := httptest.NewRecorder()
	r.ServeHTTP(wGet2, reqGet2)
	testassert.MustError(t, wGet2, 404, "E404", "NotFound")
}
