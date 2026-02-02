#!/bin/bash
# auto-fix.sh v2 - 纯 bash 自动修复，不依赖 AI
# 每分钟由系统 cron 调用，无需 OpenClaw cron

SOCKET="/tmp/openclaw-agents.sock"
AGENTS=("claude-agent" "gemini-agent" "codex-agent")
LOG_FILE="/tmp/auto-fix.log"
REDIS_PREFIX="openclaw:autofix"

log() {
    echo "[$(date '+%H:%M:%S')] $*" >> "$LOG_FILE"
}

# 检测状态
detect_state() {
    local agent="$1"
    local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null)
    
    # 检查会话是否存在
    if [[ -z "$output" ]]; then
        echo "session_missing"
        return
    fi
    
    local last_20=$(echo "$output" | tail -20)
    local last_10=$(echo "$output" | tail -10)
    local last_5=$(echo "$output" | tail -5)
    
    # 1. Gemini 多选确认 (优先检测)
    if echo "$last_10" | grep -qE "● 1\. Allow once" 2>/dev/null; then
        echo "gemini_confirm"
        return
    fi
    
    # 2. 其他确认界面
    if echo "$last_10" | grep -qE "Allow execution|Do you want to proceed|\[y/N\]|\(y/n\)|Yes, I accept|Waiting for user confirmation|Apply this change\?|Press Enter to continue" 2>/dev/null; then
        echo "needs_confirm"
        return
    fi
    
    # 3. 正在工作 (检测进度指示)
    if echo "$last_10" | grep -qE "esc to cancel|esc to interrupt|Thinking|Working|Searching|Reading|Writing|Cogitating|Shenaniganing|Buffering|Flowing|Transfiguring|Exploring|Investigating|Analyzing|Processing|Clarifying|Mining|Baking|Navigating|Checking|Compiling|Building|Mulling|Limiting|Considering|Enumerating|Scampering" 2>/dev/null; then
        echo "working"
        return
    fi
    
    # 4. 网络重试
    if echo "$last_10" | grep -qE "Trying to reach|Attempt [0-9]+/[0-9]+|Retrying|Reconnecting" 2>/dev/null; then
        echo "network_retry"
        return
    fi
    
    # 5. 循环检测
    if echo "$last_10" | grep -qE "loop was detected|infinite loop|repetitive tool calls" 2>/dev/null; then
        echo "loop_detected"
        return
    fi
    
    # 6. 有未发送的输入 (检查输入行)
    if echo "$last_5" | grep -qE "^[❯›>].*[^ \t]" 2>/dev/null; then
        # 排除空提示符和建议
        if ! echo "$last_5" | grep -qE "^[❯›>]\s*$|Summarize recent commits" 2>/dev/null; then
            echo "pending_input"
            return
        fi
    fi
    
    # 7. 空闲
    if echo "$last_5" | grep -qE "Type your message|^❯\s*$|^›\s*$" 2>/dev/null; then
        echo "idle"
        return
    fi
    
    # 8. Codex 空闲建议
    if echo "$last_5" | grep -qE "Summarize recent commits" 2>/dev/null; then
        echo "idle"
        return
    fi
    
    echo "unknown"
}

# 获取 context 使用率
get_context() {
    local agent="$1"
    local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null)
    
    # 尝试多种格式
    local ctx=$(echo "$output" | grep -oE "[0-9]+% context left" | tail -1 | grep -oE "^[0-9]+")
    if [[ -z "$ctx" ]]; then
        ctx=$(echo "$output" | tr '\n' ' ' | grep -oE "auto-compac[^0-9]*[0-9]+%" | tail -1 | grep -oE "[0-9]+")
    fi
    
    echo "${ctx:-100}"
}

# 修复
fix_agent() {
    local agent="$1"
    local state="$2"
    
    case "$state" in
        gemini_confirm)
            # Gemini 多选确认，发送 "1" + Enter
            tmux -S "$SOCKET" send-keys -t "$agent" "1" Enter 2>/dev/null
            log "$agent: gemini confirmed with '1'"
            ;;
        needs_confirm)
            # 发送确认
            tmux -S "$SOCKET" send-keys -t "$agent" Enter 2>/dev/null
            log "$agent: confirmed"
            ;;
        pending_input)
            # 发送输入
            tmux -S "$SOCKET" send-keys -t "$agent" Enter 2>/dev/null
            log "$agent: input sent"
            ;;
        loop_detected)
            # 循环检测，发送 "1" + Enter 确认
            tmux -S "$SOCKET" send-keys -t "$agent" "1" Enter 2>/dev/null
            log "$agent: loop confirmed"
            ;;
        network_retry)
            # 网络重试，记录但不干预
            local retry_count=$(redis-cli HINCRBY "$REDIS_PREFIX:retry:$agent" "count" 1 2>/dev/null)
            log "$agent: network retry #$retry_count"
            # 超过 10 次重试，发送 Ctrl+C 取消
            if [[ "$retry_count" -gt 10 ]]; then
                tmux -S "$SOCKET" send-keys -t "$agent" C-c 2>/dev/null
                redis-cli HSET "$REDIS_PREFIX:retry:$agent" "count" 0 2>/dev/null
                log "$agent: cancelled after $retry_count retries"
            fi
            ;;
        session_missing)
            log "$agent: session missing, needs restart"
            # 可以在这里添加自动重启逻辑
            ;;
    esac
}

# 检查 context 并警告
check_context() {
    local agent="$1"
    local ctx=$(get_context "$agent")
    
    if [[ "$ctx" -lt 30 ]]; then
        log "$agent: LOW CONTEXT ($ctx%)"
        redis-cli HSET "$REDIS_PREFIX:context:$agent" "level" "$ctx" "warning" "1" 2>/dev/null
    fi
}

# 主循环
main() {
    local fixed=0
    
    for agent in "${AGENTS[@]}"; do
        local state=$(detect_state "$agent")
        
        case "$state" in
            gemini_confirm|needs_confirm|pending_input|loop_detected|network_retry|session_missing)
                fix_agent "$agent" "$state"
                ((fixed++))
                ;;
            working)
                # 重置重试计数
                redis-cli HSET "$REDIS_PREFIX:retry:$agent" "count" 0 2>/dev/null
                ;;
        esac
        
        # 检查 context
        check_context "$agent"
    done
    
    if [ "$fixed" -gt 0 ]; then
        log "Fixed $fixed agents"
    fi
}

# 运行
main "$@"
