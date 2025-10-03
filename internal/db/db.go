package db

import (
    "context"
    "database/sql"
    "fmt"
    "os"
    "strings"
    "time"

    _ "github.com/go-sql-driver/mysql"
)

var sqlDB *sql.DB

// InitFromEnv initializes a MySQL connection pool from environment variables.
// Precedence:
// 1) DB_DSN (go-sql-driver format or URL)
// 2) XZ_DB_<ENV>_DSN (ENV from APP_ENV: test/staging/prod)
// 3) host-based vars: DB_HOST/DB_PORT/DB_USER/DB_PASS/DB_NAME (fallback defaults for dev)
func InitFromEnv() (*sql.DB, error) {
    dsn := os.Getenv("DB_DSN")
    if dsn == "" {
        env := os.Getenv("APP_ENV")
        if env == "" { env = "dev" }
        switch env {
        case "test":
            dsn = os.Getenv("XZ_DB_TEST_DSN")
        case "staging":
            dsn = os.Getenv("XZ_DB_STAGING_DSN")
        case "prod":
            dsn = os.Getenv("XZ_DB_PROD_DSN")
        }
    }

    if dsn == "" {
        host := getenvDefault("DB_HOST", "127.0.0.1")
        port := getenvDefault("DB_PORT", "3306")
        user := getenvDefault("DB_USER", "root")
        pass := os.Getenv("DB_PASS") // empty allowed
        name := getenvDefault("DB_NAME", "xingzuo_dev")
        socket := os.Getenv("DB_UNIX_SOCKET")
        // Prefer TCP if host provided; allow explicit unix socket via env
        if socket != "" {
            dsn = fmt.Sprintf("%s:%s@unix(%s)/%s?parseTime=true&multiStatements=true&charset=utf8mb4&collation=utf8mb4_unicode_ci", user, pass, socket, name)
        } else {
            dsn = fmt.Sprintf("%s:%s@tcp(%s:%s)/%s?parseTime=true&multiStatements=true&charset=utf8mb4&collation=utf8mb4_unicode_ci", user, pass, host, port, name)
        }
    }

    // Log masked DSN for diagnostics (mask password if present)
    masked := dsn
    if i := strings.Index(masked, ":"); i != -1 {
        if j := strings.Index(masked[i+1:], "@"); j != -1 {
            // replace between ':' and '@'
            masked = masked[:i+1] + "***" + masked[i+1+j:]
        }
    }
    fmt.Println("[db] init DSN:", masked)

    db, err := sql.Open("mysql", dsn)
    if err != nil {
        fmt.Println("[db] sql.Open error:", err)
        return nil, err
    }
    // Pool tuning (sane defaults for dev)
    db.SetMaxOpenConns(10)
    db.SetMaxIdleConns(5)
    db.SetConnMaxIdleTime(5 * time.Minute)
    db.SetConnMaxLifetime(30 * time.Minute)

    // Verify connectivity
    ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
    defer cancel()
    if err := db.PingContext(ctx); err != nil {
        fmt.Println("[db] ping TCP/UNIX failed:", err)
        // Fallback: try unix socket if not already using it
        if !strings.Contains(dsn, "@unix(") {
            socket := getenvDefault("DB_UNIX_SOCKET", "/var/run/mysqld/mysqld.sock")
            host := os.Getenv("DB_HOST")
            user := getenvDefault("DB_USER", "root")
            pass := os.Getenv("DB_PASS")
            name := getenvDefault("DB_NAME", "xingzuo_dev")
            if host == "localhost" || host == "" || strings.HasPrefix(host, "/") {
                alt := fmt.Sprintf("%s:%s@unix(%s)/%s?parseTime=true&multiStatements=true&charset=utf8mb4&collation=utf8mb4_unicode_ci", user, pass, socket, name)
                if adb, aerr := sql.Open("mysql", alt); aerr == nil {
                    ctx2, cancel2 := context.WithTimeout(context.Background(), 2*time.Second)
                    defer cancel2()
                    if pingErr := adb.PingContext(ctx2); pingErr == nil {
                        fmt.Println("[db] fallback unix socket connected:", socket)
                        sqlDB = adb
                        return adb, nil
                    } else {
                        fmt.Println("[db] fallback unix ping failed:", pingErr)
                    }
                } else {
                    fmt.Println("[db] fallback sql.Open error:", aerr)
                }
            }
        }
        return nil, err
    }

    sqlDB = db
    return db, nil
}

// DB returns the initialized sql.DB (may be nil if InitFromEnv failed/not called).
func DB() *sql.DB { return sqlDB }

// Health performs a ping with timeout to check DB connectivity.
func Health(ctx context.Context) error {
    if sqlDB == nil { return fmt.Errorf("db not initialized") }
    return sqlDB.PingContext(ctx)
}

func getenvDefault(key, def string) string {
    if v := os.Getenv(key); v != "" { return v }
    return def
}