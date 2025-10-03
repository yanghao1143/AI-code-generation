package specgen

import (
    "encoding/json"
    "fmt"
    "os"
    "path/filepath"
    "strings"

    m "xingzuo/internal/model"
)

// GenerateRequirements renders requirements.md content with dynamic spec name.
func GenerateRequirements(dm m.DomainModel, specName string) string {
    if strings.TrimSpace(specName) == "" { specName = "xingzuo" }
    var b strings.Builder
    b.WriteString(fmt.Sprintf("# %s 需求规范\n\n", specName))
    b.WriteString("本规范由自然语言解析自动生成，反映当前领域模型的核心需求与对象。\n\n")
    b.WriteString("## 领域对象\n")
    for _, e := range dm.Entities {
        b.WriteString(fmt.Sprintf("- %s：包含 %d 个字段\n", e.Name, len(e.Fields)))
    }
    b.WriteString("\n## 关系\n")
    for _, r := range dm.Relations {
        b.WriteString(fmt.Sprintf("- %s -> %s (%s)\n", r.From, r.To, r.Type))
    }
    b.WriteString("\n## 用户故事（生成版）\n")
    b.WriteString("- 作为主播，我希望能够与粉丝进行对话，并查看历史记录，以提升互动质量。\n")
    b.WriteString("- 作为运营，我希望为粉丝添加标签并按标签筛选，以进行分层运营。\n")
    b.WriteString("- 作为用户，我希望提交命理测算请求并查看测算结果，以获得个性化建议。\n")
    b.WriteString("- 作为内容策划，我希望管理话题与脚本，以提升直播内容质量。\n")
    return b.String()
}

// GenerateDesign renders design.md content with dynamic spec name.
func GenerateDesign(dm m.DomainModel, specName string) string {
    if strings.TrimSpace(specName) == "" { specName = "xingzuo" }
    var b strings.Builder
    b.WriteString(fmt.Sprintf("# %s 技术设计\n\n", specName))
    b.WriteString("本设计由 NLP 解析生成，描述实体、字段、关系与数据库约束的初步方案。\n\n")
    b.WriteString("## 实体与字段\n")
    for _, e := range dm.Entities {
        b.WriteString(fmt.Sprintf("### %s\n", e.Name))
        for _, f := range e.Fields {
            flags := []string{}
            if f.Nullable { flags = append(flags, "NULL") } else { flags = append(flags, "NOT NULL") }
            if f.Unique { flags = append(flags, "UNIQUE") }
            if f.Index { flags = append(flags, "INDEX") }
            b.WriteString(fmt.Sprintf("- %s: %s (%s)\n", f.Name, f.Type, strings.Join(flags, ", ")))
        }
        b.WriteString("\n")
    }
    b.WriteString("## 关系\n")
    for _, r := range dm.Relations {
        if r.Type == m.ManyToMany && r.Through != "" {
            b.WriteString(fmt.Sprintf("- %s <-> %s 通过联结表 %s\n", r.From, r.To, r.Through))
        } else {
            b.WriteString(fmt.Sprintf("- %s -> %s (%s)\n", r.From, r.To, r.Type))
        }
    }
    b.WriteString("\n## 澄清问题\n")
    b.WriteString("实现前建议确认以下事项：\n")
    b.WriteString("- 隐私与合规要求（生日、性别等敏感字段）\n")
    b.WriteString("- 索引策略（fan_id/anchor_id 组合索引）\n")
    b.WriteString("- 工作流定义是否采用 JSON Schema 与版本管理\n")
    b.WriteString("- 脚本内容的审计与版本区分\n")
    return b.String()
}

// GenerateTasks renders tasks.md content with dynamic spec name.
func GenerateTasks(dm m.DomainModel, specName string) string {
    if strings.TrimSpace(specName) == "" { specName = "xingzuo" }
    var b strings.Builder
    b.WriteString(fmt.Sprintf("# %s 实施任务\n\n", specName))
    b.WriteString("以下任务由自动化生成，覆盖文档与数据库落地：\n\n")
    b.WriteString("- [ ] 生成并审阅需求/设计/任务文档\n")
    b.WriteString("- [ ] 基于实体与关系生成 MySQL DDL 并执行创建\n")
    b.WriteString("- [ ] 为对话与测算记录建立必要索引\n")
    b.WriteString("- [ ] 为工作流定义与脚本内容规划版本化与审计\n")
    b.WriteString("- [ ] 持续完善 NLP 规则以提升解析准确率\n")
    return b.String()
}

// GenerateOpenAPI renders a minimal OpenAPI 3.0 document for the given domain model.
// It provides CRUD-style paths for each entity and component schemas inferred from field types.
func GenerateOpenAPI(dm m.DomainModel, specName string) string {
    if strings.TrimSpace(specName) == "" { specName = "xingzuo" }

    // Helper: map domain field type to OpenAPI type/format
    type prop struct { Type, Format string }
    mapType := func(ft m.FieldType) prop {
        switch ft {
        case m.FieldString, m.FieldText:
            return prop{Type: "string"}
        case m.FieldInt:
            return prop{Type: "integer"}
        case m.FieldBigInt:
            return prop{Type: "integer", Format: "int64"}
        case m.FieldDatetime:
            return prop{Type: "string", Format: "date-time"}
        case m.FieldBool:
            return prop{Type: "boolean"}
        case m.FieldDecimal:
            return prop{Type: "number", Format: "double"}
        default:
            return prop{Type: "string"}
        }
    }

    // Build structures
    doc := map[string]interface{}{
        "openapi": "3.0.0",
        "info": map[string]interface{}{
            "title": fmt.Sprintf("%s Domain API", specName),
            "version": "1.0.0",
        },
        "paths":   map[string]interface{}{},
        "components": map[string]interface{}{
            "schemas": map[string]interface{}{},
        },
    }

    paths := doc["paths"].(map[string]interface{})
    schemas := doc["components"].(map[string]interface{})["schemas"].(map[string]interface{})

    // Plural helper consistent with speccheck
    plural := func(s string) string {
        if strings.HasSuffix(s, "s") { return s }
        return s + "s"
    }

    // Index relations for FK annotations and schema-level relation overview
    type relInfo struct{ From, To, Type, FK, Through, OnDelete, OnUpdate string }
    var rels []relInfo
    for _, r := range dm.Relations {
        fk := strings.TrimSpace(r.FKName)
        if fk != "" { fk = strings.ToLower(m.SnakeCase(fk)) }
        rels = append(rels, relInfo{From: r.From, To: r.To, Type: string(r.Type), FK: fk, Through: strings.TrimSpace(r.Through), OnDelete: strings.TrimSpace(r.OnDelete), OnUpdate: strings.TrimSpace(r.OnUpdate)})
    }

    // Create schemas and CRUD paths per entity
    for _, e := range dm.Entities {
        // Schema
        props := map[string]map[string]interface{}{}
        required := []string{}
        for _, f := range e.Fields {
            p := mapType(f.Type)
            mp := map[string]interface{}{"type": p.Type}
            if strings.TrimSpace(p.Format) != "" { mp["format"] = p.Format }
            // add string maxLength when available
            if f.Type == m.FieldString && f.Length > 0 {
                mp["maxLength"] = f.Length
            }
            // add decimal precision/scale extensions for documentation
            if f.Type == m.FieldDecimal {
                if f.Precision > 0 { mp["x-precision"] = f.Precision }
                if f.Scale > 0 { mp["x-scale"] = f.Scale }
            }
            props[m.SnakeCase(f.Name)] = mp
            if !f.Nullable { required = append(required, m.SnakeCase(f.Name)) }
        }
        // annotate foreign key fields with description
        fkDesc := map[string]string{}
        for _, r := range rels {
            if strings.EqualFold(r.To, e.Name) && strings.TrimSpace(r.FK) != "" {
                fkDesc[r.FK] = fmt.Sprintf("foreign key to %s.id (%s)", r.From, r.Type)
            }
        }
        for k := range props {
            if d, ok := fkDesc[k]; ok {
                props[k]["description"] = d
            }
        }

        // build schema object with optional required and x-relations extension
        schema := map[string]interface{}{
            "type":       "object",
            "properties": props,
        }
        if len(required) > 0 { schema["required"] = required }
        var xrels []map[string]string
        for _, r := range rels {
            if strings.EqualFold(r.From, e.Name) || strings.EqualFold(r.To, e.Name) {
                xr := map[string]string{"from": r.From, "to": r.To, "type": r.Type}
                if strings.TrimSpace(r.FK) != "" { xr["fk"] = r.FK }
                if strings.TrimSpace(r.Through) != "" { xr["through"] = r.Through }
                if strings.TrimSpace(r.OnDelete) != "" { xr["onDelete"] = r.OnDelete }
                if strings.TrimSpace(r.OnUpdate) != "" { xr["onUpdate"] = r.OnUpdate }
                xrels = append(xrels, xr)
            }
        }
        if len(xrels) > 0 { schema["x-relations"] = xrels }
        schemas[e.Name] = schema

        // Paths
        // Use snake_case plural resource naming to align with speccheck expectations
        res := plural(strings.ToLower(m.SnakeCase(e.Name)))
        base := fmt.Sprintf("/api/v1/%s", res)
        idp := base + "/{id}"
        // GET list and POST create
        paths[base] = map[string]interface{}{
            "get": map[string]interface{}{
                "summary": fmt.Sprintf("List %ss", e.Name),
                "responses": map[string]interface{}{
                    "200": map[string]interface{}{
                        "description": "OK",
                        "content": map[string]interface{}{
                            "application/json": map[string]interface{}{
                                "schema": map[string]interface{}{
                                    "type":  "array",
                                    "items": map[string]interface{}{"$ref": fmt.Sprintf("#/components/schemas/%s", e.Name)},
                                },
                            },
                        },
                    },
                },
            },
            "post": map[string]interface{}{
                "summary": fmt.Sprintf("Create %s", e.Name),
                "requestBody": map[string]interface{}{
                    "required": true,
                    "content": map[string]interface{}{
                        "application/json": map[string]interface{}{
                            "schema": map[string]interface{}{"$ref": fmt.Sprintf("#/components/schemas/%s", e.Name)},
                        },
                    },
                },
                "responses": map[string]interface{}{
                    "201": map[string]interface{}{
                        "description": "Created",
                        "content": map[string]interface{}{
                            "application/json": map[string]interface{}{
                                "schema": map[string]interface{}{"$ref": fmt.Sprintf("#/components/schemas/%s", e.Name)},
                            },
                        },
                    },
                },
            },
        }
        // GET one, PUT update, DELETE
        paths[idp] = map[string]interface{}{
            "get": map[string]interface{}{
                "summary": fmt.Sprintf("Get %s", e.Name),
                "responses": map[string]interface{}{
                    "200": map[string]interface{}{
                        "description": "OK",
                        "content": map[string]interface{}{
                            "application/json": map[string]interface{}{
                                "schema": map[string]interface{}{"$ref": fmt.Sprintf("#/components/schemas/%s", e.Name)},
                            },
                        },
                    },
                },
            },
            "put": map[string]interface{}{
                "summary": fmt.Sprintf("Update %s", e.Name),
                "requestBody": map[string]interface{}{
                    "required": true,
                    "content": map[string]interface{}{
                        "application/json": map[string]interface{}{
                            "schema": map[string]interface{}{"$ref": fmt.Sprintf("#/components/schemas/%s", e.Name)},
                        },
                    },
                },
                "responses": map[string]interface{}{
                    "200": map[string]interface{}{
                        "description": "OK",
                        "content": map[string]interface{}{
                            "application/json": map[string]interface{}{
                                "schema": map[string]interface{}{"$ref": fmt.Sprintf("#/components/schemas/%s", e.Name)},
                            },
                        },
                    },
                },
            },
            "delete": map[string]interface{}{
                "summary": fmt.Sprintf("Delete %s", e.Name),
                "responses": map[string]interface{}{
                    "204": map[string]interface{}{"description": "No Content"},
                },
            },
        }
    }

    b, _ := json.MarshalIndent(doc, "", "  ")
    return string(b)
}

// WriteSpecFiles writes requirements.md, design.md, tasks.md into .spec-workflow/specs/{specName}.
func WriteSpecFiles(dm m.DomainModel, root string, specName string) error {
    if strings.TrimSpace(specName) == "" { specName = "xingzuo" }
    specDir := filepath.Join(root, ".spec-workflow", "specs", specName)
    // Use the last path segment as the spec title for generated documents
    specTitle := filepath.Base(specName)
    if err := os.MkdirAll(specDir, 0o755); err != nil {
        return err
    }
    files := map[string]string{
        filepath.Join(specDir, "requirements.md"): GenerateRequirements(dm, specTitle),
        filepath.Join(specDir, "design.md"):       GenerateDesign(dm, specTitle),
        filepath.Join(specDir, "tasks.md"):        GenerateTasks(dm, specTitle),
        filepath.Join(specDir, "openapi.generated.json"): GenerateOpenAPI(dm, specTitle),
    }
    for p, c := range files {
        if err := os.WriteFile(p, []byte(c), 0o644); err != nil {
            return err
        }
    }
    return nil
}