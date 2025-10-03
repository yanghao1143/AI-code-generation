package articles

type Article struct {
	ID        string   `json:"id"`
	Title     string   `json:"title"`
	Content   string   `json:"content"`
	AuthorID  string   `json:"authorId"`
	Tags      []string `json:"tags"`
	CreatedAt string   `json:"createdAt"`
	UpdatedAt string   `json:"updatedAt"`
}

type CreateRequest struct {
	Title    string   `json:"title" binding:"required"`
	Content  string   `json:"content" binding:"required"`
	AuthorID string   `json:"authorId" binding:"required"`
	Tags     []string `json:"tags"`
}

type UpdateRequest struct {
	Title   string   `json:"title"`
	Content string   `json:"content"`
	Tags    []string `json:"tags"`
}
