#!/bin/bash
# evolution-v4.sh - 自我进化框架 v4
# 核心改进:
# 1. 网络重试状态检测
# 2. 环境问题自动修复
# 3. 更智能的任务分配
# 4. 自动学习和适应

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

# ============ 精准诊断 v4 ============
diagnose_agent() {
    local agent="$1"
    local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null)
    local last_30=$(echo "$output" | tail -30)
    local last_10=$(echo "$output" | tail -10)
    local last_5=$(echo "$output" | tail -5)
    local last_3=$(echo "$output" | tail -3)
    
    # 0. 先检测明确的空闲状态 (最高优先级)
    # 但要排除正在工作的情况
    local is_working=false
    if echo "$last_10" | grep -qE "esc to cancel|esc to interrupt" 2>/dev/null; then
        is_working=true
    fi
    
    if [[ "$is_working" == "false" ]]; then
        # Gemini 空闲: 最后几行有 "Type your message" 且没有进度指示
        if echo "$last_5" | grep -qE "Type your message" 2>/dev/null; then
            echo "idle"; return
        fi
        # Claude 空闲: 最后几行有空的 ❯ 提示符
        if echo "$last_3" | grep -qE "^❯\s*$" 2>/dev/null; then
            echo "idle"; return
        fi
        # Codex 空闲: 最后几行有空的 › 提示符
        if echo "$last_3" | grep -qE "^›\s*$" 2>/dev/null; then
            echo "idle"; return
        fi
    fi

    # 1. 网络重试中 (新增)
    if echo "$last_10" | grep -qE "Trying to reach|Attempt [0-9]+/[0-9]+|Retrying|Reconnecting" 2>/dev/null; then
        echo "network_retry"; return
    fi
    
    # 2. API/连接错误 (严重)
    if echo "$output" | grep -qE "Unable to connect|ERR_BAD_REQUEST|Failed to connect|ECONNREFUSED|ETIMEDOUT" 2>/dev/null; then
        echo "api_failure"; return
    fi
    
    # 3. 环境问题 (新增) - 命令找不到
    if echo "$last_30" | grep -qE "command not found|No such file or directory|not recognized as" 2>/dev/null; then
        echo "env_error"; return
    fi
    
    # 4. 正在工作 - 有进度指示 (必须在最后几行)
    if echo "$last_10" | grep -qE "esc to interrupt|esc to cancel|Thinking|Working|Searching|Reading|Writing|Shenaniganing|Buffering|Rickrolling|Flowing|Running cargo|Transfiguring|Exploring|Investigating|Analyzing|Processing|Clarifying|Mining|Baking|Navigating|Checking|Compiling|Building|Cogitated|Searching text|Mulling|Limiting" 2>/dev/null; then
        echo "working"; return
    fi
    
    # 5. 等待用户确认 (各种格式)
    if echo "$last_10" | grep -qE "Allow execution of|Allow once|Yes, I accept|Do you want to proceed|\[y/N\]|\(y/n\)|Waiting for user confirmation|Press Enter to continue" 2>/dev/null; then
        echo "needs_confirm"; return
    fi
    
    # 6. 工具/请求错误
    if echo "$last_10" | grep -qE "Request cancelled|params must have|Something went wrong|Tool execution failed" 2>/dev/null; then
        echo "tool_error"; return
    fi
    
    # 7. Context 低 (<30%)
    local ctx=""
    ctx=$(echo "$output" | grep -oE "[0-9]+% context left" | tail -1 | grep -oE "^[0-9]+")
    if [[ -z "$ctx" ]]; then
        ctx=$(echo "$output" | tr '\n' ' ' | grep -oE "auto-compac[^0-9]*[0-9]+%" | tail -1 | grep -oE "[0-9]+")
    fi
    if [[ -n "$ctx" && "$ctx" -lt 30 ]]; then
        echo "context_low"; return
    fi
    
    # 8. 循环检测
    if echo "$last_10" | grep -qE "loop was detected|infinite loop|repetitive tool calls" 2>/dev/null; then
        echo "loop_detected"; return
    fi
    
    # 9. 编译错误 (新增)
    if echo "$last_30" | grep -qE "error\[E[0-9]+\]|cannot find|unresolved import|mismatched types" 2>/dev/null; then
        # 但如果正在工作中，不算错误
        if ! echo "$last_10" | grep -qE "esc to interrupt|esc to cancel" 2>/dev/null; then
            echo "compile_error"; return
        fi
    fi
    
    # 10. Claude 特有: 有输入但未发送
    if echo "$last_5" | grep -qE "^❯ .+" 2>/dev/null; then
        if ! echo "$last_5" | grep -qE "esc to interrupt|bypass permissions" 2>/dev/null; then
            echo "pending_input"; return
        fi
    fi
    
    # 11. Gemini 特有: 输入框有内容
    if echo "$last_5" | grep -qE "^│ > .+[^│]" 2>/dev/null; then
        if ! echo "$last_5" | grep -qE "esc to cancel" 2>/dev/null; then
            echo "pending_input"; return
        fi
    fi
    
    # 12. Codex 特有: 有 › 提示符且有内容
    if echo "$last_5" | grep -qE "^› .+" 2>/dev/null; then
        if echo "$last_5" | grep -qE "Summarize recent|Write tests" 2>/dev/null; then
            echo "idle_with_suggestion"; return
        fi
        if ! echo "$last_5" | grep -qE "esc to interrupt" 2>/dev/null; then
            echo "pending_input"; return
        fi
    fi
    
    # 13. 空闲 (空提示符)
    if echo "$last_5" | grep -qE "^❯\s*$|^›\s*$|Type your message" 2>/dev/null; then
        echo "idle"; return
    fi
    
    # 14. 刚完成任务
    if echo "$last_30" | grep -qE "Baked for|completed|finished|done|Successfully" 2>/dev/null; then
        if echo "$last_5" | grep -qE "^❯|^›|Type your message" 2>/dev/null; then
            echo "idle"; return
        fi
    fi
    
    echo "unknown"
}

# ============ 修复 v4 ============
repair_agent() {
    local agent="$1"
    local diagnosis="$2"
    
    # 记录诊断
    redis-cli HSET "$REDIS_PREFIX:diag:$agent" "last" "$diagnosis" "time" "$(date +%s)" 2>/dev/null
    
    case "$diagnosis" in
        network_retry)
            # 网络重试中，智能等待
            # Gemini 经常有网络问题，需要更耐心
            local retry_count=$(redis-cli HINCRBY "$REDIS_PREFIX:retry:$agent" "count" 1 2>/dev/null)
            
            # 根据重试次数决定策略
            if [[ "$retry_count" -gt 8 ]]; then
                # 重试太多次，重启会话
                tmux -S "$SOCKET" send-keys -t "$agent" C-c
                sleep 2
                restart_agent "$agent"
                redis-cli HSET "$REDIS_PREFIX:retry:$agent" "count" 0 2>/dev/null
                echo "restarted_after_retry"
            elif [[ "$retry_count" -gt 5 ]]; then
                # 尝试取消当前请求，让 agent 重新开始
                tmux -S "$SOCKET" send-keys -t "$agent" Escape
                sleep 2
                echo "cancelled_retry_$retry_count"
            else
                # 继续等待，网络可能会恢复
                echo "waiting_retry_$retry_count"
            fi
            ;;
        api_failure)
            # API 失败，重启
            tmux -S "$SOCKET" send-keys -t "$agent" C-c
            sleep 2
            restart_agent "$agent"
            echo "restarted"
            ;;
        env_error)
            # 环境错误，尝试修复
            fix_env_error "$agent"
            echo "env_fixed"
            ;;
        needs_confirm)
            # 自动确认
            auto_confirm "$agent"
            echo "confirmed"
            ;;
        tool_error)
            # 工具错误，发送 Enter 继续
            tmux -S "$SOCKET" send-keys -t "$agent" Enter
            sleep 1
            echo "continued"
            ;;
        context_low)
            # Context 低，重启会话
            restart_agent "$agent"
            echo "context_reset"
            ;;
        loop_detected)
            # 循环检测，发 Enter 确认，清除输入，派新任务
            tmux -S "$SOCKET" send-keys -t "$agent" Enter
            sleep 2
            for i in {1..50}; do
                tmux -S "$SOCKET" send-keys -t "$agent" BSpace
            done
            sleep 0.3
            dispatch_task "$agent"
            echo "loop_broken"
            ;;
        compile_error)
            # 编译错误，让 agent 自己处理
            # 如果空闲，派修复任务
            if echo "$(tmux -S "$SOCKET" capture-pane -t "$agent" -p | tail -5)" | grep -qE "^❯\s*$|^›\s*$" 2>/dev/null; then
                tmux -S "$SOCKET" send-keys -t "$agent" "修复上面的编译错误" Enter
                echo "fix_dispatched"
            else
                echo "agent_handling"
            fi
            ;;
        pending_input)
            # 检查是否有多行堆积的输入 (Claude 用 ❯, Gemini 用 │ >)
            local input_lines=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null | tail -10 | grep -c "^❯ \|继续之前的任务\|^│ > ")
            if [[ $input_lines -gt 2 ]]; then
                # 多行堆积，先清理
                tmux -S "$SOCKET" send-keys -t "$agent" C-c
                sleep 0.3
                # Gemini 不响应 C-u，用多个 BSpace
                if [[ "$agent" == "gemini-agent" ]]; then
                    for i in {1..50}; do
                        tmux -S "$SOCKET" send-keys -t "$agent" BSpace
                    done
                    sleep 0.3
                else
                    tmux -S "$SOCKET" send-keys -t "$agent" C-u
                    sleep 0.3
                fi
                dispatch_task "$agent"
                echo "cleared_and_dispatched"
            else
                tmux -S "$SOCKET" send-keys -t "$agent" Enter
                echo "input_sent"
            fi
            ;;
        idle|idle_with_suggestion)
            tmux -S "$SOCKET" send-keys -t "$agent" C-u
            sleep 0.3
            dispatch_task "$agent"
            echo "dispatched"
            ;;
        working|unknown)
            # 重置重试计数
            redis-cli HSET "$REDIS_PREFIX:retry:$agent" "count" 0 2>/dev/null
            echo "no_action"
            ;;
    esac
}

# ============ 环境修复 (新增) ============
fix_env_error() {
    local agent="$1"
    local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null)
    
    # 检测具体是什么命令找不到
    if echo "$output" | grep -qE "cargo: command not found|cargo: No such file" 2>/dev/null; then
        # cargo 找不到，可能是 PATH 问题
        # 在 WSL 中，需要 source cargo env
        tmux -S "$SOCKET" send-keys -t "$agent" C-c
        sleep 1
        # 告诉 agent 使用完整路径或设置环境
        tmux -S "$SOCKET" send-keys -t "$agent" "注意: cargo 命令找不到。请使用 'source ~/.cargo/env' 或使用完整路径 '~/.cargo/bin/cargo'。继续你的任务。" Enter
    elif echo "$output" | grep -qE "node: command not found" 2>/dev/null; then
        tmux -S "$SOCKET" send-keys -t "$agent" C-c
        sleep 1
        tmux -S "$SOCKET" send-keys -t "$agent" "注意: node 命令找不到。请使用 nvm 或完整路径。继续你的任务。" Enter
    else
        # 通用处理
        tmux -S "$SOCKET" send-keys -t "$agent" C-c
        sleep 1
        tmux -S "$SOCKET" send-keys -t "$agent" "遇到环境问题，请检查命令路径或使用替代方案。继续你的任务。" Enter
    fi
}

# ============ 重启 Agent ============
restart_agent() {
    local agent="$1"
    local cmd="${AGENT_CONFIG[$agent:cmd]}"
    local workdir="${AGENT_CONFIG[$agent:workdir]}"
    
    # 杀掉旧会话
    tmux -S "$SOCKET" kill-session -t "$agent" 2>/dev/null
    sleep 1
    
    # 创建新会话
    tmux -S "$SOCKET" new-session -d -s "$agent" -c "$workdir"
    sleep 1
    tmux -S "$SOCKET" send-keys -t "$agent" "$cmd" Enter
    sleep 8
    auto_confirm "$agent"
    dispatch_task "$agent"
    
    # 记录重启
    redis-cli HINCRBY "$REDIS_PREFIX:stats" "restarts:$agent" 1 2>/dev/null
    "$WORKSPACE/scripts/dashboard.sh" log "重启 $agent" 2>/dev/null
}

# ============ 自动确认 ============
auto_confirm() {
    local agent="$1"
    for i in {1..10}; do
        sleep 2
        local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p | tail -15)
        if echo "$output" | grep -qE "Yes, I accept" 2>/dev/null; then
            tmux -S "$SOCKET" send-keys -t "$agent" Down Enter
        elif echo "$output" | grep -qE "Allow once|1\. Allow|Allow execution" 2>/dev/null; then
            tmux -S "$SOCKET" send-keys -t "$agent" "1" Enter
        elif echo "$output" | grep -qE "Enter to confirm|Press Enter|Dark mode|Light mode|trust this" 2>/dev/null; then
            tmux -S "$SOCKET" send-keys -t "$agent" Enter
        elif echo "$output" | grep -qE "\[y/N\]|\(y/n\)" 2>/dev/null; then
            tmux -S "$SOCKET" send-keys -t "$agent" "y" Enter
        elif echo "$output" | grep -qE "^❯\s*$|^›\s*$|context left|Type your message" 2>/dev/null; then
            return 0
        fi
    done
}

# ============ 智能派活 v4 ============
dispatch_task() {
    local agent="$1"
    
    # 1. 优先从优先级队列获取
    local task=$("$WORKSPACE/scripts/priority-queue.sh" get "$agent" 2>/dev/null)
    
    # 2. 从 Redis 任务队列获取
    if [[ -z "$task" ]]; then
        task=$(redis-cli LPOP "$REDIS_PREFIX:tasks:queue" 2>/dev/null)
    fi
    
    # 3. 检查是否有未完成的任务需要继续
    if [[ -z "$task" ]]; then
        local last_task=$(redis-cli HGET "$REDIS_PREFIX:task:$agent" "current" 2>/dev/null)
        if [[ -n "$last_task" && "$last_task" != "null" ]]; then
            task="继续之前的任务: $last_task"
        fi
    fi
    
    # 4. 使用 task-finder 智能发现任务
    if [[ -z "$task" ]]; then
        task=$("$WORKSPACE/scripts/task-finder.sh" next "$agent" 2>/dev/null)
    fi
    
    # 5. 使用默认任务
    if [[ -z "$task" ]]; then
        case "$agent" in
            claude-agent)
                task="继续 Chi Code 中文化工作。检查 crates/ 目录下还有哪些模块需要国际化。优先处理用户界面相关的字符串。完成后提交代码。"
                ;;
            gemini-agent)
                task="继续 Chi Code 中文化工作。检查 crates/ 目录下的模块，找出硬编码的英文字符串并进行国际化。完成后提交代码。"
                ;;
            codex-agent)
                task="运行 cargo check 检查编译错误。如果有错误，修复它们。如果没有错误，运行 cargo clippy 检查代码质量。完成后提交代码。"
                ;;
        esac
    fi
    
    # 发送任务
    tmux -S "$SOCKET" send-keys -t "$agent" "$task" Enter
    
    # 记录
    redis-cli HSET "$REDIS_PREFIX:task:$agent" "current" "${task:0:100}" "time" "$(date +%s)" 2>/dev/null
    redis-cli HINCRBY "$REDIS_PREFIX:stats" "dispatched:$agent" 1 2>/dev/null
    "$WORKSPACE/scripts/dashboard.sh" log "派发任务给 $agent: ${task:0:50}..." 2>/dev/null
}

# ============ 主检查 ============
run_check() {
    local mode="${1:-quick}"
    local issues=()
    
    for agent in "${AGENTS[@]}"; do
        # 检查会话是否存在
        if ! tmux -S "$SOCKET" has-session -t "$agent" 2>/dev/null; then
            restart_agent "$agent"
            issues+=("$agent:created")
            continue
        fi
        
        local diagnosis=$(diagnose_agent "$agent")
        
        if [[ "$diagnosis" != "working" && "$diagnosis" != "unknown" ]]; then
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
    echo "===== Evolution v4 - $(date '+%H:%M:%S') ====="
    for agent in "${AGENTS[@]}"; do
        local diag=$(diagnose_agent "$agent")
        local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null)
        local ctx=$(echo "$output" | grep -oE "[0-9]+% context" | tail -1)
        if [[ -z "$ctx" ]]; then
            ctx=$(echo "$output" | tr '\n' ' ' | grep -oE "auto-compac[^0-9]*[0-9]+%" | tail -1 | sed 's/.*\([0-9]\+%\).*/\1 ctx/')
        fi
        local retry=$(redis-cli HGET "$REDIS_PREFIX:retry:$agent" "count" 2>/dev/null)
        printf "%-14s %-20s %-15s retry:%s\n" "$agent" "$diag" "${ctx:-}" "${retry:-0}"
    done
}

# ============ 学习 (新增) ============
learn() {
    local agent="$1"
    local problem="$2"
    local solution="$3"
    
    # 记录到知识库
    redis-cli HSET "$REDIS_PREFIX:knowledge:$problem" \
        "solution" "$solution" \
        "agent" "$agent" \
        "time" "$(date +%s)" \
        "success" "1" 2>/dev/null
    
    echo "学习记录: $problem → $solution"
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
    diagnose)
        diagnose_agent "$2"
        ;;
    learn)
        learn "$2" "$3" "$4"
        ;;
    *) echo "用法: $0 {check|status|repair <agent>|diagnose <agent>|learn <agent> <problem> <solution>}" ;;
esac
