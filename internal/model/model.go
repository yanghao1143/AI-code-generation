package model

import (
    "fmt"
    "regexp"
    "strings"
)

type FieldType string

const (
    FieldString   FieldType = "string"
    FieldText     FieldType = "text"
    FieldInt      FieldType = "int"
    FieldBigInt   FieldType = "bigint"
    FieldBool     FieldType = "bool"
    FieldDatetime FieldType = "datetime"
    FieldDecimal  FieldType = "decimal"
)

type RelationType string

const (
    OneToOne   RelationType = "one_to_one"
    OneToMany  RelationType = "one_to_many"
    ManyToMany RelationType = "many_to_many"
)

type Field struct {
    Name     string
    Type     FieldType
    Nullable bool
    Unique   bool
    Index    bool
    Default  string
    // Optional type details
    Length    int // for VARCHAR/CHAR length
    Precision int // for DECIMAL precision
    Scale     int // for DECIMAL scale
}

type Entity struct {
    Name   string
    Fields []Field
}

type Relation struct {
    From       string // entity name
    To         string // entity name
    Type       RelationType
    FKName     string // optional explicit foreign key name
    Through    string // for many-to-many via table
    // Optional referential actions for foreign keys (used by DDL generator)
    // Allowed values: "cascade", "restrict", "set_null", "no_action" (default)
    OnDelete   string
    OnUpdate   string
}

type DomainModel struct {
    Terms     map[string]string // normalized term dictionary
    Intents   []string          // e.g., CRUD/report/process
    Entities  []Entity
    Relations []Relation
}

type ClarifySeverity string

const (
    SeverityBlocker ClarifySeverity = "blocker"
    SeverityWarning ClarifySeverity = "warning"
    SeverityInfo    ClarifySeverity = "info"
)

type ClarifyIssue struct {
    ID       string
    Message  string
    Severity ClarifySeverity
    Resolved bool
}

// SnakeCase converts names to snake_case for DB objects.
func SnakeCase(s string) string {
    s = strings.TrimSpace(s)
    if s == "" {
        return s
    }
    // Convert camelCase/PascalCase to snake_case
    var matchFirstCap = regexp.MustCompile("(.)([A-Z][a-z]+)")
    var matchAllCap = regexp.MustCompile("([a-z0-9])([A-Z])")
    snake := matchFirstCap.ReplaceAllString(s, "${1}_${2}")
    snake = matchAllCap.ReplaceAllString(snake, "${1}_${2}")
    snake = strings.ToLower(strings.ReplaceAll(snake, "-", "_"))
    return snake
}

// MySQLType maps FieldType to a default MySQL column type without considering length/precision.
// Prefer using MySQLColumnType when Field has detailed type hints.
func MySQLType(ft FieldType) string {
    switch ft {
    case FieldString:
        return "VARCHAR(255)"
    case FieldText:
        return "TEXT"
    case FieldInt:
        return "INT"
    case FieldBigInt:
        return "BIGINT"
    case FieldBool:
        return "TINYINT(1)"
    case FieldDatetime:
        return "DATETIME"
    case FieldDecimal:
        return "DECIMAL(10,2)"
    default:
        return "VARCHAR(255)"
    }
}

// MySQLColumnType renders the precise MySQL type using Field's length/precision metadata.
func MySQLColumnType(f Field) string {
    switch f.Type {
    case FieldString:
        if f.Length > 0 {
            return fmt.Sprintf("VARCHAR(%d)", f.Length)
        }
        return "VARCHAR(255)"
    case FieldText:
        return "TEXT"
    case FieldInt:
        return "INT"
    case FieldBigInt:
        return "BIGINT"
    case FieldBool:
        return "TINYINT(1)"
    case FieldDatetime:
        return "DATETIME"
    case FieldDecimal:
        p := 10
        s := 2
        if f.Precision > 0 { p = f.Precision }
        if f.Scale > 0 { s = f.Scale }
        return fmt.Sprintf("DECIMAL(%d,%d)", p, s)
    default:
        return "VARCHAR(255)"
    }
}

// Validate performs basic checks on the domain model.
func (dm *DomainModel) Validate() error {
    if len(dm.Entities) == 0 {
        return fmt.Errorf("domain model has no entities")
    }
    names := map[string]bool{}
    for _, e := range dm.Entities {
        if e.Name == "" {
            return fmt.Errorf("entity with empty name")
        }
        if names[e.Name] {
            return fmt.Errorf("duplicate entity name: %s", e.Name)
        }
        names[e.Name] = true
        if len(e.Fields) == 0 {
            return fmt.Errorf("entity %s has no fields", e.Name)
        }
    }
    return nil
}