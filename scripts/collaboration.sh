#!/bin/bash
# collaboration.sh - Agent 协作协议系统
# 实现 agent 之间的任务交接、依赖管理、结果共享

WORKSPACE="/home/jinyang/.openclaw/workspace"
SOCKET="/tmp/openclaw-agents.sock"
REDIS_PREFIX="openclaw:collab"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# 创建任务依赖
# 用法: create_dependency <task_id> <depends_on_task_id>
create_dependency() {
    local task_id="$1"
    local depends_on="$2"
    redis-cli SADD "${REDIS_PREFIX}:deps:${task_id}" "$depends_on" >/dev/null
    redis-cli SADD "${REDIS_PREFIX}:blocks:${depends_on}" "$task_id" >/dev/null
    echo -e "${GREEN}✓${NC} 依赖创建: $task_id → $depends_on"
}

# 检查依赖是否满足
check_dependencies() {
    local task_id="$1"
    local deps=$(redis-cli SMEMBERS "${REDIS_PREFIX}:deps:${task_id}" 2>/dev/null)
    
    if [[ -z "$deps" ]]; then
        echo "satisfied"
        return 0
    fi
    
    for dep in $deps; do
        local status=$(redis-cli HGET "openclaw:tasks:${dep}" status 2>/dev/null)
        if [[ "$status" != "completed" ]]; then
            echo "blocked:$dep"
            return 1
        fi
    done
    
    echo "satisfied"
    return 0
}

# 任务完成时通知依赖方
notify_completion() {
    local task_id="$1"
    local result="$2"
    
    # 保存结果
    redis-cli HSET "${REDIS_PREFIX}:results:${task_id}" \
        "result" "$result" \
        "completed_at" "$(date +%s)" >/dev/null
    
    # 获取被阻塞的任务
    local blocked=$(redis-cli SMEMBERS "${REDIS_PREFIX}:blocks:${task_id}" 2>/dev/null)
    
    for blocked_task in $blocked; do
        # 检查该任务的所有依赖是否都满足了
        local dep_status=$(check_dependencies "$blocked_task")
        if [[ "$dep_status" == "satisfied" ]]; then
            echo -e "${GREEN}✓${NC} 任务 $blocked_task 的依赖已满足，可以开始执行"
            # 更新任务状态为 ready
            redis-cli HSET "openclaw:tasks:${blocked_task}" status "ready" >/dev/null
        fi
    done
}

# 请求协助 - 一个 agent 请求另一个 agent 帮助
request_help() {
    local from_agent="$1"
    local to_agent="$2"
    local request="$3"
    local context="$4"
    
    local request_id="help-$(date +%s)"
    
    redis-cli HSET "${REDIS_PREFIX}:help:${request_id}" \
        "from" "$from_agent" \
        "to" "$to_agent" \
        "request" "$request" \
        "context" "$context" \
        "status" "pending" \
        "created_at" "$(date +%s)" >/dev/null
    
    # 发送请求到目标 agent
    local msg="[协助请求 from $from_agent] $request"
    if [[ -n "$context" ]]; then
        msg="$msg\n上下文: $context"
    fi
    
    tmux -S "$SOCKET" send-keys -t "$to_agent" "$msg" Enter
    
    echo -e "${CYAN}📨${NC} 协助请求已发送: $from_agent → $to_agent"
    echo "$request_id"
}

# 共享发现 - agent 发现重要信息时共享给其他 agent
share_discovery() {
    local from_agent="$1"
    local discovery_type="$2"  # bug, pattern, solution, warning
    local content="$3"
    
    local discovery_id="disc-$(date +%s)"
    
    redis-cli HSET "${REDIS_PREFIX}:discovery:${discovery_id}" \
        "from" "$from_agent" \
        "type" "$discovery_type" \
        "content" "$content" \
        "created_at" "$(date +%s)" >/dev/null
    
    redis-cli LPUSH "${REDIS_PREFIX}:discoveries" "$discovery_id" >/dev/null
    
    echo -e "${GREEN}💡${NC} 发现已记录: [$discovery_type] $content"
}

# 获取相关发现 - 查询与当前任务相关的发现
get_relevant_discoveries() {
    local keyword="$1"
    local limit="${2:-5}"
    
    local discoveries=$(redis-cli LRANGE "${REDIS_PREFIX}:discoveries" 0 50 2>/dev/null)
    local count=0
    
    echo -e "${CYAN}相关发现:${NC}"
    for disc_id in $discoveries; do
        local content=$(redis-cli HGET "${REDIS_PREFIX}:discovery:${disc_id}" content 2>/dev/null)
        if echo "$content" | grep -qi "$keyword"; then
            local type=$(redis-cli HGET "${REDIS_PREFIX}:discovery:${disc_id}" type 2>/dev/null)
            local from=$(redis-cli HGET "${REDIS_PREFIX}:discovery:${disc_id}" from 2>/dev/null)
            echo -e "  [$type] $from: $content"
            ((count++))
            [[ $count -ge $limit ]] && break
        fi
    done
    
    [[ $count -eq 0 ]] && echo "  (无相关发现)"
}

# 任务交接 - 一个 agent 将任务交给另一个 agent
handoff_task() {
    local from_agent="$1"
    local to_agent="$2"
    local task_id="$3"
    local notes="$4"
    
    # 记录交接
    redis-cli HSET "${REDIS_PREFIX}:handoff:${task_id}" \
        "from" "$from_agent" \
        "to" "$to_agent" \
        "notes" "$notes" \
        "handoff_at" "$(date +%s)" >/dev/null
    
    # 更新任务分配
    redis-cli HSET "openclaw:tasks:${task_id}" assigned_to "$to_agent" >/dev/null
    
    # 通知目标 agent
    local task_desc=$(redis-cli HGET "openclaw:tasks:${task_id}" description 2>/dev/null)
    local msg="[任务交接 from $from_agent] $task_desc"
    if [[ -n "$notes" ]]; then
        msg="$msg\n交接备注: $notes"
    fi
    
    tmux -S "$SOCKET" send-keys -t "$to_agent" "$msg" Enter
    
    echo -e "${GREEN}🔄${NC} 任务已交接: $from_agent → $to_agent"
}

# 同步状态 - 广播当前工作状态给所有 agent
broadcast_status() {
    local from_agent="$1"
    local status="$2"
    
    redis-cli HSET "${REDIS_PREFIX}:status:${from_agent}" \
        "status" "$status" \
        "updated_at" "$(date +%s)" >/dev/null
    
    echo -e "${CYAN}📢${NC} 状态已广播: $from_agent - $status"
}

# 查看协作状态
show_collaboration_status() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    🤝 Agent 协作状态                              ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Agent 状态
    echo -e "${GREEN}Agent 状态:${NC}"
    for agent in claude-agent gemini-agent codex-agent; do
        local status=$(redis-cli HGET "${REDIS_PREFIX}:status:${agent}" status 2>/dev/null)
        local updated=$(redis-cli HGET "${REDIS_PREFIX}:status:${agent}" updated_at 2>/dev/null)
        if [[ -n "$status" ]]; then
            local age=$(($(date +%s) - updated))
            echo -e "  $agent: $status (${age}s ago)"
        else
            echo -e "  $agent: (未知)"
        fi
    done
    echo ""
    
    # 待处理的协助请求
    echo -e "${YELLOW}待处理协助请求:${NC}"
    local help_keys=$(redis-cli KEYS "${REDIS_PREFIX}:help:*" 2>/dev/null)
    local pending_count=0
    for key in $help_keys; do
        local status=$(redis-cli HGET "$key" status 2>/dev/null)
        if [[ "$status" == "pending" ]]; then
            local from=$(redis-cli HGET "$key" from 2>/dev/null)
            local to=$(redis-cli HGET "$key" to 2>/dev/null)
            local request=$(redis-cli HGET "$key" request 2>/dev/null)
            echo -e "  $from → $to: $request"
            ((pending_count++))
        fi
    done
    [[ $pending_count -eq 0 ]] && echo "  (无)"
    echo ""
    
    # 最近发现
    echo -e "${CYAN}最近发现:${NC}"
    local recent=$(redis-cli LRANGE "${REDIS_PREFIX}:discoveries" 0 4 2>/dev/null)
    for disc_id in $recent; do
        local type=$(redis-cli HGET "${REDIS_PREFIX}:discovery:${disc_id}" type 2>/dev/null)
        local from=$(redis-cli HGET "${REDIS_PREFIX}:discovery:${disc_id}" from 2>/dev/null)
        local content=$(redis-cli HGET "${REDIS_PREFIX}:discovery:${disc_id}" content 2>/dev/null)
        echo -e "  [$type] $from: ${content:0:60}..."
    done
    [[ -z "$recent" ]] && echo "  (无)"
}

# 主入口
case "${1:-status}" in
    dep|dependency)
        create_dependency "$2" "$3"
        ;;
    check-dep)
        check_dependencies "$2"
        ;;
    complete)
        notify_completion "$2" "$3"
        ;;
    help)
        request_help "$2" "$3" "$4" "$5"
        ;;
    share)
        share_discovery "$2" "$3" "$4"
        ;;
    discover)
        get_relevant_discoveries "$2" "$3"
        ;;
    handoff)
        handoff_task "$2" "$3" "$4" "$5"
        ;;
    broadcast)
        broadcast_status "$2" "$3"
        ;;
    status)
        show_collaboration_status
        ;;
    *)
        echo "用法: $0 <command> [args...]"
        echo ""
        echo "命令:"
        echo "  status                          - 查看协作状态"
        echo "  dep <task> <depends_on>         - 创建任务依赖"
        echo "  check-dep <task>                - 检查依赖是否满足"
        echo "  complete <task> <result>        - 通知任务完成"
        echo "  help <from> <to> <request> [ctx] - 请求协助"
        echo "  share <agent> <type> <content>  - 共享发现"
        echo "  discover <keyword> [limit]      - 查询相关发现"
        echo "  handoff <from> <to> <task> [notes] - 任务交接"
        echo "  broadcast <agent> <status>      - 广播状态"
        ;;
esac
