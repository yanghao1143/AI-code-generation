#!/bin/bash
# task-manager.sh - 统一任务管理器 v1.0
# 功能: 派发任务、追踪状态、超时检测、结果收集

SOCKET="/tmp/openclaw-agents.sock"
REDIS_PREFIX="openclaw:task"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 生成任务 ID
generate_task_id() {
    echo "task-$(date +%s)-$RANDOM"
}

# 派发任务到指定 agent
dispatch_task() {
    local agent="$1"
    local task="$2"
    local timeout="${3:-300}"  # 默认 5 分钟超时
    local task_id=$(generate_task_id)
    
    # 记录任务到 Redis
    redis-cli HSET "${REDIS_PREFIX}:${task_id}" \
        "agent" "$agent" \
        "task" "$task" \
        "status" "dispatched" \
        "timeout" "$timeout" \
        "start_time" "$(date +%s)" \
        "created_at" "$(date -Iseconds)" > /dev/null
    
    # 添加到活跃任务列表
    redis-cli SADD "${REDIS_PREFIX}:active" "$task_id" > /dev/null
    
    # 发送任务到 agent
    # 注意: 先发送文本，再发送 Enter 提交
    tmux -S "$SOCKET" send-keys -t "$agent" "$task" Enter
    sleep 0.3
    # 某些 CLI 需要额外的 Enter 来确认提交
    tmux -S "$SOCKET" send-keys -t "$agent" Enter
    
    echo "$task_id"
}

# 检查任务状态
check_task() {
    local task_id="$1"
    
    local agent=$(redis-cli HGET "${REDIS_PREFIX}:${task_id}" "agent")
    local task=$(redis-cli HGET "${REDIS_PREFIX}:${task_id}" "task")
    local status=$(redis-cli HGET "${REDIS_PREFIX}:${task_id}" "status")
    local start_time=$(redis-cli HGET "${REDIS_PREFIX}:${task_id}" "start_time")
    local timeout=$(redis-cli HGET "${REDIS_PREFIX}:${task_id}" "timeout")
    
    local now=$(date +%s)
    local elapsed=$((now - start_time))
    
    # 检查是否超时
    if [[ "$status" == "dispatched" && $elapsed -gt $timeout ]]; then
        redis-cli HSET "${REDIS_PREFIX}:${task_id}" "status" "timeout" > /dev/null
        status="timeout"
    fi
    
    echo "$task_id|$agent|$status|$elapsed|$timeout"
}

# 获取 agent 最新输出
get_agent_output() {
    local agent="$1"
    local lines="${2:-50}"
    
    tmux -S "$SOCKET" capture-pane -t "$agent" -p | tail -$lines
}

# 标记任务完成
complete_task() {
    local task_id="$1"
    local result="${2:-success}"
    
    redis-cli HSET "${REDIS_PREFIX}:${task_id}" \
        "status" "completed" \
        "result" "$result" \
        "end_time" "$(date +%s)" \
        "completed_at" "$(date -Iseconds)" > /dev/null
    
    # 从活跃列表移除
    redis-cli SREM "${REDIS_PREFIX}:active" "$task_id" > /dev/null
    
    # 添加到完成列表
    redis-cli LPUSH "${REDIS_PREFIX}:completed" "$task_id" > /dev/null
    redis-cli LTRIM "${REDIS_PREFIX}:completed" 0 99 > /dev/null  # 保留最近 100 个
}

# 取消任务
cancel_task() {
    local task_id="$1"
    local agent=$(redis-cli HGET "${REDIS_PREFIX}:${task_id}" "agent")
    
    # 发送 Ctrl+C 中断
    tmux -S "$SOCKET" send-keys -t "$agent" C-c
    
    redis-cli HSET "${REDIS_PREFIX}:${task_id}" \
        "status" "cancelled" \
        "end_time" "$(date +%s)" > /dev/null
    
    redis-cli SREM "${REDIS_PREFIX}:active" "$task_id" > /dev/null
}

# 列出所有活跃任务
list_active_tasks() {
    local tasks=$(redis-cli SMEMBERS "${REDIS_PREFIX}:active")
    
    if [[ -z "$tasks" ]]; then
        echo "没有活跃任务"
        return
    fi
    
    echo "📋 活跃任务列表"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf "%-20s %-15s %-12s %-10s %-10s\n" "Task ID" "Agent" "Status" "Elapsed" "Timeout"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    for task_id in $tasks; do
        IFS='|' read -r id agent status elapsed timeout <<< "$(check_task "$task_id")"
        
        # 颜色
        case "$status" in
            dispatched) color="$BLUE" ;;
            timeout)    color="$RED" ;;
            *)          color="$NC" ;;
        esac
        
        printf "%-20s %-15s ${color}%-12s${NC} %-10s %-10s\n" \
            "$id" "$agent" "$status" "${elapsed}s" "${timeout}s"
    done
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# 智能任务路由 - 选择最佳 agent
route_task() {
    local task_type="$1"
    
    # 根据任务类型选择 agent
    case "$task_type" in
        code|coding|implement|fix|debug)
            echo "codex-agent"
            ;;
        analyze|review|explain|document)
            echo "gemini-agent"
            ;;
        complex|architect|design|plan)
            echo "claude-agent"
            ;;
        *)
            # 默认选择最空闲的 agent
            local min_tasks=999
            local best_agent="claude-agent"
            
            for agent in claude-agent gemini-agent codex-agent; do
                local count=$(redis-cli SCARD "${REDIS_PREFIX}:active:${agent}" 2>/dev/null || echo 0)
                if [[ $count -lt $min_tasks ]]; then
                    min_tasks=$count
                    best_agent=$agent
                fi
            done
            
            echo "$best_agent"
            ;;
    esac
}

# 批量派发任务
batch_dispatch() {
    local task_file="$1"
    
    if [[ ! -f "$task_file" ]]; then
        echo "错误: 任务文件不存在: $task_file"
        return 1
    fi
    
    echo "📤 批量派发任务"
    local count=0
    
    while IFS='|' read -r agent task timeout; do
        [[ -z "$agent" || "$agent" == "#"* ]] && continue
        
        local task_id=$(dispatch_task "$agent" "$task" "$timeout")
        echo "  ✓ $task_id -> $agent"
        ((count++))
        
        sleep 1  # 避免发送太快
    done < "$task_file"
    
    echo "✅ 派发了 $count 个任务"
}

# 清理超时任务
cleanup_timeout_tasks() {
    local tasks=$(redis-cli SMEMBERS "${REDIS_PREFIX}:active")
    local cleaned=0
    
    for task_id in $tasks; do
        IFS='|' read -r id agent status elapsed timeout <<< "$(check_task "$task_id")"
        
        if [[ "$status" == "timeout" ]]; then
            echo "清理超时任务: $task_id ($agent)"
            cancel_task "$task_id"
            ((cleaned++))
        fi
    done
    
    echo "清理了 $cleaned 个超时任务"
}

# 主命令处理
action="${1:-help}"

case "$action" in
    dispatch|send)
        if [[ -z "$2" || -z "$3" ]]; then
            echo "用法: $0 dispatch <agent> <task> [timeout]"
            echo "示例: $0 dispatch claude-agent '分析这段代码' 300"
            exit 1
        fi
        task_id=$(dispatch_task "$2" "$3" "${4:-300}")
        echo "✅ 任务已派发: $task_id"
        ;;
    
    route)
        if [[ -z "$2" || -z "$3" ]]; then
            echo "用法: $0 route <task_type> <task>"
            echo "任务类型: code, analyze, complex, 或其他"
            exit 1
        fi
        agent=$(route_task "$2")
        task_id=$(dispatch_task "$agent" "$3" "${4:-300}")
        echo "✅ 任务已路由到 $agent: $task_id"
        ;;
    
    list|ls)
        list_active_tasks
        ;;
    
    check)
        if [[ -z "$2" ]]; then
            echo "用法: $0 check <task_id>"
            exit 1
        fi
        IFS='|' read -r id agent status elapsed timeout <<< "$(check_task "$2")"
        echo "任务: $id"
        echo "Agent: $agent"
        echo "状态: $status"
        echo "耗时: ${elapsed}s / ${timeout}s"
        ;;
    
    complete)
        if [[ -z "$2" ]]; then
            echo "用法: $0 complete <task_id> [result]"
            exit 1
        fi
        complete_task "$2" "${3:-success}"
        echo "✅ 任务已标记完成: $2"
        ;;
    
    cancel)
        if [[ -z "$2" ]]; then
            echo "用法: $0 cancel <task_id>"
            exit 1
        fi
        cancel_task "$2"
        echo "✅ 任务已取消: $2"
        ;;
    
    output)
        if [[ -z "$2" ]]; then
            echo "用法: $0 output <agent> [lines]"
            exit 1
        fi
        get_agent_output "$2" "${3:-50}"
        ;;
    
    batch)
        if [[ -z "$2" ]]; then
            echo "用法: $0 batch <task_file>"
            echo "文件格式: agent|task|timeout (每行一个任务)"
            exit 1
        fi
        batch_dispatch "$2"
        ;;
    
    cleanup)
        cleanup_timeout_tasks
        ;;
    
    stats)
        echo "📊 任务统计"
        echo "活跃任务: $(redis-cli SCARD "${REDIS_PREFIX}:active" 2>/dev/null || echo 0)"
        echo "已完成: $(redis-cli LLEN "${REDIS_PREFIX}:completed" 2>/dev/null || echo 0)"
        ;;
    
    help|*)
        echo "任务管理器 - 统一管理三个 AI Agent 的任务"
        echo ""
        echo "用法: $0 <command> [args]"
        echo ""
        echo "命令:"
        echo "  dispatch <agent> <task> [timeout]  - 派发任务到指定 agent"
        echo "  route <type> <task> [timeout]      - 智能路由任务到最佳 agent"
        echo "  list                               - 列出所有活跃任务"
        echo "  check <task_id>                    - 检查任务状态"
        echo "  complete <task_id> [result]        - 标记任务完成"
        echo "  cancel <task_id>                   - 取消任务"
        echo "  output <agent> [lines]             - 获取 agent 输出"
        echo "  batch <file>                       - 批量派发任务"
        echo "  cleanup                            - 清理超时任务"
        echo "  stats                              - 显示统计信息"
        echo ""
        echo "任务类型 (用于 route):"
        echo "  code     - 编码任务 -> codex-agent"
        echo "  analyze  - 分析任务 -> gemini-agent"
        echo "  complex  - 复杂任务 -> claude-agent"
        ;;
esac
