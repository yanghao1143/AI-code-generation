package nlp

import (
    "regexp"
    "strings"

    m "xingzuo/internal/model"
)

// Parse ingests natural language product planning text and produces a normalized
// DomainModel plus a list of clarification issues. This implementation is a
// lightweight, rule-based heuristic tailored for the 当前项目的《策划.md》内容结构。
//
// 设计目标：
// - 零依赖、可离线运行；
// - 针对中文 PRD 的常见模块名称（粉丝、主播、话题、脚本、工作流、测算服务等）做关键词映射；
// - 生成一个可用的初始 DomainModel，供后续文档生成与 DDL 生成使用；
// - 输出澄清项以提示后续需要用户确认的细节（合规、字段约束、索引等）。
func Parse(text string) (m.DomainModel, []m.ClarifyIssue) {
    t := strings.ToLower(text)

    // 术语标准化映射（中文 -> 英文实体名）
    terms := map[string]string{
        "主播": "Anchor",
        "粉丝": "Fan",
        "粉丝标签": "Tag",
        "标签": "Tag",
        "话题": "Topic",
        "脚本": "Script",
        "工作流": "Workflow",
        "智能体": "Agent",
        "测算服务": "FortuneService",
        "命理服务": "FortuneService",
        "测算记录": "FortuneRecord",
        "对话": "Conversation",
        // 通用业务实体补充
        "用户": "User",
        "订单": "Order",
        // 新增常见业务实体
        "商品": "Product",
        "订单项": "OrderItem",
        "支付": "Payment",
        "收藏": "Favorite",
    }

    // 基础实体集合（根据 PRD 关键词构建，若文本包含对应词语则纳入实体集）
    entities := []m.Entity{}
    addEntity := func(e m.Entity) {
        // 去重
        for _, ex := range entities {
            if ex.Name == e.Name {
                return
            }
        }
        entities = append(entities, e)
    }

    // 锚点：主播 / 粉丝
    if strings.Contains(t, "主播") {
        addEntity(m.Entity{
            Name: "Anchor",
            Fields: []m.Field{
                {Name: "id", Type: m.FieldBigInt, Unique: true},
                {Name: "name", Type: m.FieldString},
                {Name: "level", Type: m.FieldString},
                {Name: "created_at", Type: m.FieldDatetime},
            },
        })
    }
    if strings.Contains(t, "粉丝") {
        addEntity(m.Entity{
            Name: "Fan",
            Fields: []m.Field{
                {Name: "id", Type: m.FieldBigInt, Unique: true},
                {Name: "name", Type: m.FieldString},
                {Name: "gender", Type: m.FieldString, Nullable: true},
                {Name: "birthday", Type: m.FieldString, Nullable: true},
                {Name: "zodiac", Type: m.FieldString, Nullable: true},
                {Name: "created_at", Type: m.FieldDatetime},
            },
        })
        // 粉丝标签体系
        addEntity(m.Entity{
            Name: "Tag",
            Fields: []m.Field{
                {Name: "id", Type: m.FieldBigInt, Unique: true},
                {Name: "name", Type: m.FieldString},
                {Name: "created_at", Type: m.FieldDatetime},
            },
        })
    }

    // 对话系统
    if strings.Contains(t, "对话") || strings.Contains(t, "聊天") {
        addEntity(m.Entity{
            Name: "Conversation",
            Fields: []m.Field{
                {Name: "id", Type: m.FieldBigInt, Unique: true},
                {Name: "anchor_id", Type: m.FieldBigInt},
                {Name: "fan_id", Type: m.FieldBigInt},
                {Name: "content", Type: m.FieldText},
                {Name: "created_at", Type: m.FieldDatetime},
            },
        })
    }

    // 命理测算服务与记录
    if strings.Contains(t, "测算") || strings.Contains(t, "命理") {
        addEntity(m.Entity{
            Name: "FortuneService",
            Fields: []m.Field{
                {Name: "id", Type: m.FieldBigInt, Unique: true},
                {Name: "code", Type: m.FieldString},
                {Name: "name", Type: m.FieldString},
                {Name: "input_schema", Type: m.FieldText, Nullable: true},
                {Name: "created_at", Type: m.FieldDatetime},
            },
        })
        addEntity(m.Entity{
            Name: "FortuneRecord",
            Fields: []m.Field{
                {Name: "id", Type: m.FieldBigInt, Unique: true},
                {Name: "fan_id", Type: m.FieldBigInt},
                {Name: "service_id", Type: m.FieldBigInt},
                {Name: "result", Type: m.FieldText},
                {Name: "created_at", Type: m.FieldDatetime},
            },
        })
    }

    // 话题与脚本
    if strings.Contains(t, "话题") {
        addEntity(m.Entity{
            Name: "Topic",
            Fields: []m.Field{
                {Name: "id", Type: m.FieldBigInt, Unique: true},
                {Name: "name", Type: m.FieldString},
                {Name: "popularity", Type: m.FieldInt, Nullable: true},
                {Name: "created_at", Type: m.FieldDatetime},
            },
        })
    }
    if strings.Contains(t, "脚本") {
        addEntity(m.Entity{
            Name: "Script",
            Fields: []m.Field{
                {Name: "id", Type: m.FieldBigInt, Unique: true},
                {Name: "title", Type: m.FieldString},
                {Name: "content", Type: m.FieldText},
                {Name: "topic_id", Type: m.FieldBigInt, Nullable: true},
                {Name: "created_at", Type: m.FieldDatetime},
            },
        })
    }

    // 工作流
    if strings.Contains(t, "工作流") {
        addEntity(m.Entity{
            Name: "Workflow",
            Fields: []m.Field{
                {Name: "id", Type: m.FieldBigInt, Unique: true},
                {Name: "name", Type: m.FieldString},
                {Name: "definition", Type: m.FieldText},
                {Name: "created_at", Type: m.FieldDatetime},
            },
        })
    }

    // 解析中文“字段清单”并合并到对应实体
    // 支持格式示例：
    //  粉丝字段：id(主键, int64), name(字符串), gender(可空 字符串), birthday(可空 字符串), created_at(时间)
    //  对话字段：id(主键), anchor_id(外键, int64), fan_id(外键, int64), content(文本), created_at(时间)
    fieldLists := parseAllEntityFieldLists(text)
    if len(fieldLists) > 0 {
        for en, flds := range fieldLists {
            if len(flds) == 0 { continue }
            // ensure id present
            hasID := false
            for _, f := range flds { if strings.EqualFold(f.Name, "id") { hasID = true; break } }
            if !hasID { flds = append([]m.Field{{Name: "id", Type: m.FieldBigInt, Unique: true}}, flds...) }
            // merge into entity set
            merged := false
            for ei := range entities {
                if entities[ei].Name == en {
                    entities[ei].Fields = mergeFields(entities[ei].Fields, flds)
                    merged = true
                    break
                }
            }
            if !merged {
                entities = append(entities, m.Entity{Name: en, Fields: flds})
            }
        }
    }

    // 初始化关系集合，供外键解析与关系推断使用
    relations := []m.Relation{}

    // 显式外键解析：解析字段规格中的 “外键->实体.字段” 语法，为 DomainModel 添加 OneToMany 关系
    if len(fieldLists) > 0 {
        // 辅助：实体存在检查
        hasEntity := func(name string) bool {
            for _, e := range entities { if e.Name == name { return true } }
            return false
        }
        // 辅助：避免重复关系
        addRel := func(rr []m.Relation, r m.Relation) []m.Relation {
            for _, ex := range rr {
                if strings.EqualFold(ex.From, r.From) && strings.EqualFold(ex.To, r.To) && ex.Type == r.Type && strings.EqualFold(ex.FKName, r.FKName) {
                    return rr
                }
            }
            return append(rr, r)
        }
        // 中文实体到英文名映射（与字段清单解析保持一致）
        cn2en := map[string]string{
            "主播": "Anchor", "粉丝": "Fan", "标签": "Tag", "话题": "Topic", "脚本": "Script", "工作流": "Workflow",
            "测算服务": "FortuneService", "命理服务": "FortuneService", "测算记录": "FortuneRecord", "对话": "Conversation",
            "用户": "User", "订单": "Order",
            // 新增常见业务实体，支持中文短语关系解析
            "商品": "Product", "订单项": "OrderItem", "支付": "Payment", "收藏": "Favorite",
        }
        // 遍历各实体的字段列表，寻找 Default= "fk:实体.字段" 的标记
        for en, flds := range fieldLists {
            for _, f := range flds {
                df := strings.TrimSpace(f.Default)
                if !strings.HasPrefix(df, "fk:") { continue }
                tgt := strings.TrimPrefix(df, "fk:")
                // 允许中文或英文实体.字段，字段名规范化
                parts := strings.Split(tgt, ".")
                if len(parts) < 1 { continue }
                cn := strings.TrimSpace(parts[0])
                // 字段名可选（默认 id）
                tf := "id"
                if len(parts) >= 2 {
                    tf = canonicalizeNameSimple(strings.TrimSpace(parts[1]))
                    // 若类似 “用户ID/订单ID”，统一为 id
                    lowtf := strings.ToLower(tf)
                    if lowtf == "用户id" || lowtf == "订单id" || lowtf == "主键" { tf = "id" }
                }
                // 中文实体映射到英文实体名
                ten, ok := cn2en[cn]
                if !ok { ten = cn }
                if !hasEntity(ten) { continue }
                // 外键列名：使用字段清单中的字段名，规范为 snake_case
                fkcol := m.SnakeCase(f.Name)
                if fkcol == "" { fkcol = m.SnakeCase(ten + "_id") }
                // 添加 OneToMany: From=目标实体, To=当前实体
                relations = addRel(relations, m.Relation{From: ten, To: en, Type: m.OneToMany, FKName: fkcol})
            }
        }
    }

    // 关系推断（基于常识）：
    has := func(name string) bool {
        for _, e := range entities {
            if e.Name == name {
                return true
            }
        }
        return false
    }
    // Anchor -> Conversation (1:N)
    if has("Anchor") && has("Conversation") {
        relations = append(relations, m.Relation{From: "Anchor", To: "Conversation", Type: m.OneToMany, FKName: "anchor_id"})
    }
    // Fan -> Conversation (1:N)
    if has("Fan") && has("Conversation") {
        relations = append(relations, m.Relation{From: "Fan", To: "Conversation", Type: m.OneToMany, FKName: "fan_id"})
    }
    // Fan <-> Tag (M:N)
    if has("Fan") && has("Tag") {
        relations = append(relations, m.Relation{From: "Fan", To: "Tag", Type: m.ManyToMany, Through: "fan_tags"})
    }
    // Fan -> FortuneRecord (1:N)
    if has("Fan") && has("FortuneRecord") {
        relations = append(relations, m.Relation{From: "Fan", To: "FortuneRecord", Type: m.OneToMany, FKName: "fan_id"})
    }
    // FortuneService -> FortuneRecord (1:N)
    if has("FortuneService") && has("FortuneRecord") {
        relations = append(relations, m.Relation{From: "FortuneService", To: "FortuneRecord", Type: m.OneToMany, FKName: "service_id"})
    }
    // Topic -> Script (1:N)
    if has("Topic") && has("Script") {
        relations = append(relations, m.Relation{From: "Topic", To: "Script", Type: m.OneToMany, FKName: "topic_id"})
    }

    // 中文业务规则提示的关系推断：例如 “一个用户有多个订单(一对多)”
    if has("User") && has("Order") {
        // 触发条件：文本同时包含“用户”和“订单”，并且出现“一对多”或“有多个订单”的描述
        if strings.Contains(t, "一对多") || strings.Contains(t, "有多个订单") {
            // 避免重复添加
            exists := false
            for _, r := range relations {
                if strings.EqualFold(r.From, "User") && strings.EqualFold(r.To, "Order") && r.Type == m.OneToMany {
                    exists = true
                    break
                }
            }
            if !exists {
                relations = append(relations, m.Relation{From: "User", To: "Order", Type: m.OneToMany, FKName: "user_id"})
            }
        }
    }

    // 从中文短语中进一步抽取关系
    phraseRels := parseRelationsFromPhrases(text, entities)
    if len(phraseRels) > 0 {
        // 关系去重并合并
        dedup := func(rr []m.Relation, r m.Relation) []m.Relation {
            for _, ex := range rr {
                if strings.EqualFold(ex.From, r.From) && strings.EqualFold(ex.To, r.To) && ex.Type == r.Type && strings.EqualFold(ex.FKName, r.FKName) && strings.EqualFold(ex.Through, r.Through) {
                    return rr
                }
            }
            return append(rr, r)
        }
        for _, r := range phraseRels {
            relations = dedup(relations, r)
        }
    }

    dm := m.DomainModel{
        Terms:     terms,
        Intents:   []string{"crud", "report"},
        Entities:  entities,
        Relations: relations,
    }

    issues := []m.ClarifyIssue{
        {ID: "privacy-001", Message: "是否需要对包含生日、性别等敏感信息的表进行访问控制与脱敏展示？", Severity: m.SeverityWarning},
        {ID: "index-002", Message: "对话与测算记录是否需要基于 fan_id/anchor_id 的复合索引以优化查询？", Severity: m.SeverityInfo},
        {ID: "workflow-003", Message: "工作流 definition 字段是否需要采用 JSON Schema 并建立版本管理？", Severity: m.SeverityInfo},
        {ID: "script-004", Message: "脚本 content 是否需要区分草稿与发布版本并建立审计记录？", Severity: m.SeverityInfo},
    }

    return dm, issues
}

// parseAllEntityFieldLists scans the text for per-entity field list hints in Chinese
// and returns a map of PascalCase entity name -> []Field
func parseAllEntityFieldLists(text string) map[string][]m.Field {
    out := map[string][]m.Field{}
    pairs := []struct{ cn, en string }{
        {"主播", "Anchor"},
        {"粉丝", "Fan"},
        {"话题", "Topic"},
        {"脚本", "Script"},
        {"工作流", "Workflow"},
        {"测算服务", "FortuneService"},
        {"命理服务", "FortuneService"},
        {"测算记录", "FortuneRecord"},
        {"对话", "Conversation"},
        // 通用补充
        {"用户", "User"},
        {"订单", "Order"},
    }
    for _, p := range pairs {
        flds := parseEntityFieldList(text, p.cn)
        if len(flds) > 0 {
            out[p.en] = flds
        }
    }
    // 解析“实体：中文（英文）…字段清单：...”的行内规格
    inline := parseEntityInlineSpecLists(text)
    for en, flds := range inline {
        if len(flds) == 0 { continue }
        // merge if exists
        if ex, ok := out[en]; ok {
            out[en] = mergeFields(ex, flds)
        } else {
            out[en] = flds
        }
    }
    return out
}

// parseEntityFieldList finds a single-line field list for a given Chinese entity name.
// It supports ASCII/Fullwidth colon and splits by common separators (逗号/顿号/分号/逗号英文)。
func parseEntityFieldList(text string, entityCN string) []m.Field {
    // (?m) start-of-line optional spaces + entityCN + (的)?字段 + [:：] + rest-of-line
    re := regexp.MustCompile(`(?m)^\s*` + regexp.QuoteMeta(entityCN) + `(?:[的\s]*)字段[：:]\s*(.+)$`)
    ms := re.FindAllStringSubmatch(text, -1)
    if len(ms) == 0 { return nil }
    var out []m.Field
    for _, m1 := range ms {
        raw := strings.TrimSpace(m1[1])
        if raw == "" { continue }
        items := splitFields(raw)
        for _, it := range items {
            if it == "" { continue }
            // 忽略不含括号的残片（如 “唯一”、“非空)”）
            if !strings.Contains(it, "(") && !strings.Contains(it, "（") { continue }
            f := parseFieldSpec(it)
            if f.Name == "" { continue }
            out = append(out, f)
        }
    }
    return out
}

// splitFields splits a field list using common separators
func splitFields(s string) []string {
    // Robust splitter: respect parentheses depth, only split on separators at depth==0
    seps := map[rune]bool{',': true, '，': true, '、': true, ';': true, '；': true}
    var out []string
    var buf []rune
    depth := 0
    for _, r := range s {
        switch r {
        case '(', '（':
            depth++
            buf = append(buf, r)
        case ')', '）':
            if depth > 0 { depth-- }
            buf = append(buf, r)
        default:
            if seps[r] && depth == 0 {
                v := strings.TrimSpace(string(buf))
                if v != "" { out = append(out, v) }
                buf = buf[:0]
            } else {
                buf = append(buf, r)
            }
        }
    }
    // flush
    v := strings.TrimSpace(string(buf))
    if v != "" { out = append(out, v) }
    return out
}

// parseFieldSpec parses "name(qualifiers)" or "name（qualifiers）" where qualifiers include
// type hints and flags like 可空/非空/主键/外键/索引. Returns a normalized Field.
func parseFieldSpec(spec string) m.Field {
    f := m.Field{}
    spec = strings.TrimSpace(spec)
    if spec == "" { return f }
    name := spec
    quals := ""
    // Extract qualifiers within outer parentheses, supporting nested () and （）
    // ASCII
    if i := strings.Index(spec, "("); i >= 0 {
        name = strings.TrimSpace(spec[:i])
        depth := 0
        end := -1
        for pos := i; pos < len(spec); pos++ {
            c := spec[pos]
            if c == '(' { depth++ } else if c == ')' {
                depth--
                if depth == 0 { end = pos; break }
            }
        }
        if end > i { quals = strings.TrimSpace(spec[i+1 : end]) }
    } else if i := strings.Index(spec, "（"); i >= 0 { // Fullwidth
        name = strings.TrimSpace(spec[:i])
        depth := 0
        end := -1
        for pos, r := range spec[i:] {
            if r == '（' { depth++ } else if r == '）' {
                depth--
                if depth == 0 {
                    // pos is relative to i
                    end = i + pos
                    break
                }
            }
        }
        if end > i { quals = strings.TrimSpace(spec[i+1 : end]) }
    }
    // Canonicalize field name using Chinese alias map
    name = canonicalizeNameSimple(name)
    f.Name = name
    if quals == "" {
        // default type heuristics
        f.Type = defaultTypeForName(name)
        return f
    }
    ql := strings.ToLower(quals)
    // 是否为外键说明，影响“主键/唯一”解释
    isFK := strings.Contains(ql, "外键")
    // flags
    if strings.Contains(ql, "可空") { f.Nullable = true }
    if strings.Contains(ql, "非空") || strings.Contains(ql, "必填") { f.Nullable = false }
    // 仅当非外键时，当前列可解释为主键/唯一
    if !isFK && strings.Contains(ql, "主键") {
        f.Unique = true
        f.Type = m.FieldBigInt
        if name != "id" { /* keep provided name */ }
    }
    if !isFK && strings.Contains(ql, "唯一索引") { f.Unique = true; f.Index = true }
    if !isFK && strings.Contains(ql, "唯一") { f.Unique = true }
    if strings.Contains(ql, "索引") { f.Index = true }
    // 显式外键：支持 “外键->实体.字段” 语法，生成 *_id 并记录目标以便后续建立关系
    if isFK {
        // 捕获 “外键->...” 直到分隔符
        re := regexp.MustCompile(`外键->\s*([^,，；\s]+)`) // e.g., 用户.用户ID
        if ms := re.FindStringSubmatch(ql); len(ms) >= 2 {
            target := strings.TrimSpace(ms[1])
            if target != "" {
                f.Default = "fk:" + target
            }
        }
        // map to *_id bigint when possible
        if !strings.HasSuffix(name, "_id") {
            f.Name = name + "_id"
        }
        f.Type = m.FieldBigInt
        f.Index = true
    }
    // type hints + 规格提取（长度/精度）
    // 提取 varchar/char 长度，如 "varchar(64)"、"字符串(200)"、"字符(32)"，兼容全角括号
    if f.Length == 0 {
        if matches := regexp.MustCompile(`varchar\s*\(\s*(\d+)\s*\)`).FindStringSubmatch(ql); len(matches) == 2 {
            f.Type = m.FieldString
            f.Length = atoiSafe(matches[1])
        } else if matches := regexp.MustCompile(`char\s*\(\s*(\d+)\s*\)`).FindStringSubmatch(ql); len(matches) == 2 {
            f.Type = m.FieldString
            f.Length = atoiSafe(matches[1])
        } else if matches := regexp.MustCompile(`(字符串|字符)\s*\(\s*(\d+)\s*\)`).FindStringSubmatch(ql); len(matches) == 3 {
            f.Type = m.FieldString
            f.Length = atoiSafe(matches[2])
        } else if matches := regexp.MustCompile(`(字符串|字符)\s*（\s*(\d+)\s*）`).FindStringSubmatch(ql); len(matches) == 3 { // fullwidth
            f.Type = m.FieldString
            f.Length = atoiSafe(matches[2])
        }
    }
    // 提取 decimal 精度与小数位，如 "decimal(10,2)" 或 "小数(12,4)"
    if f.Precision == 0 && f.Scale == 0 {
        if matches := regexp.MustCompile(`decimal\s*\(\s*(\d+)\s*,\s*(\d+)\s*\)`).FindStringSubmatch(ql); len(matches) == 3 {
            f.Type = m.FieldDecimal
            f.Precision = atoiSafe(matches[1])
            f.Scale = atoiSafe(matches[2])
        } else if matches := regexp.MustCompile(`小数\s*\(\s*(\d+)\s*,\s*(\d+)\s*\)`).FindStringSubmatch(ql); len(matches) == 3 {
            f.Type = m.FieldDecimal
            f.Precision = atoiSafe(matches[1])
            f.Scale = atoiSafe(matches[2])
        } else if matches := regexp.MustCompile(`金额\s*\(\s*(\d+)\s*,\s*(\d+)\s*\)`).FindStringSubmatch(ql); len(matches) == 3 {
            f.Type = m.FieldDecimal
            f.Precision = atoiSafe(matches[1])
            f.Scale = atoiSafe(matches[2])
        }
    }
    // 基本类型提示（不带规格）
    switch {
    case containsAny(ql, []string{"int64", "长整型", "大整数", "bigint"}):
        f.Type = m.FieldBigInt
    case containsAny(ql, []string{"整数", "number", "数值", "数字", "int"}):
        if f.Type == "" { f.Type = m.FieldInt }
    case containsAny(ql, []string{"decimal", "小数", "金额", "价格"}):
        if f.Type == "" { f.Type = m.FieldDecimal }
    case containsAny(ql, []string{"布尔", "boolean"}):
        f.Type = m.FieldBool
    case containsAny(ql, []string{"时间", "日期", "日期时间", "date-time", "datetime"}):
        f.Type = m.FieldDatetime
    case containsAny(ql, []string{"文本", "内容"}):
        f.Type = m.FieldText
    case containsAny(ql, []string{"字符串", "字符", "string", "varchar", "char"}):
        if f.Type == "" { f.Type = m.FieldString }
    default:
        if f.Type == "" { f.Type = defaultTypeForName(name) }
    }
    return f
}

// parseRelationsFromPhrases extracts relations from Chinese phrases like:
// - "一个用户有多个订单" -> User (1:N) Order
// - "粉丝与标签是多对多" -> Fan (M:N) Tag
// - "每个脚本对应一个话题" -> Script (1:1) Topic
func parseRelationsFromPhrases(text string, entities []m.Entity) []m.Relation {
    t := strings.ToLower(text)
    has := func(name string) bool {
        for _, e := range entities { if e.Name == name { return true } }
        return false
    }
    cn2en := map[string]string{
        "主播": "Anchor", "粉丝": "Fan", "标签": "Tag", "话题": "Topic", "脚本": "Script", "工作流": "Workflow",
        "测算服务": "FortuneService", "命理服务": "FortuneService", "测算记录": "FortuneRecord", "对话": "Conversation",
        "用户": "User", "订单": "Order",
        // 常见业务实体补充
        "商品": "Product", "订单项": "OrderItem", "支付": "Payment", "收藏": "Favorite",
    }
    // Helper to map CN to EN entity name
    toEN := func(cn string) string { if v, ok := cn2en[cn]; ok { return v }; return cn }
    rels := []m.Relation{}
    // Pattern 1: One-to-Many "一个A有多个B" / "每个A有多个B"
    re1 := regexp.MustCompile(`(一个|每个)\s*(主播|粉丝|标签|话题|脚本|工作流|测算服务|命理服务|测算记录|对话|用户|订单|商品|订单项|支付|收藏)\s*(有|拥有)\s*(多个|多条|多份|多次)\s*(主播|粉丝|标签|话题|脚本|工作流|测算服务|命理服务|测算记录|对话|用户|订单|商品|订单项|支付|收藏)`) 
    for _, ms := range re1.FindAllStringSubmatch(t, -1) {
        aCN := strings.TrimSpace(ms[2])
        bCN := strings.TrimSpace(ms[5])
        a := toEN(aCN)
        b := toEN(bCN)
        if has(a) && has(b) {
            fk := m.SnakeCase(toEN(a)) + "_id"
            rels = append(rels, m.Relation{From: a, To: b, Type: m.OneToMany, FKName: fk})
        }
    }
    // Pattern 2: Many-to-Many "A与B是多对多" / "A和B是多对多"
    re2 := regexp.MustCompile(`(主播|粉丝|标签|话题|脚本|工作流|测算服务|命理服务|测算记录|对话|用户|订单|商品|订单项|支付|收藏)\s*(与|和)\s*(主播|粉丝|标签|话题|脚本|工作流|测算服务|命理服务|测算记录|对话|用户|订单|商品|订单项|支付|收藏)\s*(是)?\s*多对多`) 
    for _, ms := range re2.FindAllStringSubmatch(t, -1) {
        a := toEN(strings.TrimSpace(ms[1]))
        b := toEN(strings.TrimSpace(ms[3]))
        if has(a) && has(b) {
            // through table name by sorted pair
            pair := []string{m.SnakeCase(a), m.SnakeCase(b)}
            if pair[0] > pair[1] { pair[0], pair[1] = pair[1], pair[0] }
            through := pair[0] + "_" + pair[1]
            // dedup handled by caller
            rels = append(rels, m.Relation{From: a, To: b, Type: m.ManyToMany, Through: through})
        }
    }
    // Pattern 3: One-to-One "每个A对应一个B" / "一个A对应一个B"
    re3 := regexp.MustCompile(`(一个|每个)\s*(主播|粉丝|标签|话题|脚本|工作流|测算服务|命理服务|测算记录|对话|用户|订单|商品|订单项|支付|收藏)\s*对应(一个)?\s*(主播|粉丝|标签|话题|脚本|工作流|测算服务|命理服务|测算记录|对话|用户|订单|商品|订单项|支付|收藏)`) 
    for _, ms := range re3.FindAllStringSubmatch(t, -1) {
        a := toEN(strings.TrimSpace(ms[2]))
        b := toEN(strings.TrimSpace(ms[4]))
        if has(a) && has(b) {
            rels = append(rels, m.Relation{From: a, To: b, Type: m.OneToOne})
        }
    }

    // Post-process: detect referential actions (ON DELETE/ON UPDATE) from phrases
    // Patterns like: "用户删除时订单跟随删除" -> From=User, To=Order, OnDelete=cascade
    //                 "删除用户时订单置空" -> OnDelete=set_null
    //                 "用户更新时订单同步更新" -> OnUpdate=cascade
    entPattern := "(主播|粉丝|标签|话题|脚本|工作流|测算服务|命理服务|测算记录|对话|用户|订单|商品|订单项|支付|收藏)"
    reDelCascade := regexp.MustCompile(entPattern + `\s*(删除时|删除后|删除则)\s*` + entPattern + `\s*(跟随删除|一并删除|同时删除|级联删除)`) 
    reDelSetNull := regexp.MustCompile(entPattern + `\s*(删除时|删除后|删除则)\s*` + entPattern + `\s*(置空|设为null|设置为null)`) 
    reUpdCascade := regexp.MustCompile(entPattern + `\s*(更新时|修改时)\s*` + entPattern + `\s*(同步更新|级联更新)`) 

    // Helper: annotate relation action if relation exists
    setAction := func(fromCN, toCN, onDel, onUpd string) {
        from := toEN(strings.TrimSpace(fromCN))
        to := toEN(strings.TrimSpace(toCN))
        for i := range rels {
            if strings.EqualFold(rels[i].From, from) && strings.EqualFold(rels[i].To, to) {
                if onDel != "" { rels[i].OnDelete = onDel }
                if onUpd != "" { rels[i].OnUpdate = onUpd }
            }
        }
    }
    for _, ms := range reDelCascade.FindAllStringSubmatch(t, -1) {
        aCN := strings.TrimSpace(ms[1])
        bCN := strings.TrimSpace(ms[3])
        setAction(aCN, bCN, "cascade", "")
    }
    for _, ms := range reDelSetNull.FindAllStringSubmatch(t, -1) {
        aCN := strings.TrimSpace(ms[1])
        bCN := strings.TrimSpace(ms[3])
        setAction(aCN, bCN, "set_null", "")
    }
    for _, ms := range reUpdCascade.FindAllStringSubmatch(t, -1) {
        aCN := strings.TrimSpace(ms[1])
        bCN := strings.TrimSpace(ms[3])
        setAction(aCN, bCN, "", "cascade")
    }
    return rels
}

func containsAny(s string, kws []string) bool {
    for _, k := range kws { if strings.Contains(s, k) { return true } }
    return false
}

func defaultTypeForName(name string) m.FieldType {
    n := strings.ToLower(strings.TrimSpace(name))
    switch {
    case n == "id" || strings.HasSuffix(n, "_id"):
        return m.FieldBigInt
    case n == "created_at" || n == "updated_at" || n == "start_at" || n == "end_at" || n == "expires_at":
        return m.FieldDatetime
    case n == "definition" || n == "content" || n == "result" || n == "tags" || n == "input_schema":
        return m.FieldText
    case strings.Contains(n, "amount") || strings.Contains(n, "price") || strings.Contains(n, "fee") || strings.Contains(n, "total_amount") || strings.Contains(n, "balance"):
        return m.FieldDecimal
    default:
        return m.FieldString
    }
}

// canonicalizeNameSimple maps common Chinese aliases to canonical snake_case English names.
func canonicalizeNameSimple(name string) string {
    n := strings.TrimSpace(name)
    if n == "" { return n }
    low := strings.ToLower(n)
    aliases := map[string]string{
        "定义": "definition",
        "内容": "content",
        "结果": "result",
        "标签": "tags",
        "输入架构": "input_schema",
        "输入模式": "input_schema",
        "创建时间": "created_at",
        "注册时间": "created_at",
        "更新时间": "updated_at",
        "开始时间": "start_at",
        "结束时间": "end_at",
        "过期时间": "expires_at",
        "到期时间": "expires_at",
        "粉丝id": "fan_id",
        "服务id": "service_id",
        "会话id": "conversation_id",
        "主题id": "topic_id",
        "锚点id": "anchor_id",
        "用户id": "user_id",
        "订单id": "order_id",
        "编号": "id",
        "主键": "id",
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
        "备注": "remark",
        "金额": "amount",
        "价格": "price",
        "总金额": "total_amount",
        "余额": "balance",
        "订单编号": "order_no",
        "封面": "cover_url",
        "封面图": "cover_url",
        "封面url": "cover_url",
        "封面url ": "cover_url",
        "封面URL": "cover_url",
        "标题": "title",
        "描述": "description",
    }
    if v, ok := aliases[low]; ok { return v }
    return name
}

// atoiSafe converts string to int, returning 0 on error.
func atoiSafe(s string) int {
    s = strings.TrimSpace(s)
    n := 0
    for i := 0; i < len(s); i++ {
        c := s[i]
        if c < '0' || c > '9' { return 0 }
        n = n*10 + int(c-'0')
    }
    return n
}

// parseEntityInlineSpecLists parses inline blocks like:
//  "实体：用户（User）。字段清单：用户ID(bigint, 主键), 昵称(varchar(64), 可空)"
// Returns map of English entity name -> []Field
func parseEntityInlineSpecLists(text string) map[string][]m.Field {
    out := map[string][]m.Field{}
    // 使用非贪婪匹配，字段清单部分在下一个句号/英文句点/换行或文本结尾处截止，避免跨实体合并
    re := regexp.MustCompile(`(?m)实体[：:]\s*([^（()。\n]+)\s*[（(]\s*([^）)\s]+)\s*[）)]\s*[。.]?\s*字段清单[：:]\s*(.+?)(?:[。.]|\n|$)`)
    ms := re.FindAllStringSubmatch(text, -1)
    for _, m1 := range ms {
        en := strings.TrimSpace(m1[2])
        raw := strings.TrimSpace(m1[3])
        if en == "" || raw == "" { continue }
        items := splitFields(raw)
        var flds []m.Field
        for _, it := range items {
            if it == "" { continue }
            // 忽略不含括号的残片（如 “唯一”、“非空)”）
            if !strings.Contains(it, "(") && !strings.Contains(it, "（") { continue }
            f := parseFieldSpec(it)
            if f.Name == "" { continue }
            flds = append(flds, f)
        }
        if len(flds) > 0 {
            out[en] = flds
        }
    }
    return out
}

// mergeFields merges new fields into existing by canonicalized name, reconciling types and flags.
func mergeFields(existing []m.Field, add []m.Field) []m.Field {
    if len(add) == 0 { return existing }
    // build index by snake_case name
    idx := map[string]int{}
    for i, f := range existing { idx[m.SnakeCase(f.Name)] = i }
    for _, nf := range add {
        key := m.SnakeCase(nf.Name)
        if pos, ok := idx[key]; ok {
            cur := existing[pos]
            // reconcile: prefer stronger types; preserve unique/index; nullable union
            existing[pos] = reconcileSimple(cur, nf)
        } else {
            existing = append(existing, nf)
            idx[key] = len(existing) - 1
        }
    }
    return existing
}

func reconcileSimple(a, b m.Field) m.Field {
    out := a
    // type precedence
    rank := func(ft m.FieldType) int {
        switch ft {
        case m.FieldBigInt: return 6
        case m.FieldDecimal: return 5
        case m.FieldInt: return 4
        case m.FieldDatetime: return 3
        case m.FieldBool: return 2
        case m.FieldText: return 1
        case m.FieldString: return 0
        default: return 0
        }
    }
    if rank(b.Type) > rank(a.Type) { out.Type = b.Type }
    out.Nullable = a.Nullable || b.Nullable
    out.Unique = a.Unique || b.Unique
    out.Index = a.Index || b.Index
    if out.Default == "" { out.Default = b.Default }
    // preserve length/precision/scale when provided
    if b.Length > 0 { out.Length = b.Length }
    if b.Precision > 0 { out.Precision = b.Precision }
    if b.Scale > 0 { out.Scale = b.Scale }
    return out
}