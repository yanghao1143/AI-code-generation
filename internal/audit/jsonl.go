package audit

import (
    "encoding/json"
    "os"
    "path/filepath"
    "time"
)

// AppendJSONL appends an audit event as a single JSON line into a file.
// Path is controlled by env AUDIT_JSONL_PATH (default: dist/audit.jsonl).
// It is safe to call in a goroutine; errors are ignored to avoid impacting
// request latency, but best-effort write is attempted.
func AppendJSONL(ev Event) {
    path := os.Getenv("AUDIT_JSONL_PATH")
    if path == "" {
        path = filepath.Join("dist", "audit.jsonl")
    }
    // Ensure directory exists
    _ = os.MkdirAll(filepath.Dir(path), 0o755)
    // Build compact payload
    payload := map[string]interface{}{
        "action":         ev.Action,
        "userId":         ev.UserID,
        "approvalTicket": ev.ApprovalTicket,
        "timestamp":      ev.Timestamp.Format(time.RFC3339),
        "detail":         ev.Detail,
    }
    b, err := json.Marshal(payload)
    if err != nil {
        return
    }
    f, err := os.OpenFile(path, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o644)
    if err != nil {
        return
    }
    defer func() { _ = f.Close() }()
    _, _ = f.Write(append(b, '\n'))
}