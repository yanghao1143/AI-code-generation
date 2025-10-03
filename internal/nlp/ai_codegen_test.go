package nlp

import (
    "testing"
    m "xingzuo/internal/model"
)

// Test canonicalizeFieldName for Chinese aliases → canonical snake_case English
func TestCanonicalizeFieldName_ChineseAliases(t *testing.T) {
    cases := map[string]string{
        "定义":        "definition",
        "内容":        "content",
        "结果":        "result",
        "标签":        "tags",
        "输入架构":    "input_schema",
        "输入模式":    "input_schema",
        "创建时间":    "created_at",
        "更新时间":    "updated_at",
        "开始时间":    "start_at",
        "结束时间":    "end_at",
        "过期时间":    "expires_at",
        "到期时间":    "expires_at",
        "粉丝id":      "fan_id",
        "粉丝ID":      "fan_id", // mixed case ID should still map
        "服务id":      "service_id",
        "会话id":      "conversation_id",
        "主题id":      "topic_id",
        "锚点id":      "anchor_id",
        "编号":        "id",
        "主键":        "id",
        // common profile/metadata
        "昵称":        "name",
        "名称":        "name",
        "名字":        "name",
        "等级":        "level",
        "性别":        "gender",
        "手机号":      "phone",
        "手机":        "phone",
        "电话":        "phone",
        "电话号码":    "phone",
        "邮箱":        "email",
        "电子邮件":    "email",
        "状态":        "status",
        "类型":        "type",
        "类别":        "type",
        "分类":        "type",
        "编码":        "code",
        "标识":        "code",
        "代号":        "code",
        "代码":        "code",
        "封面":        "cover_url",
        "封面图":      "cover_url",
        "封面url":     "cover_url",
        "封面URL":     "cover_url",
        "标题":        "title",
        "描述":        "description",
        // unknown terms should remain unchanged
        "未识别字段":  "未识别字段",
    }
    for in, want := range cases {
        got := canonicalizeFieldName(in)
        if got != want {
            t.Fatalf("canonicalizeFieldName(%q) = %q, want %q", in, got, want)
        }
    }
}

// Test normalizeModel applies type rules for *_id, created_at/updated_at, and content-like fields
func TestNormalizeModel_FieldTypes(t *testing.T) {
    dm := m.DomainModel{
        Entities: []m.Entity{
            {
                Name: "X",
                Fields: []m.Field{
                    {Name: "definition", Type: m.FieldString},
                    {Name: "content", Type: m.FieldString},
                    {Name: "result", Type: m.FieldString},
                    {Name: "tags", Type: m.FieldString},
                    {Name: "input_schema", Type: m.FieldString},
                    {Name: "created_at", Type: m.FieldString},
                    {Name: "updated_at", Type: m.FieldString},
                    {Name: "start_at", Type: m.FieldString},
                    {Name: "end_at", Type: m.FieldString},
                    {Name: "expires_at", Type: m.FieldString},
                    {Name: "fan_id", Type: m.FieldString},
                    {Name: "service_id", Type: m.FieldString},
                },
            },
        },
    }
    normalizeModel(&dm)

    // Build quick lookup for assertions
    types := map[string]m.FieldType{}
    for _, f := range dm.Entities[0].Fields {
        types[m.SnakeCase(f.Name)] = f.Type
    }

    // content-like → TEXT
    for _, n := range []string{"definition", "content", "result", "tags", "input_schema"} {
        if types[n] != m.FieldText {
            t.Fatalf("field %s type = %s, want %s", n, types[n], m.FieldText)
        }
    }
    // timestamps → DATETIME
    if types["created_at"] != m.FieldDatetime {
        t.Fatalf("created_at type = %s, want %s", types["created_at"], m.FieldDatetime)
    }
    if types["updated_at"] != m.FieldDatetime {
        t.Fatalf("updated_at type = %s, want %s", types["updated_at"], m.FieldDatetime)
    }
    if types["start_at"] != m.FieldDatetime {
        t.Fatalf("start_at type = %s, want %s", types["start_at"], m.FieldDatetime)
    }
    if types["end_at"] != m.FieldDatetime {
        t.Fatalf("end_at type = %s, want %s", types["end_at"], m.FieldDatetime)
    }
    if types["expires_at"] != m.FieldDatetime {
        t.Fatalf("expires_at type = %s, want %s", types["expires_at"], m.FieldDatetime)
    }
    // *_id → BIGINT
    if types["fan_id"] != m.FieldBigInt {
        t.Fatalf("fan_id type = %s, want %s", types["fan_id"], m.FieldBigInt)
    }
    if types["service_id"] != m.FieldBigInt {
        t.Fatalf("service_id type = %s, want %s", types["service_id"], m.FieldBigInt)
    }
}

// Test propsToFields basic heuristics: *_id → BIGINT, date-time → DATETIME, object/array → TEXT
func TestPropsToFields_Heuristics(t *testing.T) {
    props := map[string]interface{}{
        "fan_id": map[string]interface{}{"type": "string"}, // overridden to BIGINT by suffix rule
        "created_at": map[string]interface{}{"type": "string", "format": "date-time"},
        "meta": map[string]interface{}{"type": "object"},
        "items": map[string]interface{}{"type": "array"},
        "score": map[string]interface{}{"type": "integer"},
        "views": map[string]interface{}{"type": "integer", "format": "int64"},
    }
    fields := propsToFields(props)
    got := map[string]m.FieldType{}
    for _, f := range fields {
        got[m.SnakeCase(f.Name)] = f.Type
    }
    if got["fan_id"] != m.FieldBigInt {
        t.Fatalf("fan_id type = %s, want %s", got["fan_id"], m.FieldBigInt)
    }
    if got["created_at"] != m.FieldDatetime {
        t.Fatalf("created_at type = %s, want %s", got["created_at"], m.FieldDatetime)
    }
    if got["meta"] != m.FieldText {
        t.Fatalf("meta type = %s, want %s", got["meta"], m.FieldText)
    }
    if got["items"] != m.FieldText {
        t.Fatalf("items type = %s, want %s", got["items"], m.FieldText)
    }
    if got["score"] != m.FieldInt {
        t.Fatalf("score type = %s, want %s", got["score"], m.FieldInt)
    }
    if got["views"] != m.FieldBigInt {
        t.Fatalf("views type = %s, want %s", got["views"], m.FieldBigInt)
    }
}

// Test inferJoinTables: detect a join table with two *_id fields and add ManyToMany
func TestInferJoinTables_AddsManyToMany(t *testing.T) {
    dm := m.DomainModel{
        Entities: []m.Entity{
            {Name: "Fan", Fields: []m.Field{{Name: "id", Type: m.FieldBigInt, Unique: true}}},
            {Name: "Topic", Fields: []m.Field{{Name: "id", Type: m.FieldBigInt, Unique: true}}},
            {
                Name: "FanTopic",
                Fields: []m.Field{
                    {Name: "id", Type: m.FieldBigInt, Unique: true},
                    {Name: "fan_id", Type: m.FieldBigInt},
                    {Name: "topic_id", Type: m.FieldBigInt},
                },
            },
        },
    }
    inferJoinTables(&dm)
    // Expect one ManyToMany Fan<->Topic through fan_topic
    found := false
    for _, r := range dm.Relations {
        if r.Type == m.ManyToMany && r.Through == "fan_topic" {
            if (r.From == "Fan" && r.To == "Topic") || (r.From == "Topic" && r.To == "Fan") {
                found = true
                break
            }
        }
    }
    if !found {
        t.Fatalf("expected ManyToMany Fan<->Topic through fan_topic, got relations: %+v", dm.Relations)
    }
}

// Test inferJoinTables does not add relation when target entities are missing
func TestInferJoinTables_MissingEntities_NoRelation(t *testing.T) {
    dm := m.DomainModel{
        Entities: []m.Entity{
            {
                Name: "UserRole",
                Fields: []m.Field{
                    {Name: "id", Type: m.FieldBigInt, Unique: true},
                    {Name: "user_id", Type: m.FieldBigInt},
                    {Name: "role_id", Type: m.FieldBigInt},
                },
            },
        },
    }
    inferJoinTables(&dm)
    if len(dm.Relations) != 0 {
        t.Fatalf("expected no relations when entities are missing, got: %+v", dm.Relations)
    }
}

// Test inferJoinTables does not create duplicate ManyToMany if one already exists
func TestInferJoinTables_Dedup(t *testing.T) {
    dm := m.DomainModel{
        Entities: []m.Entity{
            {Name: "Fan", Fields: []m.Field{{Name: "id", Type: m.FieldBigInt, Unique: true}}},
            {Name: "Topic", Fields: []m.Field{{Name: "id", Type: m.FieldBigInt, Unique: true}}},
            {
                Name: "FanTopic",
                Fields: []m.Field{
                    {Name: "id", Type: m.FieldBigInt, Unique: true},
                    {Name: "fan_id", Type: m.FieldBigInt},
                    {Name: "topic_id", Type: m.FieldBigInt},
                },
            },
        },
        Relations: []m.Relation{
            {From: "Fan", To: "Topic", Type: m.ManyToMany, Through: "fan_tags"},
        },
    }
    inferJoinTables(&dm)
    // Still only one ManyToMany relation
    mm := 0
    for _, r := range dm.Relations {
        if r.Type == m.ManyToMany {
            mm++
        }
    }
    if mm != 1 {
        t.Fatalf("expected 1 ManyToMany relation after dedup, got %d with %+v", mm, dm.Relations)
    }
}