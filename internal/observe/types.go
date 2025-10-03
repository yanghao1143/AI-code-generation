package observe

type EventRequest struct {
	Type     string `json:"type" binding:"required"`
	Severity string `json:"severity" binding:"required"`
	Message  string `json:"message" binding:"required"`
}
