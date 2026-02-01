#!/bin/bash
# cache.sh - Redis + 文件双写缓存层

REDIS_PREFIX="openclaw:"
BACKUP_DIR="/home/jinyang/.openclaw/workspace/memory"

# 写入（双写：Redis + 文件）
cache_set() {
    local key="$1"
    local value="$2"
    local redis_key="${REDIS_PREFIX}${key}"
    
    # 写 Redis
    redis-cli SET "$redis_key" "$value" > /dev/null
    
    # 写文件备份
    local file_path="${BACKUP_DIR}/cache_${key//:/\_}.json"
    echo "$value" > "$file_path"
    
    echo "OK: $key"
}

# 读取（优先 Redis，fallback 文件）
cache_get() {
    local key="$1"
    local redis_key="${REDIS_PREFIX}${key}"
    
    # 先查 Redis
    local value=$(redis-cli GET "$redis_key")
    
    if [ -n "$value" ] && [ "$value" != "(nil)" ]; then
        echo "$value"
        return 0
    fi
    
    # Redis 没有，查文件
    local file_path="${BACKUP_DIR}/cache_${key//:/\_}.json"
    if [ -f "$file_path" ]; then
        value=$(cat "$file_path")
        # 恢复到 Redis
        redis-cli SET "$redis_key" "$value" > /dev/null
        echo "$value"
        return 0
    fi
    
    echo ""
    return 1
}

# 追加到列表
cache_push() {
    local key="$1"
    local value="$2"
    local redis_key="${REDIS_PREFIX}${key}"
    
    redis-cli RPUSH "$redis_key" "$value" > /dev/null
    echo "OK: pushed to $key"
}

# 获取列表
cache_list() {
    local key="$1"
    local redis_key="${REDIS_PREFIX}${key}"
    redis-cli LRANGE "$redis_key" 0 -1
}

# 保存当前上下文摘要
save_context() {
    local summary="$1"
    local timestamp=$(date +%s)
    
    cache_set "context:current" "$summary"
    cache_push "context:history" "{\"ts\":$timestamp,\"summary\":\"$summary\"}"
    
    # 同时写到今日日志
    local today=$(date +%Y-%m-%d)
    echo -e "\n## $(date +%H:%M) - 上下文快照\n$summary" >> "${BACKUP_DIR}/${today}.md"
}

# 恢复上下文
restore_context() {
    local ctx=$(cache_get "context:current")
    if [ -n "$ctx" ]; then
        echo "$ctx"
    else
        echo "无缓存上下文"
        return 1
    fi
}

# 健康检查
health_check() {
    local redis_ok=$(redis-cli ping 2>/dev/null)
    if [ "$redis_ok" = "PONG" ]; then
        echo "Redis: OK"
    else
        echo "Redis: FAILED"
        return 1
    fi
    
    if [ -d "$BACKUP_DIR" ]; then
        echo "Backup dir: OK"
    else
        echo "Backup dir: MISSING"
        mkdir -p "$BACKUP_DIR"
    fi
}

# CLI 入口
case "$1" in
    set) cache_set "$2" "$3" ;;
    get) cache_get "$2" ;;
    push) cache_push "$2" "$3" ;;
    list) cache_list "$2" ;;
    save) save_context "$2" ;;
    restore) restore_context ;;
    health) health_check ;;
    *) echo "Usage: cache.sh {set|get|push|list|save|restore|health} [key] [value]" ;;
esac
