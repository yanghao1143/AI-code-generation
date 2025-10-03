package clarify

import (
    "encoding/json"
    "fmt"
    "net/http"
    "os"
    "os/exec"
    "path/filepath"
    "sort"
    "strings"
    "time"

    "github.com/gin-gonic/gin"
    "github.com/gorilla/websocket"

    "xingzuo/internal/api"
    "xingzuo/internal/audit"
    "xingzuo/internal/middleware"
    "xingzuo/internal/validation"
)

// RegisterRoutes registers clarify service endpoints under /api/v1/ai/clarify.
// Endpoints:
//   POST /generate  -> returns structured Requirements/Design/Tasks and minimal OpenAPI fragment
//   GET  /stream    -> streams incremental clarify artifacts via Server-Sent Events (SSE)
func RegisterRoutes(r *gin.RouterGroup) {
    r.Use(middleware.RequirePermission("ai.clarify"))
    // Unified Web/API audit: logs action/user/ticket/detail to stdout + JSONL + Observe
    r.Use(middleware.HTTPAudit("ai.clarify"))

    // Synchronous generation endpoint
    r.POST("/generate", func(c *gin.Context) {
        rid := c.GetString("request_id")
        var req GenerateRequest
        if !validation.BindJSON(c, &req) {
            return
        }
        // Defaults
        if strings.TrimSpace(req.Language) == "" {
            req.Language = "zh-CN"
        }

        // Very lightweight outline as MVP; replace with NLP pipeline later
        outline := simpleOutline(req.Prompt, req.Language)
        resp := GenerateResponse{
            Requirements: outline.Requirements,
            Design:       outline.Design,
            Tasks:        outline.Tasks,
            OpenAPI: map[string]interface{}{
                "openapi": "3.0.0",
                "info": map[string]interface{}{"title": "clarify-svc", "version": "v0.1"},
                "paths": map[string]interface{}{
                    "/api/v1/ai/clarify/generate": map[string]interface{}{"post": map[string]interface{}{"summary": "Generate clarify artifacts"}},
                    "/api/v1/ai/clarify/stream":   map[string]interface{}{"get": map[string]interface{}{"summary": "Stream clarify artifacts (SSE)"}},
                },
            },
            Issues: []map[string]interface{}{},
        }

        // Audit
        audit.Forward(c, audit.Event{
            Action:         "clarify_generate",
            UserID:         c.GetString("user_id"),
            ApprovalTicket: c.GetHeader("X-Approval-Ticket"),
            Timestamp:      time.Now().UTC(),
            Detail: map[string]interface{}{
                "requestId": rid,
                "path":      c.FullPath(),
                "method":    c.Request.Method,
                "promptLen": len(req.Prompt),
                "language":  req.Language,
                "useStructured": req.UseStructured,
            },
        })

        c.JSON(200, api.OK(rid, resp))
    })

    // Streaming endpoint via Server-Sent Events (SSE)
    r.GET("/stream", func(c *gin.Context) {
        rid := c.GetString("request_id")
        prompt := strings.TrimSpace(c.Query("prompt"))
        lang := strings.TrimSpace(c.Query("language"))
        if lang == "" { lang = "zh-CN" }

        c.Writer.Header().Set("Content-Type", "text/event-stream")
        c.Writer.Header().Set("Cache-Control", "no-cache")
        c.Writer.Header().Set("Connection", "keep-alive")
        flusher, ok := c.Writer.(http.Flusher)
        if !ok {
            c.JSON(500, api.Err(rid, "E3001", "SSEUnsupported", "不支持SSE流式响应", "error", nil))
            return
        }

        outline := simpleOutline(prompt, lang)
        // Stream three chunks: requirements, design, tasks
        type chunk struct { Type string `json:"type"`; Data interface{} `json:"data"` }
        chunks := []chunk{
            {Type: "requirements", Data: outline.Requirements},
            {Type: "design", Data: outline.Design},
            {Type: "tasks", Data: outline.Tasks},
        }
        for _, ch := range chunks {
            b, _ := json.Marshal(ch)
            _, _ = c.Writer.Write([]byte("data: "))
            _, _ = c.Writer.Write(b)
            _, _ = c.Writer.Write([]byte("\n\n"))
            flusher.Flush()
            time.Sleep(100 * time.Millisecond)
        }

        // Final done event
        _, _ = c.Writer.Write([]byte("event: done\n"))
        _, _ = c.Writer.Write([]byte("data: {\"ok\":true}\n\n"))
        flusher.Flush()

        // Audit
        audit.Forward(c, audit.Event{
            Action:    "clarify_stream",
            UserID:    c.GetString("user_id"),
            Timestamp: time.Now().UTC(),
            Detail: map[string]interface{}{
                "requestId": rid,
                "path":      c.FullPath(),
                "method":    c.Request.Method,
                "promptLen": len(prompt),
                "language":  lang,
            },
        })
    })

    // Streaming endpoint via WebSocket (WS)
    // Handshake: GET /stream/ws?prompt=...&language=zh-CN
    // Frames: JSON objects {"type":"requirements|design|tasks","data": [...]}
    // Terminal frame: {"event":"done","data":{"ok":true}}
    r.GET("/stream/ws", func(c *gin.Context) {
        rid := c.GetString("request_id")
        prompt := strings.TrimSpace(c.Query("prompt"))
        lang := strings.TrimSpace(c.Query("language"))
        if lang == "" { lang = "zh-CN" }

        upgrader := websocket.Upgrader{
            ReadBufferSize:  1024,
            WriteBufferSize: 1024,
            // In production, tighten origin check. For dev, allow all.
            CheckOrigin: func(r *http.Request) bool { return true },
        }

        conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
        if err != nil {
            c.JSON(500, api.Err(rid, "E3002", "WSUpgradeFailed", "WebSocket 握手失败", "error", gin.H{"error": err.Error()}))
            return
        }
        defer conn.Close()

        start := time.Now()
        outline := simpleOutline(prompt, lang)

        type frame struct {
            Type  string      `json:"type,omitempty"`
            Event string      `json:"event,omitempty"`
            Data  interface{} `json:"data,omitempty"`
        }
        frames := []frame{
            {Type: "requirements", Data: outline.Requirements},
            {Type: "design", Data: outline.Design},
            {Type: "tasks", Data: outline.Tasks},
        }
        var wrote int
        for _, f := range frames {
            _ = conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
            if err := conn.WriteJSON(f); err != nil {
                // Audit stream error and break
                audit.Forward(c, audit.Event{
                    Action:    "clarify_stream_ws_error",
                    UserID:    c.GetString("user_id"),
                    Timestamp: time.Now().UTC(),
                    Detail: gin.H{"requestId": rid, "error": err.Error(), "wrote": wrote},
                })
                return
            }
            wrote++
            time.Sleep(100 * time.Millisecond)
        }
        // Terminal done event
        _ = conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
        _ = conn.WriteJSON(frame{Event: "done", Data: gin.H{"ok": true}})

        dur := time.Since(start)
        // Audit WS stream
        // Inject vendor WS metrics for HTTPAudit middleware
        c.Set("ws_frames_sent", wrote+1)
        c.Set("ws_duration_ms", dur.Milliseconds())
        c.Set("ws_close_reason", "")
        audit.Forward(c, audit.Event{
            Action:    "clarify_stream_ws",
            UserID:    c.GetString("user_id"),
            Timestamp: time.Now().UTC(),
            Detail: gin.H{
                "requestId":  rid,
                "path":       c.FullPath(),
                "method":     c.Request.Method,
                "promptLen":  len(prompt),
                "language":   lang,
                "framesSent": wrote + 1, // include terminal frame
                "durationMs": dur.Milliseconds(),
            },
        })
    })

    // Document export (Markdown first). Accepts prompt/language and returns saved file metadata.
    // POST /export { prompt, language, format } where format in [md]
    r.POST("/export", func(c *gin.Context) {
        rid := c.GetString("request_id")
        var req struct {
            Prompt   string `json:"prompt"`
            Language string `json:"language"`
            Format   string `json:"format"`
        }
        if !validation.BindJSON(c, &req) {
            return
        }
        if strings.TrimSpace(req.Language) == "" { req.Language = "zh-CN" }
        fmtStr := strings.ToLower(strings.TrimSpace(req.Format))
        if fmtStr == "" { fmtStr = "md" }
        if fmtStr != "md" {
            c.JSON(400, api.Err(rid, "E3010", "FormatNotSupported", "目前仅支持导出为 Markdown (md)", "warning", nil))
            return
        }

        outline := simpleOutline(req.Prompt, req.Language)
        // Build Markdown content
        var b strings.Builder
        b.WriteString("# 需求澄清导出\n\n")
        b.WriteString("## Requirements\n")
        for _, it := range outline.Requirements { b.WriteString("- "); b.WriteString(it); b.WriteString("\n") }
        b.WriteString("\n## Design\n")
        for _, it := range outline.Design { b.WriteString("- "); b.WriteString(it); b.WriteString("\n") }
        b.WriteString("\n## Tasks\n")
        for _, it := range outline.Tasks { b.WriteString("- "); b.WriteString(it); b.WriteString("\n") }
        b.WriteString("\n## OpenAPI (fragment)\n\n")
        openapiJSON, _ := json.MarshalIndent(outline.OpenAPI, "", "  ")
        b.WriteString("```json\n")
        b.Write(openapiJSON)
        b.WriteString("\n```\n")

        // Save to dist/clarify
        outDir := filepath.Join("dist", "clarify")
        _ = os.MkdirAll(outDir, 0o755)
        ts := time.Now().UTC().Format("20060102-150405")
        fname := fmt.Sprintf("clarify-%s-%s.%s", rid, ts, fmtStr)
        fpath := filepath.Join(outDir, fname)
        if err := os.WriteFile(fpath, []byte(b.String()), 0o644); err != nil {
            c.JSON(500, api.Err(rid, "E3011", "ExportFailed", "导出文件写入失败", "error", gin.H{"error": err.Error()}))
            return
        }

        // Audit export (Forward + JSONL append for local persistence)
        fi, _ := os.Stat(fpath)
        ev := audit.Event{
            Action:    "clarify_export",
            UserID:    c.GetString("user_id"),
            Timestamp: time.Now().UTC(),
            Detail: map[string]interface{}{
                "requestId": rid,
                "path":      c.FullPath(),
                "method":    c.Request.Method,
                "format":    fmtStr,
                "fileName":  fname,
                "filePath":  fpath,
                "size":      func() int64 { if fi != nil { return fi.Size() }; return int64(len(b.String())) }(),
            },
        }
        audit.Forward(c, ev)
        audit.AppendJSONL(ev)

        c.JSON(200, api.OK(rid, gin.H{
            "fileName": fname,
            "filePath": fpath,
            "format":   fmtStr,
        }))
    })

    // Download exported document by name
    r.GET("/docs/:name", func(c *gin.Context) {
        rid := c.GetString("request_id")
        name := strings.TrimSpace(c.Param("name"))
        if name == "" {
            c.JSON(400, api.Err(rid, "E3012", "MissingName", "缺少文档名称", "warning", nil))
            return
        }
        fpath := filepath.Join("dist", "clarify", name)
        if st, err := os.Stat(fpath); err != nil || st.IsDir() {
            c.JSON(404, api.Err(rid, "E404", "NotFound", "文档不存在", "warning", gin.H{"name": name}))
            return
        }
        c.File(fpath)
    })

    // Export latest Markdown to PDF via Pandoc.
    // Requires approval ticket: X-Approval-Ticket header enforced.
    r.POST("/export/pdf", middleware.RequireApprovalTicket(), func(c *gin.Context) {
        rid := c.GetString("request_id")
        outDir := filepath.Join("dist", "clarify")
        _ = os.MkdirAll(outDir, 0o755)

        // Locate latest Markdown file under dist/clarify
        mdPath, mdName, err := latestMarkdownFile(outDir)
        if err != nil {
            c.JSON(404, api.Err(rid, "E3013", "NoMarkdownExport", "未找到最近的 Markdown 导出，请先执行 Markdown 导出", "warning", nil))
            return
        }

        ts := time.Now().UTC().Format("20060102-150405")
        pdfName := fmt.Sprintf("clarify-%s-%s.pdf", rid, ts)
        pdfPath := filepath.Join(outDir, pdfName)

        // Execute pandoc conversion: markdown -> pdf.
        // Prefer XeLaTeX for better CJK support; fallback to wkhtmltopdf if XeLaTeX is unavailable.
        var runErr error
        cmd := exec.Command("pandoc", "--pdf-engine=xelatex", "-o", pdfPath, mdPath)
        if err := cmd.Run(); err != nil {
            // Fallback: wkhtmltopdf
            fb := exec.Command("pandoc", "--pdf-engine=wkhtmltopdf", "-o", pdfPath, mdPath)
            if err2 := fb.Run(); err2 != nil {
                runErr = fmt.Errorf("xelatex failed: %v; wkhtmltopdf failed: %v", err, err2)
            }
        }
        if runErr != nil {
            c.JSON(500, api.Err(rid, "E3014", "PandocFailed", "Pandoc 转换失败，请检查服务器是否已安装 XeLaTeX 或 wkhtmltopdf", "error", gin.H{"error": runErr.Error(), "source": mdName}))
            return
        }

        // Audit PDF export
        fi, _ := os.Stat(pdfPath)
        ev := audit.Event{
            Action:    "clarify_export_pdf",
            UserID:    c.GetString("user_id"),
            Timestamp: time.Now().UTC(),
            Detail: map[string]interface{}{
                "requestId": rid,
                "path":      c.FullPath(),
                "method":    c.Request.Method,
                "sourceMd":  mdName,
                "fileName":  pdfName,
                "filePath":  pdfPath,
                "size":      func() int64 { if fi != nil { return fi.Size() }; return 0 }(),
            },
        }
        audit.Forward(c, ev)
        audit.AppendJSONL(ev)

        c.JSON(200, api.OK(rid, gin.H{
            "fileName": pdfName,
            "filePath": pdfPath,
            "format":   "pdf",
            "download": fmt.Sprintf("/api/v1/ai/clarify/docs/%s", pdfName),
        }))
    })

    // Export latest Markdown to DOCX via Pandoc.
    // Requires approval ticket: X-Approval-Ticket header enforced.
    r.POST("/export/docx", middleware.RequireApprovalTicket(), func(c *gin.Context) {
        rid := c.GetString("request_id")
        outDir := filepath.Join("dist", "clarify")
        _ = os.MkdirAll(outDir, 0o755)

        // Locate latest Markdown file under dist/clarify
        mdPath, mdName, err := latestMarkdownFile(outDir)
        if err != nil {
            c.JSON(404, api.Err(rid, "E3015", "NoMarkdownExport", "未找到最近的 Markdown 导出，请先执行 Markdown 导出", "warning", nil))
            return
        }

        ts := time.Now().UTC().Format("20060102-150405")
        docxName := fmt.Sprintf("clarify-%s-%s.docx", rid, ts)
        docxPath := filepath.Join(outDir, docxName)

        // Execute pandoc conversion: markdown -> docx.
        // DOCX 不依赖 LaTeX 引擎，直接使用缺省管线。
        cmd := exec.Command("pandoc", "-o", docxPath, mdPath)
        if err := cmd.Run(); err != nil {
            c.JSON(500, api.Err(rid, "E3016", "PandocFailed", "DOCX 转换失败，请检查服务器是否已安装 pandoc", "error", gin.H{"error": err.Error(), "source": mdName}))
            return
        }

        // Audit DOCX export
        fi, _ := os.Stat(docxPath)
        ev := audit.Event{
            Action:    "clarify_export_docx",
            UserID:    c.GetString("user_id"),
            Timestamp: time.Now().UTC(),
            Detail: map[string]interface{}{
                "requestId": rid,
                "path":      c.FullPath(),
                "method":    c.Request.Method,
                "sourceMd":  mdName,
                "fileName":  docxName,
                "filePath":  docxPath,
                "size":      func() int64 { if fi != nil { return fi.Size() }; return 0 }(),
            },
        }
        audit.Forward(c, ev)
        audit.AppendJSONL(ev)

        c.JSON(200, api.OK(rid, gin.H{
            "fileName": docxName,
            "filePath": docxPath,
            "format":   "docx",
            "download": fmt.Sprintf("/api/v1/ai/clarify/docs/%s", docxName),
        }))
    })
}

// simpleOutline builds a minimal outline from a prompt and language.
// This is a placeholder to unblock integration; replace with NLP parsing later.
func simpleOutline(prompt, language string) GenerateResponse {
    p := strings.TrimSpace(prompt)
    if p == "" { p = "请描述要澄清的业务或需求" }
    req := []string{
        firstNonEmpty(language, "zh-CN", "明确目标与范围" , "Define goals and scope"),
        firstNonEmpty(language, "zh-CN", "识别关键角色与流程", "Identify key actors and flows"),
        firstNonEmpty(language, "zh-CN", "列出约束与依赖", "List constraints and dependencies"),
    }
    des := []string{
        firstNonEmpty(language, "zh-CN", "模块划分与接口草案", "Module decomposition and interface sketch"),
        firstNonEmpty(language, "zh-CN", "数据模型初稿", "Initial data model"),
        firstNonEmpty(language, "zh-CN", "安全与审计要求", "Security and audit requirements"),
    }
    tasks := []string{
        firstNonEmpty(language, "zh-CN", "编写需求文档", "Write requirements doc"),
        firstNonEmpty(language, "zh-CN", "整理设计方案", "Draft design"),
        firstNonEmpty(language, "zh-CN", "拆解开发任务", "Break down implementation tasks"),
    }
    // Attach prompt echo as first requirement for traceability
    req = append([]string{firstNonEmpty(language, "zh-CN", "输入: "+p, "Input: "+p)}, req...)
    return GenerateResponse{Requirements: req, Design: des, Tasks: tasks}
}

func firstNonEmpty(lang, zhRef, zhText, enText string) string {
    if strings.EqualFold(lang, zhRef) || lang == "zh" || strings.HasPrefix(lang, "zh-") { return zhText }
    return enText
}

// latestMarkdownFile returns the absolute path and base name of the latest .md file under dir.
func latestMarkdownFile(dir string) (string, string, error) {
    entries, err := os.ReadDir(dir)
    if err != nil {
        return "", "", err
    }
    var names []string
    for _, e := range entries {
        if e.IsDir() { continue }
        name := e.Name()
        if strings.HasSuffix(strings.ToLower(name), ".md") {
            names = append(names, name)
        }
    }
    if len(names) == 0 {
        return "", "", fmt.Errorf("no markdown files")
    }
    sort.Slice(names, func(i, j int) bool {
        si, _ := os.Stat(filepath.Join(dir, names[i]))
        sj, _ := os.Stat(filepath.Join(dir, names[j]))
        if si == nil || sj == nil { return names[i] > names[j] }
        return si.ModTime().After(sj.ModTime())
    })
    latest := names[0]
    return filepath.Join(dir, latest), latest, nil
}