#!/bin/bash
# knowledge.sh - 知识库管理系统
# 记录问题、解决方案、最佳实践

WORKSPACE="/home/jinyang/.openclaw/workspace"

# 记录问题和解决方案
learn() {
    local problem="$1"
    local solution="$2"
    local agent="${3:-unknown}"
    local success="${4:-true}"
    
    local key="openclaw:knowledge:$(echo "$problem" | tr ' ' '_' | tr '[:upper:]' '[:lower:]')"
    
    redis-cli HSET "$key" \
        problem "$problem" \
        solution "$solution" \
        agent "$agent" \
        success "$success" \
        learned_at "$(date -Iseconds)" \
        count 1 > /dev/null 2>&1
    
    # 增加计数
    redis-cli HINCRBY "$key" count 1 > /dev/null 2>&1
    
    echo "✅ 已学习: $problem -> $solution"
}

# 查询解决方案
query() {
    local problem="$1"
    local key="openclaw:knowledge:$(echo "$problem" | tr ' ' '_' | tr '[:upper:]' '[:lower:]')"
    
    local solution=$(redis-cli HGET "$key" solution 2>/dev/null)
    
    if [[ -n "$solution" ]]; then
        echo "$solution"
    else
        echo ""
    fi
}

# 列出所有知识
list() {
    echo "📚 知识库"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    local keys=$(redis-cli KEYS "openclaw:knowledge:*" 2>/dev/null)
    
    for key in $keys; do
        local problem=$(redis-cli HGET "$key" problem 2>/dev/null)
        local solution=$(redis-cli HGET "$key" solution 2>/dev/null)
        local count=$(redis-cli HGET "$key" count 2>/dev/null)
        echo "  [$count] $problem"
        echo "      → $solution"
        echo ""
    done
}

# 导出知识库
export_kb() {
    local output="$WORKSPACE/memory/knowledge-base.md"
    
    cat > "$output" << EOF
# 知识库 - $(date '+%Y-%m-%d %H:%M')

## 问题与解决方案

EOF

    local keys=$(redis-cli KEYS "openclaw:knowledge:*" 2>/dev/null)
    
    for key in $keys; do
        local problem=$(redis-cli HGET "$key" problem 2>/dev/null)
        local solution=$(redis-cli HGET "$key" solution 2>/dev/null)
        local agent=$(redis-cli HGET "$key" agent 2>/dev/null)
        local count=$(redis-cli HGET "$key" count 2>/dev/null)
        
        cat >> "$output" << EOF
### $problem

- **解决方案**: $solution
- **相关 Agent**: $agent
- **出现次数**: $count

EOF
    done
    
    echo "✅ 已导出到: $output"
}

# 主入口
case "${1:-list}" in
    learn)
        learn "$2" "$3" "$4" "$5"
        ;;
    query)
        query "$2"
        ;;
    list)
        list
        ;;
    export)
        export_kb
        ;;
    *)
        echo "用法: $0 [learn|query|list|export]"
        echo ""
        echo "命令:"
        echo "  learn <problem> <solution> [agent] [success]"
        echo "  query <problem>"
        echo "  list"
        echo "  export"
        ;;
esac
