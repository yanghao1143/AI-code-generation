package speccheck

import (
    "encoding/json"
    "fmt"
    "os"
    "path/filepath"
    "regexp"
    "strings"
    "time"

    "xingzuo/internal/model"
)

// Report summarizes consistency findings between DomainModel and DDL tables
type Report struct {
    GeneratedAt     time.Time                     `json:"generatedAt"`
    SourceDDL       string                        `json:"sourceDDL"`
    Summary         string                        `json:"summary"`
    MissingTables   []string                      `json:"missingTables"`
    ExtraTables     []string                      `json:"extraTables"`
    MissingColumns  map[string][]string           `json:"missingColumns"` // table -> columns missing
    TypeMismatches  map[string]map[string]string  `json:"typeMismatches"` // table -> column -> {expected->actual}
    OpenAPI         *OpenAPIReport                `json:"openapi,omitempty"`
}

// Table is a simplified view of a parsed CREATE TABLE
type Table struct {
    Name    string
    Columns map[string]string // column -> type (normalized)
}

// ParseDDL extracts CREATE TABLE definitions from a SQL file.
// This is a pragmatic parser handling typical MySQL DDL produced by internal/ddl/generator.go.
func ParseDDL(path string) (map[string]Table, error) {
    b, err := os.ReadFile(path)
    if err != nil {
        return nil, fmt.Errorf("read ddl: %w", err)
    }
    text := string(b)
    // Remove inline comments starting with --
    lines := strings.Split(text, "\n")
    var sb strings.Builder
    for _, ln := range lines {
        t := strings.TrimSpace(ln)
        if strings.HasPrefix(t, "--") {
            continue
        }
        sb.WriteString(ln)
        sb.WriteString("\n")
    }
    cleaned := sb.String()

    // Regex to match CREATE TABLE blocks
    // Example: CREATE TABLE IF NOT EXISTS `fan` ( ... ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    tblRe := regexp.MustCompile(`(?is)CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?` +
        "`" + `([a-zA-Z0-9_]+)` + "`" + `\s*\((.*?)\)\s*ENGINE=`)
    colRe := regexp.MustCompile("^`([a-zA-Z0-9_]+)`\\s+([A-Z0-9()]+)")

    tables := map[string]Table{}
    for _, m := range tblRe.FindAllStringSubmatch(cleaned, -1) {
        name := m[1]
        body := m[2]
        cols := map[string]string{}
        // Split body by comma on newlines
        parts := strings.Split(body, ",\n")
        for _, p := range parts {
            line := strings.TrimSpace(p)
            if strings.HasPrefix(line, "PRIMARY KEY") || strings.HasPrefix(line, "UNIQUE") || strings.HasPrefix(line, "KEY") || strings.HasPrefix(line, "CONSTRAINT") {
                continue // skip constraints for now
            }
            if mm := colRe.FindStringSubmatch(line); len(mm) == 3 {
                col := strings.ToLower(mm[1])
                typ := strings.ToUpper(mm[2])
                cols[col] = typ
            }
        }
        tables[name] = Table{Name: name, Columns: cols}
    }
    return tables, nil
}

// CompareDomainWithDDL compares DomainModel expected tables/columns with DDL tables
func CompareDomainWithDDL(dm model.DomainModel, ddlTables map[string]Table) Report {
    rep := Report{
        GeneratedAt:    time.Now(),
        MissingTables:  []string{},
        ExtraTables:    []string{},
        MissingColumns: map[string][]string{},
        TypeMismatches: map[string]map[string]string{},
    }

    // Pre-compute many-to-many join tables to ignore in extraTables
    joinTables := computeJoinTables(dm)

    // Expected tables from DomainModel (normalize entity name to snake_case, lower)
    expected := map[string]map[string]string{}
    for _, e := range dm.Entities {
        cols := map[string]string{}
        for _, f := range e.Fields {
            cols[model.SnakeCase(f.Name)] = model.MySQLType(f.Type)
        }
        tname := strings.ToLower(model.SnakeCase(e.Name))
        expected[tname] = cols
    }

    // Missing tables
    for t := range expected {
        if _, ok := ddlTables[t]; !ok {
            rep.MissingTables = append(rep.MissingTables, t)
        }
    }
    // Extra tables
    for t := range ddlTables {
        if _, ok := expected[t]; !ok {
            // Ignore recognized join tables
            if joinTables[strings.ToLower(t)] {
                continue
            }
            rep.ExtraTables = append(rep.ExtraTables, t)
        }
    }

    // Columns and type checks
    for t, expCols := range expected {
        ddlTbl, ok := ddlTables[t]
        if !ok {
            continue
        }
        for col, expType := range expCols {
            ddlType, okc := ddlTbl.Columns[col]
            if !okc {
                rep.MissingColumns[t] = append(rep.MissingColumns[t], col)
                continue
            }
            // Normalize types: e.g., VARCHAR(255) vs VARCHAR(255)
            if !sameType(expType, ddlType) {
                if _, ok := rep.TypeMismatches[t]; !ok {
                    rep.TypeMismatches[t] = map[string]string{}
                }
                rep.TypeMismatches[t][col] = fmt.Sprintf("expected=%s actual=%s", expType, ddlType)
            }
        }
    }

    rep.Summary = fmt.Sprintf("missingTables=%d extraTables=%d missingColumnsTables=%d typeMismatchTables=%d",
        len(rep.MissingTables), len(rep.ExtraTables), len(rep.MissingColumns), len(rep.TypeMismatches))
    return rep
}

func sameType(a, b string) bool {
    // Simple normalization: trim spaces, uppercase
    aa := strings.ToUpper(strings.TrimSpace(a))
    bb := strings.ToUpper(strings.TrimSpace(b))
    return aa == bb
}

// computeJoinTables returns a set of expected many-to-many join table names (snake_case, lower)
func computeJoinTables(dm model.DomainModel) map[string]bool {
    set := map[string]bool{}
    for _, r := range dm.Relations {
        if r.Type != model.ManyToMany {
            continue
        }
        from := strings.ToLower(model.SnakeCase(r.From))
        to := strings.ToLower(model.SnakeCase(r.To))
        join := strings.TrimSpace(r.Through)
        var j string
        if join == "" {
            j = strings.ToLower(model.SnakeCase(from + "_" + to))
        } else {
            j = strings.ToLower(model.SnakeCase(join))
        }
        set[j] = true
        // Be tolerant to reversed naming conventions
        set[strings.ToLower(model.SnakeCase(to+"_"+from))] = true
    }
    return set
}

// WriteReport writes JSON report into scripts/reports/consistency/ and returns path
func WriteReport(root string, rep Report) (string, error) {
    dir := filepath.Join(root, "scripts", "reports", "consistency")
    if err := os.MkdirAll(dir, 0o755); err != nil {
        return "", fmt.Errorf("mkdir consistency reports: %w", err)
    }
    ts := time.Now().Format("20060102-150405")
    path := filepath.Join(dir, fmt.Sprintf("speccheck-%s.json", ts))
    data, err := json.MarshalIndent(rep, "", "  ")
    if err != nil {
        return "", fmt.Errorf("marshal report: %w", err)
    }
    if err := os.WriteFile(path, data, 0o644); err != nil {
        return "", fmt.Errorf("write report: %w", err)
    }
    return path, nil
}

// ===== OpenAPI consistency =====

// OpenAPIReport summarizes consistency between DomainModel and OpenAPI contract
type OpenAPIReport struct {
    Source                 string                           `json:"source"`
    MissingResources       []string                         `json:"missingResources"`        // entity resources not present in paths
    ExtraResources         []string                         `json:"extraResources"`          // resources present in paths but not in DomainModel
    SchemaMissingEntities  []string                         `json:"schemaMissingEntities"`   // entity schema not found
    SchemaMissingFields    map[string][]string              `json:"schemaMissingFields"`     // entity -> fields missing
    SchemaTypeMismatches   map[string]map[string]string     `json:"schemaTypeMismatches"`   // entity -> field -> detail
    Summary                string                           `json:"summary"`
}

// OpenAPIData holds parsed parts we care about
type OpenAPIData struct {
    Paths   map[string][]string               // path -> methods (lowercase)
    Schemas map[string]map[string]PropType    // schema name -> properties: name -> PropType
}

type PropType struct {
    Type   string
    Format string
}

// ParseOpenAPI reads a subset of OpenAPI JSON we need
func ParseOpenAPI(path string) (OpenAPIData, error) {
    var out OpenAPIData
    b, err := os.ReadFile(path)
    if err != nil {
        return out, fmt.Errorf("read openapi: %w", err)
    }
    var root map[string]any
    if err := json.Unmarshal(b, &root); err != nil {
        return out, fmt.Errorf("unmarshal openapi: %w", err)
    }
    // Paths
    out.Paths = map[string][]string{}
    if p, ok := root["paths"].(map[string]any); ok {
        for pathStr, v := range p {
            methods := []string{}
            if m, ok := v.(map[string]any); ok {
                for mk := range m {
                    lk := strings.ToLower(mk)
                    switch lk {
                    case "get", "post", "put", "delete", "patch":
                        methods = append(methods, lk)
                    }
                }
            }
            out.Paths[pathStr] = methods
        }
    }
    // Schemas
    out.Schemas = map[string]map[string]PropType{}
    comps, cok := root["components"].(map[string]any)
    if cok {
        if sch, ok := comps["schemas"].(map[string]any); ok {
            for name, raw := range sch {
                props := map[string]PropType{}
                if obj, ok := raw.(map[string]any); ok {
                    if pr, ok := obj["properties"].(map[string]any); ok {
                        for pname, pv := range pr {
                            if pvo, ok := pv.(map[string]any); ok {
                                typ := toString(pvo["type"])
                                format := toString(pvo["format"])
                                // If array of items, record as array<type>
                                if typ == "array" {
                                    if items, ok := pvo["items"].(map[string]any); ok {
                                        it := toString(items["type"])
                                        if it == "" && items["$ref"] != nil {
                                            it = "ref"
                                        }
                                        typ = "array<" + it + ">"
                                    }
                                }
                                props[pname] = PropType{Type: typ, Format: format}
                            }
                        }
                    }
                }
                out.Schemas[name] = props
            }
        }
    }
    return out, nil
}

func toString(v any) string {
    if v == nil { return "" }
    if s, ok := v.(string); ok { return s }
    return fmt.Sprintf("%v", v)
}

// CompareOpenAPIWithDomain builds OpenAPI consistency report
func CompareOpenAPIWithDomain(dm model.DomainModel, oa OpenAPIData) OpenAPIReport {
    rep := OpenAPIReport{
        MissingResources:      []string{},
        ExtraResources:        []string{},
        SchemaMissingEntities: []string{},
        SchemaMissingFields:   map[string][]string{},
        SchemaTypeMismatches:  map[string]map[string]string{},
    }

    // Ignore list (platform/system resources) from env with sensible defaults
    ignore := getIgnoreResources()

    // Expected resource names from DomainModel: snake_case plural
    expectedRes := map[string]bool{}
    for _, e := range dm.Entities {
        res := plural(strings.ToLower(model.SnakeCase(e.Name)))
        expectedRes[res] = true
    }

    // Collect resources from paths
    seenRes := map[string]bool{}
    for p := range oa.Paths {
        r := resourceFromPath(p)
        if r == "" { continue }
        // canonicalize via Terms synonyms
        r = canonicalResource(r, dm.Terms)
        if ignore[r] { continue }
        if r != "" {
            seenRes[r] = true
        }
    }

    // Fallback/complement: if a schema for the entity exists, treat its resource as present.
    // This reduces false positives when paths are incomplete but component schemas are defined.
    for _, e := range dm.Entities {
        if oa.Schemas[e.Name] != nil {
            r := plural(strings.ToLower(model.SnakeCase(e.Name)))
            if !ignore[r] {
                seenRes[r] = true
            }
        }
    }

    // Missing and extra resources
    for r := range expectedRes {
        if !seenRes[r] {
            rep.MissingResources = append(rep.MissingResources, r)
        }
    }
    for r := range seenRes {
        if !expectedRes[r] {
            rep.ExtraResources = append(rep.ExtraResources, r)
        }
    }

    // Schemas check: expect schema with entity name
    for _, e := range dm.Entities {
        schema := oa.Schemas[e.Name]
        if schema == nil {
            rep.SchemaMissingEntities = append(rep.SchemaMissingEntities, e.Name)
            continue
        }
        // field presence and type compatibility
        for _, f := range e.Fields {
            snake := strings.ToLower(model.SnakeCase(f.Name))
            camel := toCamel(snake)
            pt, okSnake := schema[snake]
            if !okSnake {
                pt2, okCamel := schema[camel]
                if !okCamel {
                    rep.SchemaMissingFields[e.Name] = append(rep.SchemaMissingFields[e.Name], f.Name)
                    continue
                }
                pt = pt2
            }
            // type compatibility
            if !jsonTypeCompatible(f.Type, pt) {
                if _, ok := rep.SchemaTypeMismatches[e.Name]; !ok {
                    rep.SchemaTypeMismatches[e.Name] = map[string]string{}
                }
                rep.SchemaTypeMismatches[e.Name][f.Name] = fmt.Sprintf("expected=%s actual=%s(%s)", f.Type, pt.Type, pt.Format)
            }
        }
    }

    rep.Summary = fmt.Sprintf("missingResources=%d extraResources=%d schemaMissing=%d fieldIssues=%d",
        len(rep.MissingResources), len(rep.ExtraResources), len(rep.SchemaMissingEntities), len(rep.SchemaMissingFields))
    return rep
}

func plural(s string) string {
    if strings.HasSuffix(s, "s") { return s }
    return s + "s"
}

func resourceFromPath(p string) string {
    // Expect /api/v1/<resource> or /<resource>
    p = strings.TrimSpace(p)
    if p == "" { return "" }
    parts := strings.Split(strings.TrimPrefix(p, "/"), "/")
    if len(parts) == 0 { return "" }
    if len(parts) >= 2 && parts[0] == "api" && parts[1] == "v1" {
        if len(parts) >= 3 { return parts[2] }
        return ""
    }
    return parts[0]
}

// canonicalResource maps a resource name to a canonical form using Terms
// Terms map may contain synonyms -> canonical term. We then snake_case + pluralize it.
func canonicalResource(res string, terms map[string]string) string {
    r := strings.ToLower(strings.TrimSpace(res))
    if r == "" { return r }
    // try direct match
    if c, ok := terms[r]; ok {
        return plural(strings.ToLower(model.SnakeCase(c)))
    }
    // try singular (dropping trailing 's')
    if strings.HasSuffix(r, "s") {
        s := strings.TrimSuffix(r, "s")
        if c, ok := terms[s]; ok {
            return plural(strings.ToLower(model.SnakeCase(c)))
        }
    }
    // default normalize
    return plural(strings.ToLower(model.SnakeCase(r)))
}

// getIgnoreResources reads XZ_SPECCHECK_IGNORE_RESOURCES from env and merges defaults
func getIgnoreResources() map[string]bool {
    set := map[string]bool{}
    defaults := []string{"billing", "ai", "observe", "llm", "registry", "api", "auth", "article"}
    for _, d := range defaults {
        set[d] = true
        set[plural(d)] = true
    }
    if val := strings.TrimSpace(os.Getenv("XZ_SPECCHECK_IGNORE_RESOURCES")); val != "" {
        parts := strings.Split(val, ",")
        for _, p := range parts {
            s := strings.ToLower(strings.TrimSpace(p))
            if s != "" {
                set[s] = true
                set[plural(s)] = true
            }
        }
    }
    return set
}

func toCamel(s string) string {
    // snake_case -> camelCase
    if s == "" { return s }
    parts := strings.Split(s, "_")
    if len(parts) == 0 { return s }
    out := parts[0]
    for i := 1; i < len(parts); i++ {
        if parts[i] == "" { continue }
        out += strings.ToUpper(parts[i][:1]) + parts[i][1:]
    }
    return out
}

func jsonTypeCompatible(ft model.FieldType, pt PropType) bool {
    t := strings.ToLower(pt.Type)
    switch ft {
    case model.FieldString, model.FieldText:
        return t == "string"
    case model.FieldInt, model.FieldBigInt:
        return t == "integer" || t == "string" // allow string for ids/serialized numbers
    case model.FieldBool:
        return t == "boolean"
    case model.FieldDatetime:
        // prefer string date-time, but accept plain string
        if t != "string" { return false }
        if pt.Format == "" { return true }
        return strings.EqualFold(pt.Format, "date-time")
    default:
        return true
    }
}