package articles

import (
	"time"

	"github.com/google/uuid"
)

// Repository defines storage operations for articles.
type Repository interface {
    List() []Article
    Get(id string) (Article, bool)
    Create(req CreateRequest) Article
    Update(id string, req UpdateRequest) (Article, bool)
    Delete(id string) bool
    Count() int
}

// MemoryRepo is an in-memory repository implementation.
type MemoryRepo struct {
	items map[string]Article
}

func NewMemoryRepo() *MemoryRepo { return &MemoryRepo{items: map[string]Article{}} }

func (m *MemoryRepo) List() []Article {
	out := make([]Article, 0, len(m.items))
	for _, a := range m.items {
		out = append(out, a)
	}
	return out
}

func (m *MemoryRepo) Get(id string) (Article, bool) {
	a, ok := m.items[id]
	return a, ok
}

func (m *MemoryRepo) Create(req CreateRequest) Article {
	now := time.Now().Format(time.RFC3339)
	id := uuid.NewString()
	a := Article{
		ID:        id,
		Title:     req.Title,
		Content:   req.Content,
		AuthorID:  req.AuthorID,
		Tags:      req.Tags,
		CreatedAt: now,
		UpdatedAt: now,
	}
	m.items[id] = a
	return a
}

func (m *MemoryRepo) Update(id string, req UpdateRequest) (Article, bool) {
	a, ok := m.items[id]
	if !ok {
		return Article{}, false
	}
	if req.Title != "" {
		a.Title = req.Title
	}
	if req.Content != "" {
		a.Content = req.Content
	}
	if req.Tags != nil {
		a.Tags = req.Tags
	}
	a.UpdatedAt = time.Now().Format(time.RFC3339)
	m.items[id] = a
	return a, true
}

func (m *MemoryRepo) Delete(id string) bool {
    if _, ok := m.items[id]; !ok {
        return false
    }
    delete(m.items, id)
    return true
}

func (m *MemoryRepo) Count() int { return len(m.items) }
