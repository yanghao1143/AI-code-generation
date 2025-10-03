package ddl

import (
    "context"
    "crypto/sha256"
    "database/sql"
    "encoding/hex"
    "encoding/json"
    "errors"
    "fmt"
    "os"
    "path/filepath"
    "strings"
    "time"

    _ "github.com/go-sql-driver/mysql"
)

// Channel represents execution channel for DDL scripts
type Channel string

const (
    ChannelRead    Channel = "READ"     // read-only: plan/validate, no writes
    ChannelChange  Channel = "CHANGE"   // apply migrate/create changes
    ChannelRollback Channel = "ROLLBACK" // rollback changes
)

// AuditRecord captures one execution attempt for auditing
type AuditRecord struct {
    TicketID   string   `json:"ticketId"`
    Channel    Channel  `json:"channel"`
    DSN        string   `json:"dsn"`
    SQLFile    string   `json:"sqlFile"`
    SQLHash    string   `json:"sqlHash"`
    DryRun     bool     `json:"dryRun"`
    StartedAt  time.Time `json:"startedAt"`
    EndedAt    time.Time `json:"endedAt"`
    Status     string   `json:"status"` // success|failed|skipped
    Error      string   `json:"error,omitempty"`
    Statements []string `json:"statements,omitempty"`
}

// LoadEnvDSN returns DSN by environment name (test|staging|prod)
func LoadEnvDSN(name string) (string, error) {
    switch strings.ToLower(name) {
    case "test", "testing":
        if v := os.Getenv("XZ_DB_TEST_DSN"); v != "" {
            return v, nil
        }
        return "", errors.New("missing env XZ_DB_TEST_DSN")
    case "staging", "stage":
        if v := os.Getenv("XZ_DB_STAGING_DSN"); v != "" {
            return v, nil
        }
        return "", errors.New("missing env XZ_DB_STAGING_DSN")
    case "prod", "production":
        if v := os.Getenv("XZ_DB_PROD_DSN"); v != "" {
            return v, nil
        }
        return "", errors.New("missing env XZ_DB_PROD_DSN")
    default:
        return "", fmt.Errorf("unknown dsn env: %s", name)
    }
}

// Run executes DDL scripts for the given channel.
// ticketID is required for non-dry-run CHANGE/ROLLBACK channels and must match env XZ_APPROVED_TICKET.
func Run(channel Channel, dryRun bool, dsn string, ticketID string) error {
    sqlFile := scriptPath(channel)
    body, err := os.ReadFile(sqlFile)
    if err != nil {
        return fmt.Errorf("read sql file: %w", err)
    }

    hash := sha256.Sum256(body)
    sqlHash := hex.EncodeToString(hash[:])
    statements := splitSQL(string(body))

    audit := AuditRecord{
        TicketID:   ticketID,
        Channel:    channel,
        DSN:        dsn,
        SQLFile:    sqlFile,
        SQLHash:    sqlHash,
        DryRun:     dryRun || channel == ChannelRead,
        StartedAt:  time.Now(),
        Statements: statements,
    }

    // Approval gate for write channels
    if !audit.DryRun && (channel == ChannelChange || channel == ChannelRollback) {
        approved := os.Getenv("XZ_APPROVED_TICKET")
        if approved == "" || approved != ticketID {
            audit.Status = "skipped"
            audit.Error = "approval required: set XZ_APPROVED_TICKET to matching ticket id"
            audit.EndedAt = time.Now()
            _ = writeAudit(audit)
            return errors.New("approval gate not satisfied")
        }
    }

    // READ channel is always dry-run (no DB writes)
    if audit.DryRun {
        audit.Status = "success"
        audit.EndedAt = time.Now()
        return writeAudit(audit)
    }

    // Execute statements
    timeout := 30 * time.Second
    if v := os.Getenv("XZ_DB_OP_TIMEOUT"); v != "" {
        if d, err := time.ParseDuration(v); err == nil {
            timeout = d
        }
    }

    ctx, cancel := context.WithTimeout(context.Background(), timeout)
    defer cancel()

    db, err := sql.Open("mysql", dsn)
    if err != nil {
        audit.Status = "failed"
        audit.Error = fmt.Sprintf("open db: %v", err)
        audit.EndedAt = time.Now()
        _ = writeAudit(audit)
        return fmt.Errorf("open db: %w", err)
    }
    defer db.Close()

    // Run each statement
    for _, s := range statements {
        if strings.TrimSpace(s) == "" { // skip empty
            continue
        }
        if _, err := db.ExecContext(ctx, s); err != nil {
            audit.Status = "failed"
            audit.Error = fmt.Sprintf("exec stmt failed: %v", err)
            audit.EndedAt = time.Now()
            _ = writeAudit(audit)
            return fmt.Errorf("exec stmt failed: %w", err)
        }
    }

    audit.Status = "success"
    audit.EndedAt = time.Now()
    return writeAudit(audit)
}

func scriptPath(channel Channel) string {
    base := filepath.Join("scripts", "db")
    switch channel {
    case ChannelRead:
        // For READ channel, we default to migrate.sql for planning
        return filepath.Join(base, "migrate.sql")
    case ChannelChange:
        return filepath.Join(base, "migrate.sql")
    case ChannelRollback:
        return filepath.Join(base, "rollback.sql")
    default:
        return filepath.Join(base, "migrate.sql")
    }
}

// writeAudit appends JSONL audit entry into scripts/db/audit/YYYYMMDD-HHMM.jsonl
func writeAudit(rec AuditRecord) error {
    ts := time.Now().Format("20060102-1504")
    dir := filepath.Join("scripts", "db", "audit")
    if err := os.MkdirAll(dir, 0o755); err != nil {
        return fmt.Errorf("mkdir audit: %w", err)
    }
    path := filepath.Join(dir, ts+".jsonl")
    f, err := os.OpenFile(path, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0o644)
    if err != nil {
        return fmt.Errorf("open audit file: %w", err)
    }
    defer f.Close()
    enc, _ := json.Marshal(rec)
    if _, err := f.Write(append(enc, '\n')); err != nil {
        return fmt.Errorf("write audit: %w", err)
    }
    return nil
}

// splitSQL splits SQL script by ';' while being naive about semicolons.
// Good enough for typical DDL files in this repository.
func splitSQL(sqlText string) []string {
    // Normalize line endings and remove comments starting with --
    lines := strings.Split(sqlText, "\n")
    var b strings.Builder
    for _, line := range lines {
        trimmed := strings.TrimSpace(line)
        if strings.HasPrefix(trimmed, "--") {
            continue
        }
        b.WriteString(line)
        b.WriteString("\n")
    }
    cleaned := b.String()
    parts := strings.Split(cleaned, ";")
    out := make([]string, 0, len(parts))
    for _, p := range parts {
        if s := strings.TrimSpace(p); s != "" {
            out = append(out, s)
        }
    }
    return out
}

// Preview returns planned statements without executing, for UI or CLI preview
func Preview(channel Channel) ([]string, string, error) {
    sqlFile := scriptPath(channel)
    body, err := os.ReadFile(sqlFile)
    if err != nil {
        return nil, "", fmt.Errorf("read sql file: %w", err)
    }
    hash := sha256.Sum256(body)
    sqlHash := hex.EncodeToString(hash[:])
    stmts := splitSQL(string(body))
    return stmts, sqlHash, nil
}