#!/bin/bash
# knowledge.sh - 知识库系统
# 积累和应用经验知识

WORKSPACE="/home/jinyang/.openclaw/workspace"
REDIS_PREFIX="openclaw:knowledge"

# 颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# 记录知识
record_knowledge() {
    local category="$1"
    local key="$2"
    local value="$3"
    
    redis-cli HSET "${REDIS_PREFIX}:${category}" "$key" "$value" >/dev/null
    redis-cli HINCRBY "${REDIS_PREFIX}:${category}:count" "$key" 1 >/dev/null
    
    echo -e "${GREEN}✓ 知识已记录: [$category] $key${NC}"
}

# 查询知识
query_knowledge() {
    local category="$1"
    local key="$2"
    
    local value=$(redis-cli HGET "${REDIS_PREFIX}:${category}" "$key" 2>/dev/null)
    local count=$(redis-cli HGET "${REDIS_PREFIX}:${category}:count" "$key" 2>/dev/null || echo 0)
    
    if [[ -n "$value" ]]; then
        echo -e "${CYAN}[$category] $key (使用 $count 次):${NC}"
        echo "  $value"
    else
        echo -e "${YELLOW}未找到知识: [$category] $key${NC}"
    fi
}

# 列出所有知识
list_knowledge() {
    local category="${1:-*}"
    
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    📚 知识库                                      ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    local keys=$(redis-cli KEYS "${REDIS_PREFIX}:*" 2>/dev/null | grep -v ":count$" | sort)
    
    for key in $keys; do
        local cat=$(echo "$key" | sed "s/${REDIS_PREFIX}://")
        echo -e "${GREEN}[$cat]${NC}"
        redis-cli HGETALL "$key" 2>/dev/null | while read -r k; do
            read -r v
            local count=$(redis-cli HGET "${key}:count" "$k" 2>/dev/null || echo 0)
            echo "  $k: $v (×$count)"
        done
        echo ""
    done
}

# 应用知识解决问题
apply_knowledge() {
    local problem="$1"
    
    echo -e "${CYAN}🔍 搜索相关知识: $problem${NC}"
    
    # 搜索所有类别
    local found=false
    local keys=$(redis-cli KEYS "${REDIS_PREFIX}:*" 2>/dev/null | grep -v ":count$")
    
    for key in $keys; do
        local matches=$(redis-cli HGETALL "$key" 2>/dev/null | grep -i "$problem")
        if [[ -n "$matches" ]]; then
            local cat=$(echo "$key" | sed "s/${REDIS_PREFIX}://")
            echo -e "${GREEN}找到相关知识 [$cat]:${NC}"
            echo "$matches"
            found=true
        fi
    done
    
    if [[ "$found" == "false" ]]; then
        echo -e "${YELLOW}未找到相关知识${NC}"
    fi
}

# 导出知识库
export_knowledge() {
    local output="${1:-knowledge_export.json}"
    
    echo "{"
    local keys=$(redis-cli KEYS "${REDIS_PREFIX}:*" 2>/dev/null | grep -v ":count$" | sort)
    local first=true
    
    for key in $keys; do
        local cat=$(echo "$key" | sed "s/${REDIS_PREFIX}://")
        [[ "$first" == "false" ]] && echo ","
        first=false
        echo "  \"$cat\": {"
        redis-cli HGETALL "$key" 2>/dev/null | {
            local inner_first=true
            while read -r k; do
                read -r v
                [[ "$inner_first" == "false" ]] && echo ","
                inner_first=false
                echo -n "    \"$k\": \"$v\""
            done
            echo ""
        }
        echo -n "  }"
    done
    echo ""
    echo "}"
}

# 主入口
case "${1:-list}" in
    record|add)
        record_knowledge "$2" "$3" "$4"
        ;;
    query|get)
        query_knowledge "$2" "$3"
        ;;
    list)
        list_knowledge "$2"
        ;;
    apply|search)
        apply_knowledge "$2"
        ;;
    export)
        export_knowledge "$2"
        ;;
    *)
        echo "用法: $0 <command> [args...]"
        echo ""
        echo "命令:"
        echo "  record <category> <key> <value>  - 记录知识"
        echo "  query <category> <key>           - 查询知识"
        echo "  list [category]                  - 列出知识"
        echo "  apply <problem>                  - 应用知识"
        echo "  export [file]                    - 导出知识库"
        ;;
esac
