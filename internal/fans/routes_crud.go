package fans

import (
    "net/http"
    "strconv"
    "strings"

    "github.com/gin-gonic/gin"
    api "xingzuo/internal/api"
    dbpkg "xingzuo/internal/db"
    "xingzuo/internal/middleware"
    "xingzuo/internal/validation"
)

// FanRepository abstracts storage operations used by CRUD routes.
type FanRepository interface {
    List(pageSize int, afterId int64, legacyLimit, legacyOffset int) (items []Fan, total int, nextAfterId int64, hasMore bool, err error)
    Get(id int64) (Fan, bool, error)
    Create(req CreateRequest) (Fan, error)
    Update(id int64, req UpdateRequest) (Fan, bool, error)
    Delete(id int64) (bool, error)
}

func newRepo() FanRepository {
    if db := dbpkg.DB(); db != nil {
        return NewSQLRepo(db)
    }
    return NewMemoryRepo()
}

// RegisterCRUDRoutes registers CRUD endpoints for fans entity under /fans.
func RegisterCRUDRoutes(r *gin.RouterGroup) {
    r.Use(middleware.RequirePermission("fans"))

    repo := newRepo()

    // List fans
    r.GET("", func(c *gin.Context) {
        rid := c.GetString("request_id")
        // Pagination: prefer pageSize/afterId; support legacy limit/offset
        pageSize := 10
        if v := strings.TrimSpace(c.Query("pageSize")); v != "" {
            if n, err := strconv.Atoi(v); err == nil && n > 0 {
                if n < 1 { n = 1 }
                if n > 1000 { n = 1000 }
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
        afterId := int64(0)
        if v := strings.TrimSpace(c.Query("afterId")); v != "" {
            if n, err := strconv.ParseInt(v, 10, 64); err == nil && n >= 0 {
                afterId = n
            }
        }

        items, total, nextAfterId, hasMore, err := repo.List(pageSize, afterId, legacyLimit, legacyOffset)
        if err != nil {
            c.JSON(http.StatusInternalServerError, api.Err(rid, "E500", "InternalError", "列表查询失败", "error", gin.H{"detail": err.Error()}))
            return
        }
        c.JSON(200, api.OK(rid, gin.H{
            "items": items,
            "page": gin.H{
                "pageSize":    pageSize,
                "nextAfterId": nextAfterId,
                "hasMore":     hasMore,
                "total":       total,
            },
        }))
    })

    // Get fan by id (use /id/:id to avoid conflict with /:fanId/active_conversation)
    r.GET("/id/:id", func(c *gin.Context) {
        rid := c.GetString("request_id")
        idStr := c.Param("id")
        id, err := strconv.ParseInt(idStr, 10, 64)
        if err != nil || id <= 0 {
            c.JSON(http.StatusBadRequest, api.Err(rid, "E1401", "InvalidArgument", "无效的ID", "warning", gin.H{"id": idStr}))
            return
        }
        f, ok, err := repo.Get(id)
        if err != nil {
            c.JSON(http.StatusInternalServerError, api.Err(rid, "E500", "InternalError", "查询失败", "error", gin.H{"detail": err.Error()}))
            return
        }
        if !ok {
            c.JSON(http.StatusNotFound, api.Err(rid, "E404", "NotFound", "粉丝不存在", "warning", gin.H{"id": id}))
            return
        }
        c.JSON(200, api.OK(rid, f))
    })

    // Create fan
    r.POST("", func(c *gin.Context) {
        rid := c.GetString("request_id")
        var req CreateRequest
        if !validation.BindJSON(c, &req) {
            return
        }
        f, err := repo.Create(req)
        if err != nil {
            c.JSON(http.StatusInternalServerError, api.Err(rid, "E500", "InternalError", "创建失败", "error", gin.H{"detail": err.Error()}))
            return
        }
        c.JSON(200, api.OK(rid, f))
    })

    // Update fan
    r.PUT("/id/:id", func(c *gin.Context) {
        rid := c.GetString("request_id")
        idStr := c.Param("id")
        id, err := strconv.ParseInt(idStr, 10, 64)
        if err != nil || id <= 0 {
            c.JSON(http.StatusBadRequest, api.Err(rid, "E1401", "InvalidArgument", "无效的ID", "warning", gin.H{"id": idStr}))
            return
        }
        var req UpdateRequest
        if !validation.BindJSON(c, &req) {
            return
        }
        f, ok, err := repo.Update(id, req)
        if err != nil {
            c.JSON(http.StatusInternalServerError, api.Err(rid, "E500", "InternalError", "更新失败", "error", gin.H{"detail": err.Error()}))
            return
        }
        if !ok {
            c.JSON(http.StatusNotFound, api.Err(rid, "E404", "NotFound", "粉丝不存在", "warning", gin.H{"id": id}))
            return
        }
        c.JSON(200, api.OK(rid, f))
    })

    // Delete fan
    r.DELETE("/id/:id", func(c *gin.Context) {
        rid := c.GetString("request_id")
        idStr := c.Param("id")
        id, err := strconv.ParseInt(idStr, 10, 64)
        if err != nil || id <= 0 {
            c.JSON(http.StatusBadRequest, api.Err(rid, "E1401", "InvalidArgument", "无效的ID", "warning", gin.H{"id": idStr}))
            return
        }
        ok, err := repo.Delete(id)
        if err != nil {
            c.JSON(http.StatusInternalServerError, api.Err(rid, "E500", "InternalError", "删除失败", "error", gin.H{"detail": err.Error()}))
            return
        }
        if !ok {
            c.JSON(http.StatusNotFound, api.Err(rid, "E404", "NotFound", "粉丝不存在", "warning", gin.H{"id": id}))
            return
        }
        c.JSON(200, api.OK(rid, gin.H{"deleted": true, "id": id}))
    })
}