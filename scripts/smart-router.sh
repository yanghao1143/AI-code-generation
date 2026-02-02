#!/bin/bash
# 智能任务路由器 - 基于 claude-code-router 思想
# 根据任务类型、优先级、负载情况智能调度

REDIS_PREFIX="openclaw"

# 模型配置 - 效率和质量优先
MODEL_DEFAULT="opus"        # 默认用最强模型
MODEL_BACKGROUND="sonnet"   # 后台任务也用强模型
MODEL_THINK="opus"          # 深度思考用最强
MODEL_FAST="sonnet"         # 快速响应用中等

# 负载阈值
MAX_CONCURRENT_TASKS=3      # 最大并发任务
LOAD_CHECK_INTERVAL=30      # 负载检查间隔(秒)
TASK_TIMEOUT=300            # 任务超时(秒)

# 获取当前负载
get_load() {
    local running=0
    for pane in claude-agent gemini-agent codex-agent; do
        status=$(redis-cli HGET "${REDIS_PREFIX}:agent:${pane}:state" "status")
        if [ "$status" = "WORKING" ]; then
            running=$((running + 1))
        fi
    done
    echo $running
}

# 检查是否过载
is_overloaded() {
    local load=$(get_load)
    if [ $load -ge $MAX_CONCURRENT_TASKS ]; then
        return 0  # true, 过载
    fi
    return 1  # false, 正常
}

# 根据任务类型选择模型
select_model() {
    local task_type="$1"
    local priority="$2"
    
    case "$task_type" in
        background|cleanup|monitor)
            echo "$MODEL_BACKGROUND"
            ;;
        think|analyze|architecture|review)
            echo "$MODEL_THINK"
            ;;
        quick|unblock|check)
            echo "$MODEL_FAST"
            ;;
        *)
            # 根据优先级选择
            case "$priority" in
                1) echo "$MODEL_FAST" ;;
                4) echo "$MODEL_BACKGROUND" ;;
                *) echo "$MODEL_DEFAULT" ;;
            esac
            ;;
    esac
}

# 智能调度 - 考虑负载
smart_schedule() {
    # 检查负载
    if is_overloaded; then
        echo "OVERLOADED"
        return 1
    fi
    
    # 获取下一个任务
    local task=$(redis-cli RPOP "${REDIS_PREFIX}:task:queue")
    if [ -z "$task" ]; then
        echo "NO_TASK"
        return 0
    fi
    
    # 解析任务
    local task_type=$(echo "$task" | grep -o '"type":"[^"]*"' | cut -d'"' -f4)
    local task_desc=$(echo "$task" | grep -o '"desc":"[^"]*"' | cut -d'"' -f4)
    local priority=$(echo "$task" | grep -o '"priority":"[^"]*"' | cut -d'"' -f4)
    
    task_type=${task_type:-general}
    priority=${priority:-3}
    
    # 选择模型
    local model=$(select_model "$task_type" "$priority")
    
    # 记录路由决策
    redis-cli LPUSH "${REDIS_PREFIX}:router:log" \
        "{\"task\":\"$task_desc\",\"type\":\"$task_type\",\"model\":\"$model\",\"ts\":$(date +%s)}" > /dev/null
    redis-cli LTRIM "${REDIS_PREFIX}:router:log" 0 99 > /dev/null
    
    echo "ROUTE:$model:$task_desc"
}

# 负载均衡 - 分配到最空闲的 agent
balance_load() {
    local task="$1"
    local preferred="$2"
    
    # 如果指定了 agent 且空闲，直接分配
    if [ -n "$preferred" ] && [ "$preferred" != "auto" ]; then
        local status=$(redis-cli HGET "${REDIS_PREFIX}:agent:${preferred}:state" "status")
        if [ "$status" = "IDLE" ]; then
            echo "$preferred"
            return
        fi
    fi
    
    # 找最空闲的 agent (考虑最近任务数)
    local best_agent=""
    local min_tasks=999
    
    for pane in claude-agent gemini-agent codex-agent; do
        local status=$(redis-cli HGET "${REDIS_PREFIX}:agent:${pane}:state" "status")
        if [ "$status" = "IDLE" ]; then
            local recent=$(redis-cli HGET "${REDIS_PREFIX}:agent:${pane}:state" "recent_tasks")
            recent=${recent:-0}
            if [ $recent -lt $min_tasks ]; then
                min_tasks=$recent
                best_agent="$pane"
            fi
        fi
    done
    
    echo "$best_agent"
}

# 节流控制 - 防止任务风暴
throttle() {
    local last_schedule=$(redis-cli GET "${REDIS_PREFIX}:scheduler:last_run")
    local now=$(date +%s)
    
    if [ -n "$last_schedule" ]; then
        local elapsed=$((now - last_schedule))
        if [ $elapsed -lt 5 ]; then
            # 5秒内不重复调度
            return 1
        fi
    fi
    
    redis-cli SET "${REDIS_PREFIX}:scheduler:last_run" "$now" EX 60 > /dev/null
    return 0
}

# 状态报告
status() {
    echo "╔════════════════════════════════════════╗"
    echo "║       智能任务路由器状态               ║"
    echo "╚════════════════════════════════════════╝"
    echo ""
    
    local load=$(get_load)
    echo "当前负载: $load / $MAX_CONCURRENT_TASKS"
    
    if is_overloaded; then
        echo "状态: 🔴 过载"
    else
        echo "状态: 🟢 正常"
    fi
    
    echo ""
    echo "Agent 状态:"
    for pane in claude-agent gemini-agent codex-agent; do
        local status=$(redis-cli HGET "${REDIS_PREFIX}:agent:${pane}:state" "status")
        local recent=$(redis-cli HGET "${REDIS_PREFIX}:agent:${pane}:state" "recent_tasks")
        printf "  %-15s %-10s (最近任务: %s)\n" "$pane" "$status" "${recent:-0}"
    done
    
    echo ""
    echo "任务队列: $(redis-cli LLEN "${REDIS_PREFIX}:task:queue") 个"
    
    echo ""
    echo "最近路由决策:"
    redis-cli LRANGE "${REDIS_PREFIX}:router:log" 0 4 | while read line; do
        echo "  $line"
    done
}

# 主命令
case "$1" in
    schedule)
        if throttle; then
            smart_schedule
        else
            echo "THROTTLED"
        fi
        ;;
    balance)
        balance_load "$2" "$3"
        ;;
    load)
        get_load
        ;;
    status)
        status
        ;;
    *)
        echo "智能任务路由器"
        echo ""
        echo "用法: $0 <command>"
        echo ""
        echo "命令:"
        echo "  schedule          智能调度下一个任务"
        echo "  balance <task>    负载均衡分配"
        echo "  load              获取当前负载"
        echo "  status            状态报告"
        ;;
esac
