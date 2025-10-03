package nlp

import (
    "encoding/json"
    "fmt"
    "os"
    "path/filepath"
    "strings"

    m "xingzuo/internal/model"
)

// ParseWithStructured augments text-based parsing with structured sources from a spec
// directory (e.g., .spec-workflow/specs/ai-codegen), merging OpenAPI/JSON Schema
// into the DomainModel for higher accuracy.
func ParseWithStructured(root string, sourceSpec string, text string) (m.DomainModel, []m.ClarifyIssue) {
    dm, issues := Parse(text)

    base := filepath.Join(root, ".spec-workflow", "specs", sourceSpec)
    candidatesOpenAPI := []string{
        filepath.Join(base, "openapi.json"),
        filepath.Join(base, "generated", "articles_openapi.json"),
        // Fallback common locations
        filepath.Join(root, "scripts", "reports", "req-ai-codegen-009", "openapi.json"),
        filepath.Join(root, "dist", "openapi.json"),
    }
    candidatesSchema := []string{
        filepath.Join(base, "jsonschema.json"),
        filepath.Join(base, "generated", "articles_schema.json"),
        // Optional shared schema bundles
        filepath.Join(root, "dist", "jsonschema.json"),
    }

    // Helper: ensure entity exists or merge fields with snake-case dedupe and type reconciliation
    upsertEntity := func(e m.Entity) {
        // canonicalize incoming field names to snake-case for dedupe purposes
        for fi := range e.Fields {
            e.Fields[fi].Name = m.SnakeCase(e.Fields[fi].Name)
        }
        for i, ex := range dm.Entities {
            if strings.EqualFold(ex.Name, e.Name) {
                // build map keyed by snake-case field name
                existing := map[string]int{}
                for idx, f := range ex.Fields { existing[m.SnakeCase(f.Name)] = idx }
                for _, f := range e.Fields {
                    key := m.SnakeCase(f.Name)
                    if pos, ok := existing[key]; ok {
                        // reconcile types: prefer stronger types (bigint > int > string; datetime > string; text > varchar)
                        cur := ex.Fields[pos]
                        ex.Fields[pos] = reconcileField(cur, f)
                    } else {
                        ex.Fields = append(ex.Fields, f)
                    }
                }
                dm.Entities[i] = ex
                return
            }
        }
        dm.Entities = append(dm.Entities, e)
    }

    // Helper: add inferred relations based on *_id fields
    addRelationsFor := func(entityName string, fields []m.Field) {
        for _, f := range fields {
            // Canonicalize potential Chinese field aliases before relation inference
            fname := canonicalizeFieldName(f.Name)
            if strings.HasSuffix(strings.ToLower(fname), "_id") {
                base := strings.TrimSuffix(fname, "_id")
                target := toEntityName(base)
                if hasEntity(dm.Entities, target) {
                    // from target -> current entity (one-to-many)
                    if !hasRelation(dm.Relations, target, entityName, m.OneToMany) {
                        dm.Relations = append(dm.Relations, m.Relation{From: target, To: entityName, Type: m.OneToMany, FKName: strings.ToLower(fname)})
                    }
                }
            }
        }
    }

    // Load JSON Schemas first (more structured for entities)
    for _, p := range candidatesSchema {
        if body, err := os.ReadFile(p); err == nil {
            var obj map[string]interface{}
            if json.Unmarshal(body, &obj) == nil {
                // Attempt to read top-level definitions or components.schemas
                // Common patterns: {"$schema":..., "definitions": {...}} or {"schemas": {...}}
                defs := findSchemas(obj)
                for name, props := range defs {
                    fields := propsToFields(props)
                    if len(fields) == 0 { continue }
                    e := m.Entity{Name: name, Fields: ensureID(fields)}
                    upsertEntity(e)
                    addRelationsFor(e.Name, e.Fields)
                }
            }
        }
    }

    // Load OpenAPI component schemas as a fallback/merge
    for _, p := range candidatesOpenAPI {
        if body, err := os.ReadFile(p); err == nil {
            var obj map[string]interface{}
            if json.Unmarshal(body, &obj) == nil {
                defs := findOpenAPISchemas(obj)
                for name, props := range defs {
                    fields := propsToFields(props)
                    if len(fields) == 0 { continue }
                    e := m.Entity{Name: name, Fields: ensureID(fields)}
                    upsertEntity(e)
                    addRelationsFor(e.Name, e.Fields)
                }
            }
        }
    }

    // Normalize common field types regardless of source
    normalizeModel(&dm)
    normalizeEntityNames(&dm)
    // Infer generic M:N via join-table detection
    inferJoinTables(&dm)

    // Structured parsing note
    issues = append(issues, m.ClarifyIssue{ID: "structured-001", Message: fmt.Sprintf("已融合 %s 的 OpenAPI/JSON Schema，提高实体与关系解析精度", sourceSpec), Severity: m.SeverityInfo})
    return dm, issues
}

// findSchemas tries to locate schema definitions within a JSON Schema document.
func findSchemas(obj map[string]interface{}) map[string]map[string]interface{} {
    out := map[string]map[string]interface{}{}
    // Look for common keys
    keys := []string{"definitions", "schemas"}
    for _, k := range keys {
        if v, ok := obj[k]; ok {
            if m1, ok := v.(map[string]interface{}); ok {
                for name, raw := range m1 {
                    if sch, ok := raw.(map[string]interface{}); ok {
                        if props := extractProperties(sch); props != nil {
                            en := toEntityName(name)
                            if isBizEntityName(en) {
                                out[en] = props
                            }
                        }
                    }
                }
            }
        }
    }
    return out
}

// findOpenAPISchemas locates component schemas within an OpenAPI document.
func findOpenAPISchemas(obj map[string]interface{}) map[string]map[string]interface{} {
    out := map[string]map[string]interface{}{}
    if comps, ok := obj["components"].(map[string]interface{}); ok {
        if schs, ok := comps["schemas"].(map[string]interface{}); ok {
            for name, raw := range schs {
                if sch, ok := raw.(map[string]interface{}); ok {
                    if props := extractProperties(sch); props != nil {
                        en := toEntityName(name)
                        if isBizEntityName(en) {
                            out[en] = props
                        }
                    }
                }
            }
        }
    }
    return out
}

// extractProperties reads a schema object and returns its properties map.
func extractProperties(sch map[string]interface{}) map[string]interface{} {
    if props, ok := sch["properties"].(map[string]interface{}); ok {
        return props
    }
    return nil
}

// propsToFields converts schema properties to model fields with basic type mapping.
func propsToFields(props map[string]interface{}) []m.Field {
    var out []m.Field
    for pname, pr := range props {
        if p, ok := pr.(map[string]interface{}); ok {
            // Canonicalize Chinese aliases to standard snake_case English names
            pname = canonicalizeFieldName(pname)
            // type and format
            t := asString(p["type"])
            fmtv := asString(p["format"])
            // nullable
            nullable := false
            if nb, ok := p["nullable"].(bool); ok { nullable = nb }
            // custom flags
            unique := false
            index := false
            if ub, ok := p["x-unique"].(bool); ok { unique = ub }
            if ib, ok := p["x-index"].(bool); ok { index = ib }

            ft := mapType(t, fmtv)
            // heuristic: *_id should be bigint
            if strings.HasSuffix(strings.ToLower(pname), "_id") {
                ft = string(m.FieldBigInt)
            }
            // heuristic: rich text/content-like fields → TEXT
            switch strings.ToLower(pname) {
            case "definition", "content", "result", "tags", "input_schema":
                ft = string(m.FieldText)
            }
            if ft == "" {
                // Fallback: nested object/array → TEXT
                ft = string(m.FieldText)
            }
            f := m.Field{Name: pname, Type: m.FieldType(ft), Nullable: nullable, Unique: unique, Index: index}
            // length/precision from schema hints
            if ml, ok := p["maxLength"].(float64); ok && ml > 0 {
                // Only for string types
                if f.Type == m.FieldString { f.Length = int(ml) }
            }
            if prec, ok := p["x-precision"].(float64); ok && prec > 0 { f.Precision = int(prec) }
            if sc, ok := p["x-scale"].(float64); ok && sc > 0 { f.Scale = int(sc) }
            out = append(out, f)
        }
    }
    return out
}

func mapType(t string, format string) string {
    switch strings.ToLower(t) {
    case "string":
        // date-time strings → DATETIME
        if strings.EqualFold(format, "date-time") { return string(m.FieldDatetime) }
        return string(m.FieldString)
    case "integer":
        // default int, int64 → bigint
        if strings.EqualFold(format, "int64") { return string(m.FieldBigInt) }
        return string(m.FieldInt)
    case "number":
        // map to int for simplicity
        return string(m.FieldInt)
    case "boolean":
        return string(m.FieldBool)
    case "object":
        return string(m.FieldText)
    case "array":
        return string(m.FieldText)
    default:
        return ""
    }
}

func ensureID(fields []m.Field) []m.Field {
    // Ensure id exists and is BIGINT primary-like
    hasID := false
    for _, f := range fields { if strings.EqualFold(f.Name, "id") { hasID = true; break } }
    if !hasID { fields = append([]m.Field{{Name: "id", Type: m.FieldBigInt, Unique: true}}, fields...) }
    return fields
}

func toEntityName(name string) string {
    // Normalize snake/camel to PascalCase entity name
    name = strings.TrimSpace(name)
    if name == "" { return name }
    name = strings.ReplaceAll(name, "-", "_")
    // If underscores present, split; otherwise try suffix segmentation
    parts := strings.Split(name, "_")
    if len(parts) == 1 {
        low := strings.ToLower(name)
        suffixes := []string{"service", "record", "request", "response", "data", "meta"}
        for _, s := range suffixes {
            if strings.HasSuffix(low, s) && len(low) > len(s) {
                pre := low[:len(low)-len(s)]
                parts = []string{pre, s}
                break
            }
        }
    }
    for i, p := range parts {
        if p == "" { continue }
        parts[i] = strings.ToUpper(p[:1]) + strings.ToLower(p[1:])
    }
    return strings.Join(parts, "")
}

func asString(v interface{}) string {
    if s, ok := v.(string); ok { return s }
    return ""
}

func hasEntity(es []m.Entity, name string) bool {
    for _, e := range es { if strings.EqualFold(e.Name, name) { return true } }
    return false
}

func hasRelation(rs []m.Relation, from, to string, typ m.RelationType) bool {
    for _, r := range rs {
        if strings.EqualFold(r.From, from) && strings.EqualFold(r.To, to) && r.Type == typ {
            return true
        }
    }
    return false
}

// hasRelationMM checks if a ManyToMany relation exists between two entities regardless of direction.
func hasRelationMM(rs []m.Relation, a, b string) bool {
    for _, r := range rs {
        if r.Type != m.ManyToMany { continue }
        if (strings.EqualFold(r.From, a) && strings.EqualFold(r.To, b)) ||
            (strings.EqualFold(r.From, b) && strings.EqualFold(r.To, a)) {
            return true
        }
    }
    return false
}

// reconcileField selects a preferred field type and merges attributes.
func reconcileField(a, b m.Field) m.Field {
    // unify name
    a.Name = m.SnakeCase(a.Name)
    b.Name = m.SnakeCase(b.Name)
    out := a
    // choose stronger type
    rank := func(t m.FieldType) int {
        switch t {
        case m.FieldBigInt:
            return 5
        case m.FieldInt:
            return 4
        case m.FieldDatetime:
            return 4
        case m.FieldText:
            return 3
        case m.FieldString:
            return 2
        case m.FieldBool:
            return 2
        default:
            return 1
        }
    }
    if rank(b.Type) > rank(a.Type) {
        out.Type = b.Type
    }
    // nullable: if either says nullable, mark nullable
    out.Nullable = a.Nullable || b.Nullable
    // unique/index keep if any says true
    out.Unique = a.Unique || b.Unique
    out.Index = a.Index || b.Index
    if out.Default == "" { out.Default = b.Default }
    return out
}

// isBizEntityName filters out transport/request/response-only schemas.
func isBizEntityName(name string) bool {
    n := strings.ToLower(strings.TrimSpace(name))
    if n == "" { return false }
    // Exclude common API payload types
    excludeSuffixes := []string{"request", "response", "data", "listdata", "list"}
    for _, s := range excludeSuffixes {
        if strings.HasSuffix(n, s) { return false }
    }
    // Exclude known non-domain entities coming from article workflow samples
    excludeExact := map[string]bool{"article": true, "pagemeta": true}
    if excludeExact[n] { return false }
    // Allow by default
    return true
}

// normalizeModel enforces common field type conventions for the domain model.
func normalizeModel(dm *m.DomainModel) {
    for ei, e := range dm.Entities {
        for fi, f := range e.Fields {
            // Canonicalize Chinese aliases to standard names first
            canon := canonicalizeFieldName(f.Name)
            dm.Entities[ei].Fields[fi].Name = canon
            n := strings.ToLower(m.SnakeCase(canon))
            switch {
            case strings.HasSuffix(n, "_id"):
                dm.Entities[ei].Fields[fi].Type = m.FieldBigInt
            case n == "created_at" || n == "updated_at" || n == "start_at" || n == "end_at" || n == "expires_at":
                dm.Entities[ei].Fields[fi].Type = m.FieldDatetime
            case n == "definition" || n == "content" || n == "result" || n == "tags" || n == "input_schema":
                dm.Entities[ei].Fields[fi].Type = m.FieldText
            }
        }
    }
}

// normalizeEntityNames forces canonical PascalCase entity names (e.g., FortuneService)
// so that table names become snake_case with underscores (fortune_service).
func normalizeEntityNames(dm *m.DomainModel) {
    for i := range dm.Entities {
        dm.Entities[i].Name = toEntityName(dm.Entities[i].Name)
    }
}

// inferJoinTables scans entities for potential join tables that contain two or more
// *_id fields referencing existing entities, and adds ManyToMany relations.
func inferJoinTables(dm *m.DomainModel) {
    for _, e := range dm.Entities {
        // Collect candidate targets from *_id fields
        targets := []string{}
        for _, f := range e.Fields {
            fname := canonicalizeFieldName(f.Name)
            n := strings.ToLower(m.SnakeCase(fname))
            if strings.HasSuffix(n, "_id") {
                base := strings.TrimSuffix(n, "_id")
                target := toEntityName(base)
                targets = append(targets, target)
            }
        }
        if len(targets) < 2 { continue }
        // For all pairs, add ManyToMany if both entities exist
        through := m.SnakeCase(e.Name)
        for i := 0; i < len(targets); i++ {
            for j := i + 1; j < len(targets); j++ {
                a := targets[i]
                b := targets[j]
                if !hasEntity(dm.Entities, a) || !hasEntity(dm.Entities, b) { continue }
                if hasRelationMM(dm.Relations, a, b) { continue }
                dm.Relations = append(dm.Relations, m.Relation{From: a, To: b, Type: m.ManyToMany, Through: through})
            }
        }
    }
}

// canonicalizeFieldName maps Chinese field aliases to canonical snake_case English names
// to ensure consistent type normalization and relation inference.
func canonicalizeFieldName(name string) string {
    n := strings.TrimSpace(name)
    if n == "" { return n }
    low := strings.ToLower(n)
    // Common Chinese aliases → canonical names
    aliases := map[string]string{
        "定义": "definition",
        "内容": "content",
        "结果": "result",
        "标签": "tags",
        "输入架构": "input_schema",
        "输入模式": "input_schema",
        "创建时间": "created_at",
        "更新时间": "updated_at",
        // Time-related
        "开始时间": "start_at",
        "结束时间": "end_at",
        "过期时间": "expires_at",
        "到期时间": "expires_at",
        "粉丝id": "fan_id",
        "服务id": "service_id",
        "会话id": "conversation_id",
        "主题id": "topic_id",
        "锚点id": "anchor_id",
        "编号": "id",
        "主键": "id",
        // Common profile/metadata
        "昵称": "name",
        "名称": "name",
        "名字": "name",
        "等级": "level",
        "性别": "gender",
        "手机号": "phone",
        "手机": "phone",
        "电话": "phone",
        "电话号码": "phone",
        "邮箱": "email",
        "电子邮件": "email",
        "状态": "status",
        "类型": "type",
        "类别": "type",
        "分类": "type",
        "编码": "code",
        "标识": "code",
        "代号": "code",
        "代码": "code",
        "封面": "cover_url",
        "封面图": "cover_url",
        "封面url": "cover_url",
        "封面URL": "cover_url",
        "标题": "title",
        "描述": "description",
    }
    if v, ok := aliases[low]; ok {
        return v
    }
    // If already canonical or mixed-case ID
    if low == "id" { return "id" }
    return name
}