package articles

import (
	"encoding/json"
	"fmt"
	"net/http"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"xingzuo/internal/api"
)

// RegisterStreamRoutes registers SSE streaming endpoint for articles module.
// Supports query param `mode`:
// - mode=example (default): emits demo frames data → :heartbeat → data → event: done
// - mode=list: streams current articles as JSON frames (event: item) then event: done
func RegisterStreamRoutes(r *gin.RouterGroup, svc *Service) {
	r.GET("/stream", func(c *gin.Context) {
		rid := c.GetString("request_id")
		mode := c.Query("mode")
		if mode == "" {
			mode = "example"
		}

		// Optional configurable heartbeat interval in milliseconds
		// Default and bounds from centralized config (env-driven)
		hbms := CfgHeartbeatDefaultMs()
		if q := c.Query("heartbeatMs"); q != "" {
			if v, err := strconv.Atoi(q); err == nil {
				if v < CfgHeartbeatMinMs() {
					v = CfgHeartbeatMinMs()
				} else if v > CfgHeartbeatMaxMs() {
					v = CfgHeartbeatMaxMs()
				}
				hbms = v
			}
		}
		hb := time.Duration(hbms) * time.Millisecond

		c.Writer.Header().Set("Content-Type", "text/event-stream")
		c.Writer.Header().Set("Cache-Control", "no-cache")
		c.Writer.Header().Set("Connection", "keep-alive")

		flusher, ok := c.Writer.(http.Flusher)
		if !ok {
			c.JSON(500, api.Err(rid, "E3001", "StreamError", "SSE不支持", "error", nil))
			return
		}

		if mode == "list" && svc != nil {
			// Structured list filters
			// Backward compatibility: support legacy limit/offset; prefer pageSize/afterId.
			pageSize := 0
			if q := c.Query("pageSize"); q != "" {
				if v, err := strconv.Atoi(q); err == nil {
					if v < ListPageSizeMin {
						v = ListPageSizeMin
					} else if v > ListPageSizeMax {
						v = ListPageSizeMax
					}
					pageSize = v
				}
			} else if q := c.Query("limit"); q != "" { // legacy
				if v, err := strconv.Atoi(q); err == nil {
					if v < ListPageSizeMin {
						v = ListPageSizeMin
					} else if v > ListPageSizeMax {
						v = ListPageSizeMax
					}
					pageSize = v
				}
			}
			legacyOffset := 0
			if q := c.Query("offset"); q != "" { // legacy
				if v, err := strconv.Atoi(q); err == nil && v >= 0 {
					legacyOffset = v
				}
			}

			authorId := c.Query("authorId")
			// Structured search inputs
			qTitle := c.Query("qTitle")
			qContent := c.Query("qContent")
			qTagsRaw := c.Query("qTags") // comma-separated; exact match required
			qTags := make([]string, 0)
			if qTagsRaw != "" {
				for _, t := range strings.Split(qTagsRaw, ",") {
					t = strings.TrimSpace(t)
					if t != "" {
						qTags = append(qTags, t)
					}
				}
			}
			// Exclusion tags (not-tags)
			qNotTagsRaw := c.Query("qNotTags")
			qNotTags := make([]string, 0)
			if qNotTagsRaw != "" {
				for _, t := range strings.Split(qNotTagsRaw, ",") {
					t = strings.TrimSpace(t)
					if t != "" {
						qNotTags = append(qNotTags, t)
					}
				}
			}
			qTagsOp := strings.ToLower(strings.TrimSpace(c.Query("qTagsOp"))) // "all"|"any"
			if qTagsOp != "any" {
				qTagsOp = "all"
			}
			qOp := strings.ToLower(strings.TrimSpace(c.Query("qOp"))) // "or"|"and"
			if qOp != "and" {
				qOp = "or"
			}
			// Legacy q across title/content/tags (contains, case-insensitive) when structured inputs missing
			qLegacy := strings.ToLower(strings.TrimSpace(c.Query("q")))

			// Time window filters (more/less-than relative to now)
			// createdWithinMs: include items with CreatedAt >= now - ms
			// createdOlderThanMs: include items with CreatedAt <= now - ms
			createdWithinMs := 0
			if q := c.Query("createdWithinMs"); q != "" {
				if v, err := strconv.Atoi(q); err == nil && v > 0 {
					createdWithinMs = v
				}
			}
			createdOlderThanMs := 0
			if q := c.Query("createdOlderThanMs"); q != "" {
				if v, err := strconv.Atoi(q); err == nil && v > 0 {
					createdOlderThanMs = v
				}
			}
			// Absolute time range (RFC3339)
			var createdStart time.Time
			var createdEnd time.Time
			createdStartStr := strings.TrimSpace(c.Query("createdStart"))
			createdEndStr := strings.TrimSpace(c.Query("createdEnd"))
			hasCreatedStart := false
			hasCreatedEnd := false
			if createdStartStr != "" {
				if ts, err := time.Parse(time.RFC3339, createdStartStr); err == nil {
					createdStart = ts
					hasCreatedStart = true
				}
			}
			if createdEndStr != "" {
				if ts, err := time.Parse(time.RFC3339, createdEndStr); err == nil {
					createdEnd = ts
					hasCreatedEnd = true
				}
			}
			now := time.Now()

			// Tag weights: format tag:weight, e.g., t1:2,t2:1; threshold by qTagMinWeight
			weights := map[string]int{}
			if wraw := strings.TrimSpace(c.Query("qTagWeights")); wraw != "" {
				for _, p := range strings.Split(wraw, ",") {
					p = strings.TrimSpace(p)
					if p == "" {
						continue
					}
					kv := strings.SplitN(p, ":", 2)
					key := strings.TrimSpace(kv[0])
					val := 0
					if len(kv) == 2 {
						if iv, err := strconv.Atoi(strings.TrimSpace(kv[1])); err == nil {
							val = iv
						}
					}
					if key != "" && val > 0 {
						weights[key] = val
					}
				}
			}
			minWeight := 0
			if q := c.Query("qTagMinWeight"); q != "" {
				if v, err := strconv.Atoi(q); err == nil && v > 0 {
					minWeight = v
				}
			}

			items := svc.List()
			// Ensure deterministic order by CreatedAt then ID
			sort.Slice(items, func(i, j int) bool {
				ti, tj := items[i].CreatedAt, items[j].CreatedAt
				if ti == tj {
					return items[i].ID < items[j].ID
				}
				return ti < tj
			})

			filtered := make([]Article, 0, len(items))
			for _, a := range items {
				if authorId != "" && a.AuthorID != authorId {
					continue
				}
				// Compute field matches
				mTitle := true
				mContent := true
				mTags := true
				anyProvided := false

				if qTitle != "" {
					anyProvided = true
					mTitle = strings.Contains(strings.ToLower(a.Title), strings.ToLower(qTitle))
				}
				if qContent != "" {
					anyProvided = true
					mContent = strings.Contains(strings.ToLower(a.Content), strings.ToLower(qContent))
				}
				if len(qTags) > 0 {
					anyProvided = true
					if qTagsOp == "all" {
						// require all tags present
						have := make(map[string]struct{}, len(a.Tags))
						for _, t := range a.Tags {
							have[t] = struct{}{}
						}
						for _, t := range qTags {
							if _, ok := have[t]; !ok {
								mTags = false
								break
							}
						}
					} else { // any
						mTags = false
						if len(a.Tags) > 0 {
							have := make(map[string]struct{}, len(a.Tags))
							for _, t := range a.Tags {
								have[strings.TrimSpace(t)] = struct{}{}
							}
							for _, t := range qTags {
								if _, ok := have[strings.TrimSpace(t)]; ok {
									mTags = true
									break
								}
							}
						}
					}
				}

				match := true
				if anyProvided {
					if qOp == "and" {
						match = mTitle && mContent && mTags
					} else { // or
						match = mTitle || mContent || mTags
					}
				} else if qLegacy != "" {
					hit := strings.Contains(strings.ToLower(a.Title), qLegacy) ||
						strings.Contains(strings.ToLower(a.Content), qLegacy)
					if !hit && len(a.Tags) > 0 {
						for _, t := range a.Tags {
							if strings.Contains(strings.ToLower(t), qLegacy) {
								hit = true
								break
							}
						}
					}
					match = hit
				}
				// Apply time window filters if provided
				if match && (createdWithinMs > 0 || createdOlderThanMs > 0) {
					if ts, err := time.Parse(time.RFC3339, a.CreatedAt); err == nil {
						if createdWithinMs > 0 {
							if ts.Before(now.Add(-time.Duration(createdWithinMs) * time.Millisecond)) {
								match = false
							}
						}
						if match && createdOlderThanMs > 0 {
							if ts.After(now.Add(-time.Duration(createdOlderThanMs) * time.Millisecond)) {
								match = false
							}
						}
					}
				}
				// Apply absolute time range if provided
				if match && (hasCreatedStart || hasCreatedEnd) {
					if ts, err := time.Parse(time.RFC3339, a.CreatedAt); err == nil {
						if hasCreatedStart && ts.Before(createdStart) {
							match = false
						}
						if match && hasCreatedEnd && ts.After(createdEnd) {
							match = false
						}
					}
				}
				// Exclude not-tags if present
				if match && len(qNotTags) > 0 && len(a.Tags) > 0 {
					excl := make(map[string]struct{}, len(qNotTags))
					for _, t := range qNotTags {
						excl[strings.TrimSpace(t)] = struct{}{}
					}
					for _, t := range a.Tags {
						if _, ok := excl[strings.TrimSpace(t)]; ok {
							match = false
							break
						}
					}
				}
				// Apply tag weights threshold if provided
				if match && minWeight > 0 && len(weights) > 0 && len(a.Tags) > 0 {
					sum := 0
					for _, t := range a.Tags {
						if w, ok := weights[strings.TrimSpace(t)]; ok {
							sum += w
						}
					}
					if sum < minWeight {
						match = false
					}
				}

				if !match {
					continue
				}
				filtered = append(filtered, a)
			}

			// Cursor-based pagination: afterId takes precedence over legacy offset
			start := 0
			if after := c.Query("afterId"); after != "" {
				idx := -1
				for i, a := range filtered {
					if a.ID == after {
						idx = i
						break
					}
				}
				if idx >= 0 {
					start = idx + 1
				} else {
					start = 0
				}
			} else {
				start = legacyOffset
				if start < 0 {
					start = 0
				}
			}
			if start > len(filtered) {
				start = len(filtered)
			}

			end := len(filtered)
			if pageSize > 0 && start+pageSize < end {
				end = start + pageSize
			}
			view := filtered[start:end]

			emitted := make(map[string]struct{}, len(view))
			for _, a := range view {
				emitted[a.ID] = struct{}{}
				b, _ := json.Marshal(a)
				fmt.Fprint(c.Writer, "event: item\n")
				fmt.Fprintf(c.Writer, "data: %s\n\n", string(b))
				flusher.Flush()
				// Emit a heartbeat comment between items
				time.Sleep(hb)
				fmt.Fprint(c.Writer, ":heartbeat\n\n")
				flusher.Flush()
			}

			// Optional follow streaming: keep connection to push newly created matching items
			follow := strings.EqualFold(c.Query("follow"), "true")
			followMaxMs := CfgFollowMaxMsDefault()
			if q := c.Query("followMaxMs"); q != "" {
				if v, err := strconv.Atoi(q); err == nil {
					if v < CfgFollowMaxMsMin() {
						v = CfgFollowMaxMsMin()
					} else if v > CfgFollowMaxMsMax() {
						v = CfgFollowMaxMsMax()
					}
					followMaxMs = v
				}
			}
			// Buffering and batch for follow mode
			bufferMs := CfgFollowBufferMsDefault()
			if q := c.Query("followBufferMs"); q != "" {
				if v, err := strconv.Atoi(q); err == nil && v > 0 {
					bufferMs = v
				}
			}
			batchMax := CfgFollowBatchMaxDefault()
			if q := c.Query("followBatchMax"); q != "" {
				if v, err := strconv.Atoi(q); err == nil && v > 0 {
					batchMax = v
				}
			}
			if follow {
				// Initialize deduper (Redis preferred if configured)
				var dedup Deduper
				if d, err := NewRedisDeduperFromEnv(); err == nil && d != nil {
					dedup = d
				} else {
					dedup = NewMemoryDeduper()
				}
				defer dedup.Close()
				deadline := time.Now().Add(time.Duration(followMaxMs) * time.Millisecond)
				lastFlush := time.Now()
				pending := make([]Article, 0, 8)
				for time.Now().Before(deadline) {
					// Heartbeat tick
					time.Sleep(hb)
					fmt.Fprint(c.Writer, ":heartbeat\n\n")
					flusher.Flush()

					// Check for new items matching filters
					items2 := svc.List()
					sort.Slice(items2, func(i, j int) bool {
						ti, tj := items2[i].CreatedAt, items2[j].CreatedAt
						if ti == tj {
							return items2[i].ID < items2[j].ID
						}
						return ti < tj
					})
					// Apply same filtering
					for _, a := range items2 {
						if _, seen := emitted[a.ID]; seen {
							continue
						}
						if authorId != "" && a.AuthorID != authorId {
							continue
						}
						// recompute match as above (dup logic kept simple)
						mTitle := true
						mContent := true
						mTags := true
						anyProvided2 := false
						if qTitle != "" {
							anyProvided2 = true
							mTitle = strings.Contains(strings.ToLower(a.Title), strings.ToLower(qTitle))
						}
						if qContent != "" {
							anyProvided2 = true
							mContent = strings.Contains(strings.ToLower(a.Content), strings.ToLower(qContent))
						}
						if len(qTags) > 0 {
							anyProvided2 = true
							if qTagsOp == "all" {
								have := make(map[string]struct{}, len(a.Tags))
								for _, t := range a.Tags {
									have[t] = struct{}{}
								}
								for _, t := range qTags {
									if _, ok := have[t]; !ok {
										mTags = false
										break
									}
								}
							} else {
								mTags = false
								if len(a.Tags) > 0 {
									have := make(map[string]struct{}, len(a.Tags))
									for _, t := range a.Tags {
										have[strings.TrimSpace(t)] = struct{}{}
									}
									for _, t := range qTags {
										if _, ok := have[strings.TrimSpace(t)]; ok {
											mTags = true
											break
										}
									}
								}
							}
						}
						match2 := true
						if anyProvided2 {
							if qOp == "and" {
								match2 = mTitle && mContent && mTags
							} else {
								match2 = mTitle || mContent || mTags
							}
						} else if qLegacy != "" {
							hit := strings.Contains(strings.ToLower(a.Title), qLegacy) ||
								strings.Contains(strings.ToLower(a.Content), qLegacy)
							if !hit && len(a.Tags) > 0 {
								for _, t := range a.Tags {
									if strings.Contains(strings.ToLower(t), qLegacy) {
										hit = true
										break
									}
								}
							}
							match2 = hit
						}
						if match2 && (createdWithinMs > 0 || createdOlderThanMs > 0) {
							if ts, err := time.Parse(time.RFC3339, a.CreatedAt); err == nil {
								if createdWithinMs > 0 {
									if ts.Before(now.Add(-time.Duration(createdWithinMs) * time.Millisecond)) {
										match2 = false
									}
								}
								if match2 && createdOlderThanMs > 0 {
									if ts.After(now.Add(-time.Duration(createdOlderThanMs) * time.Millisecond)) {
										match2 = false
									}
								}
							}
						}
						if !match2 {
							continue
						}
						// Exclusion and weights in follow mode
						if len(qNotTags) > 0 && len(a.Tags) > 0 {
							excl := make(map[string]struct{}, len(qNotTags))
							for _, t := range qNotTags {
								excl[strings.TrimSpace(t)] = struct{}{}
							}
							skip := false
							for _, t := range a.Tags {
								if _, ok := excl[strings.TrimSpace(t)]; ok {
									skip = true
									break
								}
							}
							if skip {
								continue
							}
						}
						if minWeight > 0 && len(weights) > 0 && len(a.Tags) > 0 {
							sum := 0
							for _, t := range a.Tags {
								if w, ok := weights[strings.TrimSpace(t)]; ok {
									sum += w
								}
							}
							if sum < minWeight {
								continue
							}
						}
						// buffer new item
						emitted[a.ID] = struct{}{}
						// cross-instance dedupe
						if dedup != nil {
							if dedup.Seen(a.ID) {
								continue
							}
							dedup.Mark(a.ID)
						}
						pending = append(pending, a)
					}
					// flush if buffer window elapsed or batch size reached
					if len(pending) > 0 && (time.Since(lastFlush) >= time.Duration(bufferMs)*time.Millisecond || len(pending) >= batchMax) {
						for _, a := range pending {
							b, _ := json.Marshal(a)
							fmt.Fprint(c.Writer, "event: item\n")
							fmt.Fprintf(c.Writer, "data: %s\n\n", string(b))
						}
						flusher.Flush()
						pending = pending[:0]
						lastFlush = time.Now()
					}
				}
			}

			// Terminate stream
			fmt.Fprint(c.Writer, "event: done\n\n")
			flusher.Flush()
			return
		}

		// Default example frames demonstrating SSE semantics
		fmt.Fprint(c.Writer, "data: part-1\n\n")
		flusher.Flush()

		time.Sleep(hb)
		fmt.Fprint(c.Writer, ":heartbeat\n\n")
		flusher.Flush()

		fmt.Fprint(c.Writer, "data: part-2\n\n")
		flusher.Flush()

		fmt.Fprint(c.Writer, "event: done\n\n")
		flusher.Flush()
	})
}
