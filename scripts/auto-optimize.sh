#!/bin/bash
# auto-optimize.sh - 自动优化系统
# 根据日志分析结果自动调整参数和策略

WORKSPACE="/home/jinyang/.openclaw/workspace"
REDIS_PREFIX="openclaw:optimize"
SOCKET="/tmp/openclaw-agents.sock"

log() {
    echo "[$(date '+%H:%M:%S')] $1"
    redis-cli LPUSH "$REDIS_PREFIX:log" "[$(date '+%H:%M:%S')] $1" 2>/dev/null
    redis-cli LTRIM "$REDIS_PREFIX:log" 0 99 2>/dev/null
}

# 分析并优化 Gemini
optimize_gemini() {
    local gemini_rec=$(redis-cli LRANGE "openclaw:events:queue" 0 50 2>/dev/null | grep -c '"agent":"gemini-agent".*RECOVERED')
    local gemini_retry=$(redis-cli HGET "openclaw:evo:retry:gemini-agent" "count" 2>/dev/null)
    
    if [[ $gemini_rec -gt 5 || ${gemini_retry:-0} -gt 5 ]]; then
        log "Gemini 频繁恢复，增加等待时间"
        redis-cli SET "$REDIS_PREFIX:gemini:wait_multiplier" "2" 2>/dev/null
    elif [[ $gemini_rec -lt 2 && ${gemini_retry:-0} -lt 2 ]]; then
        log "Gemini 稳定，恢复正常等待时间"
        redis-cli SET "$REDIS_PREFIX:gemini:wait_multiplier" "1" 2>/dev/null
    fi
}

# 分析并优化 Context
optimize_context() {
    for agent in claude-agent gemini-agent codex-agent; do
        local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null)
        local ctx=$(echo "$output" | grep -oE "[0-9]+% context" | tail -1 | grep -oE "^[0-9]+")
        
        if [[ -n "$ctx" ]]; then
            redis-cli HSET "$REDIS_PREFIX:context:$agent" "usage" "$ctx" "time" "$(date +%s)" 2>/dev/null
            
            if [[ "$ctx" -lt 30 ]]; then
                log "$agent context 低 (${ctx}%)，标记需要重启"
                redis-cli SADD "$REDIS_PREFIX:needs_restart" "$agent" 2>/dev/null
            elif [[ "$ctx" -gt 70 ]]; then
                redis-cli SREM "$REDIS_PREFIX:needs_restart" "$agent" 2>/dev/null
            fi
        fi
    done
}

# 优化任务分配
optimize_dispatch() {
    # 分析各 agent 的任务完成率
    local claude_dispatched=$(redis-cli HGET "openclaw:evo:stats" "dispatched:claude-agent" 2>/dev/null)
    local gemini_dispatched=$(redis-cli HGET "openclaw:evo:stats" "dispatched:gemini-agent" 2>/dev/null)
    local codex_dispatched=$(redis-cli HGET "openclaw:evo:stats" "dispatched:codex-agent" 2>/dev/null)
    
    # 如果某个 agent 派发任务明显少，可能是因为它更稳定
    # 可以给它分配更多任务
    local total=$((${claude_dispatched:-0} + ${gemini_dispatched:-0} + ${codex_dispatched:-0}))
    
    if [[ $total -gt 0 ]]; then
        local claude_ratio=$((${claude_dispatched:-0} * 100 / total))
        local gemini_ratio=$((${gemini_dispatched:-0} * 100 / total))
        local codex_ratio=$((${codex_dispatched:-0} * 100 / total))
        
        redis-cli HSET "$REDIS_PREFIX:dispatch_ratio" \
            "claude" "$claude_ratio" \
            "gemini" "$gemini_ratio" \
            "codex" "$codex_ratio" 2>/dev/null
    fi
}

# 清理过期数据
cleanup() {
    # 清理超过 24 小时的事件
    local cutoff=$(($(date +%s) - 86400))
    
    # 保留最近 100 条事件
    redis-cli LTRIM "openclaw:events:queue" 0 99 2>/dev/null
    redis-cli LTRIM "openclaw:evo:events" 0 99 2>/dev/null
    
    log "清理完成"
}

# 生成优化报告
report() {
    echo "===== 自动优化报告 ====="
    echo ""
    echo "Gemini 等待倍数: $(redis-cli GET "$REDIS_PREFIX:gemini:wait_multiplier" 2>/dev/null || echo 1)"
    echo ""
    echo "Context 使用率:"
    for agent in claude-agent gemini-agent codex-agent; do
        local usage=$(redis-cli HGET "$REDIS_PREFIX:context:$agent" "usage" 2>/dev/null)
        echo "  $agent: ${usage:-未知}%"
    done
    echo ""
    echo "需要重启的 Agent:"
    redis-cli SMEMBERS "$REDIS_PREFIX:needs_restart" 2>/dev/null | while read -r agent; do
        echo "  - $agent"
    done
    echo ""
    echo "派发比例:"
    redis-cli HGETALL "$REDIS_PREFIX:dispatch_ratio" 2>/dev/null | while read -r key; do
        read -r value
        echo "  $key: ${value}%"
    done
    echo ""
    echo "最近优化日志:"
    redis-cli LRANGE "$REDIS_PREFIX:log" 0 5 2>/dev/null
}

# 执行所有优化
run_all() {
    log "开始自动优化..."
    optimize_gemini
    optimize_context
    optimize_dispatch
    log "优化完成"
}

# 入口
case "${1:-run}" in
    run) run_all ;;
    gemini) optimize_gemini ;;
    context) optimize_context ;;
    dispatch) optimize_dispatch ;;
    cleanup) cleanup ;;
    report) report ;;
    *) echo "用法: $0 {run|gemini|context|dispatch|cleanup|report}" ;;
esac
