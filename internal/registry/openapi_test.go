package registry

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
	"xingzuo/internal/middleware"
)

// Contract test: ensure /registry endpoints are reflected in /registry/openapi paths
func TestOpenAPI_ContainsAllRegistryEndpoints(t *testing.T) {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.Use(middleware.RequestID(), middleware.ErrorHandler())

	v1 := r.Group("/api/v1")
	RegisterRoutes(v1)

	// Fetch OpenAPI
	reqOA := httptest.NewRequest(http.MethodGet, "/api/v1/registry/openapi", nil)
	wOA := httptest.NewRecorder()
	r.ServeHTTP(wOA, reqOA)
	if wOA.Code != http.StatusOK {
		t.Fatalf("openapi endpoint expected 200, got %d", wOA.Code)
	}
	var oaBody map[string]interface{}
	if err := json.Unmarshal(wOA.Body.Bytes(), &oaBody); err != nil {
		t.Fatalf("openapi invalid json: %v", err)
	}
	oaData, ok := oaBody["data"].(map[string]interface{})
	if !ok {
		t.Fatalf("openapi response missing data object")
	}
	if ver, ok := oaData["openapi"].(string); !ok || ver != "3.0.0" {
		t.Fatalf("openapi version expected 3.0.0, got %v", oaData["openapi"])
	}
	paths, ok := oaData["paths"].(map[string]interface{})
	if !ok {
		t.Fatalf("openapi paths missing or wrong type")
	}

	// Fetch registry
	reqReg := httptest.NewRequest(http.MethodGet, "/api/v1/registry", nil)
	wReg := httptest.NewRecorder()
	r.ServeHTTP(wReg, reqReg)
	if wReg.Code != http.StatusOK {
		t.Fatalf("registry endpoint expected 200, got %d", wReg.Code)
	}
	var regBody map[string]interface{}
	if err := json.Unmarshal(wReg.Body.Bytes(), &regBody); err != nil {
		t.Fatalf("registry invalid json: %v", err)
	}
	regData, ok := regBody["data"].(map[string]interface{})
	if !ok {
		t.Fatalf("registry response missing data object")
	}
	services, ok := regData["services"].(map[string]interface{})
	if !ok {
		t.Fatalf("registry services missing or wrong type")
	}

	// Check each declared endpoint exists in OpenAPI paths
	for _, svc := range services {
		svcMap, ok := svc.(map[string]interface{})
		if !ok {
			t.Fatalf("service entry wrong type")
		}
		eps, ok := svcMap["endpoints"].([]interface{})
		if !ok {
			t.Fatalf("service endpoints missing or wrong type")
		}
		for _, ep := range eps {
			epStr, ok := ep.(string)
			if !ok {
				t.Fatalf("endpoint entry not string: %v", ep)
			}
			if _, exists := paths[epStr]; !exists {
				t.Fatalf("openapi missing path for endpoint: %s", epStr)
			}
		}
	}
}

// Contract test: ensure every path declares standard 200/default responses
func TestOpenAPI_AllPathsHaveStandardResponses(t *testing.T) {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.Use(middleware.RequestID(), middleware.ErrorHandler())

	v1 := r.Group("/api/v1")
	RegisterRoutes(v1)

	// Fetch OpenAPI
	reqOA := httptest.NewRequest(http.MethodGet, "/api/v1/registry/openapi", nil)
	wOA := httptest.NewRecorder()
	r.ServeHTTP(wOA, reqOA)
	if wOA.Code != http.StatusOK {
		t.Fatalf("openapi endpoint expected 200, got %d", wOA.Code)
	}
	var oaBody map[string]interface{}
	if err := json.Unmarshal(wOA.Body.Bytes(), &oaBody); err != nil {
		t.Fatalf("openapi invalid json: %v", err)
	}
	oaData, ok := oaBody["data"].(map[string]interface{})
	if !ok {
		t.Fatalf("openapi response missing data object")
	}
	paths, ok := oaData["paths"].(map[string]interface{})
	if !ok {
		t.Fatalf("openapi paths missing or wrong type")
	}

	for path, raw := range paths {
		methods, ok := raw.(map[string]interface{})
		if !ok {
			t.Fatalf("path %s definition wrong type", path)
		}
		for method, defRaw := range methods {
			def, ok := defRaw.(map[string]interface{})
			if !ok {
				t.Fatalf("path %s %s definition wrong type", path, method)
			}
			respRaw, ok := def["responses"].(map[string]interface{})
			if !ok {
				t.Fatalf("path %s %s missing responses", path, method)
			}
			if _, ok := respRaw["200"]; !ok {
				t.Fatalf("path %s %s missing 200 response", path, method)
			}
			if _, ok := respRaw["default"]; !ok {
				t.Fatalf("path %s %s missing default response", path, method)
			}
			// Optional: check $ref to components/responses
			if ref200, ok := respRaw["200"].(map[string]interface{}); ok {
				if r, ok := ref200["$ref"].(string); ok && r != "#/components/responses/OK" {
					t.Fatalf("path %s %s 200 should ref components.responses.OK, got %s", path, method, r)
				}
			}
			if refDef, ok := respRaw["default"].(map[string]interface{}); ok {
				if r, ok := refDef["$ref"].(string); ok && r != "#/components/responses/Error" {
					t.Fatalf("path %s %s default should ref components.responses.Error, got %s", path, method, r)
				}
			}
		}
	}
}
