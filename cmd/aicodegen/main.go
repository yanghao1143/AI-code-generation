package main

import (
    "encoding/json"
    "fmt"
    "io"
    "log"
    "os"
    "path/filepath"
    "strings"

    "xingzuo/internal/audit"
    "xingzuo/internal/ddl"
    m "xingzuo/internal/model"
    "xingzuo/internal/nlp"
    "xingzuo/internal/specgen"
)

// aicodegen is a focused CLI that parses .spec-workflow/sources/策划.md and
// generates standardized technical documents under .spec-workflow/specs/ai-codegen/
// and MySQL DDL scripts under scripts/db/. When DSN env is configured, it can
// optionally apply database creation/migration automatically.
//
// Usage examples:
//   aicodegen                              # 默认：读取 sources/策划.md → 生成文档与DDL；若检测到 DSN 则自动建库
//   aicodegen --apply-db=false             # 禁止自动建库（仅生成文档与DDL）
//   aicodegen --dsn-env=staging            # 指定使用 staging DSN（默认）
//   aicodegen --source-file=path/to.md     # 指定 PRD 源文件
//   aicodegen --out-spec=ai-codegen/auto   # 输出到子目录（默认 ai-codegen）
//   aicodegen --openapi-out=dist/openapi.json  # 同步输出生成的 OpenAPI
//   aicodegen --ticket=REQ-123             # 在有审批门禁时传入票据以执行变更
//
func main() {
    root, err := os.Getwd()
    if err != nil { log.Fatalf("getwd: %v", err) }

    // Help / usage
    for _, a := range os.Args[1:] {
        if a == "-h" || a == "--help" || strings.EqualFold(strings.TrimSpace(a), "help") {
            printUsage()
            return
        }
    }

    params := parseArgs(os.Args[1:])

    // Determine source text
    var (
        srcText string
        srcPath string
        srcFrom string // inline|stdin|file
    )
    if v := params["source-text"]; strings.TrimSpace(v) != "" {
        srcText = v
        srcFrom = "inline"
    } else if strings.EqualFold(strings.TrimSpace(params["stdin"]), "true") {
        b, err := io.ReadAll(os.Stdin)
        if err != nil { log.Fatalf("read stdin: %v", err) }
        srcText = string(b)
        srcFrom = "stdin"
    } else {
        if v := params["source-file"]; v != "" {
            if filepath.IsAbs(v) { srcPath = v } else { srcPath = filepath.Join(root, v) }
        } else {
            srcPath = filepath.Join(root, ".spec-workflow", "sources", "策划.md")
        }
        data, err := os.ReadFile(srcPath)
        if err != nil { log.Fatalf("read source %s: %v", srcPath, err) }
        srcText = string(data)
        srcFrom = "file"
    }

    // Parse → DomainModel using structured merge with ai-codegen spec when available
    var dm m.DomainModel
    var issues []m.ClarifyIssue
    dm, issues = nlp.ParseWithStructured(root, "ai-codegen", srcText)

    // Merge Terms from file if provided, else try default scripts/config/terms.json
    termsPath := params["terms"]
    if strings.TrimSpace(termsPath) != "" {
        if !filepath.IsAbs(termsPath) { termsPath = filepath.Join(root, termsPath) }
        tb, err := os.ReadFile(termsPath)
        if err != nil {
            log.Printf("warn: read terms failed: %v", err)
        } else {
            var ts map[string]string
            if err := json.Unmarshal(tb, &ts); err != nil {
                log.Printf("warn: parse terms failed: %v", err)
            } else {
                if dm.Terms == nil { dm.Terms = map[string]string{} }
                for k, v := range ts { dm.Terms[strings.ToLower(strings.TrimSpace(k))] = v }
            }
        }
    } else {
        def := filepath.Join(root, "scripts", "config", "terms.json")
        if tb, err := os.ReadFile(def); err == nil {
            var ts map[string]string
            if err := json.Unmarshal(tb, &ts); err == nil {
                if dm.Terms == nil { dm.Terms = map[string]string{} }
                for k, v := range ts { dm.Terms[strings.ToLower(strings.TrimSpace(k))] = v }
                fmt.Printf("Merged default Terms: %s\n", def)
            }
        }
    }

    // Output spec name (default ai-codegen)
    outSpec := params["out-spec"]
    if strings.TrimSpace(outSpec) == "" { outSpec = "ai-codegen" }

    // Write spec documents
    if err := specgen.WriteSpecFiles(dm, root, outSpec); err != nil {
        log.Fatalf("write spec files: %v", err)
    }

    // Generate DDL and write to scripts/db
    d := ddl.BuildDDL(dm)
    if err := ddl.WriteDDLFiles(root, d); err != nil {
        log.Fatalf("write ddl files: %v", err)
    }

    // Optional: write generated OpenAPI to a chosen path (e.g., dist/openapi.json)
    var openapiWritten string
    if openapiOut := strings.TrimSpace(params["openapi-out"]); openapiOut != "" {
        if !filepath.IsAbs(openapiOut) { openapiOut = filepath.Join(root, openapiOut) }
        if err := os.MkdirAll(filepath.Dir(openapiOut), 0o755); err != nil { log.Fatalf("mkdir openapi out dir: %v", err) }
        oc := specgen.GenerateOpenAPI(dm, filepath.Base(outSpec))
        if err := os.WriteFile(openapiOut, []byte(oc), 0o644); err != nil { log.Fatalf("write openapi out: %v", err) }
        fmt.Printf("OpenAPI written: %s\n", openapiOut)
        openapiWritten = openapiOut
    }

    // Optional: also write DDL to .spec-workflow/db/mysql for workflow integration
    if strings.EqualFold(strings.TrimSpace(params["write-workflow-ddl"]), "true") {
        wfdir := filepath.Join(root, ".spec-workflow", "db", "mysql")
        if err := os.MkdirAll(wfdir, 0o755); err == nil {
            files := map[string]string{
                filepath.Join(wfdir, "create.sql"):   d.Create,
                filepath.Join(wfdir, "migrate.sql"):  d.Migrate,
                filepath.Join(wfdir, "rollback.sql"): d.Rollback,
            }
            for p, c := range files {
                _ = os.WriteFile(p, []byte(c), 0o644)
            }
            fmt.Printf("Workflow DDL written: %s\n", wfdir)
        }
    }

    // Auto-apply DB if DSN is available or explicitly requested
    applyDbFlag := strings.TrimSpace(params["apply-db"])
    dsnEnv := strings.TrimSpace(params["dsn-env"])
    if dsnEnv == "" { dsnEnv = "staging" }
    var dsn string
    // Priority: explicit --dsn, then env by --dsn-env, else detect staging env variable
    if v := params["dsn"]; strings.TrimSpace(v) != "" {
        dsn = v
    } else {
        if ds, err := ddl.LoadEnvDSN(dsnEnv); err == nil { dsn = ds } else {
            // fallback: try staging env for convenience
            if ds, err2 := ddl.LoadEnvDSN("staging"); err2 == nil { dsn = ds }
        }
    }
    applyDB := false
    if applyDbFlag != "" {
        applyDB = strings.EqualFold(applyDbFlag, "true")
    } else if dsn != "" {
        applyDB = true
        fmt.Println("Auto-enabling apply-db because DSN is available. Use --apply-db=false to disable.")
    }
    if applyDB {
        if dsn == "" { log.Fatalf("apply-db requires --dsn or env XZ_DB_*_DSN configured for --dsn-env=%s", dsnEnv) }
        ticket := params["ticket"]
        if err := ddl.Run(ddl.ChannelChange, false, dsn, ticket); err != nil {
            log.Fatalf("apply db failed: %v", err)
        }
        fmt.Println("Database creation/migration applied successfully.")
    }

    // Summary
    fmt.Println("AI Codegen: spec and DDL generation completed.")
    switch srcFrom {
    case "inline":
        fmt.Printf("- Source:       inline text (%d chars)\n", len(srcText))
    case "stdin":
        fmt.Printf("- Source:       stdin (%d chars)\n", len(srcText))
    default:
        fmt.Printf("- Source:       %s\n", srcPath)
    }
    fmt.Printf("- Requirements: %s\n", filepath.Join(root, ".spec-workflow", "specs", outSpec, "requirements.md"))
    fmt.Printf("- Design:       %s\n", filepath.Join(root, ".spec-workflow", "specs", outSpec, "design.md"))
    fmt.Printf("- Tasks:        %s\n", filepath.Join(root, ".spec-workflow", "specs", outSpec, "tasks.md"))
    fmt.Printf("- OpenAPI:      %s\n", filepath.Join(root, ".spec-workflow", "specs", outSpec, "openapi.generated.json"))
    fmt.Printf("- DDL create:   %s\n", filepath.Join(root, "scripts", "db", "create.sql"))
    fmt.Printf("- DDL migrate:  %s\n", filepath.Join(root, "scripts", "db", "migrate.sql"))
    fmt.Printf("- DDL rollback: %s\n", filepath.Join(root, "scripts", "db", "rollback.sql"))

    if len(issues) > 0 {
        fmt.Println("\nClarification issues:")
        for _, is := range issues {
            fmt.Printf("- [%s] (%s) %s\n", is.ID, is.Severity, is.Message)
        }
    } else {
        fmt.Println("\nNo clarification issues detected.")
    }

    // Audit: record aicodegen run metadata (documents & DDL generation)
    {
        // collect issue IDs for quick summary
        var issueIDs []string
        for _, is := range issues { issueIDs = append(issueIDs, is.ID) }
        // redact DSN (only presence)
        dsnProvided := dsn != ""
        // ticket provided (even if not applying DB)
        ticket := params["ticket"]
        detail := map[string]interface{}{
            "sourceFrom": srcFrom,
            "sourcePath": srcPath,
            "outSpec":    outSpec,
            "specPaths": map[string]string{
                "requirements": filepath.Join(root, ".spec-workflow", "specs", outSpec, "requirements.md"),
                "design":       filepath.Join(root, ".spec-workflow", "specs", outSpec, "design.md"),
                "tasks":        filepath.Join(root, ".spec-workflow", "specs", outSpec, "tasks.md"),
                "openapi":      filepath.Join(root, ".spec-workflow", "specs", outSpec, "openapi.generated.json"),
            },
            "ddlPaths": map[string]string{
                "create":   filepath.Join(root, "scripts", "db", "create.sql"),
                "migrate":  filepath.Join(root, "scripts", "db", "migrate.sql"),
                "rollback": filepath.Join(root, "scripts", "db", "rollback.sql"),
            },
            "openapiOut":     openapiWritten,
            "applyDB":        applyDB,
            "dsnEnv":         dsnEnv,
            "dsnProvided":    dsnProvided,
            "entityCount":    len(dm.Entities),
            "relationCount":  len(dm.Relations),
            "termsCount":     len(dm.Terms),
            "clarifyCount":   len(issues),
            "clarifyIssueIDs": issueIDs,
        }
        audit.LogAICodegenRun(detail, ticket)
    }
}

func parseArgs(args []string) map[string]string {
    out := make(map[string]string)
    for _, a := range args {
        if strings.HasPrefix(a, "--") {
            kv := strings.SplitN(strings.TrimPrefix(a, "--"), "=", 2)
            if len(kv) == 2 {
                out[strings.ToLower(kv[0])] = kv[1]
            } else if len(kv) == 1 {
                out[strings.ToLower(kv[0])] = "true"
            }
        }
    }
    return out
}

func printUsage() {
    // 中文说明
    fmt.Println("aicodegen - 从策划/PRD 文档生成规格 (Requirements/Design/Tasks)、DDL 与 OpenAPI")
    fmt.Println()
    fmt.Println("用法:")
    fmt.Println("  aicodegen [参数]")
    fmt.Println()
    fmt.Println("常用参数:")
    fmt.Println("  --apply-db=true|false       是否自动执行数据库创建/迁移；当检测到 DSN 时默认自动执行。使用 --apply-db=false 可关闭")
    fmt.Println("  --dsn-env=test|staging|prod 指定使用的 DSN 环境；支持的环境变量为：")
    fmt.Println("                              - XZ_DB_TEST_DSN     (test/testing)")
    fmt.Println("                              - XZ_DB_STAGING_DSN  (staging/stage)")
    fmt.Println("                              - XZ_DB_PROD_DSN     (prod/production)")
    fmt.Println("  --dsn=<DSN>                 直接传入 DSN（优先级高于 --dsn-env）")
    fmt.Println("  --source-file=path.md       指定策划/PRD 源文件（默认：.spec-workflow/sources/策划.md）")
    fmt.Println("  --source-text=...           直接传入内联文本作为源（适合快速试验/CI）")
    fmt.Println("  --stdin                     从标准输入读取源文本：例如 echo \"...\" | aicodegen --stdin")
    fmt.Println("  --out-spec=ai-codegen/auto  指定规格输出目录（相对 .spec-workflow/specs/，默认 ai-codegen）")
    fmt.Println("  --openapi-out=dist/openapi.aicodegen.json  指定额外导出的 OpenAPI 文件路径")
    fmt.Println("  --write-workflow-ddl=true   额外写入 .spec-workflow/db/mysql 下的 DDL 文件以供工作流集成")
    fmt.Println("  --terms=scripts/config/terms.json  指定术语映射 JSON 文件以辅助解析术语")
    fmt.Println("  --ticket=REQ-123            在启用审批门禁时传入票据以执行数据库变更（需与环境变量 XZ_APPROVED_TICKET 匹配）")
    fmt.Println()
    fmt.Println("环境变量:")
    fmt.Println("  XZ_DB_TEST_DSN / XZ_DB_STAGING_DSN / XZ_DB_PROD_DSN  数据库连接 DSN（用于 --dsn-env）")
    fmt.Println("  XZ_APPROVED_TICKET         审批门禁：当执行 CHANGE/ROLLBACK 时需与 --ticket 一致，否则跳过")
    fmt.Println("  XZ_DB_OP_TIMEOUT           数据库操作超时，例如 '45s'、'2m'（默认 30s）")
    fmt.Println()
    fmt.Println("审计日志:")
    fmt.Println("  每次运行会在 stdout 输出一行 [AUDIT]，标识 action=aicodegen_run，包含规格与 DDL 生成的关键元数据")
    fmt.Println()
    fmt.Println("示例:")
    fmt.Println("  aicodegen --apply-db=false --out-spec=ai-codegen/ci --openapi-out=dist/openapi.aicodegen.json")
    fmt.Println("  aicodegen --dsn-env=staging --ticket=REQ-123")
    fmt.Println("  echo '需求：生成商品与订单模型...' | aicodegen --stdin --apply-db=false")
    fmt.Println("  aicodegen --source-text='需求：生成用户与团队模型...' --out-spec=ai-codegen/demo --apply-db=false")
    fmt.Println()
    // English help
    fmt.Println("aicodegen - Generate specs (Requirements/Design/Tasks), DDL and OpenAPI from PRD text")
    fmt.Println("Usage:")
    fmt.Println("  aicodegen [flags]")
    fmt.Println("Flags:")
    fmt.Println("  --apply-db=true|false       Auto apply DB create/migrate when DSN is available; use --apply-db=false to disable")
    fmt.Println("  --dsn-env=test|staging|prod Use DSN from env: XZ_DB_TEST_DSN / XZ_DB_STAGING_DSN / XZ_DB_PROD_DSN")
    fmt.Println("  --dsn=<DSN>                 Provide DSN directly (takes precedence over --dsn-env)")
    fmt.Println("  --source-file=path.md       Source PRD file (default: .spec-workflow/sources/策划.md)")
    fmt.Println("  --source-text=...           Inline PRD text as source")
    fmt.Println("  --stdin                     Read PRD text from stdin")
    fmt.Println("  --out-spec=ai-codegen/auto  Output spec directory under .spec-workflow/specs/")
    fmt.Println("  --openapi-out=dist/openapi.aicodegen.json  Extra OpenAPI output path")
    fmt.Println("  --write-workflow-ddl=true   Also write DDL under .spec-workflow/db/mysql for workflow integration")
    fmt.Println("  --terms=scripts/config/terms.json  Terms mapping JSON to aid parsing")
    fmt.Println("  --ticket=REQ-123            Approval ticket required when DB change gate is enabled (must match XZ_APPROVED_TICKET)")
    fmt.Println("Env:")
    fmt.Println("  XZ_APPROVED_TICKET          Approval gate for CHANGE/ROLLBACK channels")
    fmt.Println("  XZ_DB_OP_TIMEOUT            DB operation timeout (default 30s)")
}