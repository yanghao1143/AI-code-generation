package clarify

// GenerateRequest represents input for clarify generation.
// It accepts a free-form prompt and optional flags controlling parsing behavior.
type GenerateRequest struct {
    // 用户输入的业务或需求描述（自然语言）
    Prompt       string `json:"prompt"`
    // 期望输出语言（默认跟随系统或中文），例如：zh-CN、en-US
    Language     string `json:"language"`
    // 是否使用结构化解析（更严格、更可控），默认false
    UseStructured bool   `json:"useStructured"`
    // 是否要求流式输出（SSE/WS），默认false
    Stream       bool   `json:"stream"`
}

// GenerateResponse is a simplified structured output from clarify generation.
// It provides Requirements/Design/Tasks bullets and a minimal OpenAPI fragment for discovery.
type GenerateResponse struct {
    Requirements []string               `json:"requirements"`
    Design       []string               `json:"design"`
    Tasks        []string               `json:"tasks"`
    OpenAPI      map[string]interface{} `json:"openapi"`
    Issues       []map[string]interface{} `json:"issues,omitempty"`
}