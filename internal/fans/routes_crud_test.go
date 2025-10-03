package fans

import (
    "fmt"
    "net/http"
    "net/http/httptest"
    "testing"

    "github.com/gin-gonic/gin"
    "xingzuo/internal/testassert"
    "xingzuo/internal/testutil"
)

// setupRouterCRUD initializes a test router with fans CRUD routes.
func setupRouterCRUD(t *testing.T) *gin.Engine {
    return testutil.SetupRouterWith(t, "/fans", RegisterCRUDRoutes)
}

// auth headers for fans module
func authHeadersCRUD(req *http.Request) {
    req.Header.Set("Authorization", "Bearer dev-token")
    req.Header.Set("X-User-Permissions", "fans")
    req.Header.Set("Content-Type", "application/json")
}

// Test basic CRUD flow on /api/v1/fans endpoints
func TestFansCRUD(t *testing.T) {
    r := setupRouterCRUD(t)

    // List initially empty
    reqList := httptest.NewRequest(http.MethodGet, "/api/v1/fans", nil)
    authHeadersCRUD(reqList)
    wList := httptest.NewRecorder()
    r.ServeHTTP(wList, reqList)
    testassert.MustStatus(t, wList, 200)
    data := testassert.DataOf(t, testassert.MustJSON(t, wList))
    if items, ok := data["items"].([]interface{}); !ok || len(items) != 0 {
        t.Fatalf("expected empty items, got %v", data["items"])
    }

    // Create a fan
    bodyCreate := `{"name":"Alice","gender":"female","birthday":"1990-01-01","zodiac":"Capricorn"}`
    reqCreate := testassert.NewJSONRequest(http.MethodPost, "/api/v1/fans", bodyCreate)
    authHeadersCRUD(reqCreate)
    wCreate := httptest.NewRecorder()
    r.ServeHTTP(wCreate, reqCreate)
    testassert.MustStatus(t, wCreate, 200)
    createData := testassert.DataOf(t, testassert.MustJSON(t, wCreate))
    idAny, ok := createData["id"].(float64)
    if !ok {
        t.Fatalf("expected numeric id in create response, got %T", createData["id"])
    }
    id := int64(idAny)
    if id <= 0 {
        t.Fatalf("expected positive id, got %v", id)
    }

    // Get the fan
    reqGet := httptest.NewRequest(http.MethodGet, fmt.Sprintf("/api/v1/fans/id/%d", id), nil)
    authHeadersCRUD(reqGet)
    wGet := httptest.NewRecorder()
    r.ServeHTTP(wGet, reqGet)
    testassert.MustStatus(t, wGet, 200)
    getData := testassert.DataOf(t, testassert.MustJSON(t, wGet))
    if name, _ := getData["name"].(string); name != "Alice" {
        t.Fatalf("expected name Alice, got %v", name)
    }

    // Update the fan
    bodyUpdate := `{"name":"AliceUpdated","zodiac":"Aquarius"}`
    reqUpdate := testassert.NewJSONRequest(http.MethodPut, fmt.Sprintf("/api/v1/fans/id/%d", id), bodyUpdate)
    authHeadersCRUD(reqUpdate)
    wUpdate := httptest.NewRecorder()
    r.ServeHTTP(wUpdate, reqUpdate)
    testassert.MustStatus(t, wUpdate, 200)
    updData := testassert.DataOf(t, testassert.MustJSON(t, wUpdate))
    if name, _ := updData["name"].(string); name != "AliceUpdated" {
        t.Fatalf("expected name AliceUpdated, got %v", name)
    }
    if zodiac, _ := updData["zodiac"].(string); zodiac != "Aquarius" {
        t.Fatalf("expected zodiac Aquarius, got %v", zodiac)
    }

    // Delete the fan
    reqDel := httptest.NewRequest(http.MethodDelete, fmt.Sprintf("/api/v1/fans/id/%d", id), nil)
    authHeadersCRUD(reqDel)
    wDel := httptest.NewRecorder()
    r.ServeHTTP(wDel, reqDel)
    testassert.MustStatus(t, wDel, 200)

    // Confirm deletion returns 404
    reqGet2 := httptest.NewRequest(http.MethodGet, fmt.Sprintf("/api/v1/fans/id/%d", id), nil)
    authHeadersCRUD(reqGet2)
    wGet2 := httptest.NewRecorder()
    r.ServeHTTP(wGet2, reqGet2)
    testassert.MustError(t, wGet2, 404, "E404", "NotFound")
}