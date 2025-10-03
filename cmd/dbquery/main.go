package main

import (
    "context"
    "database/sql"
    "encoding/json"
    "flag"
    "fmt"
    "io/ioutil"
    "log"
    "strings"
    "time"

    _ "github.com/go-sql-driver/mysql"
    "xingzuo/internal/ddl"
)

// dbquery is a small utility to run READ-ONLY SQL (SELECT ...) against MySQL.
// It accepts either --dsn or --dsn-env=test|staging|prod, and prints JSON rows.
// This is intended for safe pre-checks and should not run any mutating statements.

func main() {
    var dsn string
    var dsnEnv string
    var sqlText string
    var sqlFile string
    var timeoutStr string
    flag.StringVar(&dsn, "dsn", "", "MySQL DSN (go-sql-driver format), e.g. user:pass@tcp(127.0.0.1:3306)/db?parseTime=true")
    flag.StringVar(&dsnEnv, "dsn-env", "", "Use DSN from env: test|staging|prod (reads XZ_DB_*_DSN)")
    flag.StringVar(&sqlText, "sql", "", "SQL to execute (must start with SELECT)")
    flag.StringVar(&sqlFile, "sql-file", "", "Path to a file containing SQL (first statement used)")
    flag.StringVar(&timeoutStr, "timeout", "30s", "Per-query timeout, e.g. 30s, 1m")
    flag.Parse()

    // Load SQL from file if provided
    if sqlFile != "" {
        b, err := ioutil.ReadFile(sqlFile)
        if err != nil {
            log.Fatalf("read sql-file: %v", err)
        }
        sqlText = string(b)
    }

    if strings.TrimSpace(sqlText) == "" {
        log.Fatalf("sql is required: provide --sql or --sql-file")
    }

    if !looksLikeSelect(sqlText) {
        log.Fatalf("only SELECT statements are allowed for safety")
    }

    // Resolve DSN
    var d string
    var err error
    if dsn != "" && dsnEnv != "" {
        log.Fatalf("provide either --dsn or --dsn-env, not both")
    }
    if dsn != "" {
        d = dsn
    } else if dsnEnv != "" {
        d, err = ddl.LoadEnvDSN(dsnEnv)
        if err != nil {
            log.Fatalf("load dsn from env %s: %v", dsnEnv, err)
        }
    } else {
        log.Fatalf("dsn required: provide --dsn or --dsn-env=test|staging|prod with env variables set")
    }

    // Timeout
    t := 30 * time.Second
    if timeoutStr != "" {
        if dur, err := time.ParseDuration(timeoutStr); err == nil {
            t = dur
        } else {
            log.Fatalf("invalid timeout: %v", err)
        }
    }

    ctx, cancel := context.WithTimeout(context.Background(), t)
    defer cancel()

    db, err := sql.Open("mysql", d)
    if err != nil {
        log.Fatalf("open db: %v", err)
    }
    defer db.Close()

    rows, err := db.QueryContext(ctx, sqlText)
    if err != nil {
        log.Fatalf("query: %v", err)
    }
    defer rows.Close()

    cols, err := rows.Columns()
    if err != nil {
        log.Fatalf("columns: %v", err)
    }

    // Prepare scan buffers
    values := make([]interface{}, len(cols))
    for i := range values {
        var b sql.RawBytes
        values[i] = &b
    }

    type rowObj map[string]interface{}
    out := make([]rowObj, 0, 64)

    for rows.Next() {
        if err := rows.Scan(values...); err != nil {
            log.Fatalf("scan: %v", err)
        }
        obj := make(rowObj, len(cols))
        for i, col := range cols {
            v := *(values[i].(*sql.RawBytes))
            if v == nil {
                obj[col] = nil
            } else {
                obj[col] = string(v)
            }
        }
        out = append(out, obj)
    }
    if err := rows.Err(); err != nil {
        log.Fatalf("rows: %v", err)
    }

    enc := json.NewEncoder(logWriter{})
    enc.SetIndent("", "  ")
    if err := enc.Encode(out); err != nil {
        log.Fatalf("encode: %v", err)
    }
}

// looksLikeSelect checks that the statement starts with SELECT (case-insensitive), ignoring leading whitespace and comments.
func looksLikeSelect(s string) bool {
    trimmed := strings.TrimSpace(s)
    // Remove leading SQL line comments
    for strings.HasPrefix(trimmed, "--") || strings.HasPrefix(trimmed, "#") {
        nl := strings.Index(trimmed, "\n")
        if nl == -1 {
            trimmed = ""
            break
        }
        trimmed = strings.TrimSpace(trimmed[nl+1:])
    }
    if trimmed == "" {
        return false
    }
    return strings.HasPrefix(strings.ToLower(trimmed), "select")
}

// logWriter implements io.Writer by forwarding to log.Printf without timestamp prefix in JSON output.
type logWriter struct{}

func (logWriter) Write(p []byte) (n int, err error) {
    // Print raw JSON without additional formatting
    fmt.Print(string(p))
    return len(p), nil
}