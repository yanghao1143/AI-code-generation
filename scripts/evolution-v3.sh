#!/bin/bash
# evolution-v3.sh - 自我进化框架 v3
# 核心改进: 更精准的状态检测 + 更智能的修复

WORKSPACE="/home/jinyang/.openclaw/workspace"
SOCKET="/tmp/openclaw-agents.sock"
REDIS_PREFIX="openclaw:evo"
AGENTS=("claude-agent" "gemini-agent" "codex-agent")

declare -A AGENT_CONFIG=(
    ["claude-agent:cmd"]='ANTHROPIC_AUTH_TOKEN="sk-KwfZ1MFGt3K28O1Osjdd6WpN5fRJde3fUVzGIlUSIL50AYZf" ANTHROPIC_BASE_URL="https://vip.chiddns.com" claude --dangerously-skip-permissions'
    ["claude-agent:workdir"]="/mnt/d/ai软件/zed"
    ["gemini-agent:cmd"]="gemini"
    ["gemini-agent:workdir"]="/mnt/d/ai软件/zed"
    ["codex-agent:cmd"]="codex"
    ["codex-agent:workdir"]="/mnt/d/ai软件/zed"
)

# ============ 精准诊断 ============
diagnose_agent() {
    local agent="$1"
    local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null)
    local last_20=$(echo "$output" | tail -20)
    local last_5=$(echo "$output" | tail -5)
    
    # 1. API/连接错误
    if echo "$output" | grep -qE "Unable to connect|ERR_BAD_REQUEST|Failed to connect|ECONNREFUSED" 2>/dev/null; then
        echo "api_failure"; return
    fi
    
    # 2. 正在工作 (优先检测) - 有进度指示
    if echo "$last_20" | grep -qE "esc to interrupt|esc to cancel|Thinking|Working|Searching|Reading|Writing|Shenaniganing|Buffering|Rickrolling|Flowing|Running cargo|Checking|Transfiguring|Exploring" 2>/dev/null; then
        echo "working"; return
    fi
    
    # 3. 等待用户确认 (各种格式)
    if echo "$last_20" | grep -qE "Allow execution of|Allow once|Yes, I accept|Do you want to proceed|\[y/N\]|\(y/n\)|Waiting for user confirmation" 2>/dev/null; then
        echo "needs_confirm"; return
    fi
    
    # 4. 工具/请求错误
    if echo "$last_20" | grep -qE "Request cancelled|params must have|Something went wrong" 2>/dev/null; then
        echo "tool_error"; return
    fi
    
    # 5. Context 低 (<30%)
    # 支持多种格式: "59% context left", "Context left until auto-compact: 8%"
    local ctx=""
    # Codex/Gemini 格式
    ctx=$(echo "$output" | grep -oE "[0-9]+% context left" | tail -1 | grep -oE "^[0-9]+")
    # Claude 格式 (可能跨行)
    if [[ -z "$ctx" ]]; then
        ctx=$(echo "$output" | tr '\n' ' ' | grep -oE "auto-compac[^0-9]*[0-9]+%" | tail -1 | grep -oE "[0-9]+")
    fi
    if [[ -n "$ctx" && "$ctx" -lt 30 ]]; then
        echo "context_low"; return
    fi
    
    # 7. 循环检测
    if echo "$last_20" | grep -qE "loop was detected|infinite loop" 2>/dev/null; then
        echo "loop_detected"; return
    fi
    
    # 8. Claude 特有: 有输入但未发送 (❯ 后面有内容但没在工作)
    # 注意: 输入行可能有前导空格，且不能在工作状态
    if echo "$last_5" | grep -qE "❯ .+" 2>/dev/null; then
        if ! echo "$last_20" | grep -qE "esc to interrupt|bypass permissions|Thinking|Working" 2>/dev/null; then
            echo "pending_input"; return
        fi
    fi
    
    # 8. Gemini 特有: 输入框有内容
    if echo "$last_5" | grep -qE "^│ > .+[^│]" 2>/dev/null; then
        if ! echo "$last_5" | grep -qE "esc to cancel" 2>/dev/null; then
            echo "pending_input"; return
        fi
    fi
    
    # 9. Codex 特有: 有 › 提示符且有内容
    if echo "$last_5" | grep -qE "^› .+" 2>/dev/null; then
        if echo "$last_5" | grep -qE "Summarize recent|Write tests" 2>/dev/null; then
            echo "idle_with_suggestion"; return
        fi
        if ! echo "$last_5" | grep -qE "esc to interrupt" 2>/dev/null; then
            echo "pending_input"; return
        fi
    fi
    
    # 10. 空闲 (空提示符)
    if echo "$last_5" | grep -qE "^❯\s*$|^›\s*$|Type your message" 2>/dev/null; then
        echo "idle"; return
    fi
    
    # 11. 刚完成任务
    if echo "$last_20" | grep -qE "Baked for|completed|finished|done" 2>/dev/null; then
        if echo "$last_5" | grep -qE "^❯|^›|Type your message" 2>/dev/null; then
            echo "idle"; return
        fi
    fi
    
    echo "unknown"
}

# ============ 智能修复 ============
repair_agent() {
    local agent="$1"
    local diagnosis="$2"
    
    case "$diagnosis" in
        api_failure)
            tmux -S "$SOCKET" send-keys -t "$agent" C-c
            sleep 1
            local cmd="${AGENT_CONFIG[$agent:cmd]}"
            local workdir="${AGENT_CONFIG[$agent:workdir]}"
            tmux -S "$SOCKET" send-keys -t "$agent" "cd $workdir && $cmd" Enter
            sleep 5
            auto_confirm "$agent"
            "$WORKSPACE/scripts/auto-learn.sh" failure "$agent" "api_failure" "connection_error" "auto_repair" 2>/dev/null
            echo "restarted"
            ;;
        needs_confirm)
            local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p | tail -15)
            if echo "$output" | grep -qE "Allow once|1\. Allow once" 2>/dev/null; then
                tmux -S "$SOCKET" send-keys -t "$agent" "1" Enter
            elif echo "$output" | grep -qE "Yes, I accept" 2>/dev/null; then
                tmux -S "$SOCKET" send-keys -t "$agent" Down Enter
            elif echo "$output" | grep -qE "\[y/N\]|\(y/n\)" 2>/dev/null; then
                tmux -S "$SOCKET" send-keys -t "$agent" "y" Enter
            else
                tmux -S "$SOCKET" send-keys -t "$agent" Enter
            fi
            "$WORKSPACE/scripts/auto-learn.sh" success "$agent" "confirm" "auto_confirm" 2>/dev/null
            echo "confirmed"
            ;;
        tool_error)
            # 发送新指令绕过错误
            tmux -S "$SOCKET" send-keys -t "$agent" C-c
            sleep 0.5
            tmux -S "$SOCKET" send-keys -t "$agent" "上一个操作出错了，换个方法继续完成任务" Enter
            "$WORKSPACE/scripts/auto-learn.sh" failure "$agent" "tool_error" "request_error" "auto_repair" 2>/dev/null
            echo "error_bypassed"
            ;;
        context_low)
            # 杀掉会话重建
            tmux -S "$SOCKET" kill-session -t "$agent" 2>/dev/null
            sleep 1
            local cmd="${AGENT_CONFIG[$agent:cmd]}"
            local workdir="${AGENT_CONFIG[$agent:workdir]}"
            tmux -S "$SOCKET" new-session -d -s "$agent" -c "$workdir"
            sleep 1
            tmux -S "$SOCKET" send-keys -t "$agent" "$cmd" Enter
            sleep 8
            auto_confirm "$agent"
            dispatch_task "$agent"
            "$WORKSPACE/scripts/auto-learn.sh" success "$agent" "context_reset" "low_context" 2>/dev/null
            echo "context_reset"
            ;;
        loop_detected)
            # Gemini 循环检测: 先发 Enter 确认循环消息，清除输入框，再派新任务
            # 注意: 循环消息会阻塞输入，必须先 Enter 确认
            tmux -S "$SOCKET" send-keys -t "$agent" Enter
            sleep 2
            # 清除可能堆积的输入
            for i in {1..50}; do
                tmux -S "$SOCKET" send-keys -t "$agent" BSpace
            done
            sleep 0.3
            dispatch_task "$agent"
            "$WORKSPACE/scripts/auto-learn.sh" failure "$agent" "loop" "loop_detected" "auto_repair" 2>/dev/null
            echo "loop_broken_and_dispatched"
            ;;
        pending_input)
            tmux -S "$SOCKET" send-keys -t "$agent" Enter
            "$WORKSPACE/scripts/auto-learn.sh" success "$agent" "pending_input" "sent_enter" 2>/dev/null
            echo "input_sent"
            ;;
        idle|idle_with_suggestion)
            # 清除建议，派新任务
            tmux -S "$SOCKET" send-keys -t "$agent" C-u
            sleep 0.3
            dispatch_task "$agent"
            "$WORKSPACE/scripts/auto-learn.sh" success "$agent" "dispatch" "idle_dispatch" 2>/dev/null
            echo "dispatched"
            ;;
        working|unknown)
            echo "no_action"
            ;;
    esac
}

# ============ 自动确认 ============
auto_confirm() {
    local agent="$1"
    for i in {1..8}; do
        sleep 2
        local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p | tail -10)
        if echo "$output" | grep -qE "Yes, I accept" 2>/dev/null; then
            tmux -S "$SOCKET" send-keys -t "$agent" Down Enter
        elif echo "$output" | grep -qE "Allow once|1\. Allow" 2>/dev/null; then
            tmux -S "$SOCKET" send-keys -t "$agent" "1" Enter
        elif echo "$output" | grep -qE "Enter to confirm|Press Enter|Dark mode|Light mode" 2>/dev/null; then
            tmux -S "$SOCKET" send-keys -t "$agent" Enter
        elif echo "$output" | grep -qE "^❯\s*$|^›\s*$|context left" 2>/dev/null; then
            return 0
        fi
    done
}

# ============ 派活 ============
dispatch_task() {
    local agent="$1"
    
    # 优先从优先级队列获取
    local task=$("$WORKSPACE/scripts/priority-queue.sh" get "$agent" 2>/dev/null)
    
    # 如果队列为空，从旧队列获取
    if [[ -z "$task" ]]; then
        task=$(redis-cli LPOP "$REDIS_PREFIX:tasks:queue" 2>/dev/null)
    fi
    
    # 如果还是空，使用默认任务
    if [[ -z "$task" ]]; then
        case "$agent" in
            claude-agent)
                task="继续 Chi Code 中文化，检查 crates/agent_ui 还有哪些硬编码字符串需要国际化。完成后提交代码。"
                ;;
            gemini-agent)
                task="继续 Chi Code 中文化，检查 crates/repl 模块的硬编码字符串。完成后提交代码。"
                ;;
            codex-agent)
                task="运行 cargo check 检查编译错误，修复发现的问题。完成后提交代码。"
                ;;
        esac
    fi
    
    tmux -S "$SOCKET" send-keys -t "$agent" "$task" Enter
    redis-cli HINCRBY "$REDIS_PREFIX:stats" "dispatched:$agent" 1 2>/dev/null
    
    # 记录事件
    "$WORKSPACE/scripts/dashboard.sh" log "派发任务给 $agent: ${task:0:30}..." 2>/dev/null
}

# ============ 主检查 ============
run_check() {
    local mode="${1:-quick}"
    local issues=()
    
    for agent in "${AGENTS[@]}"; do
        if ! tmux -S "$SOCKET" has-session -t "$agent" 2>/dev/null; then
            local workdir="${AGENT_CONFIG[$agent:workdir]}"
            tmux -S "$SOCKET" new-session -d -s "$agent" -c "$workdir"
            local cmd="${AGENT_CONFIG[$agent:cmd]}"
            tmux -S "$SOCKET" send-keys -t "$agent" "$cmd" Enter
            sleep 5
            auto_confirm "$agent"
            issues+=("$agent:created")
            continue
        fi
        
        local diagnosis=$(diagnose_agent "$agent")
        
        if [[ "$diagnosis" != "working" ]]; then
            local result=$(repair_agent "$agent" "$diagnosis")
            if [[ "$result" != "no_action" ]]; then
                issues+=("$agent:$diagnosis→$result")
            fi
        fi
    done
    
    if [[ ${#issues[@]} -gt 0 ]]; then
        echo "🔧 ${issues[*]}"
    fi
}

# ============ 状态 ============
status() {
    echo "===== $(date '+%H:%M:%S') ====="
    for agent in "${AGENTS[@]}"; do
        local diag=$(diagnose_agent "$agent")
        local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null)
        local ctx=$(echo "$output" | grep -oE "[0-9]+% context" | tail -1)
        # Claude 格式
        if [[ -z "$ctx" ]]; then
            ctx=$(echo "$output" | tr '\n' ' ' | grep -oE "auto-compac[^0-9]*[0-9]+%" | tail -1 | sed 's/.*\([0-9]\+%\).*/\1 ctx/')
        fi
        printf "%-14s %-20s %s\n" "$agent" "$diag" "${ctx:-}"
    done
}

# ============ 入口 ============
case "${1:-check}" in
    check) run_check quick ;;
    status) status ;;
    repair) 
        d=$(diagnose_agent "$2")
        r=$(repair_agent "$2" "$d")
        echo "$2: $d → $r"
        ;;
    *) echo "用法: $0 {check|status|repair <agent>}" ;;
esac
