#!/bin/bash
# 错误日志记录器 - 监控 OpenClaw 日志并记录错误到 Redis

REDIS_KEY_PREFIX="openclaw:errors"
MAX_ERRORS=100  # 保留最近100条错误

log_error() {
    local timestamp="$1"
    local error_type="$2"
    local message="$3"
    local context="$4"
    
    local error_json=$(jq -n \
        --arg ts "$timestamp" \
        --arg type "$error_type" \
        --arg msg "$message" \
        --arg ctx "$context" \
        '{timestamp: $ts, type: $type, message: $msg, context: $ctx}')
    
    # 添加到错误列表
    redis-cli LPUSH "${REDIS_KEY_PREFIX}:list" "$error_json" > /dev/null
    redis-cli LTRIM "${REDIS_KEY_PREFIX}:list" 0 $((MAX_ERRORS - 1)) > /dev/null
    
    # 更新错误计数
    redis-cli HINCRBY "${REDIS_KEY_PREFIX}:stats" "$error_type" 1 > /dev/null
    redis-cli SET "${REDIS_KEY_PREFIX}:last" "$error_json" > /dev/null
    redis-cli SET "${REDIS_KEY_PREFIX}:last_time" "$timestamp" > /dev/null
}

# 从 stdin 或日志文件读取
parse_logs() {
    while IFS= read -r line; do
        # 检测 400 错误
        if echo "$line" | grep -qE '400.*Improperly formed request|400.*Bad Request'; then
            ts=$(date -Iseconds)
            log_error "$ts" "API_400" "$line" "context_overflow_or_malformed"
            echo "[ERROR LOGGED] 400 at $ts"
        fi
        
        # 检测其他 API 错误
        if echo "$line" | grep -qE 'error.*[45][0-9]{2}'; then
            ts=$(date -Iseconds)
            error_code=$(echo "$line" | grep -oE '[45][0-9]{2}' | head -1)
            log_error "$ts" "API_${error_code}" "$line" "api_error"
        fi
        
        # 检测 context overflow
        if echo "$line" | grep -qiE 'context.*overflow|token.*limit|too many tokens'; then
            ts=$(date -Iseconds)
            log_error "$ts" "CONTEXT_OVERFLOW" "$line" "token_limit_exceeded"
            echo "[ERROR LOGGED] Context overflow at $ts"
        fi
        
        # 检测连接错误
        if echo "$line" | grep -qiE 'ECONNREFUSED|ETIMEDOUT|fetch failed|network error'; then
            ts=$(date -Iseconds)
            log_error "$ts" "NETWORK_ERROR" "$line" "connection_failed"
        fi
    done
}

# 查看错误
show_errors() {
    local count=${1:-10}
    echo "=== 最近 $count 条错误 ==="
    redis-cli LRANGE "${REDIS_KEY_PREFIX}:list" 0 $((count - 1)) | while read -r err; do
        echo "$err" | jq -r '"[\(.timestamp)] \(.type): \(.message | .[0:100])"' 2>/dev/null || echo "$err"
    done
    echo ""
    echo "=== 错误统计 ==="
    redis-cli HGETALL "${REDIS_KEY_PREFIX}:stats"
}

# 清空错误
clear_errors() {
    redis-cli DEL "${REDIS_KEY_PREFIX}:list" "${REDIS_KEY_PREFIX}:stats" "${REDIS_KEY_PREFIX}:last" "${REDIS_KEY_PREFIX}:last_time"
    echo "错误日志已清空"
}

case "$1" in
    watch)
        echo "开始监控 OpenClaw 日志..."
        openclaw logs --follow 2>&1 | parse_logs
        ;;
    show)
        show_errors "${2:-10}"
        ;;
    last)
        redis-cli GET "${REDIS_KEY_PREFIX}:last" | jq .
        ;;
    stats)
        redis-cli HGETALL "${REDIS_KEY_PREFIX}:stats"
        ;;
    clear)
        clear_errors
        ;;
    parse)
        # 从 stdin 解析
        parse_logs
        ;;
    *)
        echo "用法: $0 {watch|show [n]|last|stats|clear|parse}"
        echo "  watch  - 实时监控日志并记录错误"
        echo "  show   - 显示最近 n 条错误 (默认10)"
        echo "  last   - 显示最后一条错误"
        echo "  stats  - 显示错误统计"
        echo "  clear  - 清空错误日志"
        echo "  parse  - 从 stdin 解析日志"
        ;;
esac
