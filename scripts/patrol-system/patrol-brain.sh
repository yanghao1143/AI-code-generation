#!/bin/bash
# patrol-brain.sh - Layer 2: 智能决策引擎
# 基于规则的任务分配和会话管理，不依赖 LLM

set -e

SOCKET="/tmp/openclaw-agents.sock"
AGENTS=("claude-agent" "gemini-agent" "codex-agent")
REDIS_PREFIX="patrol:agent"
LOG_FILE="/tmp/patrol-brain.log"
PROJECT_DIR="/home/jinyang/Koma"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# 发送任务给 agent
dispatch_task() {
    local agent="$1"
    local task="$2"
    
    tmux -S "$SOCKET" send-keys -t "$agent" "$task" Enter 2>/dev/null
    redis-cli SET "${REDIS_PREFIX}:${agent}:task" "$task" EX 3600 >/dev/null
    redis-cli DEL "${REDIS_PREFIX}:${agent}:idle_since" >/dev/null 2>&1
    log "$agent: dispatched task: ${task:0:50}..."
    redis-cli INCR "patrol:stats:dispatches" >/dev/null
}

# 重启 agent 会话
restart_agent() {
    local agent="$1"
    local cli=""
    
    case "$agent" in
        "claude-agent") cli="claude --dangerously-skip-permissions" ;;
        "gemini-agent") cli="gemini" ;;
        "codex-agent") cli="codex" ;;
    esac
    
    log "$agent: restarting session..."
    
    # 杀掉旧会话
    tmux -S "$SOCKET" kill-session -t "$agent" 2>/dev/null || true
    sleep 0.5
    
    # 创建新会话
    tmux -S "$SOCKET" new-session -d -s "$agent" -c "$PROJECT_DIR"
    sleep 0.5
    
    # 启动 PowerShell (Windows CLI 需要)
    if [[ "$agent" == "gemini-agent" || "$agent" == "codex-agent" ]]; then
        tmux -S "$SOCKET" send-keys -t "$agent" "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe" Enter
        sleep 2
        tmux -S "$SOCKET" send-keys -t "$agent" "cd D:\\" Enter
        sleep 0.5
    fi
    
    # 启动 CLI
    tmux -S "$SOCKET" send-keys -t "$agent" "$cli" Enter
    
    log "$agent: session restarted with $cli"
    redis-cli INCR "patrol:stats:restarts" >/dev/null
}

# 获取默认任务
get_default_task() {
    local agent="$1"
    
    # 检查是否有 TypeScript 错误
    local ts_errors=$(cd "$PROJECT_DIR/frontend" && npx tsc --noEmit 2>&1 | grep -c "error TS" || echo "0")
    
    if [[ "$ts_errors" -gt 0 ]]; then
        case "$agent" in
            "claude-agent")
                echo "Fix TypeScript errors in src/chat/ and src/services/. Run 'cd frontend && npx tsc --noEmit' to see errors."
                ;;
            "gemini-agent")
                echo "Fix TypeScript errors in src/workflow/. Run 'cd \\\\wsl.localhost\\Ubuntu\\home\\jinyang\\Koma\\frontend && npx tsc --noEmit' to see errors."
                ;;
            "codex-agent")
                echo "Fix TypeScript errors in src/components/. Run 'cd \\\\wsl.localhost\\Ubuntu\\home\\jinyang\\Koma\\frontend && npx tsc --noEmit' to see errors."
                ;;
        esac
        return
    fi
    
    # 没有 TypeScript 错误，分配其他任务
    case "$agent" in
        "claude-agent")
            echo "Review the codebase for code quality improvements. Focus on error handling and type safety."
            ;;
        "gemini-agent")
            echo "Check for any i18n strings that need translation. Look for hardcoded Chinese text."
            ;;
        "codex-agent")
            echo "Run tests and fix any failing ones. Check for unused imports and dead code."
            ;;
    esac
}

# 处理问题队列
process_problems() {
    while true; do
        local problem=$(redis-cli RPOP "patrol:queue:problems" 2>/dev/null)
        [[ -z "$problem" ]] && break
        
        local agent=$(echo "$problem" | grep -oP '"agent":"[^"]+"' | cut -d'"' -f4)
        local type=$(echo "$problem" | grep -oP '"type":"[^"]+"' | cut -d'"' -f4)
        
        log "Processing problem: $agent - $type"
        
        case "$type" in
            "cli_exited"|"session_missing"|"network_timeout")
                restart_agent "$agent"
                sleep 3
                local task=$(get_default_task "$agent")
                dispatch_task "$agent" "$task"
                ;;
            "env_error")
                # 环境错误通常需要手动处理，加入通知队列
                redis-cli LPUSH "patrol:notify:pending" "⚠️ $agent 遇到环境错误，需要手动检查" >/dev/null
                ;;
        esac
    done
}

# 处理空闲 agent
process_idle_agents() {
    while true; do
        local agent=$(redis-cli RPOP "patrol:queue:idle_agents" 2>/dev/null)
        [[ -z "$agent" ]] && break
        
        # 检查是否还是空闲
        local state=$(redis-cli GET "${REDIS_PREFIX}:${agent}:state" 2>/dev/null)
        if [[ "$state" != "idle" ]]; then
            log "$agent: no longer idle, skipping"
            continue
        fi
        
        # 检查任务队列
        local task=$(redis-cli RPOP "patrol:queue:tasks" 2>/dev/null)
        
        if [[ -z "$task" ]]; then
            # 没有待分配任务，使用默认任务
            task=$(get_default_task "$agent")
        fi
        
        dispatch_task "$agent" "$task"
    done
}

# 检查 context 使用率
check_context() {
    for agent in "${AGENTS[@]}"; do
        local context=$(redis-cli GET "${REDIS_PREFIX}:${agent}:context" 2>/dev/null)
        
        # 如果 context 低于 20%，需要重启
        if [[ "$context" =~ ^[0-9]+$ ]] && [[ "$context" -lt 20 ]]; then
            log "$agent: context low ($context%), scheduling restart"
            redis-cli LPUSH "patrol:queue:problems" "{\"agent\":\"$agent\",\"type\":\"context_low\",\"time\":$(date +%s)}" >/dev/null
        fi
    done
}

# 主函数
main() {
    log "=== Brain cycle started ==="
    
    # 1. 处理问题队列
    process_problems
    
    # 2. 处理空闲 agent
    process_idle_agents
    
    # 3. 检查 context 使用率
    check_context
    
    log "=== Brain cycle completed ==="
}

main "$@"
