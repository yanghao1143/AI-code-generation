package registry

import "github.com/gin-gonic/gin"

// BuildOpenAPISpec builds an OpenAPI 3.0 spec reflecting current endpoints,
// including security schemes, common parameters, and request schemas.
func BuildOpenAPISpec() map[string]interface{} {
    return gin.H{
        "openapi": "3.0.0",
        "info":    gin.H{"title": "Xingzuo API", "version": "v1"},
        "components": gin.H{
			"securitySchemes": gin.H{
				"bearerAuth":        gin.H{"type": "http", "scheme": "bearer"},
				"headerPermissions": gin.H{"type": "apiKey", "in": "header", "name": "X-User-Permissions"},
			},
			"parameters": gin.H{
				"XRequestId":     gin.H{"name": "X-Request-Id", "in": "header", "required": false, "schema": gin.H{"type": "string"}},
				"XApprovalTicket": gin.H{"name": "X-Approval-Ticket", "in": "header", "required": true, "schema": gin.H{"type": "string"}, "description": "审批票据；需在白名单(APPROVAL_TICKETS)中"},
			},
            "schemas": gin.H{
                // Standard unified responses
                "Response": gin.H{
                    "type":     "object",
                    "required": []string{"code", "message", "requestId"},
                    "properties": gin.H{
                        "code":      gin.H{"type": "string", "enum": []string{"OK"}},
                        "message":   gin.H{"type": "string"},
                        "requestId": gin.H{"type": "string"},
                        "severity":  gin.H{"type": "string", "enum": []string{"info", "warning", "error"}},
                        "data":      gin.H{"type": "object"},
                    },
                },
                "ErrorResponse": gin.H{
                    "type":     "object",
                    "required": []string{"code", "message", "requestId"},
                    "properties": gin.H{
                        "code":      gin.H{"type": "string", "enum": []string{"E1000", "E1100", "E1200", "E1300", "E1400", "E1500", "E2000", "E2100", "E3000", "E3100"}},
                        "message":   gin.H{"type": "string"},
                        "requestId": gin.H{"type": "string"},
                        "hint":      gin.H{"type": "string"},
                        "severity":  gin.H{"type": "string", "enum": []string{"info", "warning", "error"}},
                        "detail":    gin.H{"type": "object"},
                    },
                },
                // AI Specs: request/response schemas
                "AISpecsGenerateRequest": gin.H{
                    "type":       "object",
                    "description": "Generate specs and DDL from PRD (策划.md). All fields optional with sensible defaults.",
                    "properties": gin.H{
                        "specName":        gin.H{"type": "string", "description": "Spec name under .spec-workflow/specs/{specName}", "example": "ai-codegen"},
                        "sourceSpec":      gin.H{"type": "string", "description": "Source spec for structured merge (openapi/jsonschema) under .spec-workflow/specs/{sourceSpec}"},
                        "useStructured":   gin.H{"type": "boolean", "description": "Use structured merge when available"},
                        "generateDocs":    gin.H{"type": "boolean", "description": "Generate requirements/design/tasks/openapi docs", "example": true},
                        "generateDDL":     gin.H{"type": "boolean", "description": "Generate DDL SQL from DomainModel", "example": false},
                        "writeWorkflowDDL": gin.H{"type": "boolean", "description": "Also write DDL files into .spec-workflow/db/mysql"},
                        "execChannel":     gin.H{"type": "string", "description": "Optional: preview planned SQL for given channel", "enum": []string{"READ", "CHANGE", "ROLLBACK"}},
                        "execEnv":         gin.H{"type": "string", "description": "Optional: environment name for DSN resolution when executing", "enum": []string{"test", "staging", "prod"}},
                        "dryRun":          gin.H{"type": "boolean", "description": "Dry-run flag (default true). When true, never execute DB changes."},
                        "ticketId":        gin.H{"type": "string", "description": "Ticket ID for approval when executing change/rollback"},
                    },
                },
                "ClarifyIssue": gin.H{
                    "type":       "object",
                    "description": "Clarification issues discovered during PRD parsing",
                    "properties": gin.H{
                        "ID":       gin.H{"type": "string"},
                        "Message":  gin.H{"type": "string"},
                        "Severity": gin.H{"type": "string", "enum": []string{"blocker", "warning", "info"}},
                        "Resolved": gin.H{"type": "boolean"},
                    },
                },
                "AISpecsGenerateResponseData": gin.H{
                    "type":       "object",
                    "description": "Response data for /api/v1/ai/specs/generate",
                    "properties": gin.H{
                        "operationId": gin.H{"type": "string"},
                        "specName":    gin.H{"type": "string"},
                        "sourceSpec":  gin.H{"type": "string"},
                        "entities":    gin.H{"type": "integer", "minimum": 0},
                        "relations":   gin.H{"type": "integer", "minimum": 0},
                        "issues":      gin.H{"type": "array", "items": gin.H{"$ref": "#/components/schemas/ClarifyIssue"}},
                        "files":       gin.H{"type": "object", "additionalProperties": gin.H{"type": "string"}},
                        "sqlPreview":  gin.H{"type": "array", "items": gin.H{"type": "string"}},
                        "sqlHash":     gin.H{"type": "string"},
                    },
                },
                // Clarify service: request/response schemas
                "ClarifyGenerateRequest": gin.H{
                    "type":       "object",
                    "description": "Clarify generation input from natural language prompt",
                    "properties": gin.H{
                        "prompt":       gin.H{"type": "string", "description": "用户输入的业务或需求描述（自然语言）"},
                        "language":     gin.H{"type": "string", "description": "期望输出语言，例如 zh-CN、en-US", "example": "zh-CN"},
                        "useStructured": gin.H{"type": "boolean", "description": "是否使用结构化解析（更严格、更可控）", "example": false},
                        "stream":       gin.H{"type": "boolean", "description": "是否要求流式输出（SSE/WS）", "example": false},
                    },
                },
                "ClarifyGenerateResponseData": gin.H{
                    "type":       "object",
                    "description": "Structured clarify artifacts: requirements/design/tasks and minimal OpenAPI fragment",
                    "properties": gin.H{
                        "requirements": gin.H{"type": "array", "items": gin.H{"type": "string"}},
                        "design":       gin.H{"type": "array", "items": gin.H{"type": "string"}},
                        "tasks":        gin.H{"type": "array", "items": gin.H{"type": "string"}},
                        "openapi":      gin.H{"type": "object"},
                        "issues":       gin.H{"type": "array", "items": gin.H{"$ref": "#/components/schemas/ClarifyIssue"}},
                    },
                },
                // Clarify export: request/response schemas
                "ClarifyExportMarkdownRequest": gin.H{
                    "type":       "object",
                    "description": "导出澄清产物为 Markdown 文件。仅支持 format=md。",
                    "properties": gin.H{
                        "prompt":   gin.H{"type": "string", "description": "自然语言 prompt"},
                        "language": gin.H{"type": "string", "description": "输出语言", "example": "zh-CN"},
                        "format":   gin.H{"type": "string", "enum": []string{"md"}, "description": "导出格式（仅支持md）"},
                    },
                },
                "ClarifyExportResponseData": gin.H{
                    "type":       "object",
                    "description": "澄清文档导出结果（Markdown/PDF/DOCX）。download 字段在 PDF/DOCX 导出返回。",
                    "properties": gin.H{
                        "fileName": gin.H{"type": "string"},
                        "filePath": gin.H{"type": "string"},
                        "format":   gin.H{"type": "string", "enum": []string{"md", "pdf", "docx"}},
                        "download": gin.H{"type": "string", "description": "受限下载路径（/api/v1/ai/clarify/docs/:name），仅在pdf/docx导出时返回"},
                    },
                },
                // Articles entity & list response (for pagination documentation)
                "Article": gin.H{
                    "type":     "object",
                    "required": []string{"id", "title", "content", "authorId", "createdAt", "updatedAt"},
                    "properties": gin.H{
                        "id":        gin.H{"type": "string"},
                        "title":     gin.H{"type": "string"},
                        "content":   gin.H{"type": "string"},
                        "authorId":  gin.H{"type": "string"},
                        "tags":      gin.H{"type": "array", "items": gin.H{"type": "string"}},
                        "createdAt": gin.H{"type": "string", "format": "date-time"},
                        "updatedAt": gin.H{"type": "string", "format": "date-time"},
                    },
                },
                "PageMeta": gin.H{
                    "type":       "object",
                    "description": "Cursor-based pagination metadata",
                    "properties": gin.H{
                        "pageSize":    gin.H{"type": "integer", "minimum": 1, "maximum": 1000},
                        "nextAfterId": gin.H{"type": "string"},
                        "hasMore":     gin.H{"type": "boolean"},
                        "total":       gin.H{"type": "integer", "minimum": 0},
                    },
                },
                "ArticlesListData": gin.H{
                    "type":       "object",
                    "description": "List data for /api/v1/articles",
                    "properties": gin.H{
                        "items": gin.H{"type": "array", "items": gin.H{"$ref": "#/components/schemas/Article"}},
                        "page":  gin.H{"$ref": "#/components/schemas/PageMeta"},
                    },
                },
                // Articles create/update requests
                "ArticleCreateRequest": gin.H{
                    "type":     "object",
                    "required": []string{"title", "content", "authorId"},
                    "properties": gin.H{
                        "title":    gin.H{"type": "string"},
                        "content":  gin.H{"type": "string"},
                        "authorId": gin.H{"type": "string"},
                        "tags":     gin.H{"type": "array", "items": gin.H{"type": "string"}},
                    },
                },
                "ArticleUpdateRequest": gin.H{
                    "type":       "object",
                    "description": "Partial update; all fields optional",
                    "properties": gin.H{
                        "title":   gin.H{"type": "string"},
                        "content": gin.H{"type": "string"},
                        "tags":    gin.H{"type": "array", "items": gin.H{"type": "string"}},
                    },
                },
                "ArticleData": gin.H{
                    "type":       "object",
                    "description": "Single article response data",
                    "properties": gin.H{"item": gin.H{"$ref": "#/components/schemas/Article"}},
                },
                // Frontend requests
                "FrontendGenerateRequest": gin.H{
                    "type":     "object",
                    "required": []string{"name", "dsl"},
                    "properties": gin.H{
						"name":        gin.H{"type": "string"},
						"template":    gin.H{"type": "string"},
						"dsl":         gin.H{"type": "object"},
						"permissions": gin.H{"type": "array", "items": gin.H{"type": "string"}},
					},
				},
				"FrontendValidateRequest": gin.H{
					"type":       "object",
					"required":   []string{"dsl"},
					"properties": gin.H{"dsl": gin.H{"type": "object"}},
				},
				"FrontendCommitRequest": gin.H{
					"type":     "object",
					"required": []string{"snapshotId"},
					"properties": gin.H{
						"snapshotId": gin.H{"type": "string"},
						"message":    gin.H{"type": "string"},
					},
				},

				// Backend requests
				"BackendGenerateRequest": gin.H{
					"type":     "object",
					"required": []string{"name", "spec"},
					"properties": gin.H{
						"name":     gin.H{"type": "string"},
						"spec":     gin.H{"type": "object"},
						"template": gin.H{"type": "string"},
					},
				},
				"BackendScaffoldRequest": gin.H{
					"type":     "object",
					"required": []string{"serviceName", "endpoints"},
					"properties": gin.H{
						"serviceName": gin.H{"type": "string"},
						"endpoints":   gin.H{"type": "array", "items": gin.H{"type": "string"}},
					},
				},
				"BackendFixRequest": gin.H{
					"type":     "object",
					"required": []string{"reportId", "diff"},
					"properties": gin.H{
						"reportId": gin.H{"type": "string"},
						"diff":     gin.H{"type": "object"},
					},
				},

				// Billing requests
				"BillingCreateOrderRequest": gin.H{
					"type":     "object",
					"required": []string{"productId", "amount", "currency"},
					"properties": gin.H{
						"productId": gin.H{"type": "string"},
						"amount":    gin.H{"type": "integer"},
						"currency":  gin.H{"type": "string"},
					},
				},
				"BillingCreatePaymentRequest": gin.H{
					"type":     "object",
					"required": []string{"orderId", "method"},
					"properties": gin.H{
						"orderId": gin.H{"type": "string"},
						"method":  gin.H{"type": "string"},
					},
				},

				// Observe request
				"ObserveEventRequest": gin.H{
					"type":     "object",
					"required": []string{"type", "severity"},
					"properties": gin.H{
						"type":     gin.H{"type": "string"},
						"severity": gin.H{"type": "string"},
						"message":  gin.H{"type": "string"},
					},
				},

				// LLM unified requests (simplified)
				"LLMChatRequest": gin.H{
					"type":     "object",
					"required": []string{"modelId", "messages"},
					"properties": gin.H{
						"modelId":      gin.H{"type": "string"},
						"providerHint": gin.H{"type": "string"},
						"stream":       gin.H{"type": "boolean"},
						"temperature":  gin.H{"type": "number"},
						"topP":         gin.H{"type": "number"},
						"messages": gin.H{
							"type": "array",
							"items": gin.H{
								"type":       "object",
								"required":   []string{"role", "content"},
								"properties": gin.H{"role": gin.H{"type": "string"}, "content": gin.H{"type": "string"}},
							},
						},
					},
				},
				"LLMEmbeddingsRequest": gin.H{
					"type":     "object",
					"required": []string{"modelId", "input"},
					"properties": gin.H{
						"modelId": gin.H{"type": "string"},
						"input":   gin.H{"type": "array", "items": gin.H{"type": "string"}},
					},
				},
			"LLMModerateRequest": gin.H{
				"type":     "object",
				"required": []string{"input"},
				"properties": gin.H{
					"input": gin.H{"type": "string"},
				},
			},

			// Public auth login (request/response)
			"AuthLoginRequest": gin.H{
				"type":       "object",
				"description": "Public login request to issue HS256 JWT",
				"properties": gin.H{
					"userId":       gin.H{"type": "string", "example": "u1"},
					"permissions":  gin.H{"type": "array", "items": gin.H{"type": "string"}, "example": []string{"articles"}},
					"expiresInSec": gin.H{"type": "integer", "minimum": 1, "example": 3600},
				},
			},
			"AuthLoginResponse": gin.H{
				"type":       "object",
				"description": "Public login response containing JWT and claims",
				"required":   []string{"token", "userId", "expiresAt"},
				"properties": gin.H{
					"token":       gin.H{"type": "string", "description": "HS256 JWT"},
					"userId":      gin.H{"type": "string"},
					"permissions": gin.H{"type": "array", "items": gin.H{"type": "string"}},
					"expiresAt":   gin.H{"type": "integer", "description": "Unix timestamp (seconds)"},
				},
			},

				// Reply template preview request (simplified)
				"ReplyTemplatePreviewRequest": gin.H{
					"type":     "object",
					"required": []string{"content"},
					"properties": gin.H{
						"content": gin.H{"type": "string", "description": "模板内容，支持 {{var}} 变量"},
						"vars":    gin.H{"type": "object", "description": "变量值字典"},
						"schema":  gin.H{"type": "object", "description": "变量Schema（简化版）", "properties": gin.H{
							"properties": gin.H{"type": "object", "additionalProperties": gin.H{"type": "object", "properties": gin.H{"type": gin.H{"type": "string", "enum": []string{"string", "number", "boolean"}}}}},
							"required":   gin.H{"type": "array", "items": gin.H{"type": "string"}},
						}},
						"strict":  gin.H{"type": "boolean", "description": "严格模式：校验失败直接返回400"},
					},
				},

				// Fans batch export (request/response)
				"FansExportRequest": gin.H{
					"type":       "object",
					"description": "批量导出粉丝；支持过滤并需审批票据",
					"properties": gin.H{
						"format":   gin.H{"type": "string", "enum": []string{"csv"}, "description": "导出格式（目前仅支持csv）"},
						"anchorId": gin.H{"type": "string", "description": "主播ID过滤"},
						"tagIds":   gin.H{"type": "array", "items": gin.H{"type": "string"}, "description": "标签ID集合（任一匹配）"},
						"active":   gin.H{"type": "boolean", "description": "是否活跃过滤"},
					},
				},
				"FansExportResponseData": gin.H{
					"type":       "object",
					"description": "批量导出结果数据（占位）",
					"properties": gin.H{
						"format":     gin.H{"type": "string"},
						"filters":    gin.H{"$ref": "#/components/schemas/FansExportRequest"},
						"csvContent": gin.H{"type": "string", "description": "CSV文本内容"},
					},
				},

				// Fans session uniqueness (request/response)
				"ActiveConversationRequest": gin.H{
					"type":     "object",
					"required": []string{"conversationId"},
					"properties": gin.H{
						"conversationId": gin.H{"type": "string"},
					},
				},
				"ActiveConversationData": gin.H{
					"type":       "object",
					"description": "粉丝当前活跃会话返回数据",
					"properties": gin.H{
						"fanId":          gin.H{"type": "string"},
						"conversationId": gin.H{"type": "string"},
					},
				},
				"ActiveConversationClearedData": gin.H{
					"type":       "object",
					"description": "清除粉丝活跃会话后的返回数据",
					"properties": gin.H{
						"fanId":  gin.H{"type": "string"},
						"cleared": gin.H{"type": "boolean"},
					},
				},

				// Fans entity & list response
				"Fan": gin.H{
					"type":     "object",
					"required": []string{"id", "name", "createdAt"},
					"properties": gin.H{
						"id":        gin.H{"type": "integer", "format": "int64"},
						"name":      gin.H{"type": "string"},
						"gender":    gin.H{"type": "string"},
						"birthday":  gin.H{"type": "string", "description": "YYYY-MM-DD 或 RFC3339 日期字符串"},
						"zodiac":    gin.H{"type": "string"},
						"createdAt": gin.H{"type": "string", "format": "date-time"},
					},
				},
				"FanCreateRequest": gin.H{
					"type":     "object",
					"required": []string{"name"},
					"properties": gin.H{
						"name":     gin.H{"type": "string"},
						"gender":   gin.H{"type": "string"},
						"birthday": gin.H{"type": "string"},
						"zodiac":   gin.H{"type": "string"},
					},
				},
				"FanUpdateRequest": gin.H{
					"type":       "object",
					"description": "Partial update; all fields optional",
					"properties": gin.H{
						"name":     gin.H{"type": "string"},
						"gender":   gin.H{"type": "string"},
						"birthday": gin.H{"type": "string"},
						"zodiac":   gin.H{"type": "string"},
					},
				},
				"FansListData": gin.H{
					"type":       "object",
					"description": "List data for /api/v1/fans",
					"properties": gin.H{
						"items": gin.H{"type": "array", "items": gin.H{"$ref": "#/components/schemas/Fan"}},
						"page":  gin.H{"$ref": "#/components/schemas/PageMeta"},
					},
				},
			},
			"responses": gin.H{
				"OK": gin.H{
					"description": "OK",
					"content":     gin.H{"application/json": gin.H{"schema": gin.H{"$ref": "#/components/schemas/Response"}, "examples": gin.H{"success": gin.H{"value": gin.H{"code": "OK", "message": "success", "requestId": "00000000-0000-0000-0000-000000000000", "severity": "info", "data": gin.H{"example": "value"}}}}}},
				},
				"Error": gin.H{
					"description": "Error",
					"content":     gin.H{"application/json": gin.H{"schema": gin.H{"$ref": "#/components/schemas/ErrorResponse"}, "examples": gin.H{"authFailed": gin.H{"value": gin.H{"code": "E1100", "message": "AuthFailed", "requestId": "00000000-0000-0000-0000-000000000000", "hint": "请提供Authorization: Bearer <token>", "severity": "warning", "detail": gin.H{"error": "missing Authorization"}}}}}},
				},
			},
		},
		"paths": gin.H{
			// Public auth (no security)
			"/api/public/auth/login": gin.H{"post": gin.H{
				"summary":     "Public login",
				"description": "Issue HS256 JWT with claims: sub (userId), permissions, exp. This endpoint is public and does not require authentication.",
				"parameters":  []interface{}{gin.H{"$ref": "#/components/parameters/XRequestId"}},
				"requestBody": gin.H{"required": true, "content": gin.H{"application/json": gin.H{"schema": gin.H{"$ref": "#/components/schemas/AuthLoginRequest"}, "examples": gin.H{"default": gin.H{"value": gin.H{"userId": "u1", "permissions": []string{"articles"}, "expiresInSec": 3600}}}}}},
				"x-data-schema": gin.H{"$ref": "#/components/schemas/AuthLoginResponse"},
				"responses":   gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
			}},
			// Registry (auth only)
			"/api/v1/registry":         gin.H{"get": gin.H{"summary": "API registry", "parameters": []interface{}{gin.H{"$ref": "#/components/parameters/XRequestId"}}, "security": []gin.H{gin.H{"bearerAuth": []interface{}{}}}, "responses": gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}}}},
			"/api/v1/registry/openapi": gin.H{"get": gin.H{"summary": "OpenAPI spec", "parameters": []interface{}{gin.H{"$ref": "#/components/parameters/XRequestId"}}, "security": []gin.H{gin.H{"bearerAuth": []interface{}{}}}, "responses": gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}}}},

            // Articles (auth + permission)
            "/api/v1/articles": gin.H{
                "get": gin.H{
                    "summary":    "List articles",
                    "parameters": []interface{}{
                        gin.H{"$ref": "#/components/parameters/XRequestId"},
                        // Pagination & filters (non-breaking; current implementation returns full list)
                        gin.H{"name": "pageSize", "in": "query", "required": false, "schema": gin.H{"type": "integer", "minimum": 1, "maximum": 1000}, "example": 10, "description": "Page size (1-1000). Prefer over legacy 'limit'"},
                        gin.H{"name": "afterId", "in": "query", "required": false, "schema": gin.H{"type": "string"}, "example": "article-id-123", "description": "Cursor: start after the given article ID"},
                        gin.H{"name": "authorId", "in": "query", "required": false, "schema": gin.H{"type": "string"}, "example": "u1", "description": "Filter items by authorId"},
                        gin.H{"name": "qTitle", "in": "query", "required": false, "schema": gin.H{"type": "string"}, "example": "Hello", "description": "Structured search: substring match on title (case-insensitive)"},
                        gin.H{"name": "qContent", "in": "query", "required": false, "schema": gin.H{"type": "string"}, "example": "World", "description": "Structured search: substring match on content (case-insensitive)"},
                        // Legacy filters kept for compatibility
                        gin.H{"name": "limit", "in": "query", "required": false, "schema": gin.H{"type": "integer", "minimum": 1, "maximum": 1000}, "example": 10, "description": "[Legacy] Max number of items (use 'pageSize')"},
                        gin.H{"name": "offset", "in": "query", "required": false, "schema": gin.H{"type": "integer", "minimum": 0}, "example": 0, "description": "[Legacy] Start offset (prefer 'afterId' cursor)"},
                        gin.H{"name": "q", "in": "query", "required": false, "schema": gin.H{"type": "string"}, "example": "hello", "description": "[Legacy] Keyword across title/content/tags (case-insensitive contains)"},
                    },
                    "security":   []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
                    // Document the expected data shape for clients; response envelope stays unified
                    "x-data-schema": gin.H{"$ref": "#/components/schemas/ArticlesListData"},
                    "responses":  gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
                },
                "post": gin.H{
                    "summary":     "Create article",
                    "parameters":  []interface{}{gin.H{"$ref": "#/components/parameters/XRequestId"}},
					"security":    []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
					"requestBody": gin.H{"required": true, "content": gin.H{"application/json": gin.H{"schema": gin.H{"$ref": "#/components/schemas/ArticleCreateRequest"}}}},
					"x-data-schema": gin.H{"$ref": "#/components/schemas/Article"},
					"responses":   gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
                },
			},
			"/api/v1/articles/stream": gin.H{
				"get": gin.H{
					"summary":     "Articles SSE stream",
					"description": "Server-Sent Events stream for article operations. Content-Type: text/event-stream. Frames include data (payload), heartbeat (keep-alive), and a terminal 'event: done'. Requires bearer authentication and 'articles' permission via RBAC. Errors follow unified ErrorResponse codes and structure.",
					"parameters": []interface{}{
						gin.H{"$ref": "#/components/parameters/XRequestId"},
						gin.H{"name": "mode", "in": "query", "required": false, "schema": gin.H{"type": "string", "enum": []string{"example", "list"}}, "description": "Streaming mode: 'example' emits demo frames; 'list' streams current articles as JSON frames"},
						// Heartbeat interval configuration (milliseconds)
						gin.H{"name": "heartbeatMs", "in": "query", "required": false, "schema": gin.H{"type": "integer", "minimum": 1, "maximum": 10000}, "example": 5, "examples": gin.H{"fast": gin.H{"summary": "Fast", "value": 5}, "medium": gin.H{"summary": "Medium", "value": 50}, "slow": gin.H{"summary": "Slow", "value": 500}}, "description": "Heartbeat comment frame interval in milliseconds (default 5ms; bounds 1–10000ms)"},
						// List mode filters (structured)
						gin.H{"name": "pageSize", "in": "query", "required": false, "schema": gin.H{"type": "integer", "minimum": 1, "maximum": 1000}, "example": 10, "description": "Page size when mode=list (1-1000). Prefer over legacy 'limit'"},
						gin.H{"name": "afterId", "in": "query", "required": false, "schema": gin.H{"type": "string"}, "example": "article-id-123", "description": "Cursor: start after the given article ID when mode=list"},
						gin.H{"name": "authorId", "in": "query", "required": false, "schema": gin.H{"type": "string"}, "example": "u1", "description": "Filter items by authorId when mode=list"},
						gin.H{"name": "qTitle", "in": "query", "required": false, "schema": gin.H{"type": "string"}, "example": "Hello", "description": "Structured search: substring match on title (case-insensitive)"},
						gin.H{"name": "qContent", "in": "query", "required": false, "schema": gin.H{"type": "string"}, "example": "World", "description": "Structured search: substring match on content (case-insensitive)"},
						gin.H{"name": "qTags", "in": "query", "required": false, "schema": gin.H{"type": "string"}, "example": "t1,t2", "description": "Structured search: comma-separated tags. Use qTagsOp=all to require all tags, qTagsOp=any to match any"},
						// Exclusion and weighting
						gin.H{"name": "qNotTags", "in": "query", "required": false, "schema": gin.H{"type": "string"}, "example": "t3,t4", "description": "Exclude items containing any of these comma-separated tags"},
						gin.H{"name": "qTagsOp", "in": "query", "required": false, "schema": gin.H{"type": "string", "enum": []string{"all", "any"}}, "example": "all", "description": "Tag match operator: all (intersection) or any (union); default all"},
						gin.H{"name": "qOp", "in": "query", "required": false, "schema": gin.H{"type": "string", "enum": []string{"or", "and"}}, "example": "or", "description": "Combine structured filters using logical 'or' or 'and' (default 'or')"},
						gin.H{"name": "qTagWeights", "in": "query", "required": false, "schema": gin.H{"type": "string"}, "example": "t1:2,t2:1", "description": "Tag weights mapping as 'tag:weight' pairs, comma-separated; used to score items"},
						gin.H{"name": "qTagMinWeight", "in": "query", "required": false, "schema": gin.H{"type": "integer", "minimum": 1}, "example": 2, "description": "Minimum cumulative tag weight threshold to include an item"},
						gin.H{"name": "createdWithinMs", "in": "query", "required": false, "schema": gin.H{"type": "integer", "minimum": 1}, "example": 60000, "description": "Include items created within the last N milliseconds"},
						gin.H{"name": "createdOlderThanMs", "in": "query", "required": false, "schema": gin.H{"type": "integer", "minimum": 1}, "example": 3600000, "description": "Include items created older than N milliseconds"},
						gin.H{"name": "createdStart", "in": "query", "required": false, "schema": gin.H{"type": "string", "format": "date-time"}, "example": "2025-09-30T21:00:00Z", "description": "Include items created at or after the given RFC3339 timestamp"},
						gin.H{"name": "createdEnd", "in": "query", "required": false, "schema": gin.H{"type": "string", "format": "date-time"}, "example": "2025-09-30T22:00:00Z", "description": "Include items created at or before the given RFC3339 timestamp"},
						gin.H{"name": "follow", "in": "query", "required": false, "schema": gin.H{"type": "boolean"}, "example": true, "description": "Keep stream open to push newly created matching items (mode=list)"},
						gin.H{"name": "followMaxMs", "in": "query", "required": false, "schema": gin.H{"type": "integer", "minimum": 1, "maximum": 60000}, "example": 2000, "description": "Max follow duration in milliseconds (bounds 1–60000ms; default 2000ms, env adjustable)"},
						gin.H{"name": "followBufferMs", "in": "query", "required": false, "schema": gin.H{"type": "integer", "minimum": 1}, "example": 10, "description": "Buffer window in milliseconds to aggregate new items before flush"},
						gin.H{"name": "followBatchMax", "in": "query", "required": false, "schema": gin.H{"type": "integer", "minimum": 1}, "example": 100, "description": "Max items per flush batch during follow mode"},
						// Legacy filters kept for compatibility
						gin.H{"name": "limit", "in": "query", "required": false, "schema": gin.H{"type": "integer", "minimum": 1, "maximum": 1000}, "example": 10, "description": "[Legacy] Max number of items (use 'pageSize')"},
						gin.H{"name": "offset", "in": "query", "required": false, "schema": gin.H{"type": "integer", "minimum": 0}, "example": 0, "description": "[Legacy] Start offset (prefer 'afterId' cursor)"},
						gin.H{"name": "q", "in": "query", "required": false, "schema": gin.H{"type": "string"}, "example": "hello", "description": "[Legacy] Keyword across title/content/tags (case-insensitive contains)"},
					},
					"security": []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
					// Vendor extension to indicate streaming semantics without breaking unified responses
					"x-streaming":             true,
					"x-response-content-type": "text/event-stream",
					"x-sse": gin.H{
						"contentType": "text/event-stream",
						"examples": gin.H{
							"exampleMode": gin.H{"summary": "Demo frames", "body": `data: part-1

:heartbeat

data: part-2

event: done

`},
							"listMode": gin.H{"summary": "List items", "body": `event: item

data: {"id":"a1"}

:heartbeat

event: item

data: {"id":"a2"}

event: done

`},
							"followMode": gin.H{"summary": "Follow new items", "body": `event: item

data: {"id":"a1"}

:heartbeat

:heartbeat

event: item

data: {"id":"a3"}

event: done

`},
							"jitter": gin.H{"summary": "Network jitter with variable heartbeats", "body": `event: item

data: {"id":"a10"}

:heartbeat

// transient jitter

:heartbeat

:heartbeat

event: item

data: {"id":"a11"}

event: done

`},
							"heartbeatLoss": gin.H{"summary": "Heartbeat loss and late recovery", "body": `event: item

data: {"id":"a20"}

:heartbeat

// network drop (no heartbeats)

event: item

data: {"id":"a21"}

:heartbeat

event: done

`},
							"serverRestartRecovery": gin.H{"summary": "Server restart with reconnection guidance", "body": `retry: 1000

id: a30

event: item

data: {"id":"a30"}

// server restarts; client reconnects with Last-Event-ID: a30

event: item

id: a31

data: {"id":"a31"}

event: done

`},
						},
						"notes":       "Heartbeat is an SSE comment frame (':heartbeat'). Interval configurable via 'heartbeatMs' query param (default 5ms; bounds 1–10000ms). List mode supports structured filters (qTitle, qContent, qTags/qNotTags with qOp), tag weighting (qTagWeights + qTagMinWeight), relative time windows (createdWithinMs/createdOlderThanMs) and absolute ranges (createdStart/createdEnd), cursor pagination (afterId, pageSize), and optional follow streaming (follow, followMaxMs, followBufferMs, followBatchMax). For restart recovery, servers may emit 'id' and 'retry' fields; clients can reconnect with 'Last-Event-ID'. Termination is signaled via 'event: done'.",
						"frameFields": gin.H{"event": "optional event name for the following data", "id": "optional message id for reconnection", "retry": "client reconnection delay in milliseconds"},
						"errorExamples": []interface{}{
							gin.H{"status": 401, "contentType": "application/json", "body": gin.H{"code": "E1100", "message": "AuthFailed", "requestId": "00000000-0000-0000-0000-000000000000", "severity": "warning"}},
							gin.H{"status": 403, "contentType": "application/json", "body": gin.H{"code": "E1200", "message": "PermissionDenied", "requestId": "00000000-0000-0000-0000-000000000000", "severity": "warning", "detail": gin.H{"reason": "权限中途变更"}}},
							gin.H{"status": 429, "contentType": "application/json", "body": gin.H{"code": "E1300", "message": "RateLimited", "requestId": "00000000-0000-0000-0000-000000000000", "severity": "warning"}},
							gin.H{"status": 500, "contentType": "application/json", "body": gin.H{"code": "E3001", "message": "StreamError", "requestId": "00000000-0000-0000-0000-000000000000", "severity": "error", "detail": gin.H{"hint": "SSE不支持"}}},
						},
					},
					"responses": gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
				},
			},
			"/api/v1/articles/:id": gin.H{
                "get": gin.H{
                    "summary":    "Get article",
                    "parameters": []interface{}{gin.H{"$ref": "#/components/parameters/XRequestId"}},
                    "security":   []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
                    "x-data-schema": gin.H{"$ref": "#/components/schemas/Article"},
                    "responses":  gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
                },
                "put": gin.H{
                    "summary":     "Update article",
                    "parameters":  []interface{}{gin.H{"$ref": "#/components/parameters/XRequestId"}},
                    "security":    []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
					"requestBody": gin.H{"required": true, "content": gin.H{"application/json": gin.H{"schema": gin.H{"$ref": "#/components/schemas/ArticleUpdateRequest"}}}},
					"x-data-schema": gin.H{"$ref": "#/components/schemas/Article"},
                    "responses":   gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
                },
				"delete": gin.H{
					"summary":    "Delete article",
					"parameters": []interface{}{gin.H{"$ref": "#/components/parameters/XRequestId"}},
					"security":   []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
					"responses":  gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
				},
			},

			// AI Frontend (auth + permission)
			"/api/v1/ai/frontend/generate": gin.H{"post": gin.H{
				"summary":     "Generate frontend",
				"parameters":  []interface{}{gin.H{"$ref": "#/components/parameters/XRequestId"}},
				"security":    []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
				"requestBody": gin.H{"required": true, "content": gin.H{"application/json": gin.H{"schema": gin.H{"$ref": "#/components/schemas/FrontendGenerateRequest"}}}},
				"responses":   gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
            }},
            
            // AI Clarify (auth + permission)
            "/api/v1/ai/clarify/generate": gin.H{"post": gin.H{
                "summary":     "Generate clarify artifacts",
                "description": "根据自然语言 prompt 生成结构化澄清产物（requirements/design/tasks）与最小 OpenAPI 片段。需携带 RBAC 权限 'ai.clarify'。",
                "parameters":  []interface{}{gin.H{"$ref": "#/components/parameters/XRequestId"}},
                "security":    []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
                "requestBody": gin.H{"required": true, "content": gin.H{"application/json": gin.H{"schema": gin.H{"$ref": "#/components/schemas/ClarifyGenerateRequest"}}}},
                "x-data-schema": gin.H{"$ref": "#/components/schemas/ClarifyGenerateResponseData"},
                "responses":   gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
            }},
            "/api/v1/ai/clarify/stream": gin.H{"get": gin.H{
                "summary":     "Clarify SSE stream",
                "description": "以 Server-Sent Events 流式返回澄清产物分片。Content-Type: text/event-stream；终止帧为 'event: done'。需携带 RBAC 权限 'ai.clarify'。",
                "parameters": []interface{}{
                    gin.H{"$ref": "#/components/parameters/XRequestId"},
                    gin.H{"name": "prompt", "in": "query", "required": false, "schema": gin.H{"type": "string"}, "description": "自然语言 prompt"},
                    gin.H{"name": "language", "in": "query", "required": false, "schema": gin.H{"type": "string", "example": "zh-CN"}, "description": "输出语言（默认 zh-CN）"},
                },
                "security": []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
                "x-streaming":             true,
                "x-response-content-type": "text/event-stream",
                "x-sse": gin.H{
                    "contentType": "text/event-stream",
                    "examples": gin.H{
                        "chunks": gin.H{"summary": "分片示例", "body": `data: {"type":"requirements","data":["输入: ...","明确目标与范围",...]}

:heartbeat

data: {"type":"design","data":["模块划分与接口草案",...]}

data: {"type":"tasks","data":["编写需求文档",...]}

event: done

`},
                    },
                },
                "responses": gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
            }},
            // Clarify WebSocket streaming (WS)
            "/api/v1/ai/clarify/stream/ws": gin.H{"get": gin.H{
                "summary":     "Clarify WS stream",
                "description": "通过 WebSocket 流式返回澄清产物分片。握手：GET /api/v1/ai/clarify/stream/ws?prompt&language。帧为 JSON 对象 {type, data}，终止帧为 {event:'done'}.",
                "parameters": []interface{}{
                    gin.H{"$ref": "#/components/parameters/XRequestId"},
                    gin.H{"name": "prompt", "in": "query", "required": false, "schema": gin.H{"type": "string"}},
                    gin.H{"name": "language", "in": "query", "required": false, "schema": gin.H{"type": "string", "example": "zh-CN"}},
                },
                "security": []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
                "x-streaming": true,
                "x-websocket": gin.H{
                    "handshake": gin.H{"method": "GET", "path": "/api/v1/ai/clarify/stream/ws", "query": gin.H{"prompt": "string", "language": "string"}},
                    "frames": gin.H{
                        "dataFrame": gin.H{"example": gin.H{"type": "requirements", "data": []string{"明确目标与范围", "约束与假设"}}},
                        "terminal": gin.H{"example": gin.H{"event": "done", "data": gin.H{"ok": true}}},
                    },
                    "notes": "WS 适用于浏览器/Node 客户端；SSE 仍兼容。错误通过关闭与统一错误响应返回（握手失败）。",
                },
                "responses": gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
            }},
            // Clarify export endpoints
            "/api/v1/ai/clarify/export": gin.H{"post": gin.H{
                "summary":     "Export clarify as Markdown",
                "description": "根据 prompt 与 language 导出 Markdown 文档（format=md）。不需要审批票据。",
                "parameters":  []interface{}{gin.H{"$ref": "#/components/parameters/XRequestId"}},
                "security":    []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
                "requestBody": gin.H{"required": true, "content": gin.H{"application/json": gin.H{"schema": gin.H{"$ref": "#/components/schemas/ClarifyExportMarkdownRequest"}}}},
                "x-data-schema": gin.H{"$ref": "#/components/schemas/ClarifyExportResponseData"},
                "responses":   gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
            }},
            "/api/v1/ai/clarify/export/pdf": gin.H{"post": gin.H{
                "summary":     "Export latest Markdown to PDF",
                "description": "将最近一次 Markdown 导出转换为 PDF（Pandoc + XeLaTeX 或 wkhtmltopdf）。需在请求头携带审批票据 X-Approval-Ticket。",
                "parameters":  []interface{}{gin.H{"$ref": "#/components/parameters/XRequestId"}, gin.H{"$ref": "#/components/parameters/XApprovalTicket"}},
                "security":    []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
                "x-data-schema": gin.H{"$ref": "#/components/schemas/ClarifyExportResponseData"},
                "responses":   gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
            }},
            "/api/v1/ai/clarify/export/docx": gin.H{"post": gin.H{
                "summary":     "Export latest Markdown to DOCX",
                "description": "将最近一次 Markdown 导出转换为 DOCX（Pandoc）。需在请求头携带审批票据 X-Approval-Ticket。",
                "parameters":  []interface{}{gin.H{"$ref": "#/components/parameters/XRequestId"}, gin.H{"$ref": "#/components/parameters/XApprovalTicket"}},
                "security":    []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
                "x-data-schema": gin.H{"$ref": "#/components/schemas/ClarifyExportResponseData"},
                "responses":   gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
            }},
            "/api/v1/ai/clarify/docs/:name": gin.H{"get": gin.H{
                "summary":    "Download exported clarify document",
                "description": "下载已导出的澄清文档（Markdown/PDF/DOCX）。",
                "parameters": []interface{}{gin.H{"$ref": "#/components/parameters/XRequestId"}, gin.H{"name": "name", "in": "path", "required": true, "schema": gin.H{"type": "string"}, "description": "文件名"}},
                "security":   []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
                "responses":  gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
            }},

			// Aliased Clarify endpoints under /api/clarify for spec compatibility
            "/api/clarify/generate": gin.H{"post": gin.H{
                "summary":     "Generate clarify artifacts (alias)",
                "description": "别名路径：与 /api/v1/ai/clarify/generate 等价。",
                "parameters":  []interface{}{gin.H{"$ref": "#/components/parameters/XRequestId"}},
                "security":    []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
                "requestBody": gin.H{"required": true, "content": gin.H{"application/json": gin.H{"schema": gin.H{"$ref": "#/components/schemas/ClarifyGenerateRequest"}}}},
                "x-data-schema": gin.H{"$ref": "#/components/schemas/ClarifyGenerateResponseData"},
                "responses":   gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
            }},
            "/api/clarify/stream": gin.H{"get": gin.H{
                "summary":     "Clarify SSE stream (alias)",
                "description": "别名路径：与 /api/v1/ai/clarify/stream 等价。",
                "parameters": []interface{}{
                    gin.H{"$ref": "#/components/parameters/XRequestId"},
                    gin.H{"name": "prompt", "in": "query", "required": false, "schema": gin.H{"type": "string"}, "description": "自然语言 prompt"},
                    gin.H{"name": "language", "in": "query", "required": false, "schema": gin.H{"type": "string", "example": "zh-CN"}, "description": "输出语言（默认 zh-CN）"},
                },
                "security": []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
                "x-streaming":             true,
                "x-response-content-type": "text/event-stream",
                "responses": gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
            }},
            "/api/clarify/stream/ws": gin.H{"get": gin.H{
                "summary":     "Clarify WS stream (alias)",
                "description": "别名路径：与 /api/v1/ai/clarify/stream/ws 等价。",
                "parameters": []interface{}{
                    gin.H{"$ref": "#/components/parameters/XRequestId"},
                    gin.H{"name": "prompt", "in": "query", "required": false, "schema": gin.H{"type": "string"}},
                    gin.H{"name": "language", "in": "query", "required": false, "schema": gin.H{"type": "string", "example": "zh-CN"}},
                },
                "security": []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
                "x-streaming": true,
                "x-websocket": gin.H{
                    "handshake": gin.H{"method": "GET", "path": "/api/clarify/stream/ws", "query": gin.H{"prompt": "string", "language": "string"}},
                    "frames": gin.H{
                        "dataFrame": gin.H{"example": gin.H{"type": "design", "data": []string{"模块划分与接口草案"}}},
                        "terminal": gin.H{"example": gin.H{"event": "done", "data": gin.H{"ok": true}}},
                    },
                },
                "responses": gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
            }},
            "/api/clarify/export": gin.H{"post": gin.H{
                "summary":     "Export clarify as Markdown (alias)",
                "description": "别名路径：与 /api/v1/ai/clarify/export 等价。",
                "parameters":  []interface{}{gin.H{"$ref": "#/components/parameters/XRequestId"}},
                "security":    []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
                "requestBody": gin.H{"required": true, "content": gin.H{"application/json": gin.H{"schema": gin.H{"$ref": "#/components/schemas/ClarifyExportMarkdownRequest"}}}},
                "x-data-schema": gin.H{"$ref": "#/components/schemas/ClarifyExportResponseData"},
                "responses":   gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
            }},
            "/api/clarify/export/pdf": gin.H{"post": gin.H{
                "summary":     "Export latest Markdown to PDF (alias)",
                "parameters":  []interface{}{gin.H{"$ref": "#/components/parameters/XRequestId"}, gin.H{"$ref": "#/components/parameters/XApprovalTicket"}},
                "security":    []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
                "x-data-schema": gin.H{"$ref": "#/components/schemas/ClarifyExportResponseData"},
                "responses":   gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
            }},
            "/api/clarify/export/docx": gin.H{"post": gin.H{
                "summary":     "Export latest Markdown to DOCX (alias)",
                "parameters":  []interface{}{gin.H{"$ref": "#/components/parameters/XRequestId"}, gin.H{"$ref": "#/components/parameters/XApprovalTicket"}},
                "security":    []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
                "x-data-schema": gin.H{"$ref": "#/components/schemas/ClarifyExportResponseData"},
                "responses":   gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
            }},
            "/api/clarify/docs/:name": gin.H{"get": gin.H{
                "summary":    "Download exported clarify document (alias)",
                "parameters": []interface{}{gin.H{"$ref": "#/components/parameters/XRequestId"}, gin.H{"name": "name", "in": "path", "required": true, "schema": gin.H{"type": "string"}}},
                "security":   []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
                "responses":  gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
            }},

            // AI Specs (auth + permission)
            "/api/v1/ai/specs/generate": gin.H{"post": gin.H{
                "summary":    "Generate specs and DDL from PRD",
                "parameters": []interface{}{gin.H{"$ref": "#/components/parameters/XRequestId"}},
                "security":   []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
                "requestBody": gin.H{"required": true, "content": gin.H{"application/json": gin.H{"schema": gin.H{"$ref": "#/components/schemas/AISpecsGenerateRequest"}}}},
                "x-data-schema": gin.H{"$ref": "#/components/schemas/AISpecsGenerateResponseData"},
                "responses":  gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
            }},
			"/api/v1/ai/frontend/validate": gin.H{"post": gin.H{
				"summary":     "Validate frontend",
				"parameters":  []interface{}{gin.H{"$ref": "#/components/parameters/XRequestId"}},
				"security":    []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
				"requestBody": gin.H{"required": true, "content": gin.H{"application/json": gin.H{"schema": gin.H{"$ref": "#/components/schemas/FrontendValidateRequest"}}}},
				"responses":   gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
			}},
			"/api/v1/ai/frontend/templates": gin.H{"get": gin.H{
				"summary":    "List frontend templates",
				"parameters": []interface{}{gin.H{"$ref": "#/components/parameters/XRequestId"}},
				"security":   []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
				"responses":  gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
			}},
			"/api/v1/ai/frontend/commit": gin.H{"post": gin.H{
				"summary":     "Commit frontend snapshot",
				"parameters":  []interface{}{gin.H{"$ref": "#/components/parameters/XRequestId"}},
				"security":    []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
				"requestBody": gin.H{"required": true, "content": gin.H{"application/json": gin.H{"schema": gin.H{"$ref": "#/components/schemas/FrontendCommitRequest"}}}},
				"responses":   gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
			}},

			// AI Backend (auth + permission)
			"/api/v1/ai/backend/generate": gin.H{"post": gin.H{
				"summary":     "Generate backend",
				"parameters":  []interface{}{gin.H{"$ref": "#/components/parameters/XRequestId"}},
				"security":    []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
				"requestBody": gin.H{"required": true, "content": gin.H{"application/json": gin.H{"schema": gin.H{"$ref": "#/components/schemas/BackendGenerateRequest"}}}},
				"responses":   gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
			}},
			"/api/v1/ai/backend/scaffold": gin.H{"post": gin.H{
				"summary":     "Scaffold backend",
				"parameters":  []interface{}{gin.H{"$ref": "#/components/parameters/XRequestId"}},
				"security":    []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
				"requestBody": gin.H{"required": true, "content": gin.H{"application/json": gin.H{"schema": gin.H{"$ref": "#/components/schemas/BackendScaffoldRequest"}}}},
				"responses":   gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
			}},
			"/api/v1/ai/backend/fix": gin.H{"post": gin.H{
				"summary":     "Fix backend",
				"parameters":  []interface{}{gin.H{"$ref": "#/components/parameters/XRequestId"}},
				"security":    []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
				"requestBody": gin.H{"required": true, "content": gin.H{"application/json": gin.H{"schema": gin.H{"$ref": "#/components/schemas/BackendFixRequest"}}}},
				"responses":   gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
			}},
			"/api/v1/ai/backend/templates": gin.H{"get": gin.H{
				"summary":    "List backend templates",
				"parameters": []interface{}{gin.H{"$ref": "#/components/parameters/XRequestId"}},
				"security":   []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
				"responses":  gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
			}},

			// AI Integration (auth + permission; no detailed schemas yet)
			"/api/v1/ai/integration/test": gin.H{"post": gin.H{
				"summary":    "Integration test",
				"parameters": []interface{}{gin.H{"$ref": "#/components/parameters/XRequestId"}},
				"security":   []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
				"responses":  gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
			}},
			"/api/v1/ai/integration/diagnose": gin.H{"post": gin.H{
				"summary":    "Integration diagnose",
				"parameters": []interface{}{gin.H{"$ref": "#/components/parameters/XRequestId"}},
				"security":   []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
				"responses":  gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
			}},
			"/api/v1/ai/integration/patch": gin.H{"post": gin.H{
				"summary":    "Integration patch",
				"parameters": []interface{}{gin.H{"$ref": "#/components/parameters/XRequestId"}},
				"security":   []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
				"responses":  gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
			}},
			"/api/v1/ai/integration/reports": gin.H{"get": gin.H{
				"summary":    "Integration reports",
				"parameters": []interface{}{gin.H{"$ref": "#/components/parameters/XRequestId"}},
				"security":   []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
				"responses":  gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
			}},

			// Billing (auth + permission)
			"/api/v1/billing/orders": gin.H{"post": gin.H{
				"summary":     "Create order",
				"parameters":  []interface{}{gin.H{"$ref": "#/components/parameters/XRequestId"}},
				"security":    []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
				"requestBody": gin.H{"required": true, "content": gin.H{"application/json": gin.H{"schema": gin.H{"$ref": "#/components/schemas/BillingCreateOrderRequest"}}}},
				"responses":   gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
			}},
			"/api/v1/billing/payments": gin.H{"post": gin.H{
				"summary":     "Create payment",
				"parameters":  []interface{}{gin.H{"$ref": "#/components/parameters/XRequestId"}},
				"security":    []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
				"requestBody": gin.H{"required": true, "content": gin.H{"application/json": gin.H{"schema": gin.H{"$ref": "#/components/schemas/BillingCreatePaymentRequest"}}}},
				"responses":   gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
			}},
			"/api/v1/billing/plans": gin.H{"get": gin.H{
				"summary":    "List plans",
				"parameters": []interface{}{gin.H{"$ref": "#/components/parameters/XRequestId"}},
				"security":   []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
				"responses":  gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
			}},
			"/api/v1/billing/invoices": gin.H{"get": gin.H{
				"summary":    "List invoices",
				"parameters": []interface{}{gin.H{"$ref": "#/components/parameters/XRequestId"}},
				"security":   []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
				"responses":  gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
			}},

			// Observe (auth + permission)
			"/api/v1/observe/metrics": gin.H{"get": gin.H{
				"summary":    "Metrics",
				"parameters": []interface{}{gin.H{"$ref": "#/components/parameters/XRequestId"}},
				"security":   []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
				"responses":  gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
			}},
			"/api/v1/observe/traces": gin.H{"get": gin.H{
				"summary":    "Traces",
				"parameters": []interface{}{gin.H{"$ref": "#/components/parameters/XRequestId"}},
				"security":   []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
				"responses":  gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
			}},
			"/api/v1/observe/events": gin.H{"post": gin.H{
				"summary":     "Post event",
				"parameters":  []interface{}{gin.H{"$ref": "#/components/parameters/XRequestId"}},
				"security":    []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
				"requestBody": gin.H{"required": true, "content": gin.H{"application/json": gin.H{"schema": gin.H{"$ref": "#/components/schemas/ObserveEventRequest"}}}},
				"responses":   gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
			}},

			// Fans management (auth + permission + approval)
			"/api/v1/fans/export": gin.H{"post": gin.H{
				"summary":     "Export fans (CSV)",
				"description": "批量导出粉丝（CSV）。需要携带审批票据头 X-Approval-Ticket，受 RBAC 权限 'fans' 控制。",
				"parameters":  []interface{}{gin.H{"$ref": "#/components/parameters/XRequestId"}, gin.H{"$ref": "#/components/parameters/XApprovalTicket"}},
				"security":    []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
				"requestBody": gin.H{"required": true, "content": gin.H{"application/json": gin.H{"schema": gin.H{"$ref": "#/components/schemas/FansExportRequest"}}}},
				"x-approval":  gin.H{"required": true, "header": "X-Approval-Ticket"},
				"x-data-schema": gin.H{"$ref": "#/components/schemas/FansExportResponseData"},
				"responses":   gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
			}},

			// Fans session uniqueness (auth + permission)
			"/api/v1/fans/{fanId}/active_conversation": gin.H{
				"get": gin.H{
					"summary":    "Get fan active conversation",
					"description": "查询粉丝当前活跃会话ID。如无则返回空字符串。受 RBAC 权限 'fans' 控制。",
					"parameters": []interface{}{
						gin.H{"$ref": "#/components/parameters/XRequestId"},
						gin.H{"name": "fanId", "in": "path", "required": true, "schema": gin.H{"type": "string"}},
					},
					"security":    []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
					"x-data-schema": gin.H{"$ref": "#/components/schemas/ActiveConversationData"},
					"responses":   gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
				},
				"post": gin.H{
					"summary":     "Set fan active conversation",
					"description": "设置粉丝活跃会话。若已有其他活跃会话则返回409冲突（E1400）。受 RBAC 权限 'fans' 控制。",
					"parameters":  []interface{}{
						gin.H{"$ref": "#/components/parameters/XRequestId"},
						gin.H{"name": "fanId", "in": "path", "required": true, "schema": gin.H{"type": "string"}},
					},
					"security":    []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
					"requestBody": gin.H{"required": true, "content": gin.H{"application/json": gin.H{"schema": gin.H{"$ref": "#/components/schemas/ActiveConversationRequest"}}}},
					"x-data-schema": gin.H{"$ref": "#/components/schemas/ActiveConversationData"},
					"responses":   gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "409": gin.H{"$ref": "#/components/responses/Error"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
				},
				"delete": gin.H{
					"summary":    "Clear fan active conversation",
					"description": "清除粉丝活跃会话。受 RBAC 权限 'fans' 控制。",
					"parameters": []interface{}{
						gin.H{"$ref": "#/components/parameters/XRequestId"},
						gin.H{"name": "fanId", "in": "path", "required": true, "schema": gin.H{"type": "string"}},
					},
					"security":    []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
					"x-data-schema": gin.H{"$ref": "#/components/schemas/ActiveConversationClearedData"},
					"responses":   gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
				},
			},

			// Reply templates (auth + permission)
			"/api/v1/reply_templates/preview": gin.H{"post": gin.H{
				"summary":     "Preview reply template",
				"parameters":  []interface{}{gin.H{"$ref": "#/components/parameters/XRequestId"}},
				"security":    []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
				"requestBody": gin.H{"required": true, "content": gin.H{"application/json": gin.H{"schema": gin.H{"$ref": "#/components/schemas/ReplyTemplatePreviewRequest"}}}},
				"responses":   gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
			}},

			// LLM (auth + permission)
			"/api/v1/llm/providers": gin.H{"get": gin.H{
				"summary":    "List LLM providers",
				"parameters": []interface{}{gin.H{"$ref": "#/components/parameters/XRequestId"}},
				"security":   []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
				"responses":  gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
			}},
			"/api/v1/llm/models": gin.H{"get": gin.H{
				"summary":    "List LLM models",
				"parameters": []interface{}{gin.H{"$ref": "#/components/parameters/XRequestId"}},
				"security":   []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
				"responses":  gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
			}},
			"/api/v1/llm/chat": gin.H{"post": gin.H{
				"summary":     "Unified LLM chat",
				"parameters":  []interface{}{gin.H{"$ref": "#/components/parameters/XRequestId"}},
				"security":    []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
				"requestBody": gin.H{"required": true, "content": gin.H{"application/json": gin.H{"schema": gin.H{"$ref": "#/components/schemas/LLMChatRequest"}}}},
				"responses":   gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
			}},
			"/api/v1/llm/embeddings": gin.H{"post": gin.H{
				"summary":     "Generate embeddings",
				"parameters":  []interface{}{gin.H{"$ref": "#/components/parameters/XRequestId"}},
				"security":    []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
				"requestBody": gin.H{"required": true, "content": gin.H{"application/json": gin.H{"schema": gin.H{"$ref": "#/components/schemas/LLMEmbeddingsRequest"}}}},
				"responses":   gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
			}},
			"/api/v1/llm/moderate": gin.H{"post": gin.H{
				"summary":     "Content moderation",
				"parameters":  []interface{}{gin.H{"$ref": "#/components/parameters/XRequestId"}},
				"security":    []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
				"requestBody": gin.H{"required": true, "content": gin.H{"application/json": gin.H{"schema": gin.H{"$ref": "#/components/schemas/LLMModerateRequest"}}}},
				"responses":   gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
			}},

			// Fans CRUD (auth + permission)
			"/api/v1/fans": gin.H{
				"get": gin.H{
					"summary":    "List fans",
					"parameters": []interface{}{
						gin.H{"$ref": "#/components/parameters/XRequestId"},
						// Pagination & filters (prefer pageSize/afterId; support legacy limit/offset)
						gin.H{"name": "pageSize", "in": "query", "required": false, "schema": gin.H{"type": "integer", "minimum": 1, "maximum": 1000}, "example": 10, "description": "Page size (1-1000). Prefer over legacy 'limit'"},
						gin.H{"name": "afterId", "in": "query", "required": false, "schema": gin.H{"type": "string"}, "example": "8", "description": "Cursor: start after the given fan ID"},
						gin.H{"name": "limit", "in": "query", "required": false, "schema": gin.H{"type": "integer", "minimum": 1, "maximum": 1000}, "example": 10, "description": "[Legacy] Max number of items (use 'pageSize')"},
						gin.H{"name": "offset", "in": "query", "required": false, "schema": gin.H{"type": "integer", "minimum": 0}, "example": 0, "description": "[Legacy] Start offset (prefer 'afterId' cursor)"},
					},
					"security": []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
					"x-data-schema": gin.H{"$ref": "#/components/schemas/FansListData"},
					"responses": gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
				},
				"post": gin.H{
					"summary":     "Create fan",
					"parameters":  []interface{}{gin.H{"$ref": "#/components/parameters/XRequestId"}},
					"security":    []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
					"requestBody": gin.H{"required": true, "content": gin.H{"application/json": gin.H{"schema": gin.H{"$ref": "#/components/schemas/FanCreateRequest"}}}},
					"x-data-schema": gin.H{"$ref": "#/components/schemas/Fan"},
					"responses":   gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
				},
			},
			"/api/v1/fans/id/:id": gin.H{
				"get": gin.H{
					"summary":    "Get fan by ID",
					"parameters": []interface{}{gin.H{"$ref": "#/components/parameters/XRequestId"}, gin.H{"name": "id", "in": "path", "required": true, "schema": gin.H{"type": "string"}}},
					"security":   []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
					"x-data-schema": gin.H{"$ref": "#/components/schemas/Fan"},
					"responses":  gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
				},
				"put": gin.H{
					"summary":     "Update fan by ID",
					"parameters":  []interface{}{gin.H{"$ref": "#/components/parameters/XRequestId"}, gin.H{"name": "id", "in": "path", "required": true, "schema": gin.H{"type": "string"}}},
					"security":    []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
					"requestBody": gin.H{"required": true, "content": gin.H{"application/json": gin.H{"schema": gin.H{"$ref": "#/components/schemas/FanUpdateRequest"}}}},
					"x-data-schema": gin.H{"$ref": "#/components/schemas/Fan"},
					"responses":   gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
				},
				"delete": gin.H{
					"summary":    "Delete fan by ID",
					"parameters": []interface{}{gin.H{"$ref": "#/components/parameters/XRequestId"}, gin.H{"name": "id", "in": "path", "required": true, "schema": gin.H{"type": "string"}}},
					"security":   []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
					"responses":  gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
				},
			},

			// Fans session endpoints
			"/api/v1/fans/:fanId/active_conversation": gin.H{
				"get": gin.H{
					"summary":    "Get active conversation for a fan",
					"parameters": []interface{}{gin.H{"$ref": "#/components/parameters/XRequestId"}, gin.H{"name": "fanId", "in": "path", "required": true, "schema": gin.H{"type": "string"}}},
					"security":   []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
					"x-data-schema": gin.H{"$ref": "#/components/schemas/ActiveConversationData"},
					"responses":  gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
				},
				"post": gin.H{
					"summary":     "Set active conversation for a fan",
					"parameters":  []interface{}{gin.H{"$ref": "#/components/parameters/XRequestId"}, gin.H{"name": "fanId", "in": "path", "required": true, "schema": gin.H{"type": "string"}}},
					"security":    []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
					"requestBody": gin.H{"required": true, "content": gin.H{"application/json": gin.H{"schema": gin.H{"$ref": "#/components/schemas/ActiveConversationRequest"}}}},
					"x-data-schema": gin.H{"$ref": "#/components/schemas/ActiveConversationData"},
					"responses":   gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
				},
				"delete": gin.H{
					"summary":    "Clear active conversation for a fan",
					"parameters": []interface{}{gin.H{"$ref": "#/components/parameters/XRequestId"}, gin.H{"name": "fanId", "in": "path", "required": true, "schema": gin.H{"type": "string"}}},
					"security":   []gin.H{gin.H{"bearerAuth": []interface{}{}}, gin.H{"headerPermissions": []interface{}{}}},
					"x-data-schema": gin.H{"$ref": "#/components/schemas/ActiveConversationClearedData"},
					"responses":  gin.H{"200": gin.H{"$ref": "#/components/responses/OK"}, "default": gin.H{"$ref": "#/components/responses/Error"}},
				},
			},
		},
	}
}
