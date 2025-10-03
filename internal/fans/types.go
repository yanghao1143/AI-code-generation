package fans

// Fan represents a fan entity aligned with nlp-spec-automation.
// JSON uses camelCase for consistency with existing modules; OpenAPI checks allow snake/camel.
type Fan struct {
    ID        int64  `json:"id"`
    Name      string `json:"name"`
    Gender    string `json:"gender,omitempty"`
    Birthday  string `json:"birthday,omitempty"`
    Zodiac    string `json:"zodiac,omitempty"`
    CreatedAt string `json:"createdAt"`
}

// CreateRequest defines request body for creating a fan.
type CreateRequest struct {
    Name     string `json:"name" binding:"required"`
    Gender   string `json:"gender"`
    Birthday string `json:"birthday"`
    Zodiac   string `json:"zodiac"`
}

// UpdateRequest defines request body for updating a fan.
type UpdateRequest struct {
    Name     string `json:"name"`
    Gender   string `json:"gender"`
    Birthday string `json:"birthday"`
    Zodiac   string `json:"zodiac"`
}