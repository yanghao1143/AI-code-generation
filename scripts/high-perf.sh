#!/bin/bash
# high-perf.sh - 高性能并发调度器
# 目标: 减少延迟、提高并发、达到高可用

WORKSPACE="/home/jinyang/.openclaw/workspace"
SOCKET="/tmp/openclaw-agents.sock"
AGENTS=("claude-agent" "gemini-agent" "codex-agent")

# 性能配置
CHECK_INTERVAL=10        # 检查间隔 (秒) - 从5分钟降到10秒
COMMIT_INTERVAL=900      # 提交间隔 (秒) - 15分钟
CONTEXT_THRESHOLD=30     # Context 阈值 (%) - 低于此值重启
MAX_IDLE_TIME=120        # 最大空闲时间 (秒) - 超过则派活

# 并发执行函数
parallel_check() {
    local pids=()
    
    for agent in "${AGENTS[@]}"; do
        check_single_agent "$agent" &
        pids+=($!)
    done
    
    # 等待所有并发任务完成
    for pid in "${pids[@]}"; do
        wait $pid
    done
}

# 单个 agent 检查 (可并发)
check_single_agent() {
    local agent="$1"
    local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null)
    local last_lines=$(echo "$output" | tail -10)
    local issues=""
    
    # 1. 检查未发送输入 (最常见问题)
    if echo "$last_lines" | grep -qE "^> .+|^› .+|^│ > .+" 2>/dev/null; then
        if ! echo "$output" | tail -15 | grep -qE "(esc to interrupt|esc to cancel|Thinking|Working|Searching)" 2>/dev/null; then
            # 排除默认提示
            if ! echo "$last_lines" | grep -qE "Type your message|Write tests for" 2>/dev/null; then
                tmux -S "$SOCKET" send-keys -t "$agent" Enter
                issues+="pending_input "
            fi
        fi
    fi
    
    # 2. 检查确认界面
    if echo "$last_lines" | grep -qE "Yes, proceed|Press enter|loop was detected|Do you want to proceed" 2>/dev/null; then
        tmux -S "$SOCKET" send-keys -t "$agent" Enter
        issues+="confirm "
    fi
    
    # 3. 检查 context
    local ctx=$(echo "$output" | grep -oE "[0-9]+% context left" | grep -oE "[0-9]+" | head -1)
    if [[ -n "$ctx" && $ctx -lt $CONTEXT_THRESHOLD ]]; then
        # 重启会话
        tmux -S "$SOCKET" send-keys -t "$agent" C-c
        sleep 1
        case "$agent" in
            codex-agent)
                tmux -S "$SOCKET" send-keys -t "$agent" "/exit" Enter
                sleep 2
                tmux -S "$SOCKET" send-keys -t "$agent" "codex" Enter
                ;;
        esac
        issues+="context_low "
    fi
    
    # 4. 检查空闲状态
    if echo "$last_lines" | grep -qE "^>\s*$|Type your message.*$|context left.*shortcuts$" 2>/dev/null; then
        if ! echo "$output" | tail -15 | grep -qE "(esc to interrupt|esc to cancel)" 2>/dev/null; then
            # 派活
            local task=""
            case "$agent" in
                claude-agent)
                    task="继续 i18n 国际化，完成后 git add -u && git commit -m 'i18n: 模块国际化' && git push"
                    ;;
                gemini-agent)
                    task="继续 i18n 国际化，完成后 git add -u && git commit -m 'i18n: 模块国际化' && git push"
                    ;;
                codex-agent)
                    task="运行 cargo check，修复编译错误，完成后 git add -u && git commit -m 'fix: 修复编译错误' && git push"
                    ;;
            esac
            tmux -S "$SOCKET" send-keys -t "$agent" "$task" Enter
            issues+="idle_dispatched "
        fi
    fi
    
    # 输出结果
    if [[ -n "$issues" ]]; then
        echo "[$agent] $issues"
    fi
}

# 快速健康检查 (无输出版本)
quick_check() {
    for agent in "${AGENTS[@]}"; do
        local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null | tail -10)
        
        # 只检查最关键的问题
        # 1. 未发送输入
        if echo "$output" | grep -qE "^> .+[^$]|^› .+[^$]" 2>/dev/null; then
            if ! echo "$output" | grep -qE "(esc to|Thinking|Working|Type your message|Write tests)" 2>/dev/null; then
                tmux -S "$SOCKET" send-keys -t "$agent" Enter
            fi
        fi
        
        # 2. 确认界面
        if echo "$output" | grep -qE "Yes, proceed|Press enter|loop was detected" 2>/dev/null; then
            tmux -S "$SOCKET" send-keys -t "$agent" Enter
        fi
    done
}

# 强制提交
force_commit() {
    echo "📤 强制提交所有 agent"
    for agent in "${AGENTS[@]}"; do
        local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null | tail -5)
        
        # 只在空闲时提交
        if echo "$output" | grep -qE "^>\s*$|Type your message|context left.*shortcuts" 2>/dev/null; then
            tmux -S "$SOCKET" send-keys -t "$agent" "git add -u && git commit -m 'wip: 进度保存' && git push" Enter
            echo "  → $agent 已发送提交命令"
        fi
    done
}

# 状态报告
status_report() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🚀 高性能调度器状态 - $(date '+%H:%M:%S')"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    for agent in "${AGENTS[@]}"; do
        local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null)
        local status="unknown"
        local ctx="?"
        
        # 状态判断
        if echo "$output" | tail -15 | grep -qE "(esc to interrupt|esc to cancel|Thinking|Working)" 2>/dev/null; then
            status="🟢 working"
        elif echo "$output" | tail -5 | grep -qE "^>\s*$|Type your message|context left.*shortcuts" 2>/dev/null; then
            status="🟡 idle"
        else
            status="🔵 active"
        fi
        
        # Context
        ctx=$(echo "$output" | grep -oE "[0-9]+% context" | grep -oE "[0-9]+" | head -1)
        [[ -z "$ctx" ]] && ctx="?"
        
        printf "  %-15s %s  (ctx: %s%%)\n" "$agent" "$status" "$ctx"
    done
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# 守护进程模式
daemon_mode() {
    echo "🚀 高性能调度器启动 (间隔: ${CHECK_INTERVAL}s)"
    
    local last_commit=$(date +%s)
    
    while true; do
        # 快速检查
        quick_check
        
        # 定期提交
        local now=$(date +%s)
        if [[ $((now - last_commit)) -gt $COMMIT_INTERVAL ]]; then
            force_commit
            last_commit=$now
        fi
        
        sleep $CHECK_INTERVAL
    done
}

# 主入口
case "${1:-check}" in
    check|c)
        parallel_check
        ;;
    quick|q)
        quick_check
        ;;
    commit|cm)
        force_commit
        ;;
    status|s)
        status_report
        ;;
    daemon|d)
        daemon_mode
        ;;
    *)
        echo "用法: $0 [check|quick|commit|status|daemon]"
        echo ""
        echo "命令:"
        echo "  check (c)   - 完整检查 (并发)"
        echo "  quick (q)   - 快速检查 (最小延迟)"
        echo "  commit (cm) - 强制提交"
        echo "  status (s)  - 状态报告"
        echo "  daemon (d)  - 守护进程模式"
        ;;
esac
