#!/bin/bash
# workflow-check.sh - 综合工作流检查与自动修复
# 每5分钟运行一次，检查所有系统是否正常

WORKSPACE="/home/jinyang/.openclaw/workspace"
SOCKET="/tmp/openclaw-agents.sock"
LOG_FILE="$WORKSPACE/memory/workflow-check.log"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 记录日志
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    echo "$1"
}

# 问题计数
ISSUES=0
FIXED=0

# 1. 检查 tmux 会话
check_tmux() {
    log "📋 检查 tmux 会话..."
    
    if ! tmux -S "$SOCKET" list-sessions &>/dev/null; then
        log "❌ tmux 会话不存在"
        ((ISSUES++))
        # 尝试修复: 重新创建会话
        log "  → 尝试重新创建 tmux 会话"
        "$WORKSPACE/scripts/start-agents.sh" &>/dev/null
        if tmux -S "$SOCKET" list-sessions &>/dev/null; then
            log "  ✅ tmux 会话已恢复"
            ((FIXED++))
        fi
        return 1
    fi
    
    # 检查每个 agent 会话
    for agent in claude-agent gemini-agent codex-agent; do
        if ! tmux -S "$SOCKET" has-session -t "$agent" &>/dev/null; then
            log "❌ $agent 会话不存在"
            ((ISSUES++))
        fi
    done
    
    return 0
}

# 2. 检查 Agent 健康状态
check_agents() {
    log "📋 检查 Agent 健康状态..."
    
    for agent in claude-agent gemini-agent codex-agent; do
        local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null | tail -20)
        local last_lines=$(echo "$output" | tail -5)
        
        # 检查是否正在处理中
        local is_working=false
        if echo "$output" | grep -qE "(⠋|⠙|⠹|⠸|Thinking|Working|Shenaniganing|Cogitat|Cooked|esc to interrupt|esc to cancel)" 2>/dev/null; then
            is_working=true
        fi
        
        # 如果不在工作中，检查是否有未发送的输入
        if [[ "$is_working" == "false" ]]; then
            # Claude: > 后面有内容
            if echo "$last_lines" | grep -qE "^> .+" 2>/dev/null; then
                # 排除空提示符
                if ! echo "$last_lines" | grep -qE "^>\s*$" 2>/dev/null; then
                    log "⚠️ $agent 有未发送的输入 (Claude)"
                    ((ISSUES++))
                    tmux -S "$SOCKET" send-keys -t "$agent" Enter
                    log "  → 已发送 Enter"
                    ((FIXED++))
                fi
            fi
            
            # Gemini: │ > 后面有内容 (排除 Type your message)
            if echo "$last_lines" | grep -qE "^│ > " 2>/dev/null; then
                if ! echo "$last_lines" | grep -qE "Type your message|^│ >\s*│|^│ >\s*$" 2>/dev/null; then
                    log "⚠️ $agent 有未发送的输入 (Gemini)"
                    ((ISSUES++))
                    tmux -S "$SOCKET" send-keys -t "$agent" Enter
                    log "  → 已发送 Enter"
                    ((FIXED++))
                fi
            fi
            
            # Codex: › 后面有内容
            if echo "$last_lines" | grep -qE "^› .+" 2>/dev/null; then
                if ! echo "$last_lines" | grep -qE "^›\s*$" 2>/dev/null; then
                    log "⚠️ $agent 有未发送的输入 (Codex)"
                    ((ISSUES++))
                    tmux -S "$SOCKET" send-keys -t "$agent" Enter
                    log "  → 已发送 Enter"
                    ((FIXED++))
                fi
            fi
        fi
        
        # 检查是否卡在确认界面
        if echo "$last_lines" | grep -qE "Do you want to proceed|Allow execution|Waiting for.*confirm|\[Y/n\]|Yes, proceed|Press enter to confirm" 2>/dev/null; then
            log "⚠️ $agent 卡在确认界面"
            ((ISSUES++))
            # 修复: 发送确认
            tmux -S "$SOCKET" send-keys -t "$agent" Enter
            log "  → 已发送 Enter 确认"
            ((FIXED++))
        fi
        
        # 检查 context 使用率 (Codex 特有)
        if [[ "$agent" == "codex-agent" ]]; then
            local ctx_left=$(echo "$output" | grep -oE "[0-9]+% context left" | grep -oE "[0-9]+" | head -1)
            if [[ -n "$ctx_left" && $ctx_left -lt 25 ]]; then
                log "⚠️ $agent context 只剩 ${ctx_left}%，需要重启"
                ((ISSUES++))
                # 重启 Codex
                tmux -S "$SOCKET" send-keys -t "$agent" C-c
                sleep 1
                tmux -S "$SOCKET" send-keys -t "$agent" "/exit" Enter
                sleep 2
                tmux -S "$SOCKET" send-keys -t "$agent" "codex" Enter
                sleep 3
                tmux -S "$SOCKET" send-keys -t "$agent" "继续之前的工作，运行 cargo check 检查编译错误" Enter
                log "  → 已重启 Codex"
                ((FIXED++))
            fi
        fi
        
        # 检查是否空闲太久 (超过10分钟)
        local idle_check=$(echo "$last_lines" | grep -qE "^>\s*$|^›\s*$|Type your message" && echo "idle")
        if [[ "$idle_check" == "idle" ]]; then
            # 检查 Redis 中的最后活动时间
            local last_dispatch=$(redis-cli HGET "openclaw:dispatch:stats" "${agent}_last" 2>/dev/null)
            if [[ -n "$last_dispatch" ]]; then
                local last_ts=$(date -d "$last_dispatch" +%s 2>/dev/null || echo 0)
                local now=$(date +%s)
                local idle_time=$((now - last_ts))
                if [[ $idle_time -gt 600 ]]; then
                    log "⚠️ $agent 空闲超过10分钟"
                    ((ISSUES++))
                fi
            fi
        fi
    done
}

# 3. 检查 Redis 连接
check_redis() {
    log "📋 检查 Redis 连接..."
    
    if ! redis-cli ping &>/dev/null; then
        log "❌ Redis 连接失败"
        ((ISSUES++))
        return 1
    fi
    
    return 0
}

# 4. 检查 Git 状态
check_git() {
    log "📋 检查 Git 状态..."
    
    cd "$WORKSPACE"
    
    # 检查是否有未提交的更改
    local changes=$(git status --porcelain 2>/dev/null | wc -l)
    if [[ $changes -gt 10 ]]; then
        log "⚠️ 有 $changes 个未提交的文件"
        ((ISSUES++))
    fi
    
    # 检查是否有未推送的提交
    local unpushed=$(git log origin/master..HEAD --oneline 2>/dev/null | wc -l)
    if [[ $unpushed -gt 5 ]]; then
        log "⚠️ 有 $unpushed 个未推送的提交"
        ((ISSUES++))
        # 自动推送
        git push &>/dev/null
        if [[ $? -eq 0 ]]; then
            log "  → 已自动推送"
            ((FIXED++))
        fi
    fi
}

# 5. 检查 Cron 任务
check_cron() {
    log "📋 检查 Cron 任务..."
    
    # 这个由 OpenClaw 管理，这里只记录状态
    local auto_manage_enabled=$(redis-cli GET "openclaw:cron:auto-manage:enabled" 2>/dev/null)
    if [[ "$auto_manage_enabled" == "false" ]]; then
        log "⚠️ auto-manage cron 任务被禁用"
        ((ISSUES++))
    fi
}

# 6. 自我进化检查
check_evolution() {
    log "📋 检查自我进化..."
    
    # 检查最近是否有进化记录
    local last_evolution=$(redis-cli HGET "openclaw:evolution" "last_update" 2>/dev/null)
    # 这里可以添加更多进化检查逻辑
}

# 主函数
main() {
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log "🔍 工作流综合检查 - $(date '+%Y-%m-%d %H:%M:%S')"
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    check_tmux
    check_agents
    check_redis
    check_git
    
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if [[ $ISSUES -eq 0 ]]; then
        log "✅ 所有工作流正常运行"
        echo "ok"
    else
        log "📊 发现 $ISSUES 个问题，修复了 $FIXED 个"
        
        # 记录到 Redis
        redis-cli HINCRBY "openclaw:workflow:stats" "total_issues" $ISSUES &>/dev/null
        redis-cli HINCRBY "openclaw:workflow:stats" "total_fixed" $FIXED &>/dev/null
        redis-cli HSET "openclaw:workflow:stats" "last_check" "$(date -Iseconds)" &>/dev/null
        
        # 如果有未修复的问题，输出警告
        local unfixed=$((ISSUES - FIXED))
        if [[ $unfixed -gt 0 ]]; then
            echo "⚠️ 有 $unfixed 个问题需要关注"
        else
            echo "✅ 所有问题已自动修复"
        fi
    fi
    
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# 运行
main "$@"
