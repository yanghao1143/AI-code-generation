package ddl

import (
    "os"
    "path/filepath"
)

// WriteDDLFiles writes DDL scripts to scripts/db under the repository root.
func WriteDDLFiles(root string, d DDL) error {
    dir := filepath.Join(root, "scripts", "db")
    if err := os.MkdirAll(dir, 0o755); err != nil {
        return err
    }
    files := map[string]string{
        filepath.Join(dir, "create.sql"):   d.Create,
        filepath.Join(dir, "migrate.sql"):  d.Migrate,
        filepath.Join(dir, "rollback.sql"): d.Rollback,
    }
    for p, c := range files {
        if err := os.WriteFile(p, []byte(c), 0o644); err != nil {
            return err
        }
    }
    return nil
}