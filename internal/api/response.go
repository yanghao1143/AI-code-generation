package api

type Response struct {
	Code      string      `json:"code"`
	Message   string      `json:"message"`
	RequestID string      `json:"requestId"`
	Data      interface{} `json:"data,omitempty"`
	Severity  string      `json:"severity,omitempty"`
}

type ErrorResponse struct {
	Code      string      `json:"code"`
	Message   string      `json:"message"`
	RequestID string      `json:"requestId"`
	Hint      string      `json:"hint,omitempty"`
	Severity  string      `json:"severity,omitempty"`
	Detail    interface{} `json:"detail,omitempty"`
}

func OK(rid string, data interface{}) Response {
	return Response{Code: "OK", Message: "success", RequestID: rid, Data: data}
}

func Err(rid, code, msg, hint, severity string, detail interface{}) ErrorResponse {
	return ErrorResponse{Code: code, Message: msg, RequestID: rid, Hint: hint, Severity: severity, Detail: detail}
}
