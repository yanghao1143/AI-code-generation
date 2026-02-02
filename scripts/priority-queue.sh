#!/bin/bash
# priority-queue.sh - 智能任务优先级队列
# 功能: 根据任务类型、紧急程度、依赖关系智能排序

REDIS_PREFIX="openclaw:tasks"

# 优先级定义 (数字越小优先级越高)
declare -A PRIORITY_MAP=(
    ["critical"]=1      # 紧急修复
    ["bug"]=2           # Bug 修复
    ["compile"]=3       # 编译错误
    ["test"]=4          # 测试失败
    ["feature"]=5       # 新功能
    ["i18n"]=6          # 国际化
    ["refactor"]=7      # 重构
    ["cleanup"]=8       # 清理
    ["docs"]=9          # 文档
    ["default"]=10      # 默认
)

# Agent 专长映射
declare -A AGENT_SPECIALTY=(
    ["claude-agent"]="i18n,refactor,backend,algorithm,review,critical"
    ["gemini-agent"]="i18n,frontend,ui,architecture,design,feature"
    ["codex-agent"]="cleanup,test,fix,optimize,debug,compile,bug"
)

# 添加任务
add_task() {
    local task="$1"
    local type="${2:-default}"
    local agent="${3:-any}"  # 指定 agent 或 any
    local priority="${PRIORITY_MAP[$type]:-10}"
    local id=$(date +%s%N | md5sum | head -c 8)
    local timestamp=$(date +%s)
    
    # 存储任务详情
    redis-cli HSET "$REDIS_PREFIX:task:$id" \
        "task" "$task" \
        "type" "$type" \
        "priority" "$priority" \
        "agent" "$agent" \
        "status" "pending" \
        "created" "$timestamp" >/dev/null 2>&1
    
    # 添加到优先级队列 (sorted set, score = priority * 1000000 + timestamp)
    local score=$((priority * 1000000 + timestamp))
    redis-cli ZADD "$REDIS_PREFIX:queue" "$score" "$id" >/dev/null 2>&1
    
    echo "✅ 任务已添加: $id (优先级: $priority, 类型: $type)"
}

# 获取下一个任务 (为指定 agent)
get_next_task() {
    local agent="$1"
    local specialty="${AGENT_SPECIALTY[$agent]}"
    
    # 获取所有待处理任务
    local task_ids=$(redis-cli ZRANGE "$REDIS_PREFIX:queue" 0 -1 2>/dev/null)
    
    for id in $task_ids; do
        local task_agent=$(redis-cli HGET "$REDIS_PREFIX:task:$id" "agent" 2>/dev/null)
        local task_type=$(redis-cli HGET "$REDIS_PREFIX:task:$id" "type" 2>/dev/null)
        local status=$(redis-cli HGET "$REDIS_PREFIX:task:$id" "status" 2>/dev/null)
        
        # 跳过非 pending 状态
        [[ "$status" != "pending" ]] && continue
        
        # 检查是否匹配
        if [[ "$task_agent" == "any" || "$task_agent" == "$agent" ]]; then
            # 检查专长匹配
            if [[ "$task_agent" == "any" && -n "$specialty" ]]; then
                if ! echo "$specialty" | grep -q "$task_type"; then
                    continue  # 不匹配专长，跳过
                fi
            fi
            
            # 找到匹配任务
            local task=$(redis-cli HGET "$REDIS_PREFIX:task:$id" "task" 2>/dev/null)
            
            # 更新状态
            redis-cli HSET "$REDIS_PREFIX:task:$id" "status" "in_progress" "assigned" "$agent" "started" "$(date +%s)" >/dev/null 2>&1
            redis-cli ZREM "$REDIS_PREFIX:queue" "$id" >/dev/null 2>&1
            
            echo "$task"
            return 0
        fi
    done
    
    # 没有匹配任务
    return 1
}

# 完成任务
complete_task() {
    local id="$1"
    redis-cli HSET "$REDIS_PREFIX:task:$id" "status" "completed" "completed" "$(date +%s)" >/dev/null 2>&1
    echo "✅ 任务 $id 已完成"
}

# 列出任务
list_tasks() {
    local filter="${1:-all}"  # all, pending, in_progress, completed
    
    echo "===== 任务列表 ($filter) ====="
    
    # 从队列获取
    local queue_ids=$(redis-cli ZRANGE "$REDIS_PREFIX:queue" 0 -1 2>/dev/null)
    
    # 从所有任务 key 获取
    local all_ids=$(redis-cli KEYS "$REDIS_PREFIX:task:*" 2>/dev/null | sed "s|$REDIS_PREFIX:task:||g")
    
    for id in $all_ids; do
        local status=$(redis-cli HGET "$REDIS_PREFIX:task:$id" "status" 2>/dev/null)
        
        if [[ "$filter" != "all" && "$status" != "$filter" ]]; then
            continue
        fi
        
        local task=$(redis-cli HGET "$REDIS_PREFIX:task:$id" "task" 2>/dev/null)
        local type=$(redis-cli HGET "$REDIS_PREFIX:task:$id" "type" 2>/dev/null)
        local priority=$(redis-cli HGET "$REDIS_PREFIX:task:$id" "priority" 2>/dev/null)
        local agent=$(redis-cli HGET "$REDIS_PREFIX:task:$id" "agent" 2>/dev/null)
        
        local status_icon="❓"
        case "$status" in
            pending) status_icon="⏳" ;;
            in_progress) status_icon="🔄" ;;
            completed) status_icon="✅" ;;
        esac
        
        printf "%s [%s] P%s %-10s %-12s %s\n" "$status_icon" "$id" "$priority" "$type" "$agent" "${task:0:50}"
    done
}

# 清理已完成任务
cleanup() {
    local count=0
    local all_ids=$(redis-cli KEYS "$REDIS_PREFIX:task:*" 2>/dev/null | sed "s|$REDIS_PREFIX:task:||g")
    
    for id in $all_ids; do
        local status=$(redis-cli HGET "$REDIS_PREFIX:task:$id" "status" 2>/dev/null)
        if [[ "$status" == "completed" ]]; then
            redis-cli DEL "$REDIS_PREFIX:task:$id" >/dev/null 2>&1
            ((count++))
        fi
    done
    
    echo "🧹 清理了 $count 个已完成任务"
}

# 统计
stats() {
    local pending=$(redis-cli ZCARD "$REDIS_PREFIX:queue" 2>/dev/null || echo 0)
    local in_progress=0
    local completed=0
    
    local all_ids=$(redis-cli KEYS "$REDIS_PREFIX:task:*" 2>/dev/null | sed "s|$REDIS_PREFIX:task:||g")
    for id in $all_ids; do
        local status=$(redis-cli HGET "$REDIS_PREFIX:task:$id" "status" 2>/dev/null)
        case "$status" in
            in_progress) ((in_progress++)) ;;
            completed) ((completed++)) ;;
        esac
    done
    
    echo "📊 任务统计"
    echo "  待处理: $pending"
    echo "  进行中: $in_progress"
    echo "  已完成: $completed"
}

# 入口
case "${1:-help}" in
    add)
        add_task "$2" "$3" "$4"
        ;;
    get)
        get_next_task "$2"
        ;;
    complete)
        complete_task "$2"
        ;;
    list)
        list_tasks "$2"
        ;;
    cleanup)
        cleanup
        ;;
    stats)
        stats
        ;;
    *)
        echo "用法: $0 {add|get|complete|list|cleanup|stats}"
        echo ""
        echo "  add <task> [type] [agent]  - 添加任务"
        echo "    类型: critical, bug, compile, test, feature, i18n, refactor, cleanup, docs"
        echo "    agent: claude-agent, gemini-agent, codex-agent, any"
        echo ""
        echo "  get <agent>                - 获取下一个任务"
        echo "  complete <id>              - 标记任务完成"
        echo "  list [filter]              - 列出任务 (all, pending, in_progress, completed)"
        echo "  cleanup                    - 清理已完成任务"
        echo "  stats                      - 显示统计"
        ;;
esac
