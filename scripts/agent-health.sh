#!/bin/bash
# agent-health.sh - Agent 健康检查与自动恢复 v2.0
# 优化: 更智能的状态检测，任务超时检测，减少误判

WORKSPACE="/home/jinyang/.openclaw/workspace"
SOCKET="/tmp/openclaw-agents.sock"
AGENTS=("claude-agent" "gemini-agent" "codex-agent")
DEADLOCK_THRESHOLD=600   # 10分钟无活动视为死锁 (从5分钟增加)
TASK_TIMEOUT=300         # 5分钟任务超时警告
CONTEXT_WARNING=70       # 70% 上下文使用率警告
CONTEXT_CRITICAL=85      # 85% 上下文使用率危险

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 检测 CLI 类型
detect_cli_type() {
    local output="$1"
    local agent_name="$2"  # 可选: 从 agent 名称推断
    
    # 1. 从输出内容检测
    if echo "$output" | grep -qE "(Claude Code|claude|CLAUDE|Opus|Sonnet)" 2>/dev/null; then
        echo "claude"
        return
    elif echo "$output" | grep -qE "(GEMINI|Gemini|gemini-)" 2>/dev/null; then
        echo "gemini"
        return
    elif echo "$output" | grep -qE "(Codex|codex|gpt-.*-codex)" 2>/dev/null; then
        echo "codex"
        return
    fi
    
    # 2. 从 UI 特征检测
    # Claude CLI 特征: "Do you want to proceed?", "● " 任务标记, "ctrl+b to run"
    if echo "$output" | grep -qE "(Do you want to proceed\?|● |ctrl\+b to run|Esc to cancel · Tab to amend)" 2>/dev/null; then
        echo "claude"
        return
    fi
    
    # Gemini CLI 特征: "Type your message", "accepting edits"
    if echo "$output" | grep -qE "(Type your message|accepting edits|shift \+ tab)" 2>/dev/null; then
        echo "gemini"
        return
    fi
    
    # Codex CLI 特征: "context left", "› "
    if echo "$output" | grep -qE "(context left|^› )" 2>/dev/null; then
        echo "codex"
        return
    fi
    
    # 3. 从 agent 名称推断 (最后手段)
    if [[ -n "$agent_name" ]]; then
        case "$agent_name" in
            *claude*) echo "claude"; return ;;
            *gemini*) echo "gemini"; return ;;
            *codex*)  echo "codex"; return ;;
        esac
    fi
    
    echo "unknown"
}

# 检测是否正在处理任务 (AI 正在思考/生成)
is_processing() {
    local output="$1"
    local cli_type="$2"
    
    # 通用处理中标志
    if echo "$output" | grep -qE "(⠋|⠙|⠹|⠸|⠼|⠴|⠦|⠧|⠇|⠏|Thinking|thinking|Analyzing|analyzing|Working|working|Generating|generating|Processing|processing)" 2>/dev/null; then
        return 0
    fi
    
    # Claude 特有: 显示工具调用或代码块
    if [[ "$cli_type" == "claude" ]]; then
        if echo "$output" | grep -qE "(Running|Editing|Reading|Writing|Searching)" 2>/dev/null; then
            return 0
        fi
    fi
    
    # Gemini 特有
    if [[ "$cli_type" == "gemini" ]]; then
        if echo "$output" | grep -qE "(Initializing|Loading)" 2>/dev/null; then
            return 0
        fi
    fi
    
    # Codex 特有
    if [[ "$cli_type" == "codex" ]]; then
        if echo "$output" | grep -qE "(Worked for|Token usage)" 2>/dev/null; then
            # 这是完成标志，不是处理中
            return 1
        fi
    fi
    
    return 1
}

# 检测是否在等待用户确认 (真正需要干预的情况)
# 只检查最后 15 行，避免历史输出干扰
is_waiting_confirm() {
    local output="$1"
    local last_lines=$(echo "$output" | tail -15)
    local very_last=$(echo "$output" | tail -5)
    
    # 如果最后几行显示空闲输入提示，说明不在等待确认
    if echo "$very_last" | grep -qE "^>\s*$|^────.*────$|Type your message|context left|^›\s*$" 2>/dev/null; then
        return 1
    fi
    
    # 真正需要用户确认的情况
    
    # 1. Claude CLI 特有: "Do you want to proceed?" 选择菜单
    if echo "$last_lines" | grep -qE "Do you want to proceed\?" 2>/dev/null; then
        # 检查是否有选项菜单 (1. Yes, 2. Yes allow, 3. No)
        if echo "$last_lines" | grep -qE "^\s*[>]?\s*[123]\.\s*(Yes|No)" 2>/dev/null; then
            return 0
        fi
    fi
    
    # 2. Gemini CLI 特有: "Allow execution of" 确认 或 loop detection
    if echo "$last_lines" | grep -qE "Allow execution of:|Allow.*\?|loop was detected|Keep loop detection" 2>/dev/null; then
        return 0
    fi
    
    # 3. Codex CLI 特有: 权限确认或选择确认
    if echo "$last_lines" | grep -qE "Waiting for user confirmation|Yes, proceed|Press enter to confirm" 2>/dev/null; then
        return 0
    fi
    
    # 4. 危险操作确认 (明确的 Y/N 提示)
    if echo "$last_lines" | grep -qE "\[Y/n\]|\[y/N\]|yes/no" 2>/dev/null; then
        return 0
    fi
    
    # 5. 选择菜单 - 只有在没有输入提示时才算等待确认
    if echo "$last_lines" | grep -qE "Esc to cancel.*Tab to amend" 2>/dev/null; then
        # 这是 Claude 的选择菜单，但需要确认不是已完成状态
        if ! echo "$very_last" | grep -qE "bypass permissions|shift\+tab to cycle" 2>/dev/null; then
            return 0
        fi
    fi
    
    return 1
}

# 检测是否空闲等待输入
is_idle() {
    local output="$1"
    local cli_type="$2"
    
    # 首先检查是否在处理中
    if echo "$output" | tail -15 | grep -qE "(⠋|⠙|⠹|⠸|⠼|⠴|⠦|⠧|⠇|⠏|Thinking|thinking|Working|working|Shenaniganing|Cogitat|Burrowing|esc to interrupt|esc to cancel)" 2>/dev/null; then
        return 1
    fi
    
    # 检查是否显示输入提示符
    case "$cli_type" in
        claude)
            # Claude 的输入提示: 空的 > 提示符
            if echo "$output" | tail -5 | grep -qE "^>\s*$" 2>/dev/null; then
                return 0
            fi
            ;;
        gemini)
            # Gemini 的输入提示: Type your message
            if echo "$output" | tail -5 | grep -qE "Type your message" 2>/dev/null; then
                return 0
            fi
            ;;
        codex)
            # Codex 的输入提示: 空的 › 提示符或 context left (没有 esc to interrupt)
            if echo "$output" | tail -5 | grep -qE "context left.*shortcuts" 2>/dev/null; then
                return 0
            fi
            ;;
    esac
    
    return 1
}

# 检测是否有未发送的输入 (输入框有内容但没执行)
has_pending_input() {
    local output="$1"
    local cli_type="$2"
    local last_lines=$(echo "$output" | tail -10)
    
    case "$cli_type" in
        gemini)
            # Gemini: 检查输入框是否有内容 (> 后面有实际文字，不是提示语)
            # 排除 "Type your message" 这种提示
            if echo "$last_lines" | grep -qE "^│ > " 2>/dev/null; then
                # 排除空输入框和提示语
                if echo "$last_lines" | grep -qE "^│ > \s*Type your message|^│ >\s*│|^│ >\s*$" 2>/dev/null; then
                    return 1
                fi
                # 确认有实际内容且没有在处理中
                if echo "$last_lines" | grep -qE "^│ > [^T│ ]" 2>/dev/null; then
                    if ! echo "$last_lines" | grep -qE "(⠋|⠙|⠹|⠸|⠼|⠴|⠦|⠧|⠇|⠏|esc to cancel)" 2>/dev/null; then
                        return 0
                    fi
                fi
            fi
            ;;
        claude)
            # Claude: 检查 > 后面有多行内容但没有 thinking/working
            if echo "$last_lines" | grep -qE "^> .+" 2>/dev/null; then
                if ! echo "$last_lines" | grep -qE "(Thinking|thinking|Working|·.*tokens)" 2>/dev/null; then
                    return 0
                fi
            fi
            ;;
        codex)
            # Codex: 检查 › 后面有内容但没有处理中标志
            # 排除默认提示语 "Write tests for @filename"
            if echo "$last_lines" | grep -qE "^› .+" 2>/dev/null; then
                # 排除默认提示语
                if echo "$last_lines" | grep -qE "^› Write tests for|^› \s*$" 2>/dev/null; then
                    return 1
                fi
                if ! echo "$last_lines" | grep -qE "(Searching|Investigating|esc to interrupt)" 2>/dev/null; then
                    return 0
                fi
            fi
            ;;
    esac
    
    return 1
}

check_agent() {
    local agent="$1"
    local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null)
    local output_tail=$(echo "$output" | tail -30)
    local last_activity=$(tmux -S "$SOCKET" display-message -t "$agent" -p '#{pane_last_activity}' 2>/dev/null)
    local current_cmd=$(tmux -S "$SOCKET" display-message -t "$agent" -p '#{pane_current_command}' 2>/dev/null)
    local now=$(date +%s)
    
    # 确保 last_activity 是有效数字
    if [[ -z "$last_activity" || "$last_activity" == "0" ]]; then
        last_activity=$now
    fi
    local idle_time=$((now - last_activity))
    
    # 检测 CLI 类型
    local cli_type=$(detect_cli_type "$output_tail" "$agent")
    
    # 状态判定
    local status="unknown"
    local health="healthy"
    
    # 1. 首先检查是否有 CLI 在运行
    if [[ "$cli_type" == "unknown" ]]; then
        # 检查是否在纯 shell
        if [[ "$current_cmd" == "bash" || "$current_cmd" == "zsh" || "$current_cmd" == "sh" ]]; then
            # 检查最后输出是否是 shell 提示符
            if echo "$output_tail" | tail -3 | grep -qE "\\\$\s*$|#\s*$" 2>/dev/null; then
                status="no_cli"
                health="warning"  # 改为 warning，不是 critical
            fi
        fi
    else
        # 2. CLI 在运行，检查具体状态
        
        # 2.1 检查是否正在处理任务
        if is_processing "$output_tail" "$cli_type"; then
            status="working"
            health="healthy"
        # 2.2 检查是否等待用户确认 (真正需要干预)
        elif is_waiting_confirm "$output_tail"; then
            status="needs_confirm"
            health="blocked"
        # 2.3 检查是否有未发送的输入 (输入框有内容但没按 Enter)
        elif has_pending_input "$output_tail" "$cli_type"; then
            status="pending_input"
            health="blocked"
        # 2.4 检查是否空闲
        elif is_idle "$output_tail" "$cli_type"; then
            status="idle"
            health="healthy"
        # 2.5 检查是否有错误
        elif echo "$output_tail" | grep -qE "(panic|PANIC|fatal|FATAL|Error:|ERROR:)" 2>/dev/null; then
            status="error"
            health="unhealthy"
        # 2.6 检查是否超时 (长时间无活动)
        elif [[ $idle_time -gt $DEADLOCK_THRESHOLD ]]; then
            status="timeout"
            health="warning"
        else
            # 默认: 可能在处理中或等待
            status="active"
            health="healthy"
        fi
    fi
    
    # 获取 context 使用率 (从 Redis 或解析输出)
    local context=0
    
    # 尝试从输出解析 context
    local ctx_match=$(echo "$output_tail" | grep -oE "[0-9]+%\s*context" | head -1 | grep -oE "[0-9]+")
    if [[ -n "$ctx_match" ]]; then
        context=$((100 - ctx_match))  # "100% context left" 意味着 0% 使用
    else
        # 从 Redis 获取
        context=$(redis-cli HGET "openclaw:agent:efficiency" "${agent}_context" 2>/dev/null | tr -d '%')
        context=${context:-0}
    fi
    
    # Context 健康检查
    if [[ $context -ge $CONTEXT_CRITICAL ]]; then
        health="critical"
    elif [[ $context -ge $CONTEXT_WARNING ]]; then
        [[ "$health" == "healthy" ]] && health="warning"
    fi
    
    echo "$agent|$status|$health|$idle_time|$context|$cli_type"
}

recover_agent() {
    local agent="$1"
    local status="$2"
    local cli_type="$3"
    
    case "$status" in
        no_cli)
            echo "  → 启动 AI CLI"
            case "$agent" in
                claude-agent) 
                    # 使用 Windows 的 claude (通过 cmd.exe)
                    tmux -S "$SOCKET" send-keys -t "$agent" "/mnt/c/Windows/System32/cmd.exe /c claude" Enter 
                    ;;
                gemini-agent) 
                    tmux -S "$SOCKET" send-keys -t "$agent" "gemini" Enter 
                    ;;
                codex-agent)  
                    tmux -S "$SOCKET" send-keys -t "$agent" "codex" Enter 
                    ;;
            esac
            ;;
        needs_confirm)
            echo "  → 自动确认 ($cli_type)"
            # 根据 CLI 类型选择不同的确认方式
            case "$cli_type" in
                claude)
                    # Claude CLI: 批量确认 - 连续发送多次 Down+Enter
                    # 选择 "2. Yes, allow for this session" 避免重复确认
                    for i in {1..5}; do
                        tmux -S "$SOCKET" send-keys -t "$agent" Down Enter
                        sleep 0.3
                    done
                    # 如果还卡着，考虑重启 (用跳过权限模式)
                    sleep 2
                    local still_blocked=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p | tail -10 | grep -c "Do you want to proceed")
                    if [[ $still_blocked -gt 0 ]]; then
                        echo "  → Claude 仍在等待确认，重启为无权限模式"
                        tmux -S "$SOCKET" send-keys -t "$agent" C-c
                        sleep 1
                        tmux -S "$SOCKET" send-keys -t "$agent" "/exit" Enter
                        sleep 1
                        tmux -S "$SOCKET" send-keys -t "$agent" "/mnt/c/Windows/System32/cmd.exe /c 'cd /d D:\\ai软件\\zed && claude --dangerously-skip-permissions'" Enter
                    fi
                    ;;
                gemini)
                    # Gemini CLI: 选择 "2. Allow for this session"
                    tmux -S "$SOCKET" send-keys -t "$agent" "2" Enter
                    sleep 0.5
                    # 多发几次以防多个确认
                    tmux -S "$SOCKET" send-keys -t "$agent" "2" Enter
                    ;;
                codex)
                    # Codex CLI: 通常按 Enter 或 y
                    tmux -S "$SOCKET" send-keys -t "$agent" Enter
                    sleep 0.5
                    tmux -S "$SOCKET" send-keys -t "$agent" "y" Enter
                    ;;
                *)
                    # 默认: 尝试多种方式
                    tmux -S "$SOCKET" send-keys -t "$agent" Enter
                    sleep 0.3
                    tmux -S "$SOCKET" send-keys -t "$agent" "y" Enter
                    sleep 0.3
                    tmux -S "$SOCKET" send-keys -t "$agent" "2" Enter
                    ;;
            esac
            ;;
        pending_input)
            echo "  → 发送 Enter 提交未发送的输入"
            tmux -S "$SOCKET" send-keys -t "$agent" Enter
            ;;
        timeout)
            echo "  → 发送 Ctrl+C 中断超时任务"
            tmux -S "$SOCKET" send-keys -t "$agent" C-c
            sleep 1
            echo "  → 发送恢复测试"
            tmux -S "$SOCKET" send-keys -t "$agent" "echo 'Agent recovered at $(date)'" Enter
            ;;
        error)
            echo "  → 发送 Ctrl+C 清除错误状态"
            tmux -S "$SOCKET" send-keys -t "$agent" C-c
            sleep 1
            # 尝试重启 CLI
            case "$agent" in
                claude-agent) 
                    tmux -S "$SOCKET" send-keys -t "$agent" "/mnt/c/Windows/System32/cmd.exe /c claude" Enter 
                    ;;
                gemini-agent) 
                    tmux -S "$SOCKET" send-keys -t "$agent" "gemini" Enter 
                    ;;
                codex-agent)  
                    tmux -S "$SOCKET" send-keys -t "$agent" "codex" Enter 
                    ;;
            esac
            ;;
    esac
    
    # 记录恢复事件
    redis-cli HINCRBY "openclaw:agent:recovery" "${agent}_count" 1 > /dev/null 2>&1
    redis-cli HSET "openclaw:agent:recovery" "${agent}_last" "$(date -Iseconds)" > /dev/null 2>&1
    redis-cli HSET "openclaw:agent:recovery" "${agent}_reason" "$status" > /dev/null 2>&1
    
    # 即时学习：记录问题和解决方案
    local solution_desc=""
    case "$status" in
        needs_confirm) solution_desc="auto_confirm_$cli_type" ;;
        timeout) solution_desc="ctrl_c_interrupt" ;;
        no_cli) solution_desc="restart_cli" ;;
        error) solution_desc="restart_cli" ;;
        *) solution_desc="unknown_fix" ;;
    esac
    "$WORKSPACE/scripts/learn.sh" "$status" "$agent" "$solution_desc" "true" 2>/dev/null
}

action="${1:-check}"

case "$action" in
    check)
        echo "🔍 Agent 健康检查"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        printf "%-15s %-15s %-10s %-10s %-10s %-10s\n" "Agent" "Status" "Health" "Idle(s)" "Context" "CLI"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        for agent in "${AGENTS[@]}"; do
            IFS='|' read -r name status health idle context cli_type <<< "$(check_agent "$agent")"
            
            # 颜色
            case "$health" in
                healthy)  color="$GREEN" ;;
                warning)  color="$YELLOW" ;;
                blocked)  color="$YELLOW" ;;
                *)        color="$RED" ;;
            esac
            
            printf "%-15s %-15s ${color}%-10s${NC} %-10s %-10s %-10s\n" \
                "$name" "$status" "$health" "$idle" "${context}%" "$cli_type"
        done
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        ;;
    
    recover)
        echo "🔧 Agent 自动恢复"
        RECOVERED=0
        
        for agent in "${AGENTS[@]}"; do
            IFS='|' read -r name status health idle context cli_type <<< "$(check_agent "$agent")"
            
            # 只恢复真正有问题的 agent (blocked, critical, unhealthy)
            if [[ "$health" == "blocked" || "$health" == "critical" || "$health" == "unhealthy" ]]; then
                echo "[$name] 状态: $status, 健康: $health, CLI: $cli_type"
                recover_agent "$name" "$status" "$cli_type"
                ((RECOVERED++))
            fi
        done
        
        if [[ $RECOVERED -eq 0 ]]; then
            echo "✅ 所有 agent 健康，无需恢复"
        else
            echo "✅ 恢复了 $RECOVERED 个 agent"
        fi
        ;;
    
    auto)
        # 自动模式: 检查并在需要时恢复
        NEEDS_RECOVERY=false
        
        for agent in "${AGENTS[@]}"; do
            # 直接获取输出，避免多次调用导致状态变化
            output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null)
            output_tail=$(echo "$output" | tail -30)
            last_lines=$(echo "$output" | tail -5)
            cli_type=$(detect_cli_type "$output_tail" "$agent")
            
            # 检查是否需要确认
            if is_waiting_confirm "$output_tail"; then
                NEEDS_RECOVERY=true
                echo "⚠️ [$agent] 需要确认"
                recover_agent "$agent" "needs_confirm" "$cli_type"
                continue
            fi
            
            # 检查是否有未发送的输入
            if has_pending_input "$output_tail" "$cli_type"; then
                NEEDS_RECOVERY=true
                echo "⚠️ [$agent] 有未发送的输入"
                recover_agent "$agent" "pending_input" "$cli_type"
                continue
            fi
        done
        
        if [[ "$NEEDS_RECOVERY" == "false" ]]; then
            echo "✅ 所有 agent 正常"
        fi
        ;;
    
    monitor)
        # 持续监控模式
        echo "👁️ 持续监控模式 (Ctrl+C 退出)"
        while true; do
            clear
            echo "🔍 Agent 健康监控 - $(date)"
            $0 check
            
            # 检查是否需要自动恢复
            for agent in "${AGENTS[@]}"; do
                IFS='|' read -r name status health idle context cli_type <<< "$(check_agent "$agent")"
                
                if [[ "$health" == "critical" || "$health" == "blocked" ]]; then
                    echo ""
                    echo "⚠️ 检测到问题，自动恢复..."
                    recover_agent "$name" "$status" "$cli_type"
                fi
            done
            
            sleep 60
        done
        ;;
    
    report)
        # 生成健康报告
        echo "📊 Agent 健康报告 - $(date)"
        echo ""
        
        for agent in "${AGENTS[@]}"; do
            IFS='|' read -r name status health idle context cli_type <<< "$(check_agent "$agent")"
            
            echo "### $name"
            echo "- CLI 类型: $cli_type"
            echo "- 状态: $status"
            echo "- 健康: $health"
            echo "- 空闲时间: ${idle}s"
            echo "- Context 使用: ${context}%"
            
            # 恢复历史
            RECOVERY_COUNT=$(redis-cli HGET "openclaw:agent:recovery" "${name}_count" 2>/dev/null)
            LAST_RECOVERY=$(redis-cli HGET "openclaw:agent:recovery" "${name}_last" 2>/dev/null)
            LAST_REASON=$(redis-cli HGET "openclaw:agent:recovery" "${name}_reason" 2>/dev/null)
            if [[ -n "$RECOVERY_COUNT" ]]; then
                echo "- 恢复次数: $RECOVERY_COUNT"
                echo "- 最后恢复: $LAST_RECOVERY"
                echo "- 恢复原因: $LAST_REASON"
            fi
            echo ""
        done
        ;;
    
    status)
        # 简洁状态输出 (适合 cron)
        ALL_HEALTHY=true
        for agent in "${AGENTS[@]}"; do
            IFS='|' read -r name status health idle context cli_type <<< "$(check_agent "$agent")"
            if [[ "$health" != "healthy" ]]; then
                ALL_HEALTHY=false
                echo "$name: $status ($health)"
            fi
        done
        
        if [[ "$ALL_HEALTHY" == "true" ]]; then
            echo "ok"
        fi
        ;;
    
    *)
        echo "用法: $0 [check|recover|auto|monitor|report|status]"
        echo ""
        echo "命令:"
        echo "  check   - 显示所有 agent 状态"
        echo "  recover - 恢复所有异常 agent"
        echo "  auto    - 检查并自动恢复 (适合 cron)"
        echo "  monitor - 持续监控模式"
        echo "  report  - 生成详细报告"
        echo "  status  - 简洁状态输出"
        ;;
esac
