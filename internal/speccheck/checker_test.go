package speccheck

import (
    "os"
    "path/filepath"
    "testing"

    "xingzuo/internal/ddl"
    m "xingzuo/internal/model"
)

// helper to write text to temp file
func writeTempFile(t *testing.T, dir string, name string, data string) string {
    t.Helper()
    p := filepath.Join(dir, name)
    if err := os.WriteFile(p, []byte(data), 0o644); err != nil {
        t.Fatalf("write temp file: %v", err)
    }
    return p
}

func TestCompareDomainWithDDL_IgnoresJoinTables(t *testing.T) {
    dm := m.DomainModel{
        Entities: []m.Entity{
            {Name: "Fan", Fields: []m.Field{{Name: "name", Type: m.FieldString}}},
            {Name: "Tag", Fields: []m.Field{{Name: "name", Type: m.FieldString}}},
        },
        Relations: []m.Relation{
            {From: "Fan", To: "Tag", Type: m.ManyToMany},
        },
    }
    d := ddl.BuildDDL(dm)
    dir := t.TempDir()
    ddlPath := writeTempFile(t, dir, "create.sql", d.Create)
    tbls, err := ParseDDL(ddlPath)
    if err != nil { t.Fatalf("parse ddl: %v", err) }
    rep := CompareDomainWithDDL(dm, tbls)
    if len(rep.ExtraTables) != 0 {
        t.Fatalf("expected no extra tables, got %v", rep.ExtraTables)
    }
    if len(rep.MissingTables) != 0 {
        t.Fatalf("expected no missing tables, got %v", rep.MissingTables)
    }
}

func TestOpenAPIParsingAndCompare_Basic(t *testing.T) {
    dm := m.DomainModel{
        Entities: []m.Entity{
            {Name: "Fan", Fields: []m.Field{{Name: "id", Type: m.FieldBigInt}, {Name: "name", Type: m.FieldString}}},
            {Name: "Tag", Fields: []m.Field{{Name: "id", Type: m.FieldBigInt}, {Name: "name", Type: m.FieldString}}},
        },
    }
    // Minimal OpenAPI content with paths and schemas for fans and tags
    openapi := `{
      "paths": {
        "/api/v1/fans": {"get": {}, "post": {}},
        "/api/v1/tags": {"get": {}, "post": {}}
      },
      "components": {
        "schemas": {
          "Fan": {"properties": {"id": {"type": "string"}, "name": {"type": "string"}}},
          "Tag": {"properties": {"id": {"type": "string"}, "name": {"type": "string"}}}
        }
      }
    }`
    dir := t.TempDir()
    oaPath := writeTempFile(t, dir, "openapi.json", openapi)
    oa, err := ParseOpenAPI(oaPath)
    if err != nil { t.Fatalf("parse openapi: %v", err) }
    rep := CompareOpenAPIWithDomain(dm, oa)
    if len(rep.MissingResources) != 0 {
        t.Fatalf("expected no missing resources, got %v", rep.MissingResources)
    }
    if len(rep.ExtraResources) != 0 {
        t.Fatalf("expected no extra resources, got %v", rep.ExtraResources)
    }
    if len(rep.SchemaMissingEntities) != 0 {
        t.Fatalf("expected no missing schemas, got %v", rep.SchemaMissingEntities)
    }
}

func TestOpenAPISynonyms_CanonicalResource(t *testing.T) {
    dm := m.DomainModel{
        Terms: map[string]string{
            "conversation": "Conversation",
            "conversations": "Conversation",
        },
        Entities: []m.Entity{
            {Name: "Conversation", Fields: []m.Field{{Name: "id", Type: m.FieldBigInt}}},
        },
    }
    openapi := `{
      "paths": {
        "/api/v1/conversations": {"get": {}}
      },
      "components": {"schemas": {"Conversation": {"properties": {"id": {"type": "string"}}}}}
    }`
    dir := t.TempDir()
    oaPath := writeTempFile(t, dir, "openapi.json", openapi)
    oa, err := ParseOpenAPI(oaPath)
    if err != nil { t.Fatalf("parse openapi: %v", err) }
    rep := CompareOpenAPIWithDomain(dm, oa)
    if len(rep.MissingResources) != 0 {
        t.Fatalf("expected no missing resources via synonyms, got %v", rep.MissingResources)
    }
    if len(rep.SchemaMissingEntities) != 0 {
        t.Fatalf("expected no missing schemas, got %v", rep.SchemaMissingEntities)
    }
}