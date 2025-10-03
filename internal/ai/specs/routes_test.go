package specs

import (
    "bytes"
    "encoding/json"
    "crypto/sha256"
    "fmt"
    "net/http"
    "net/http/httptest"
    "os"
    "path/filepath"
    "testing"

    "github.com/gin-gonic/gin"
)

// setupTempPRD creates a temporary working directory with .spec-workflow/sources/策划.md
func setupTempPRD(t *testing.T, content string) (string, func()) {
    t.Helper()
    dir := t.TempDir()
    srcDir := filepath.Join(dir, ".spec-workflow", "sources")
    if err := os.MkdirAll(srcDir, 0o755); err != nil {
        t.Fatalf("mkdir sources: %v", err)
    }
    prdPath := filepath.Join(srcDir, "策划.md")
    if err := os.WriteFile(prdPath, []byte(content), 0o644); err != nil {
        t.Fatalf("write PRD: %v", err)
    }
    // change working dir
    oldWd, _ := os.Getwd()
    if err := os.Chdir(dir); err != nil {
        t.Fatalf("chdir: %v", err)
    }
    cleanup := func() {
        _ = os.Chdir(oldWd)
    }
    return dir, cleanup
}

func buildRouter() *gin.Engine {
    gin.SetMode(gin.TestMode)
    r := gin.New()
    // We only attach RequestID to satisfy response envelope; RBAC is enforced per group.
    r.Use(func(c *gin.Context) { c.Set("request_id", "test-rid"); c.Next() })
    g := r.Group("/api/v1/ai/specs")
    RegisterRoutes(g)
    return r
}

func performJSON(r *gin.Engine, method, path string, body interface{}, headers map[string]string) *httptest.ResponseRecorder {
    data, _ := json.Marshal(body)
    req := httptest.NewRequest(method, path, bytes.NewReader(data))
    req.Header.Set("Content-Type", "application/json")
    for k, v := range headers {
        req.Header.Set(k, v)
    }
    w := httptest.NewRecorder()
    r.ServeHTTP(w, req)
    return w
}

// performRaw sends raw bytes as request body (used to simulate invalid JSON)
func performRaw(r *gin.Engine, method, path string, raw []byte, headers map[string]string) *httptest.ResponseRecorder {
    req := httptest.NewRequest(method, path, bytes.NewReader(raw))
    req.Header.Set("Content-Type", "application/json")
    for k, v := range headers {
        req.Header.Set(k, v)
    }
    w := httptest.NewRecorder()
    r.ServeHTTP(w, req)
    return w
}

// Test success path for generating docs from PRD
func TestGenerateSpecs_Success(t *testing.T) {
    // 使用括号形式的字段规格，满足解析器对字段清单的要求
    prd := "用户字段：id(主键, int64), name(字符串)。订单字段：id(主键, int64), user_id(外键->用户.用户ID)。一个用户有多个订单。"
    _, cleanup := setupTempPRD(t, prd)
    defer cleanup()

    r := buildRouter()

    w := performJSON(r, "POST", "/api/v1/ai/specs/generate", map[string]interface{}{
        "specName":      "ai-codegen",
        "generateDocs":  true,
        "generateDDL":   false,
        "useStructured": false,
    }, map[string]string{
        "X-User-Permissions": "ai.specs",
    })

    if w.Code != http.StatusOK {
        t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
    }

    var resp struct {
        Code      string          `json:"code"`
        Message   string          `json:"message"`
        RequestID string          `json:"requestId"`
        Data      json.RawMessage `json:"data"`
    }
    if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
        t.Fatalf("unmarshal resp: %v", err)
    }
    if resp.Code != "OK" || resp.Message != "success" {
        t.Fatalf("unexpected envelope: %+v", resp)
    }

    var data struct {
        SpecName string            `json:"specName"`
        Files    map[string]string `json:"files"`
        Entities int               `json:"entities"`
    }
    if err := json.Unmarshal(resp.Data, &data); err != nil {
        t.Fatalf("unmarshal data: %v", err)
    }

    // Validate files exist
    required := []string{"requirements", "design", "tasks", "openapi"}
    for _, k := range required {
        p, ok := data.Files[k]
        if !ok {
            t.Fatalf("missing file key: %s", k)
        }
        if _, err := os.Stat(p); err != nil {
            t.Fatalf("file not found for %s: %s (%v)", k, p, err)
        }
    }
    if data.Entities < 1 {
        t.Fatalf("expected at least 1 entity, got %d", data.Entities)
    }
}

// Test permission enforcement
func TestGenerateSpecs_PermissionDenied(t *testing.T) {
    prd := "实体 用户 字段 id:int name:string"
    _, cleanup := setupTempPRD(t, prd)
    defer cleanup()

    r := buildRouter()
    w := performJSON(r, "POST", "/api/v1/ai/specs/generate", map[string]interface{}{
        "generateDocs": true,
    }, map[string]string{})

    if w.Code != http.StatusForbidden {
        t.Fatalf("expected 403, got %d: %s", w.Code, w.Body.String())
    }
}

// Test DDL generation paths
func TestGenerateSpecs_GenerateDDL(t *testing.T) {
    prd := "实体 用户 字段 id:int name:string"
    wd, cleanup := setupTempPRD(t, prd)
    defer cleanup()

    r := buildRouter()
    w := performJSON(r, "POST", "/api/v1/ai/specs/generate", map[string]interface{}{
        "generateDocs":     false,
        "generateDDL":      true,
        "writeWorkflowDDL": true,
        "execChannel":      "READ",
    }, map[string]string{
        "X-User-Permissions": "ai.specs",
    })

    if w.Code != http.StatusOK {
        t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
    }

    var resp struct{ Data json.RawMessage }
    if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
        t.Fatalf("unmarshal resp: %v", err)
    }
    var data struct{ Files map[string]string `json:"files"` }
    if err := json.Unmarshal(resp.Data, &data); err != nil {
        t.Fatalf("unmarshal data: %v", err)
    }

    // scripts/db files
    for _, k := range []string{"ddl.create", "ddl.migrate", "ddl.rollback"} {
        p := data.Files[k]
        if p == "" {
            t.Fatalf("missing %s path", k)
        }
        if _, err := os.Stat(p); err != nil {
            t.Fatalf("missing file %s: %v", p, err)
        }
    }

    // workflow ddl files
    wf := filepath.Join(wd, ".spec-workflow", "db", "mysql")
    for _, name := range []string{"create.sql", "migrate.sql", "rollback.sql"} {
        p := filepath.Join(wf, name)
        if _, err := os.Stat(p); err != nil {
            t.Fatalf("missing workflow ddl %s: %v", p, err)
        }
    }
}

// Helper to hash a file's contents
func fileSHA(t *testing.T, p string) string {
    t.Helper()
    b, err := os.ReadFile(p)
    if err != nil {
        t.Fatalf("read %s: %v", p, err)
    }
    h := sha256.Sum256(b)
    return fmt.Sprintf("%x", h[:])
}

// Idempotency: running the same generation twice should yield identical spec files
func TestGenerateSpecs_Idempotency(t *testing.T) {
    prd := "用户字段：id(主键, int64), name(字符串)。"
    _, cleanup := setupTempPRD(t, prd)
    defer cleanup()

    r := buildRouter()
    body := map[string]interface{}{
        "specName":     "ai-codegen",
        "generateDocs": true,
        "generateDDL":  false,
    }
    headers := map[string]string{"X-User-Permissions": "ai.specs"}

    // First run
    w1 := performJSON(r, "POST", "/api/v1/ai/specs/generate", body, headers)
    if w1.Code != http.StatusOK {
        t.Fatalf("first run expected 200, got %d: %s", w1.Code, w1.Body.String())
    }
    var resp1 struct{ Data json.RawMessage }
    _ = json.Unmarshal(w1.Body.Bytes(), &resp1)
    var d1 struct{ Files map[string]string `json:"files"` }
    _ = json.Unmarshal(resp1.Data, &d1)

    // Record hashes
    req1 := fileSHA(t, d1.Files["requirements"])
    des1 := fileSHA(t, d1.Files["design"])
    tas1 := fileSHA(t, d1.Files["tasks"])
    oas1 := fileSHA(t, d1.Files["openapi"])

    // Second run (same inputs)
    w2 := performJSON(r, "POST", "/api/v1/ai/specs/generate", body, headers)
    if w2.Code != http.StatusOK {
        t.Fatalf("second run expected 200, got %d: %s", w2.Code, w2.Body.String())
    }
    var resp2 struct{ Data json.RawMessage }
    _ = json.Unmarshal(w2.Body.Bytes(), &resp2)
    var d2 struct{ Files map[string]string `json:"files"` }
    _ = json.Unmarshal(resp2.Data, &d2)

    req2 := fileSHA(t, d2.Files["requirements"])
    des2 := fileSHA(t, d2.Files["design"])
    tas2 := fileSHA(t, d2.Files["tasks"])
    oas2 := fileSHA(t, d2.Files["openapi"])

    if req1 != req2 || des1 != des2 || tas1 != tas2 || oas1 != oas2 {
        t.Fatalf("idempotency failed: files differ after repeated generation")
    }
}

// Error path: missing PRD file should return 500 with error envelope
func TestGenerateSpecs_MissingPRD_Error(t *testing.T) {
    // Prepare temp dir without writing PRD
    dir := t.TempDir()
    srcDir := filepath.Join(dir, ".spec-workflow", "sources")
    if err := os.MkdirAll(srcDir, 0o755); err != nil {
        t.Fatalf("mkdir: %v", err)
    }
    oldWd, _ := os.Getwd()
    defer func() { _ = os.Chdir(oldWd) }()
    _ = os.Chdir(dir)

    r := buildRouter()
    w := performJSON(r, "POST", "/api/v1/ai/specs/generate", map[string]interface{}{
        "generateDocs": true,
    }, map[string]string{"X-User-Permissions": "ai.specs"})

    if w.Code != http.StatusInternalServerError {
        t.Fatalf("expected 500, got %d: %s", w.Code, w.Body.String())
    }
    var errResp struct {
        Code    string `json:"code"`
        Message string `json:"message"`
    }
    _ = json.Unmarshal(w.Body.Bytes(), &errResp)
    if errResp.Code == "OK" {
        t.Fatalf("expected error response, got OK")
    }
}

// Error path: invalid JSON body should return 400 ValidationError
func TestGenerateSpecs_InvalidJSON_Error(t *testing.T) {
    // Prepare temp dir with valid PRD
    _, cleanup := setupTempPRD(t, "用户字段：id(主键, int64), name(字符串)。")
    defer cleanup()

    r := buildRouter()
    // Malformed JSON body
    raw := []byte("{ invalid")
    w := performRaw(r, "POST", "/api/v1/ai/specs/generate", raw, map[string]string{"X-User-Permissions": "ai.specs"})

    if w.Code != http.StatusBadRequest {
        t.Fatalf("expected 400, got %d: %s", w.Code, w.Body.String())
    }
    var errResp struct {
        Code    string `json:"code"`
        Message string `json:"message"`
    }
    _ = json.Unmarshal(w.Body.Bytes(), &errResp)
    if errResp.Code != "E1000" || errResp.Message != "ValidationError" {
        t.Fatalf("unexpected error envelope: %+v", errResp)
    }
}

// Error path: unreadable PRD file should return 500
func TestGenerateSpecs_UnreadablePRD_Error(t *testing.T) {
    // Create PRD file but make it unreadable
    dir := t.TempDir()
    srcDir := filepath.Join(dir, ".spec-workflow", "sources")
    if err := os.MkdirAll(srcDir, 0o755); err != nil {
        t.Fatalf("mkdir: %v", err)
    }
    // Make path a directory to force read error (works even when running as root)
    prdPath := filepath.Join(srcDir, "策划.md")
    if err := os.MkdirAll(prdPath, 0o755); err != nil {
        t.Fatalf("mkdir prd dir: %v", err)
    }
    oldWd, _ := os.Getwd()
    defer func() { _ = os.Chdir(oldWd) }()
    _ = os.Chdir(dir)

    r := buildRouter()
    w := performJSON(r, "POST", "/api/v1/ai/specs/generate", map[string]interface{}{
        "generateDocs": true,
    }, map[string]string{"X-User-Permissions": "ai.specs"})

    if w.Code != http.StatusInternalServerError {
        t.Fatalf("expected 500, got %d: %s", w.Code, w.Body.String())
    }
}

// Structured merge: provide an OpenAPI schema to ensure entities are parsed even with minimal PRD
func TestGenerateSpecs_StructuredMerge(t *testing.T) {
    // Minimal PRD
    _, cleanup := setupTempPRD(t, "")
    defer cleanup()
    // Create structured OpenAPI under .spec-workflow/specs/ai-codegen/openapi.json
    wd, _ := os.Getwd()
    specDir := filepath.Join(wd, ".spec-workflow", "specs", "ai-codegen")
    if err := os.MkdirAll(specDir, 0o755); err != nil {
        t.Fatalf("mkdir spec: %v", err)
    }
    openapi := map[string]interface{}{
        "openapi": "3.0.0",
        "components": map[string]interface{}{
            "schemas": map[string]interface{}{
                "User": map[string]interface{}{
                    "type":       "object",
                    "properties": map[string]interface{}{"id": map[string]interface{}{"type": "integer", "format": "int64"}, "name": map[string]interface{}{"type": "string"}},
                },
            },
        },
    }
    buf, _ := json.Marshal(openapi)
    if err := os.WriteFile(filepath.Join(specDir, "openapi.json"), buf, 0o644); err != nil {
        t.Fatalf("write openapi: %v", err)
    }

    r := buildRouter()
    w := performJSON(r, "POST", "/api/v1/ai/specs/generate", map[string]interface{}{
        "specName":      "ai-codegen",
        "sourceSpec":    "ai-codegen",
        "useStructured": true,
        "generateDocs":  false,
        "generateDDL":   false,
    }, map[string]string{"X-User-Permissions": "ai.specs"})

    if w.Code != http.StatusOK {
        t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
    }
    var resp struct{ Data json.RawMessage }
    _ = json.Unmarshal(w.Body.Bytes(), &resp)
    var data struct{ Entities int `json:"entities"` }
    _ = json.Unmarshal(resp.Data, &data)
    if data.Entities < 1 {
        t.Fatalf("expected entities >= 1 with structured merge, got %d", data.Entities)
    }
}