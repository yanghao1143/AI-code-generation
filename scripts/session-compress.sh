#!/bin/bash
# Session Compress - /new 时自动压缩上下文
# 用法: ./session-compress.sh <action> [session_key] [summary]

set -e

SCRIPT_DIR="$(dirname "$0")"
REDIS_PREFIX="openclaw:session"
PG_DB="openclaw"
PG_USER="openclaw"
PG_PASS="openclaw123"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +%H:%M:%S)]${NC} $1"; }
warn() { echo -e "${YELLOW}[$(date +%H:%M:%S)] WARN:${NC} $1"; }
error() { echo -e "${RED}[$(date +%H:%M:%S)] ERROR:${NC} $1"; }

# 初始化数据库表
init_db() {
    log "初始化 PostgreSQL 会话压缩表..."
    PGPASSWORD=$PG_PASS psql -h localhost -U $PG_USER -d $PG_DB << 'SQL'
-- 会话压缩摘要表
CREATE TABLE IF NOT EXISTS session_summaries (
    id SERIAL PRIMARY KEY,
    session_key VARCHAR(256) NOT NULL,
    summary TEXT NOT NULL,
    context_usage INT DEFAULT 0,
    message_count INT DEFAULT 0,
    compressed_at TIMESTAMP DEFAULT NOW(),
    metadata JSONB DEFAULT '{}',
    UNIQUE(session_key, compressed_at)
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_session_summaries_key ON session_summaries(session_key);
CREATE INDEX IF NOT EXISTS idx_session_summaries_time ON session_summaries(compressed_at DESC);

SELECT 'Tables created successfully' as status;
SQL
    log "数据库初始化完成"
}

# 压缩当前会话并保存
compress() {
    local session_key="${1:-main}"
    local summary="$2"
    local context_usage="${3:-0}"
    local msg_count="${4:-0}"
    local timestamp=$(date +%s)
    local date_str=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [ -z "$summary" ]; then
        error "摘要内容不能为空"
        return 1
    fi
    
    log "压缩会话: $session_key"
    
    # 1. 保存到 Redis (热数据，快速读取)
    redis-cli HSET "${REDIS_PREFIX}:${session_key}:latest" \
        "summary" "$summary" \
        "context_usage" "$context_usage" \
        "message_count" "$msg_count" \
        "compressed_at" "$timestamp" > /dev/null
    
    # 保存到历史列表
    local history_entry=$(cat << EOF
{"ts":$timestamp,"date":"$date_str","ctx":$context_usage,"msgs":$msg_count}
EOF
)
    redis-cli LPUSH "${REDIS_PREFIX}:${session_key}:history" "$history_entry" > /dev/null
    redis-cli LTRIM "${REDIS_PREFIX}:${session_key}:history" 0 19 > /dev/null  # 保留最近20条
    
    # 2. 保存到 PostgreSQL (持久化归档)
    local escaped_summary=$(echo "$summary" | sed "s/'/''/g")
    PGPASSWORD=$PG_PASS psql -h localhost -U $PG_USER -d $PG_DB -c "
INSERT INTO session_summaries (session_key, summary, context_usage, message_count)
VALUES ('$session_key', '$escaped_summary', $context_usage, $msg_count);
" 2>/dev/null
    
    # 3. 写入 MEMORY.md (OpenClaw 自动加载)
    local workspace_dir="${WORKSPACE_DIR:-$HOME/.openclaw/workspace}"
    local memory_file="$workspace_dir/MEMORY.md"
    
    if [ -f "$memory_file" ]; then
        # 创建摘要块
        local summary_block="<!-- LAST_SESSION_START -->
## 🔄 上次会话摘要
**更新时间**: $date_str
**会话**: $session_key
**上下文**: ${context_usage}%

$summary
<!-- LAST_SESSION_END -->"
        
        # 检查是否已有摘要块
        if grep -q "<!-- LAST_SESSION_START -->" "$memory_file"; then
            # 替换现有摘要块
            local temp_file=$(mktemp)
            awk '
                /<!-- LAST_SESSION_START -->/ { skip=1; next }
                /<!-- LAST_SESSION_END -->/ { skip=0; next }
                !skip { print }
            ' "$memory_file" > "$temp_file"
            
            # 在文件开头插入新摘要
            echo "$summary_block" | cat - "$temp_file" > "$memory_file"
            rm "$temp_file"
        else
            # 在文件开头插入摘要块
            local temp_file=$(mktemp)
            echo "$summary_block" | cat - "$memory_file" > "$temp_file"
            mv "$temp_file" "$memory_file"
        fi
        
        log "已写入 $memory_file"
    fi
    
    echo -e "${GREEN}✓ 会话已压缩并保存${NC}"
    echo "  Redis: ${REDIS_PREFIX}:${session_key}:latest"
    echo "  PostgreSQL: session_summaries"
    echo "  MEMORY.md: $memory_file"
}

# 获取最新的会话摘要
get_latest() {
    local session_key="${1:-main}"
    
    # 优先从 Redis 读取
    local summary=$(redis-cli HGET "${REDIS_PREFIX}:${session_key}:latest" "summary" 2>/dev/null)
    
    if [ -n "$summary" ] && [ "$summary" != "(nil)" ]; then
        local ctx=$(redis-cli HGET "${REDIS_PREFIX}:${session_key}:latest" "context_usage" 2>/dev/null)
        local ts=$(redis-cli HGET "${REDIS_PREFIX}:${session_key}:latest" "compressed_at" 2>/dev/null)
        local date_str=$(date -d "@$ts" '+%Y-%m-%d %H:%M' 2>/dev/null || date -r "$ts" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "unknown")
        
        echo "## 上次会话摘要 ($date_str, 上下文: ${ctx}%)"
        echo ""
        echo "$summary"
        return 0
    fi
    
    # Redis 没有，从 PostgreSQL 读取
    local pg_result=$(PGPASSWORD=$PG_PASS psql -h localhost -U $PG_USER -d $PG_DB -t -A -c "
SELECT summary, context_usage, compressed_at 
FROM session_summaries 
WHERE session_key = '$session_key' 
ORDER BY compressed_at DESC 
LIMIT 1;
" 2>/dev/null)
    
    if [ -n "$pg_result" ]; then
        local pg_summary=$(echo "$pg_result" | cut -d'|' -f1)
        local pg_ctx=$(echo "$pg_result" | cut -d'|' -f2)
        local pg_time=$(echo "$pg_result" | cut -d'|' -f3)
        
        echo "## 上次会话摘要 ($pg_time, 上下文: ${pg_ctx}%)"
        echo ""
        echo "$pg_summary"
        return 0
    fi
    
    echo "无历史摘要"
    return 1
}

# 获取会话历史
get_history() {
    local session_key="${1:-main}"
    local limit="${2:-5}"
    
    echo -e "${BLUE}=== 会话压缩历史 ($session_key) ===${NC}"
    echo ""
    
    # 从 PostgreSQL 获取详细历史
    PGPASSWORD=$PG_PASS psql -h localhost -U $PG_USER -d $PG_DB -c "
SELECT 
    compressed_at as \"时间\",
    context_usage as \"上下文%\",
    message_count as \"消息数\",
    LEFT(summary, 100) as \"摘要预览\"
FROM session_summaries 
WHERE session_key = '$session_key' 
ORDER BY compressed_at DESC 
LIMIT $limit;
" 2>/dev/null
}

# 自动压缩 - 检测上下文使用率并压缩
auto_compress() {
    local session_key="${1:-main}"
    local threshold="${2:-60}"
    
    # 获取当前上下文使用率
    local usage=$(redis-cli HGET "openclaw:agent:main:state" "context_usage" 2>/dev/null || echo "0")
    
    if [ "$usage" -ge "$threshold" ]; then
        warn "上下文使用率 ${usage}% >= ${threshold}%，需要压缩"
        echo "请提供会话摘要后调用: $0 compress $session_key \"<摘要内容>\" $usage"
        return 1
    else
        echo -e "${GREEN}✓ 上下文使用率正常 (${usage}% < ${threshold}%)${NC}"
        return 0
    fi
}

# 清理旧的压缩记录
cleanup() {
    local days="${1:-30}"
    
    log "清理 ${days} 天前的压缩记录..."
    
    PGPASSWORD=$PG_PASS psql -h localhost -U $PG_USER -d $PG_DB -c "
DELETE FROM session_summaries 
WHERE compressed_at < NOW() - INTERVAL '$days days';
" 2>/dev/null
    
    echo -e "${GREEN}✓ 清理完成${NC}"
}

# 状态报告
status() {
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║      Session Compress Status           ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo ""
    
    # Redis 状态
    echo -e "${YELLOW}Redis 缓存:${NC}"
    local redis_keys=$(redis-cli KEYS "${REDIS_PREFIX}:*:latest" 2>/dev/null | wc -l)
    echo "  活跃会话摘要: $redis_keys 个"
    
    # PostgreSQL 状态
    echo ""
    echo -e "${YELLOW}PostgreSQL 归档:${NC}"
    local pg_count=$(PGPASSWORD=$PG_PASS psql -h localhost -U $PG_USER -d $PG_DB -t -A -c "SELECT COUNT(*) FROM session_summaries;" 2>/dev/null || echo "0")
    local pg_sessions=$(PGPASSWORD=$PG_PASS psql -h localhost -U $PG_USER -d $PG_DB -t -A -c "SELECT COUNT(DISTINCT session_key) FROM session_summaries;" 2>/dev/null || echo "0")
    echo "  总压缩记录: $pg_count 条"
    echo "  不同会话: $pg_sessions 个"
    
    # 最近压缩
    echo ""
    echo -e "${YELLOW}最近压缩:${NC}"
    PGPASSWORD=$PG_PASS psql -h localhost -U $PG_USER -d $PG_DB -c "
SELECT session_key, context_usage as ctx, compressed_at 
FROM session_summaries 
ORDER BY compressed_at DESC 
LIMIT 3;
" 2>/dev/null
}

# 主命令
case "${1:-status}" in
    init)
        init_db
        ;;
    compress)
        compress "$2" "$3" "$4" "$5"
        ;;
    get|latest)
        get_latest "$2"
        ;;
    history)
        get_history "$2" "$3"
        ;;
    auto)
        auto_compress "$2" "$3"
        ;;
    cleanup)
        cleanup "$2"
        ;;
    status)
        status
        ;;
    *)
        echo "Session Compress - /new 时自动压缩上下文"
        echo ""
        echo "用法: $0 <command> [args]"
        echo ""
        echo "命令:"
        echo "  init                              初始化数据库表"
        echo "  compress <key> <summary> [ctx%] [msgs]  压缩并保存会话摘要"
        echo "  get|latest <key>                  获取最新摘要"
        echo "  history <key> [limit]             查看压缩历史"
        echo "  auto <key> [threshold]            自动检测并提示压缩"
        echo "  cleanup [days]                    清理旧记录 (默认30天)"
        echo "  status                            状态报告"
        echo ""
        echo "示例:"
        echo "  $0 compress main \"讨论了上下文压缩方案\" 65 50"
        echo "  $0 get main"
        ;;
esac
