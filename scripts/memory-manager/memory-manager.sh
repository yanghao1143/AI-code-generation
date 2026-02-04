#!/bin/bash
# memory-manager.sh - MEMORY.md 自动管理系统
# 解决 MEMORY.md 过大问题，自动归档旧记录

set -e

WORKSPACE="/home/jinyang/.openclaw/workspace"
MEMORY_FILE="$WORKSPACE/MEMORY.md"
ARCHIVE_DIR="$WORKSPACE/memory/archive"
MAX_SIZE=18000  # 保留 2000 字符缓冲
LOG_FILE="/tmp/memory-manager.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# 获取文件大小
get_size() {
    wc -c < "$MEMORY_FILE" 2>/dev/null || echo 0
}

# 提取日期标记的章节
extract_sections() {
    # 提取所有 ### 开头的章节及其日期
    grep -n "^### [0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}" "$MEMORY_FILE" 2>/dev/null || true
}

# 归档旧章节
archive_old_sections() {
    local current_size=$(get_size)
    
    if [[ "$current_size" -lt "$MAX_SIZE" ]]; then
        log "Size OK: $current_size < $MAX_SIZE"
        return 0
    fi
    
    log "Size exceeded: $current_size > $MAX_SIZE, starting archive..."
    
    # 获取今天和昨天的日期
    local today=$(date +%Y-%m-%d)
    local yesterday=$(date -d "yesterday" +%Y-%m-%d 2>/dev/null || date -v-1d +%Y-%m-%d 2>/dev/null)
    
    # 创建归档文件
    local archive_file="$ARCHIVE_DIR/memory-$(date +%Y-%m).md"
    
    # 读取文件内容
    local content=$(cat "$MEMORY_FILE")
    
    # 分离头部（核心规则等）和日志部分
    # 头部是从开始到第一个 "### 20" 之前
    local header=$(echo "$content" | sed -n '1,/^### 20/p' | head -n -1)
    local logs=$(echo "$content" | sed -n '/^### 20/,$p')
    
    # 保留最近 7 天的日志
    local keep_date=$(date -d "7 days ago" +%Y-%m-%d 2>/dev/null || date -v-7d +%Y-%m-%d 2>/dev/null)
    
    # 分离要保留的和要归档的
    local to_keep=""
    local to_archive=""
    local current_section=""
    local current_date=""
    local in_section=false
    
    while IFS= read -r line; do
        if [[ "$line" =~ ^###\ ([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
            # 新章节开始
            if [[ -n "$current_section" ]]; then
                # 保存上一个章节
                if [[ "$current_date" > "$keep_date" ]] || [[ "$current_date" == "$keep_date" ]]; then
                    to_keep+="$current_section"
                else
                    to_archive+="$current_section"
                fi
            fi
            current_date="${BASH_REMATCH[1]}"
            current_section="$line"$'\n'
            in_section=true
        elif [[ "$in_section" == true ]]; then
            current_section+="$line"$'\n'
        fi
    done <<< "$logs"
    
    # 处理最后一个章节
    if [[ -n "$current_section" ]]; then
        if [[ "$current_date" > "$keep_date" ]] || [[ "$current_date" == "$keep_date" ]]; then
            to_keep+="$current_section"
        else
            to_archive+="$current_section"
        fi
    fi
    
    # 写入归档文件
    if [[ -n "$to_archive" ]]; then
        echo -e "\n# Archived from MEMORY.md - $(date +%Y-%m-%d)\n" >> "$archive_file"
        echo "$to_archive" >> "$archive_file"
        log "Archived $(echo "$to_archive" | wc -c) bytes to $archive_file"
    fi
    
    # 重写 MEMORY.md
    echo "$header" > "$MEMORY_FILE"
    echo "" >> "$MEMORY_FILE"
    echo "$to_keep" >> "$MEMORY_FILE"
    
    local new_size=$(get_size)
    log "New size: $new_size (was $current_size)"
    
    # 如果还是太大，进一步压缩
    if [[ "$new_size" -gt "$MAX_SIZE" ]]; then
        log "Still too large, keeping only last 3 days..."
        compress_further
    fi
}

# 进一步压缩
compress_further() {
    local keep_date=$(date -d "3 days ago" +%Y-%m-%d 2>/dev/null || date -v-3d +%Y-%m-%d 2>/dev/null)
    
    # 只保留核心规则和最近 3 天
    local content=$(cat "$MEMORY_FILE")
    local header=$(echo "$content" | sed -n '1,/^---$/p')
    
    # 提取最近 3 天的日志
    local recent_logs=""
    local in_recent=false
    
    while IFS= read -r line; do
        if [[ "$line" =~ ^###\ ([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
            local date="${BASH_REMATCH[1]}"
            if [[ "$date" > "$keep_date" ]]; then
                in_recent=true
            else
                in_recent=false
            fi
        fi
        if [[ "$in_recent" == true ]]; then
            recent_logs+="$line"$'\n'
        fi
    done <<< "$content"
    
    echo "$header" > "$MEMORY_FILE"
    echo "" >> "$MEMORY_FILE"
    echo "## 历史记录" >> "$MEMORY_FILE"
    echo "" >> "$MEMORY_FILE"
    echo "$recent_logs" >> "$MEMORY_FILE"
    
    log "Compressed to $(get_size) bytes"
}

# 创建 Redis 索引
create_index() {
    # 为归档文件创建 Redis 索引，方便快速检索
    for archive in "$ARCHIVE_DIR"/*.md; do
        [[ -f "$archive" ]] || continue
        local filename=$(basename "$archive")
        
        # 提取所有日期
        local dates=$(grep -oE "^### [0-9]{4}-[0-9]{2}-[0-9]{2}" "$archive" | cut -d' ' -f2 | sort -u)
        
        for date in $dates; do
            redis-cli HSET "memory:index:$date" "file" "$filename" EX 2592000 >/dev/null 2>&1
        done
    done
    
    log "Index updated"
}

# 主函数
main() {
    log "=== Memory Manager started ==="
    
    archive_old_sections
    create_index
    
    log "=== Memory Manager completed ==="
    
    echo "Current size: $(get_size) bytes"
}

main "$@"
