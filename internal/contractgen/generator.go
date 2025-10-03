package contractgen

import (
	"fmt"
	"strings"
)

// GenerateOpenAPI converts a structured prompt (map form) into an OpenAPI-like map.
// The prompt structure is expected to be:
//
//	{
//	  "name": string,
//	  "resources": [
//	    {
//	      "name": string,
//	      "basePath": string, // e.g. /api/v1/articles
//	      "operations": ["list","get","create","update","delete"],
//	      "schema": { ... } // JSON Schema for resource
//	    }
//	  ]
//	}
func GenerateOpenAPI(prompt map[string]interface{}) map[string]interface{} {
	title := getString(prompt, "name", "Generated API")
	components := baseComponents()
	paths := make(map[string]interface{})

	// Attach resource schemas
	if resources, ok := prompt["resources"].([]interface{}); ok {
		for _, r := range resources {
			rm, ok := r.(map[string]interface{})
			if !ok {
				continue
			}
			rname := getString(rm, "name", "Resource")
			base := getString(rm, "basePath", "/api/v1/"+strings.ToLower(rname)+"s")
			// register schema
			if schema, ok := rm["schema"].(map[string]interface{}); ok {
				componentsSchemas(components)[rname] = schema
			}
			// operations
			ops := toStringSlice(rm["operations"]) // known: list,get,create,update,delete
			for _, op := range ops {
				switch op {
				case "list":
					setPath(paths, base, "get", rname+" list")
				case "get":
					setPath(paths, base+"/{id}", "get", rname+" get")
				case "create":
					setPath(paths, base, "post", rname+" create")
					attachRequestBody(paths, base, "post", rname)
				case "update":
					setPath(paths, base+"/{id}", "put", rname+" update")
					attachRequestBody(paths, base+"/{id}", "put", rname)
				case "delete":
					setPath(paths, base+"/{id}", "delete", rname+" delete")
				}
			}
		}
	}

	return map[string]interface{}{
		"openapi":    "3.0.0",
		"info":       map[string]interface{}{"title": title, "version": "v1"},
		"components": components,
		"paths":      paths,
	}
}

// GenerateJSONSchema extracts resource schemas from the prompt into a flat map.
func GenerateJSONSchema(prompt map[string]interface{}) map[string]interface{} {
	out := map[string]interface{}{}
	if resources, ok := prompt["resources"].([]interface{}); ok {
		for _, r := range resources {
			rm, ok := r.(map[string]interface{})
			if !ok {
				continue
			}
			rname := getString(rm, "name", "Resource")
			if schema, ok := rm["schema"].(map[string]interface{}); ok {
				out[rname] = schema
			}
		}
	}
	return out
}

// Helpers
func baseComponents() map[string]interface{} {
	return map[string]interface{}{
		"securitySchemes": map[string]interface{}{
			"bearerAuth":        map[string]interface{}{"type": "http", "scheme": "bearer"},
			"headerPermissions": map[string]interface{}{"type": "apiKey", "in": "header", "name": "X-User-Permissions"},
		},
		"parameters": map[string]interface{}{
			"XRequestId": map[string]interface{}{"name": "X-Request-Id", "in": "header", "required": false, "schema": map[string]interface{}{"type": "string"}},
		},
		"schemas": map[string]interface{}{
			"Response": map[string]interface{}{
				"type":     "object",
				"required": []string{"code", "message", "requestId"},
				"properties": map[string]interface{}{
					"code":      map[string]interface{}{"type": "string", "enum": []string{"OK"}},
					"message":   map[string]interface{}{"type": "string"},
					"requestId": map[string]interface{}{"type": "string"},
					"severity":  map[string]interface{}{"type": "string", "enum": []string{"info", "warning", "error"}},
					"data":      map[string]interface{}{"type": "object"},
				},
			},
			"ErrorResponse": map[string]interface{}{
				"type":     "object",
				"required": []string{"code", "message", "requestId"},
				"properties": map[string]interface{}{
					"code":      map[string]interface{}{"type": "string", "enum": []string{"E1000", "E1100", "E1200", "E1300", "E1400", "E1500", "E2000", "E2100", "E3000", "E3100"}},
					"message":   map[string]interface{}{"type": "string"},
					"requestId": map[string]interface{}{"type": "string"},
					"hint":      map[string]interface{}{"type": "string"},
					"severity":  map[string]interface{}{"type": "string", "enum": []string{"info", "warning", "error"}},
					"detail":    map[string]interface{}{"type": "object"},
				},
			},
		},
		"responses": map[string]interface{}{
			"OK": map[string]interface{}{
				"description": "OK",
				"content": map[string]interface{}{
					"application/json": map[string]interface{}{
						"schema": map[string]interface{}{"$ref": "#/components/schemas/Response"},
					},
				},
			},
			"Error": map[string]interface{}{
				"description": "Error",
				"content": map[string]interface{}{
					"application/json": map[string]interface{}{
						"schema": map[string]interface{}{"$ref": "#/components/schemas/ErrorResponse"},
					},
				},
			},
		},
	}
}

func componentsSchemas(components map[string]interface{}) map[string]interface{} {
	if s, ok := components["schemas"].(map[string]interface{}); ok {
		return s
	}
	panic("components.schemas missing")
}

func setPath(paths map[string]interface{}, path, method, summary string) {
	pm := ensurePath(paths, path)
	pm[method] = map[string]interface{}{
		"summary":    summary,
		"parameters": []interface{}{map[string]interface{}{"$ref": "#/components/parameters/XRequestId"}},
		"security":   []map[string]interface{}{{"bearerAuth": []interface{}{}}, {"headerPermissions": []interface{}{}}},
		"responses":  map[string]interface{}{"200": map[string]interface{}{"$ref": "#/components/responses/OK"}, "default": map[string]interface{}{"$ref": "#/components/responses/Error"}},
	}
}

func attachRequestBody(paths map[string]interface{}, path, method, schemaRefName string) {
	if pm, ok := paths[path].(map[string]interface{}); ok {
		pm[method] = merge(pm[method], map[string]interface{}{
			"requestBody": map[string]interface{}{
				"required": true,
				"content": map[string]interface{}{
					"application/json": map[string]interface{}{
						"schema": map[string]interface{}{"$ref": fmt.Sprintf("#/components/schemas/%s", schemaRefName)},
					},
				},
			},
		})
	}
}

func ensurePath(paths map[string]interface{}, path string) map[string]interface{} {
	if v, ok := paths[path].(map[string]interface{}); ok {
		return v
	}
	m := map[string]interface{}{}
	paths[path] = m
	return m
}

func merge(a, b interface{}) map[string]interface{} {
	am, _ := a.(map[string]interface{})
	bm, _ := b.(map[string]interface{})
	out := map[string]interface{}{}
	for k, v := range am {
		out[k] = v
	}
	for k, v := range bm {
		out[k] = v
	}
	return out
}

func getString(m map[string]interface{}, key string, def string) string {
	if v, ok := m[key]; ok {
		if s, ok := v.(string); ok && s != "" {
			return s
		}
	}
	return def
}

func toStringSlice(v interface{}) []string {
	out := []string{}
	if v == nil {
		return out
	}
	if arr, ok := v.([]interface{}); ok {
		for _, x := range arr {
			if s, ok := x.(string); ok {
				out = append(out, s)
			}
		}
	}
	return out
}
