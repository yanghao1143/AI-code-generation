package frontend

type GenerateRequest struct {
	Name        string                 `json:"name" binding:"required"`
	Template    string                 `json:"template,omitempty"`
	DSL         map[string]interface{} `json:"dsl" binding:"required"`
	Permissions []string               `json:"permissions,omitempty"`
}

type ValidateRequest struct {
	DSL map[string]interface{} `json:"dsl" binding:"required"`
}

type CommitRequest struct {
	SnapshotID string `json:"snapshotId" binding:"required"`
	Message    string `json:"message,omitempty"`
}
