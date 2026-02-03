#!/bin/bash
# patrol-collector.sh - Layer 0: 状态采集
# 每分钟由系统 cron 调用，纯 bash，不依赖任何 API

set -e

SOCKET="/tmp/openclaw-agents.sock"
AGENTS=("claude-agent" "gemini-agent" "codex-agent")
REDIS_PREFIX="patrol:agent"

# 检测 agent 状态
detect_state() {
    local agent="$1"
    local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null)
    
    if [[ -z "$output" ]]; then
        echo "session_missing"
        return
    fi
    
    local last_20=$(echo "$output" | tail -20)
    local last_10=$(echo "$output" | tail -10)
    local last_5=$(echo "$output" | tail -5)
    
    # 1. Gemini 多选确认
    if echo "$last_10" | grep -qE "● 1\. Allow once" 2>/dev/null; then
        echo "gemini_confirm"
        return
    fi
    
    # 2. 循环检测消息
    if echo "$last_10" | grep -qE "loop detected|infinite loop|breaking out" 2>/dev/null; then
        echo "loop_detected"
        return
    fi
    
    # 3. 其他确认界面
    if echo "$last_10" | grep -qE "Allow execution|Do you want to proceed|\[y/N\]|\(y/n\)|Yes, I accept|Apply this change\?|Press Enter" 2>/dev/null; then
        echo "needs_confirm"
        return
    fi
    
    # 4. 正在工作 (检测更多状态)
    if echo "$last_20" | grep -qE "esc to cancel|esc to interrupt|Thinking|Working|Searching|Reading|Writing|Cogitating|Shenaniganing|Buffering|Flowing|Transfiguring|Exploring|Investigating|Analyzing|Processing|Clarifying|Mining|Baking|Navigating|Checking|Compiling|Building|Mulling|Limiting|Considering|Enumerating|Scampering|Hatching|Pontificating|Nebulizing|Refining|Resolving|TARDIS|Burrowing|Worked for|context left|Listing|Scanning|Fetching|Loading|Parsing|Generating|Executing|Running|Querying" 2>/dev/null; then
        echo "working"
        return
    fi
    
    # 5. 网络重试
    if echo "$last_10" | grep -qE "Trying to reach|Attempt [0-9]+/[0-9]+|Retrying|Reconnecting" 2>/dev/null; then
        echo "network_retry"
        return
    fi
    
    # 6. 工具错误
    if echo "$last_10" | grep -qE "Request cancelled|params must have required|MCP.*failed" 2>/dev/null; then
        echo "tool_error"
        return
    fi
    
    # 7. 环境错误
    if echo "$last_10" | grep -qE "command not found|No such file|not recognized|UNC.*not supported" 2>/dev/null; then
        echo "env_error"
        return
    fi
    
    # 8. 有待发送的输入
    if echo "$last_5" | grep -qE "^> .+" 2>/dev/null; then
        # 排除空提示符和特殊状态
        local input_line=$(echo "$last_5" | grep -E "^> " | tail -1)
        if [[ -n "$input_line" ]] && ! echo "$input_line" | grep -qE "^> \s*$|Type your message"; then
            echo "pending_input"
            return
        fi
    fi
    
    # 9. 空闲 (CLI 提示符)
    if echo "$last_5" | grep -qE "^>\s*$|Type your message|❯\s*$" 2>/dev/null; then
        echo "idle"
        return
    fi
    
    # 10. bash 环境 (CLI 退出了)
    if echo "$last_5" | grep -qE "^\w+@.*\$\s*$" 2>/dev/null; then
        echo "bash_shell"
        return
    fi
    
    echo "unknown"
}

# 提取 context 使用率
extract_context() {
    local agent="$1"
    local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null)
    
    # Claude 格式: "auto-compact: 8%" 或 "↑ 31.4k tokens"
    local claude_ctx=$(echo "$output" | grep -oE "auto-compact: [0-9]+%" | tail -1 | grep -oE "[0-9]+")
    if [[ -n "$claude_ctx" ]]; then
        echo "$claude_ctx"
        return
    fi
    
    # Codex 格式: "100% context left"
    local codex_ctx=$(echo "$output" | grep -oE "[0-9]+% context" | tail -1 | grep -oE "^[0-9]+")
    if [[ -n "$codex_ctx" ]]; then
        echo "$codex_ctx"
        return
    fi
    
    # Gemini 没有明确的 context 显示
    echo "unknown"
}

# 提取当前工作目录
extract_cwd() {
    local agent="$1"
    local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null)
    
    # 从状态栏提取
    local cwd=$(echo "$output" | grep -oE "\.\.\.[^(]+" | tail -1 | sed 's/\.\.\.//g' | xargs)
    if [[ -n "$cwd" ]]; then
        echo "$cwd"
        return
    fi
    
    # 从 bash 提示符提取
    local bash_cwd=$(echo "$output" | grep -oE "@[^:]+:([^$]+)\$" | tail -1 | sed 's/.*://;s/\$//g')
    if [[ -n "$bash_cwd" ]]; then
        echo "$bash_cwd"
        return
    fi
    
    echo "unknown"
}

# 主循环
main() {
    local timestamp=$(date +%s)
    
    for agent in "${AGENTS[@]}"; do
        local state=$(detect_state "$agent")
        local context=$(extract_context "$agent")
        local cwd=$(extract_cwd "$agent")
        
        # 写入 Redis
        redis-cli SET "${REDIS_PREFIX}:${agent}:state" "$state" EX 300 >/dev/null
        redis-cli SET "${REDIS_PREFIX}:${agent}:context" "$context" EX 300 >/dev/null
        redis-cli SET "${REDIS_PREFIX}:${agent}:cwd" "$cwd" EX 300 >/dev/null
        redis-cli SET "${REDIS_PREFIX}:${agent}:updated" "$timestamp" EX 300 >/dev/null
        
        # 如果空闲，记录空闲开始时间
        if [[ "$state" == "idle" || "$state" == "bash_shell" ]]; then
            local idle_since=$(redis-cli GET "${REDIS_PREFIX}:${agent}:idle_since" 2>/dev/null)
            if [[ -z "$idle_since" ]]; then
                redis-cli SET "${REDIS_PREFIX}:${agent}:idle_since" "$timestamp" EX 3600 >/dev/null
            fi
        else
            redis-cli DEL "${REDIS_PREFIX}:${agent}:idle_since" >/dev/null 2>&1
        fi
    done
    
    # 记录采集时间
    redis-cli SET "patrol:last_collect" "$timestamp" EX 300 >/dev/null
}

main "$@"
