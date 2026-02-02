#!/bin/bash
# auto-dispatch.sh - 自动派活系统
# 检测空闲 agent，从任务队列分配任务

WORKSPACE="/home/jinyang/.openclaw/workspace"
SOCKET="/tmp/openclaw-agents.sock"

# Agent 专长映射
declare -A AGENT_SKILLS=(
    ["claude-agent"]="i18n|refactor|backend|algorithm|review"
    ["gemini-agent"]="i18n|frontend|ui|architecture|design"
    ["codex-agent"]="cleanup|test|fix|optimize|debug"
)

# 获取空闲 agent
get_idle_agents() {
    local idle_agents=()
    for agent in claude-agent gemini-agent codex-agent; do
        local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null | tail -20)
        local last_lines=$(echo "$output" | tail -5)
        
        # 检查是否空闲 (有输入提示符，没有处理中标志)
        local is_idle=false
        
        # Claude: 空的 > 提示符或 ──── 分隔线
        if echo "$last_lines" | grep -qE "^>\s*$|^────.*────$" 2>/dev/null; then
            is_idle=true
        fi
        
        # Gemini: Type your message
        if echo "$last_lines" | grep -qE "Type your message" 2>/dev/null; then
            is_idle=true
        fi
        
        # Codex: 空的 › 提示符或 context left
        if echo "$last_lines" | grep -qE "^›\s*$|context left.*shortcuts" 2>/dev/null; then
            is_idle=true
        fi
        
        # 排除正在处理中的情况
        if echo "$output" | grep -qE "(⠋|⠙|⠹|⠸|Thinking|Working|esc to interrupt|esc to cancel)" 2>/dev/null; then
            is_idle=false
        fi
        
        if [[ "$is_idle" == "true" ]]; then
            idle_agents+=("$agent")
        fi
    done
    echo "${idle_agents[@]}"
}

# 获取待处理任务
get_pending_tasks() {
    # 从 Redis 获取活跃任务中状态为 pending 或 paused 的
    local tasks=$(redis-cli SMEMBERS openclaw:ctx:tasks:active 2>/dev/null)
    local pending=()
    
    for task in $tasks; do
        local status=$(redis-cli HGET "openclaw:ctx:task:$task" status 2>/dev/null)
        if [[ "$status" == "pending" || "$status" == "paused" || "$status" == "resumed" ]]; then
            pending+=("$task")
        fi
    done
    
    # 如果没有待处理任务，检查是否有默认任务
    if [[ ${#pending[@]} -eq 0 ]]; then
        # 返回默认任务类型
        echo "default"
        return
    fi
    
    echo "${pending[@]}"
}

# 匹配任务到 agent
match_task_to_agent() {
    local task="$1"
    local agent="$2"
    
    local skills="${AGENT_SKILLS[$agent]}"
    
    # 检查任务是否匹配 agent 技能
    if echo "$task" | grep -qE "$skills" 2>/dev/null; then
        return 0
    fi
    
    return 1
}

# 派发任务
dispatch_task() {
    local agent="$1"
    local task="$2"
    
    # 获取任务详情
    local task_desc=$(redis-cli HGET "openclaw:ctx:task:$task" task 2>/dev/null)
    local task_details=$(redis-cli HGET "openclaw:ctx:task:$task" details 2>/dev/null)
    
    if [[ -z "$task_desc" ]]; then
        # 默认任务
        case "$agent" in
            claude-agent)
                task_desc="继续 i18n 国际化工作，找到下一个需要国际化的模块并处理"
                ;;
            gemini-agent)
                task_desc="继续 i18n 国际化工作，找到下一个需要国际化的模块并处理"
                ;;
            codex-agent)
                task_desc="继续代码清理工作，找到未使用的 imports 或死代码并清理"
                ;;
        esac
    fi
    
    # 构建 prompt
    local prompt="$task_desc"
    if [[ -n "$task_details" ]]; then
        prompt="$task_desc ($task_details)"
    fi
    
    # 发送到 agent
    echo "[$agent] 派发任务: $prompt"
    tmux -S "$SOCKET" send-keys -t "$agent" "$prompt" Enter
    
    # 更新任务状态
    if [[ "$task" != "default" ]]; then
        redis-cli HSET "openclaw:ctx:task:$task" status "in_progress" > /dev/null 2>&1
        redis-cli HSET "openclaw:ctx:task:$task" assigned_to "$agent" > /dev/null 2>&1
        redis-cli HSET "openclaw:ctx:task:$task" dispatched_at "$(date -Iseconds)" > /dev/null 2>&1
    fi
    
    # 记录派发
    redis-cli HINCRBY "openclaw:dispatch:stats" total 1 > /dev/null 2>&1
    redis-cli HINCRBY "openclaw:dispatch:stats" "${agent}_count" 1 > /dev/null 2>&1
    redis-cli HSET "openclaw:dispatch:stats" last_dispatch "$(date -Iseconds)" > /dev/null 2>&1
}

# 主逻辑
main() {
    local action="${1:-auto}"
    
    case "$action" in
        auto)
            # 获取空闲 agent
            local idle_agents=($(get_idle_agents))
            
            if [[ ${#idle_agents[@]} -eq 0 ]]; then
                echo "✅ 所有 agent 都在工作"
                exit 0
            fi
            
            echo "🔍 发现 ${#idle_agents[@]} 个空闲 agent: ${idle_agents[*]}"
            
            # 获取待处理任务
            local pending_tasks=($(get_pending_tasks))
            
            # 为每个空闲 agent 分配任务
            for agent in "${idle_agents[@]}"; do
                local assigned=false
                
                # 尝试匹配专长任务
                for task in "${pending_tasks[@]}"; do
                    if match_task_to_agent "$task" "$agent"; then
                        dispatch_task "$agent" "$task"
                        assigned=true
                        break
                    fi
                done
                
                # 如果没有匹配的任务，分配默认任务
                if [[ "$assigned" == "false" ]]; then
                    dispatch_task "$agent" "default"
                fi
            done
            ;;
        
        status)
            echo "📊 派发统计"
            redis-cli HGETALL "openclaw:dispatch:stats" 2>/dev/null
            ;;
        
        list)
            echo "📋 待处理任务"
            get_pending_tasks
            ;;
        
        *)
            echo "用法: $0 [auto|status|list]"
            ;;
    esac
}

main "$@"
