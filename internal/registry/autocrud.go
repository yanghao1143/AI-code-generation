package registry

import (
    "strings"

    "github.com/gin-gonic/gin"
    m "xingzuo/internal/model"
)

// RegisterAutoCRUD registers placeholder CRUD endpoints for each entity in the DomainModel.
// This provides automatic API registration from parsed domain without requiring manual route wiring.
// Endpoints return 501 Not Implemented with basic metadata; integrate with services/repositories later.
//
// Routes created per entity (snake_case plural):
//   GET    /api/v1/<entities>          # list
//   POST   /api/v1/<entities>          # create
//   GET    /api/v1/<entities>/:id      # get one
//   PUT    /api/v1/<entities>/:id      # update
//   DELETE /api/v1/<entities>/:id      # delete
func RegisterAutoCRUD(r *gin.RouterGroup, dm m.DomainModel) {
    if r == nil { return }
    for _, e := range dm.Entities {
        // build plural resource path
        ent := strings.ToLower(m.SnakeCase(e.Name))
        if !strings.HasSuffix(ent, "s") { ent += "s" }
        base := "/api/v1/" + ent
        idp := base + "/:id"

        // capture entity name for handlers
        en := e.Name

        r.GET(base, func(c *gin.Context) {
            c.JSON(501, gin.H{
                "code":      "NotImplemented",
                "message":   "auto-crud list placeholder",
                "requestId": c.GetString("request_id"),
                "detail": gin.H{"entity": en, "op": "list"},
            })
        })
        r.POST(base, func(c *gin.Context) {
            c.JSON(501, gin.H{
                "code":      "NotImplemented",
                "message":   "auto-crud create placeholder",
                "requestId": c.GetString("request_id"),
                "detail": gin.H{"entity": en, "op": "create"},
            })
        })
        r.GET(idp, func(c *gin.Context) {
            c.JSON(501, gin.H{
                "code":      "NotImplemented",
                "message":   "auto-crud get placeholder",
                "requestId": c.GetString("request_id"),
                "detail": gin.H{"entity": en, "op": "get", "id": c.Param("id")},
            })
        })
        r.PUT(idp, func(c *gin.Context) {
            c.JSON(501, gin.H{
                "code":      "NotImplemented",
                "message":   "auto-crud update placeholder",
                "requestId": c.GetString("request_id"),
                "detail": gin.H{"entity": en, "op": "update", "id": c.Param("id")},
            })
        })
        r.DELETE(idp, func(c *gin.Context) {
            c.JSON(501, gin.H{
                "code":      "NotImplemented",
                "message":   "auto-crud delete placeholder",
                "requestId": c.GetString("request_id"),
                "detail": gin.H{"entity": en, "op": "delete", "id": c.Param("id")},
            })
        })
    }
}