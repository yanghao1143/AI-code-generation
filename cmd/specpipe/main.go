package main

import (
    "encoding/json"
    "fmt"
    "io"
    "log"
    "os"
    "path/filepath"
    "strings"

    "xingzuo/internal/ddl"
    m "xingzuo/internal/model"
    "xingzuo/internal/nlp"
    "xingzuo/internal/speccheck"
    "xingzuo/internal/specgen"
)

func usage() {
    fmt.Println("specpipe usage:")
    fmt.Println("  specpipe gen [--source-spec=ai-codegen --out-spec=xingzuo --source-file=path/to.md --source-text=\"中文PRD文本...\" --stdin=true --terms=path/to/terms.json --openapi-out=dist/openapi.json --apply-db=true --dsn-env=test|staging|prod --dsn=<mysql_dsn> --ticket=<id>]")
    fmt.Println("                                            # 解析自然语言需求，生成 .spec-workflow/specs/{out-spec} 文档与 DDL；当提供 --dsn 或 --dsn-env 时默认开启自动建库（除非 --apply-db=false）")
    fmt.Println("  specpipe nlpgen --module-name=<user-order> --source-file=path/to.txt --source-text=\"中文PRD文本...\" --openapi-out=dist/openapi.json --ddl-out=scripts/db/create.sql --speccheck=true [--terms=path/to/terms.json] [--apply-db=true --dsn-env=test|staging|prod --dsn=<mysql_dsn>]")
    fmt.Println("                                            # NLP → 规格生成（输出到 .spec-workflow/specs/xingzuo/<module>）→ OpenAPI/DDL，并可选 speccheck；当提供 --dsn 或 --dsn-env 时默认开启自动建库（除非 --apply-db=false）")
    fmt.Println("  specpipe db-preview --channel=READ|CHANGE|ROLLBACK")
    fmt.Println("  specpipe db-runner  --channel=CHANGE --dry-run=false --dsn-env=test|staging|prod --ticket=<id>")
    fmt.Println("  specpipe db-runner  --channel=ROLLBACK --dry-run=false --dsn-env=test|staging|prod --ticket=<id>")
    fmt.Println("  specpipe db-runner  --channel=READ --dry-run=true                      # 仅预览，不连接数据库")
    fmt.Println("  specpipe speccheck  --ddl=scripts/db/create.sql --openapi=path/to/openapi.json --terms=path/to/terms.json  # 规格 ↔ DDL/OpenAPI 一致性检查")
}

func main() {
    root, err := os.Getwd()
    if err != nil {
        log.Fatalf("getwd: %v", err)
    }

    args := os.Args
    if len(args) < 2 {
        // default to gen with defaults
        runGenWithParams(root, map[string]string{})
        return
    }

    switch args[1] {
    case "gen":
        params := parseArgs(args[2:])
        runGenWithParams(root, params)
    case "nlpgen":
        // Convenience wrapper for NLP → spec generation into xingzuo/<module>, with optional speccheck
        params := parseArgs(args[2:])
        mod := strings.TrimSpace(params["module-name"])
        if mod == "" {
            log.Fatalf("module-name required for nlpgen (e.g., --module-name=user-order)")
        }
        // Write specs under .spec-workflow/specs/xingzuo/<module>
        params["out-spec"] = filepath.Join("xingzuo", mod)
        // Run generation (spec docs + DDL + optional OpenAPI out + optional apply-db)
        runGenWithParams(root, params)
        // Optional consistency check
        if strings.EqualFold(params["speccheck"], "true") {
            // Determine DDL path
            ddlPath := params["ddl-out"]
            if ddlPath == "" {
                ddlPath = filepath.Join(root, "scripts", "db", "create.sql")
            } else if !filepath.IsAbs(ddlPath) {
                ddlPath = filepath.Join(root, ddlPath)
            }
            // Determine OpenAPI path
            openapiPath := params["openapi-out"]
            if openapiPath == "" {
                openapiPath = filepath.Join(root, "dist", "openapi.json")
            } else if !filepath.IsAbs(openapiPath) {
                openapiPath = filepath.Join(root, openapiPath)
            }
            // Optional terms
            termsPath := params["terms"]
            if termsPath != "" && !filepath.IsAbs(termsPath) {
                termsPath = filepath.Join(root, termsPath)
            }
            // Build DomainModel from the same params to ensure consistency
            dm := buildDomainModelFromParams(root, params)
            runSpecCheckDM(dm, root, ddlPath, openapiPath, termsPath)
        }
    case "db-preview":
        params := parseArgs(args[2:])
        ch := toChannel(params["channel"]) // default CHANGE for preview
        stmts, hash, err := ddl.Preview(ch)
        if err != nil {
            log.Fatalf("preview: %v", err)
        }
        fmt.Printf("Preview channel=%s sqlHash=%s\n", ch, hash)
        for i, s := range stmts {
            fmt.Printf("[%d] %s;\n", i+1, s)
        }
    case "db-runner":
        params := parseArgs(args[2:])
        ch := toChannel(params["channel"]) // default CHANGE
        dry := strings.EqualFold(params["dry-run"], "true") || ch == ddl.ChannelRead
        var dsn string
        if v := params["dsn"]; v != "" {
            dsn = v
        } else if env := params["dsn-env"]; env != "" {
            d, err := ddl.LoadEnvDSN(env)
            if err != nil {
                log.Fatalf("load dsn env: %v", err)
            }
            dsn = d
        }
        if !dry && dsn == "" {
            log.Fatalf("dsn required for non-dry-run channel. Provide --dsn or --dsn-env=test|staging|prod with env variables set.")
        }
        ticket := params["ticket"]
        if err := ddl.Run(ch, dry, dsn, ticket); err != nil {
            log.Fatalf("run: %v", err)
        }
        fmt.Printf("db-runner completed: channel=%s dryRun=%v\n", ch, dry)
    case "speccheck":
        params := parseArgs(args[2:])
        ddlPath := params["ddl"]
        if ddlPath == "" {
            ddlPath = filepath.Join(root, "scripts", "db", "create.sql")
        } else if !filepath.IsAbs(ddlPath) {
            ddlPath = filepath.Join(root, ddlPath)
        }
        // Optional OpenAPI path
        openapiPath := params["openapi"]
        if openapiPath == "" {
            candidate := filepath.Join(root, "scripts", "reports", "req-ai-codegen-009", "openapi.json")
            if _, err := os.Stat(candidate); err == nil {
                openapiPath = candidate
            } else {
                candidate = filepath.Join(root, "dist", "openapi.json")
                if _, err := os.Stat(candidate); err == nil {
                    openapiPath = candidate
                }
            }
        } else if !filepath.IsAbs(openapiPath) {
            openapiPath = filepath.Join(root, openapiPath)
        }
        // Optional Terms path
        termsPath := params["terms"]
        if termsPath != "" && !filepath.IsAbs(termsPath) {
            termsPath = filepath.Join(root, termsPath)
        }
        runSpecCheck(root, ddlPath, openapiPath, termsPath)
    default:
        usage()
    }
}

func runGenWithParams(root string, params map[string]string) {
    // Determine source text
    var (
        srcText    string
        srcPath    string
        sourceSpec string
        srcFrom    string // inline|stdin|file
    )
    if v := params["source-text"]; strings.TrimSpace(v) != "" {
        srcText = v
        srcFrom = "inline"
    } else if strings.EqualFold(strings.TrimSpace(params["stdin"]), "true") {
        b, err := io.ReadAll(os.Stdin)
        if err != nil {
            log.Fatalf("read stdin: %v", err)
        }
        srcText = string(b)
        srcFrom = "stdin"
    } else {
        if v := params["source-file"]; v != "" {
            if filepath.IsAbs(v) { srcPath = v } else { srcPath = filepath.Join(root, v) }
        } else if spec := params["source-spec"]; spec != "" {
            // Read requirements.md from a spec (e.g., .spec-workflow/specs/ai-codegen/requirements.md)
            sourceSpec = spec
            srcPath = filepath.Join(root, ".spec-workflow", "specs", spec, "requirements.md")
        } else {
            // Fallback to planning source
            srcPath = filepath.Join(root, ".spec-workflow", "sources", "策划.md")
        }
        data, err := os.ReadFile(srcPath)
        if err != nil {
            log.Fatalf("read source %s: %v", srcPath, err)
        }
        srcText = string(data)
        srcFrom = "file"
    }

    // NLP parse -> DomainModel + clarify issues
    var dm m.DomainModel
    var issues []m.ClarifyIssue
    // Decide structured vs text parsing
    useStructured := false
    if sourceSpec != "" {
        // If ai-codegen or structured files exist in source spec dir, use structured parsing
        base := filepath.Join(root, ".spec-workflow", "specs", sourceSpec)
        candidates := []string{
            filepath.Join(base, "openapi.json"),
            filepath.Join(base, "generated", "articles_openapi.json"),
            filepath.Join(base, "jsonschema.json"),
            filepath.Join(base, "generated", "articles_schema.json"),
        }
        for _, c := range candidates {
            if _, err := os.Stat(c); err == nil { useStructured = true; break }
        }
        if strings.EqualFold(sourceSpec, "ai-codegen") { useStructured = true }
    }
    if useStructured {
        dm, issues = nlp.ParseWithStructured(root, sourceSpec, srcText)
    } else {
        dm, issues = nlp.Parse(srcText)
    }

    // Merge Terms from file if provided
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
    } else if strings.EqualFold(sourceSpec, "ai-codegen") {
        // Auto-merge default Terms when using ai-codegen and --terms not provided
        def := filepath.Join(root, "scripts", "config", "terms.json")
        if tb, err := os.ReadFile(def); err == nil {
            var ts map[string]string
            if err := json.Unmarshal(tb, &ts); err != nil {
                log.Printf("warn: parse default terms failed: %v", err)
            } else {
                if dm.Terms == nil { dm.Terms = map[string]string{} }
                for k, v := range ts { dm.Terms[strings.ToLower(strings.TrimSpace(k))] = v }
                fmt.Printf("Merged default Terms: %s\n", def)
            }
        }
    }

    // Output spec name
    outSpec := params["out-spec"]
    if strings.TrimSpace(outSpec) == "" { outSpec = "xingzuo" }

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
    if openapiOut := strings.TrimSpace(params["openapi-out"]); openapiOut != "" {
        if !filepath.IsAbs(openapiOut) {
            openapiOut = filepath.Join(root, openapiOut)
        }
        if err := os.MkdirAll(filepath.Dir(openapiOut), 0o755); err != nil {
            log.Fatalf("mkdir openapi out dir: %v", err)
        }
        oc := specgen.GenerateOpenAPI(dm, outSpec)
        if err := os.WriteFile(openapiOut, []byte(oc), 0o644); err != nil {
            log.Fatalf("write openapi out: %v", err)
        }
        fmt.Printf("OpenAPI written: %s\n", openapiOut)
    }

    // Optional: apply DB changes automatically
    // Default behavior: if --apply-db is not explicitly provided, auto-enable when --dsn or --dsn-env is present.
    applyDbFlag := strings.TrimSpace(params["apply-db"])
    dsnFlagPresent := strings.TrimSpace(params["dsn"]) != "" || strings.TrimSpace(params["dsn-env"]) != ""
    applyDB := false
    if applyDbFlag != "" {
        applyDB = strings.EqualFold(applyDbFlag, "true")
    } else if dsnFlagPresent {
        applyDB = true
        fmt.Println("Auto-enabling apply-db because --dsn/--dsn-env provided. Use --apply-db=false to disable.")
    }
    if applyDB {
        var dsn string
        if v := params["dsn"]; v != "" {
            dsn = v
        } else if env := params["dsn-env"]; env != "" {
            d, err := ddl.LoadEnvDSN(env)
            if err != nil {
                log.Fatalf("load dsn env: %v", err)
            }
            dsn = d
        }
        if dsn == "" {
            log.Fatalf("apply-db requires --dsn or --dsn-env=test|staging|prod")
        }
        ticket := params["ticket"]
        if err := ddl.Run(ddl.ChannelChange, false, dsn, ticket); err != nil {
            log.Fatalf("apply db failed: %v", err)
        }
        fmt.Println("Database creation/migration applied successfully.")
    }

    // Summary
    fmt.Println("Spec and DDL generation completed.")
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
}

// runSpecCheck parses DomainModel from default planning source and compares with provided DDL/OpenAPI.
// Used by the standalone speccheck subcommand.
func runSpecCheck(root string, ddlPath string, openapiPath string, termsPath string) {
    // Parse DomainModel from the planning doc
    src := filepath.Join(root, ".spec-workflow", "sources", "策划.md")
    data, err := os.ReadFile(src)
    if err != nil {
        log.Fatalf("read source %s: %v", src, err)
    }
    dm, _ := nlp.Parse(string(data))

    // Merge Terms from file if provided
    if strings.TrimSpace(termsPath) != "" {
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
    }

    // Parse DDL tables
    tbls, err := speccheck.ParseDDL(ddlPath)
    if err != nil {
        log.Fatalf("parse ddl: %v", err)
    }
    rep := speccheck.CompareDomainWithDDL(dm, tbls)
    rep.SourceDDL = ddlPath
    // Parse OpenAPI if provided
    if strings.TrimSpace(openapiPath) != "" {
        oa, err := speccheck.ParseOpenAPI(openapiPath)
        if err != nil {
            log.Printf("warn: parse openapi failed: %v", err)
        } else {
            orep := speccheck.CompareOpenAPIWithDomain(dm, oa)
            orep.Source = openapiPath
            rep.OpenAPI = &orep
        }
    }
    path, err := speccheck.WriteReport(root, rep)
    if err != nil {
        log.Fatalf("write speccheck report: %v", err)
    }
    fmt.Printf("Consistency report written: %s\n", path)
    fmt.Printf("Summary: %s\n", rep.Summary)
    if len(rep.MissingTables) > 0 {
        fmt.Printf("Missing tables: %v\n", rep.MissingTables)
    }
    if len(rep.ExtraTables) > 0 {
        fmt.Printf("Extra tables: %v\n", rep.ExtraTables)
    }
    if len(rep.MissingColumns) > 0 {
        fmt.Println("Missing columns:")
        for t, cols := range rep.MissingColumns {
            fmt.Printf("- %s: %v\n", t, cols)
        }
    }
    if len(rep.TypeMismatches) > 0 {
        fmt.Println("Type mismatches:")
        for t, cols := range rep.TypeMismatches {
            for c, d := range cols {
                fmt.Printf("- %s.%s: %s\n", t, c, d)
            }
        }
    }
    if rep.OpenAPI != nil {
        fmt.Printf("OpenAPI Summary: %s\n", rep.OpenAPI.Summary)
        if len(rep.OpenAPI.MissingResources) > 0 {
            fmt.Printf("OpenAPI Missing resources: %v\n", rep.OpenAPI.MissingResources)
        }
        if len(rep.OpenAPI.ExtraResources) > 0 {
            fmt.Printf("OpenAPI Extra resources: %v\n", rep.OpenAPI.ExtraResources)
        }
        if len(rep.OpenAPI.SchemaMissingEntities) > 0 {
            fmt.Printf("OpenAPI Missing entity schemas: %v\n", rep.OpenAPI.SchemaMissingEntities)
        }
        if len(rep.OpenAPI.SchemaMissingFields) > 0 {
            fmt.Println("OpenAPI Schema missing fields:")
            for e, fs := range rep.OpenAPI.SchemaMissingFields {
                fmt.Printf("- %s: %v\n", e, fs)
            }
        }
        if len(rep.OpenAPI.SchemaTypeMismatches) > 0 {
            fmt.Println("OpenAPI Schema type mismatches:")
            for e, mp := range rep.OpenAPI.SchemaTypeMismatches {
                for f, d := range mp {
                    fmt.Printf("- %s.%s: %s\n", e, f, d)
                }
            }
        }
    }
}

// buildDomainModelFromParams reuses the same source selection logic to construct a DomainModel
// for use in nlpgen's speccheck, ensuring the comparison aligns with generated specs/DDL.
func buildDomainModelFromParams(root string, params map[string]string) m.DomainModel {
    var (
        srcText    string
        srcPath    string
        sourceSpec string
    )
    if v := params["source-text"]; strings.TrimSpace(v) != "" {
        srcText = v
    } else if strings.EqualFold(strings.TrimSpace(params["stdin"]), "true") {
        b, err := io.ReadAll(os.Stdin)
        if err != nil { log.Fatalf("read stdin: %v", err) }
        srcText = string(b)
    } else {
        if v := params["source-file"]; v != "" {
            if filepath.IsAbs(v) { srcPath = v } else { srcPath = filepath.Join(root, v) }
        } else if spec := params["source-spec"]; spec != "" {
            sourceSpec = spec
            srcPath = filepath.Join(root, ".spec-workflow", "specs", spec, "requirements.md")
        } else {
            srcPath = filepath.Join(root, ".spec-workflow", "sources", "策划.md")
        }
        data, err := os.ReadFile(srcPath)
        if err != nil { log.Fatalf("read source %s: %v", srcPath, err) }
        srcText = string(data)
    }
    // NLP parse -> DomainModel (structured if source-spec provided)
    var dm m.DomainModel
    if sourceSpec != "" {
        dm, _ = nlp.ParseWithStructured(root, sourceSpec, srcText)
    } else {
        dm, _ = nlp.Parse(srcText)
    }
    // Merge Terms
    termsPath := params["terms"]
    if strings.TrimSpace(termsPath) != "" {
        if !filepath.IsAbs(termsPath) { termsPath = filepath.Join(root, termsPath) }
        tb, err := os.ReadFile(termsPath)
        if err == nil {
            var ts map[string]string
            if json.Unmarshal(tb, &ts) == nil {
                if dm.Terms == nil { dm.Terms = map[string]string{} }
                for k, v := range ts { dm.Terms[strings.ToLower(strings.TrimSpace(k))] = v }
            }
        }
    }
    return dm
}

// runSpecCheckDM compares provided DomainModel with DDL/OpenAPI and writes a consistency report.
func runSpecCheckDM(dm m.DomainModel, root string, ddlPath string, openapiPath string, termsPath string) {
    // Parse DDL tables
    tbls, err := speccheck.ParseDDL(ddlPath)
    if err != nil { log.Fatalf("parse ddl: %v", err) }
    rep := speccheck.CompareDomainWithDDL(dm, tbls)
    rep.SourceDDL = ddlPath
    // Parse OpenAPI if provided
    if strings.TrimSpace(openapiPath) != "" {
        oa, err := speccheck.ParseOpenAPI(openapiPath)
        if err != nil {
            log.Printf("warn: parse openapi failed: %v", err)
        } else {
            orep := speccheck.CompareOpenAPIWithDomain(dm, oa)
            orep.Source = openapiPath
            rep.OpenAPI = &orep
        }
    }
    path, err := speccheck.WriteReport(root, rep)
    if err != nil { log.Fatalf("write speccheck report: %v", err) }
    fmt.Printf("Consistency report written: %s\n", path)
    fmt.Printf("Summary: %s\n", rep.Summary)
    if len(rep.MissingTables) > 0 {
        fmt.Printf("Missing tables: %v\n", rep.MissingTables)
    }
    if len(rep.ExtraTables) > 0 {
        fmt.Printf("Extra tables: %v\n", rep.ExtraTables)
    }
    if len(rep.MissingColumns) > 0 {
        fmt.Println("Missing columns:")
        for t, cols := range rep.MissingColumns { fmt.Printf("- %s: %v\n", t, cols) }
    }
    if len(rep.TypeMismatches) > 0 {
        fmt.Println("Type mismatches:")
        for t, cols := range rep.TypeMismatches { for c, d := range cols { fmt.Printf("- %s.%s: %s\n", t, c, d) } }
    }
    if rep.OpenAPI != nil {
        fmt.Printf("OpenAPI Summary: %s\n", rep.OpenAPI.Summary)
        if len(rep.OpenAPI.MissingResources) > 0 { fmt.Printf("OpenAPI Missing resources: %v\n", rep.OpenAPI.MissingResources) }
        if len(rep.OpenAPI.ExtraResources) > 0 { fmt.Printf("OpenAPI Extra resources: %v\n", rep.OpenAPI.ExtraResources) }
        if len(rep.OpenAPI.SchemaMissingEntities) > 0 { fmt.Printf("OpenAPI Missing entity schemas: %v\n", rep.OpenAPI.SchemaMissingEntities) }
        if len(rep.OpenAPI.SchemaMissingFields) > 0 {
            fmt.Println("OpenAPI Schema missing fields:")
            for e, fs := range rep.OpenAPI.SchemaMissingFields { fmt.Printf("- %s: %v\n", e, fs) }
        }
        if len(rep.OpenAPI.SchemaTypeMismatches) > 0 {
            fmt.Println("OpenAPI Schema type mismatches:")
            for e, mp := range rep.OpenAPI.SchemaTypeMismatches { for f, d := range mp { fmt.Printf("- %s.%s: %s\n", e, f, d) } }
        }
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

func toChannel(s string) ddl.Channel {
    v := strings.ToUpper(strings.TrimSpace(s))
    switch v {
    case "READ":
        return ddl.ChannelRead
    case "ROLLBACK":
        return ddl.ChannelRollback
    case "CHANGE":
        fallthrough
    default:
        return ddl.ChannelChange
    }
}