package fans

import (
    "database/sql"
    "fmt"
    "time"
)

// SQLRepo implements Fan repository backed by MySQL (database/sql).
type SQLRepo struct {
    db *sql.DB
}

func NewSQLRepo(db *sql.DB) *SQLRepo { return &SQLRepo{db: db} }

// List returns fans with pagination.
// Preferred mode: pageSize & afterId (cursor by id ascending).
// Legacy mode: limit & offset (takes precedence when provided).
func (r *SQLRepo) List(pageSize int, afterId int64, legacyLimit, legacyOffset int) (items []Fan, total int, nextAfterId int64, hasMore bool, err error) {
    if r == nil || r.db == nil {
        return nil, 0, 0, false, fmt.Errorf("repo not initialized")
    }

    // Total count
    if err = r.db.QueryRow("SELECT COUNT(*) FROM fan").Scan(&total); err != nil {
        return nil, 0, 0, false, err
    }

    // Build query
    var rows *sql.Rows
    if legacyLimit > 0 || legacyOffset > 0 {
        // Legacy: LIMIT/OFFSET
        q := "SELECT id, name, gender, birthday, zodiac, created_at FROM fan ORDER BY id ASC LIMIT ? OFFSET ?"
        rows, err = r.db.Query(q, legacyLimit, legacyOffset)
    } else {
        // Cursor: afterId
        if afterId > 0 {
            q := "SELECT id, name, gender, birthday, zodiac, created_at FROM fan WHERE id > ? ORDER BY id ASC LIMIT ?"
            rows, err = r.db.Query(q, afterId, pageSize)
        } else {
            q := "SELECT id, name, gender, birthday, zodiac, created_at FROM fan ORDER BY id ASC LIMIT ?"
            rows, err = r.db.Query(q, pageSize)
        }
    }
    if err != nil {
        return nil, 0, 0, false, err
    }
    defer rows.Close()

    items = make([]Fan, 0, pageSize)
    var lastId int64
    for rows.Next() {
        var f Fan
        var created time.Time
        var gender, birthday, zodiac sql.NullString
        if err = rows.Scan(&f.ID, &f.Name, &gender, &birthday, &zodiac, &created); err != nil {
            return nil, 0, 0, false, err
        }
        if gender.Valid { f.Gender = gender.String }
        if birthday.Valid { f.Birthday = birthday.String }
        if zodiac.Valid { f.Zodiac = zodiac.String }
        f.CreatedAt = created.Format(time.RFC3339)
        items = append(items, f)
        lastId = f.ID
    }
    if err = rows.Err(); err != nil {
        return nil, 0, 0, false, err
    }

    nextAfterId = lastId
    // hasMore: estimate based on count or page size
    if legacyLimit > 0 || legacyOffset > 0 {
        hasMore = legacyOffset+len(items) < total
    } else {
        hasMore = len(items) == pageSize && total > int(lastId)
    }
    return items, total, nextAfterId, hasMore, nil
}

// Get returns a fan by id.
func (r *SQLRepo) Get(id int64) (Fan, bool, error) {
    var f Fan
    var gender, birthday, zodiac sql.NullString
    var created time.Time
    err := r.db.QueryRow("SELECT id, name, gender, birthday, zodiac, created_at FROM fan WHERE id = ?", id).
        Scan(&f.ID, &f.Name, &gender, &birthday, &zodiac, &created)
    if err == sql.ErrNoRows {
        return Fan{}, false, nil
    }
    if err != nil {
        return Fan{}, false, err
    }
    if gender.Valid { f.Gender = gender.String }
    if birthday.Valid { f.Birthday = birthday.String }
    if zodiac.Valid { f.Zodiac = zodiac.String }
    f.CreatedAt = created.Format(time.RFC3339)
    return f, true, nil
}

// Create inserts a new fan and returns it.
func (r *SQLRepo) Create(req CreateRequest) (Fan, error) {
    res, err := r.db.Exec("INSERT INTO fan (name, gender, birthday, zodiac, created_at) VALUES (?, ?, ?, ?, NOW())",
        req.Name, nullOr(req.Gender), nullOr(req.Birthday), nullOr(req.Zodiac))
    if err != nil {
        return Fan{}, err
    }
    id, err := res.LastInsertId()
    if err != nil {
        return Fan{}, err
    }
    f, ok, err := r.Get(id)
    if err != nil { return Fan{}, err }
    if !ok { return Fan{}, fmt.Errorf("created fan not found") }
    return f, nil
}

// Update updates fields of a fan; returns updated fan.
func (r *SQLRepo) Update(id int64, req UpdateRequest) (Fan, bool, error) {
    // If no fields provided, just return current
    if (req.Name == "" && req.Gender == "" && req.Birthday == "" && req.Zodiac == "") {
        f, ok, err := r.Get(id)
        return f, ok, err
    }
    // Build dynamic update
    q := "UPDATE fan SET "
    args := make([]interface{}, 0, 5)
    first := true
    add := func(expr string, v interface{}) {
        if !first { q += ", " } else { first = false }
        q += expr
        args = append(args, v)
    }
    if req.Name != "" { add("name = ?", req.Name) }
    if req.Gender != "" { add("gender = ?", req.Gender) }
    if req.Birthday != "" { add("birthday = ?", req.Birthday) }
    if req.Zodiac != "" { add("zodiac = ?", req.Zodiac) }
    q += " WHERE id = ?"
    args = append(args, id)
    res, err := r.db.Exec(q, args...)
    if err != nil {
        return Fan{}, false, err
    }
    if n, _ := res.RowsAffected(); n == 0 {
        // Not found
        return Fan{}, false, nil
    }
    f, ok, err := r.Get(id)
    return f, ok, err
}

// Delete removes a fan by id.
func (r *SQLRepo) Delete(id int64) (bool, error) {
    res, err := r.db.Exec("DELETE FROM fan WHERE id = ?", id)
    if err != nil {
        return false, err
    }
    n, _ := res.RowsAffected()
    return n > 0, nil
}

// nullOr returns nil for empty strings to allow NULL inserts where appropriate.
func nullOr(s string) interface{} {
    if s == "" { return nil }
    return s
}