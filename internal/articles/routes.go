package articles

import (
    "net/http"
    "sort"
    "strconv"
    "strings"

    "github.com/gin-gonic/gin"
    "xingzuo/internal/api"
    "xingzuo/internal/middleware"
    "xingzuo/internal/validation"
)

// RegisterRoutes registers CRUD endpoints for articles.
func RegisterRoutes(r *gin.RouterGroup) {
	r.Use(middleware.RequirePermission("articles"))

	svc := NewService(NewMemoryRepo())

	// Register SSE stream endpoint under the same middleware chain
	RegisterStreamRoutes(r, svc)

    // List articles
    r.GET("", func(c *gin.Context) {
        rid := c.GetString("request_id")
        // Preferred pagination: pageSize, afterId; legacy: limit, offset
        pageSize := CfgListPageSizeDefault()
        if v := strings.TrimSpace(c.Query("pageSize")); v != "" {
            if n, err := strconv.Atoi(v); err == nil && n > 0 {
                if n < CfgListPageSizeMin() {
                    n = CfgListPageSizeMin()
                }
                if n > CfgListPageSizeMax() {
                    n = CfgListPageSizeMax()
                }
                pageSize = n
            }
        }
        legacyLimit := -1
        if v := strings.TrimSpace(c.Query("limit")); v != "" {
            if n, err := strconv.Atoi(v); err == nil && n > 0 {
                legacyLimit = n
            }
        }
        legacyOffset := 0
        if v := strings.TrimSpace(c.Query("offset")); v != "" {
            if n, err := strconv.Atoi(v); err == nil && n >= 0 {
                legacyOffset = n
            }
        }
        afterId := strings.TrimSpace(c.Query("afterId"))
        authorId := strings.TrimSpace(c.Query("authorId"))
        qTitle := strings.TrimSpace(c.Query("qTitle"))
        qContent := strings.TrimSpace(c.Query("qContent"))

        // Load items and apply filters
        all := svc.List()
        filtered := make([]Article, 0, len(all))
        for _, a := range all {
            if authorId != "" && !strings.EqualFold(a.AuthorID, authorId) {
                continue
            }
            if qTitle != "" && !strings.Contains(strings.ToLower(a.Title), strings.ToLower(qTitle)) {
                continue
            }
            if qContent != "" && !strings.Contains(strings.ToLower(a.Content), strings.ToLower(qContent)) {
                continue
            }
            filtered = append(filtered, a)
        }

        // Stable order: newest first by CreatedAt
        sort.Slice(filtered, func(i, j int) bool {
            return strings.Compare(filtered[i].CreatedAt, filtered[j].CreatedAt) > 0
        })

        total := len(filtered)
        start := 0
        size := pageSize

        // Legacy limit/offset takes precedence when provided
        if legacyLimit > 0 || legacyOffset > 0 {
            if legacyLimit > 0 {
                size = legacyLimit
            }
            if legacyOffset > 0 {
                start = legacyOffset
            }
        } else if afterId != "" {
            // Cursor mode: start after the given id
            for idx, a := range filtered {
                if a.ID == afterId {
                    start = idx + 1
                    break
                }
            }
        }

        if start < 0 {
            start = 0
        }
        if start > total {
            start = total
        }
        end := start + size
        if end > total {
            end = total
        }
        items := filtered[start:end]
        hasMore := end < total
        nextAfterId := ""
        if hasMore && len(items) > 0 {
            last := items[len(items)-1]
            nextAfterId = last.ID
        }

        c.JSON(200, api.OK(rid, gin.H{
            "items": items,
            "page": gin.H{
                "pageSize":    size,
                "nextAfterId": nextAfterId,
                "hasMore":     hasMore,
                "total":       total,
            },
        }))
    })

	// Get article by id
	r.GET("/:id", func(c *gin.Context) {
		rid := c.GetString("request_id")
		id := c.Param("id")
		a, ok := svc.Get(id)
		if !ok {
			c.JSON(http.StatusNotFound, api.Err(rid, "E404", "NotFound", "文章不存在", "warning", gin.H{"id": id}))
			return
		}
		c.JSON(200, api.OK(rid, a))
	})

	// Create article
	r.POST("", func(c *gin.Context) {
		rid := c.GetString("request_id")
		var req CreateRequest
		if !validation.BindJSON(c, &req) {
			return
		}
		a := svc.Create(req)
		c.JSON(200, api.OK(rid, a))
	})

	// Update article
	r.PUT("/:id", func(c *gin.Context) {
		rid := c.GetString("request_id")
		id := c.Param("id")
		var req UpdateRequest
		if !validation.BindJSON(c, &req) {
			return
		}
		a, ok := svc.Update(id, req)
		if !ok {
			c.JSON(http.StatusNotFound, api.Err(rid, "E404", "NotFound", "文章不存在", "warning", gin.H{"id": id}))
			return
		}
		c.JSON(200, api.OK(rid, a))
	})

	// Delete article
	r.DELETE("/:id", func(c *gin.Context) {
		rid := c.GetString("request_id")
		id := c.Param("id")
		if !svc.Delete(id) {
			c.JSON(http.StatusNotFound, api.Err(rid, "E404", "NotFound", "文章不存在", "warning", gin.H{"id": id}))
			return
		}
		c.JSON(200, api.OK(rid, gin.H{"deleted": true, "id": id}))
	})
}
