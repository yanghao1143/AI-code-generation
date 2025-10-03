package ddl

import (
    "fmt"
    "sort"
    "strings"

    m "xingzuo/internal/model"
)

// DDL holds SQL scripts for create, migrate, and rollback.
type DDL struct {
    Create   string
    Migrate  string
    Rollback string
}

// BuildDDL generates MySQL DDL statements based on the given DomainModel.
// It creates tables for entities, adds indexes/uniques, foreign keys for relations,
// and many-to-many join tables when applicable.
func BuildDDL(dm m.DomainModel) DDL {
    var createParts []string
    var fkAlterParts []string
    var joinCreateParts []string

    // Build entity tables
    for _, e := range dm.Entities {
        table := m.SnakeCase(e.Name)
        var cols []string
        var hasID bool
        for _, f := range e.Fields {
            col := m.SnakeCase(f.Name)
            if col == "id" {
                hasID = true
                cols = append(cols, "`id` BIGINT AUTO_INCREMENT PRIMARY KEY")
                continue
            }
            null := "NOT NULL"
            if f.Nullable { null = "NULL" }
            // Use precise column type rendering with length/precision when available
            cols = append(cols, fmt.Sprintf("`%s` %s %s", col, m.MySQLColumnType(f), null))
        }
        if !hasID {
            // Safety: ensure primary key exists
            cols = append(cols, "`id` BIGINT AUTO_INCREMENT PRIMARY KEY")
        }

        // Unique/Index constraints declared as keys inside CREATE TABLE
        var keys []string
        for _, f := range e.Fields {
            col := m.SnakeCase(f.Name)
            if f.Unique && col != "id" {
                keys = append(keys, fmt.Sprintf("UNIQUE KEY `uk_%s_%s` (`%s`)", table, col, col))
            }
            if f.Index && col != "id" {
                keys = append(keys, fmt.Sprintf("KEY `idx_%s_%s` (`%s`)", table, col, col))
            }
        }

        // Assemble CREATE TABLE
        def := strings.Join(append(cols, keys...), ",\n  ")
        createParts = append(createParts, fmt.Sprintf("CREATE TABLE IF NOT EXISTS `%s` (\n  %s\n) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;", table, def))
    }

    // Helper: map relation action to SQL keyword
    actionSQL := func(s string, isDelete bool) string {
        v := strings.ToLower(strings.TrimSpace(s))
        switch v {
        case "cascade":
            return "CASCADE"
        case "restrict":
            return "RESTRICT"
        case "set_null", "set null", "null":
            return "SET NULL"
        case "no_action", "no action":
            return "NO ACTION"
        default:
            // default: CASCADE for delete, NO ACTION for update when unspecified
            if isDelete { return "CASCADE" }
            return "CASCADE"
        }
    }

    // Foreign keys for one-to-many/one-to-one
    for _, r := range dm.Relations {
        if r.Type == m.ManyToMany {
            // handled later as join table
            continue
        }
        // FK resides in the target (To) side for one-to-many
        toTable := m.SnakeCase(r.To)
        fromTable := m.SnakeCase(r.From)
        fkCol := r.FKName
        if fkCol == "" {
            fkCol = m.SnakeCase(fromTable + "_id")
        } else {
            fkCol = m.SnakeCase(fkCol)
        }
        // Add FK constraint only if the column is present; we assume presence by design.
        onDel := actionSQL(r.OnDelete, true)
        onUpd := actionSQL(r.OnUpdate, false)
        fkAlterParts = append(fkAlterParts, fmt.Sprintf(
            "ALTER TABLE `%s` ADD CONSTRAINT `fk_%s_%s` FOREIGN KEY (`%s`) REFERENCES `%s`(`id`) ON DELETE %s ON UPDATE %s;",
            toTable, toTable, fkCol, fkCol, fromTable, onDel, onUpd,
        ))
    }

    // Many-to-many join tables
    // Use set to avoid duplicate join tables
    seen := map[string]bool{}
    for _, r := range dm.Relations {
        if r.Type != m.ManyToMany { continue }
        fromTable := m.SnakeCase(r.From)
        toTable := m.SnakeCase(r.To)
        join := r.Through
        if strings.TrimSpace(join) == "" {
            join = fromTable + "_" + toTable
        }
        join = m.SnakeCase(join)
        if seen[join] { continue }
        seen[join] = true
        // Composite PK of (from_id, to_id)
        create := fmt.Sprintf(
            "CREATE TABLE IF NOT EXISTS `%s` (\n  `%s_id` BIGINT NOT NULL,\n  `%s_id` BIGINT NOT NULL,\n  PRIMARY KEY (`%s_id`, `%s_id`),\n  CONSTRAINT `fk_%s_%s` FOREIGN KEY (`%s_id`) REFERENCES `%s`(`id`) ON DELETE CASCADE ON UPDATE CASCADE,\n  CONSTRAINT `fk_%s_%s` FOREIGN KEY (`%s_id`) REFERENCES `%s`(`id`) ON DELETE CASCADE ON UPDATE CASCADE\n) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;",
            join, fromTable, toTable, fromTable, toTable,
            join, fromTable, fromTable, fromTable,
            join, toTable, toTable, toTable,
        )
        joinCreateParts = append(joinCreateParts, create)
    }

    // Combine create script: entities first, then FKs (ALTER), then join tables
    createSQL := strings.Join(createParts, "\n\n")
    if len(fkAlterParts) > 0 {
        createSQL += "\n\n" + strings.Join(fkAlterParts, "\n")
    }
    if len(joinCreateParts) > 0 {
        createSQL += "\n\n" + strings.Join(joinCreateParts, "\n\n")
    }

    // Migrate: for initial version, same as create
    migrateSQL := createSQL

    // Rollback: drop join tables first, then entity tables (reverse order for safety)
    var drops []string
    // collect entity table names
    var entityTables []string
    for _, e := range dm.Entities {
        entityTables = append(entityTables, m.SnakeCase(e.Name))
    }
    sort.Strings(entityTables)
    // join tables
    var joinTables []string
    for j := range seen {
        joinTables = append(joinTables, j)
    }
    sort.Strings(joinTables)
    // Drop join tables
    for i := len(joinTables) - 1; i >= 0; i-- {
        drops = append(drops, fmt.Sprintf("DROP TABLE IF EXISTS `%s`;", joinTables[i]))
    }
    // Drop entity tables
    for i := len(entityTables) - 1; i >= 0; i-- {
        drops = append(drops, fmt.Sprintf("DROP TABLE IF EXISTS `%s`;", entityTables[i]))
    }
    rollbackSQL := strings.Join(drops, "\n")

    return DDL{Create: createSQL, Migrate: migrateSQL, Rollback: rollbackSQL}
}