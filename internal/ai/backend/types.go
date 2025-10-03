package backend

type GenerateRequest struct {
	Name     string                 `json:"name" binding:"required"`
	Spec     map[string]interface{} `json:"spec" binding:"required"`
	Template string                 `json:"template,omitempty"`
}

type ScaffoldRequest struct {
	ServiceName string   `json:"serviceName" binding:"required"`
	Endpoints   []string `json:"endpoints" binding:"required"`
}

type FixRequest struct {
	ReportID string                 `json:"reportId" binding:"required"`
	Diff     map[string]interface{} `json:"diff" binding:"required"`
}
