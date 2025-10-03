package specs

import (
    "os"
    "path/filepath"
    "strings"

    "github.com/gin-gonic/gin"

    "xingzuo/internal/api"
    "xingzuo/internal/ddl"
    m "xingzuo/internal/model"
    "xingzuo/internal/middleware"
    "xingzuo/internal/nlp"
    "xingzuo/internal/specgen"
    "xingzuo/internal/validation"
)

// GenerateRequest defines the payload for /api/v1/ai/specs/generate
type GenerateRequest struct {
    // Spec name under .spec-workflow/specs/{specName}
    SpecName        string `json:"specName"`
    // Source spec name for structured merge (openapi/jsonschema) under .spec-workflow/specs/{sourceSpec}
    SourceSpec      string `json:"sourceSpec"`
    // Use structured merge when available
    UseStructured   bool   `json:"useStructured"`
    // Generate requirements/design/tasks/openapi docs
    GenerateDocs    bool   `json:"generateDocs"`
    // Generate DDL SQL from DomainModel
    GenerateDDL     bool   `json:"generateDDL"`
    // Also write DDL files into .spec-workflow/db/mysql in addition to scripts/db
    WriteWorkflowDDL bool  `json:"writeWorkflowDDL"`
    // Optional: preview planned SQL for given channel (READ|CHANGE|ROLLBACK)
    ExecChannel     string `json:"execChannel"`
    // Optional: environment name for DSN resolution when executing (test|staging|prod)
    ExecEnv         string `json:"execEnv"`
    // Dry-run flag (default true). When true, never execute DB changes.
    DryRun          bool   `json:"dryRun"`
    // Ticket ID for approval when executing change/rollback (matched against env XZ_APPROVED_TICKET)
    TicketID        string `json:"ticketId"`
}

// GenerateResponse summarizes outputs of the generation process.
type GenerateResponse struct {
    OperationID string            `json:"operationId"`
    SpecName    string            `json:"specName"`
    SourceSpec  string            `json:"sourceSpec"`
    Entities    int               `json:"entities"`
    Relations   int               `json:"relations"`
    Issues      []m.ClarifyIssue  `json:"issues"`
    Files       map[string]string `json:"files"` // logical -> absolute path
    SQLPreview  []string          `json:"sqlPreview,omitempty"`
    SQLHash     string            `json:"sqlHash,omitempty"`
}

// RegisterRoutes registers /api/v1/ai/specs endpoints.
func RegisterRoutes(r *gin.RouterGroup) {
    r.Use(middleware.RequirePermission("ai.specs"))

    r.POST("/generate", func(c *gin.Context) {
        rid := c.GetString("request_id")
        var req GenerateRequest
        if !validation.BindJSON(c, &req) {
            return
        }

        // Defaults
        if strings.TrimSpace(req.SpecName) == "" { req.SpecName = "ai-codegen" }
        if strings.TrimSpace(req.SourceSpec) == "" { req.SourceSpec = req.SpecName }
        if req.GenerateDocs == false && req.GenerateDDL == false { req.GenerateDocs = true }
        if !req.GenerateDDL { req.WriteWorkflowDDL = false }

        // Load planning doc
        wd, _ := os.Getwd()
        srcPath := filepath.Join(wd, ".spec-workflow", "sources", "策划.md")
        body, err := os.ReadFile(srcPath)
        if err != nil {
            c.JSON(500, api.Err(rid, "E2001", "ReadPRDFailed", "无法读取策划文档，请确认文件存在", "error", gin.H{"path": srcPath, "error": err.Error()}))
            return
        }

        // Parse to DomainModel
        var dm m.DomainModel
        var issues []m.ClarifyIssue
        if req.UseStructured {
            dm, issues = nlp.ParseWithStructured(wd, req.SourceSpec, string(body))
        } else {
            dm, issues = nlp.Parse(string(body))
        }

        // Write spec documents
        files := map[string]string{}
        if req.GenerateDocs {
            if err := specgen.WriteSpecFiles(dm, wd, req.SpecName); err != nil {
                c.JSON(500, api.Err(rid, "E2002", "WriteSpecFailed", "写入规范文档失败", "error", gin.H{"error": err.Error()}))
                return
            }
            // Record paths
            specDir := filepath.Join(wd, ".spec-workflow", "specs", req.SpecName)
            files["requirements"] = filepath.Join(specDir, "requirements.md")
            files["design"] = filepath.Join(specDir, "design.md")
            files["tasks"] = filepath.Join(specDir, "tasks.md")
            files["openapi"] = filepath.Join(specDir, "openapi.generated.json")
        }

        // Generate DDL and write files
        var previewStmts []string
        var sqlHash string
        if req.GenerateDDL {
            ddlPack := ddl.BuildDDL(dm)
            if err := ddl.WriteDDLFiles(wd, ddlPack); err != nil {
                c.JSON(500, api.Err(rid, "E2003", "WriteDDLFailed", "写入DDL文件失败", "error", gin.H{"error": err.Error()}))
                return
            }
            // Record script paths under scripts/db
            files["ddl.create"] = filepath.Join(wd, "scripts", "db", "create.sql")
            files["ddl.migrate"] = filepath.Join(wd, "scripts", "db", "migrate.sql")
            files["ddl.rollback"] = filepath.Join(wd, "scripts", "db", "rollback.sql")

            // Also write into .spec-workflow/db/mysql if requested
            if req.WriteWorkflowDDL {
                wfDir := filepath.Join(wd, ".spec-workflow", "db", "mysql")
                if err := os.MkdirAll(wfDir, 0o755); err == nil {
                    _ = os.WriteFile(filepath.Join(wfDir, "create.sql"), []byte(ddlPack.Create), 0o644)
                    _ = os.WriteFile(filepath.Join(wfDir, "migrate.sql"), []byte(ddlPack.Migrate), 0o644)
                    _ = os.WriteFile(filepath.Join(wfDir, "rollback.sql"), []byte(ddlPack.Rollback), 0o644)
                    files["wf.ddl.create"] = filepath.Join(wfDir, "create.sql")
                    files["wf.ddl.migrate"] = filepath.Join(wfDir, "migrate.sql")
                    files["wf.ddl.rollback"] = filepath.Join(wfDir, "rollback.sql")
                }
            }

            // Optional preview for the requested channel
            ch := strings.ToUpper(strings.TrimSpace(req.ExecChannel))
            if ch == string(ddl.ChannelRead) || ch == string(ddl.ChannelChange) || ch == string(ddl.ChannelRollback) {
                var channel ddl.Channel
                switch ch {
                case string(ddl.ChannelRead):
                    channel = ddl.ChannelRead
                case string(ddl.ChannelChange):
                    channel = ddl.ChannelChange
                case string(ddl.ChannelRollback):
                    channel = ddl.ChannelRollback
                }
                if stmts, hash, err := ddl.Preview(channel); err == nil {
                    previewStmts = stmts
                    sqlHash = hash
                }
            }
        }

        resp := GenerateResponse{
            OperationID: "specs_gen_" + rid,
            SpecName:    req.SpecName,
            SourceSpec:  req.SourceSpec,
            Entities:    len(dm.Entities),
            Relations:   len(dm.Relations),
            Issues:      issues,
            Files:       files,
            SQLPreview:  previewStmts,
            SQLHash:     sqlHash,
        }

        c.JSON(200, api.OK(rid, resp))
    })
}