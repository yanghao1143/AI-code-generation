package fans

import (
    "sort"
    "time"
)

// MemoryRepo is an in-memory repository implementation for Fan.
// It supports simple pagination compatible with SQLRepo's List signature.
type MemoryRepo struct {
    items map[int64]Fan
    nextID int64
}

func NewMemoryRepo() *MemoryRepo { return &MemoryRepo{items: map[int64]Fan{}, nextID: 1} }

func (m *MemoryRepo) List(pageSize int, afterId int64, legacyLimit, legacyOffset int) (items []Fan, total int, nextAfterId int64, hasMore bool, err error) {
    total = len(m.items)
    ids := make([]int64, 0, len(m.items))
    for id := range m.items { ids = append(ids, id) }
    sort.Slice(ids, func(i, j int) bool { return ids[i] < ids[j] })

    // Legacy mode
    if legacyLimit > 0 || legacyOffset > 0 {
        start := legacyOffset
        if start < 0 { start = 0 }
        if start > total { start = total }
        end := start + legacyLimit
        if legacyLimit <= 0 { end = total } else if end > total { end = total }
        sel := ids[start:end]
        items = make([]Fan, 0, len(sel))
        for _, id := range sel { items = append(items, m.items[id]) }
        hasMore = end < total
        if len(sel) > 0 { nextAfterId = sel[len(sel)-1] }
        return
    }

    // Cursor mode
    items = make([]Fan, 0, pageSize)
    for _, id := range ids {
        if afterId > 0 && id <= afterId { continue }
        items = append(items, m.items[id])
        nextAfterId = id
        if pageSize > 0 && len(items) >= pageSize { break }
    }
    hasMore = (pageSize > 0 && len(items) == pageSize)
    return
}

func (m *MemoryRepo) Get(id int64) (Fan, bool, error) {
    f, ok := m.items[id]
    return f, ok, nil
}

func (m *MemoryRepo) Create(req CreateRequest) (Fan, error) {
    id := m.nextID
    m.nextID++
    now := time.Now().Format(time.RFC3339)
    f := Fan{
        ID: id,
        Name: req.Name,
        Gender: req.Gender,
        Birthday: req.Birthday,
        Zodiac: req.Zodiac,
        CreatedAt: now,
    }
    m.items[id] = f
    return f, nil
}

func (m *MemoryRepo) Update(id int64, req UpdateRequest) (Fan, bool, error) {
    f, ok := m.items[id]
    if !ok { return Fan{}, false, nil }
    if req.Name != "" { f.Name = req.Name }
    if req.Gender != "" { f.Gender = req.Gender }
    if req.Birthday != "" { f.Birthday = req.Birthday }
    if req.Zodiac != "" { f.Zodiac = req.Zodiac }
    m.items[id] = f
    return f, true, nil
}

func (m *MemoryRepo) Delete(id int64) (bool, error) {
    if _, ok := m.items[id]; !ok { return false, nil }
    delete(m.items, id)
    return true, nil
}