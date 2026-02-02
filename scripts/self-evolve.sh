#!/bin/bash
# self-evolve.sh - 自我进化系统 v1.0
# 分析工作缺陷，提出改进，记录学习

WORKSPACE="/home/jinyang/.openclaw/workspace"
EVOLUTION_LOG="$WORKSPACE/memory/evolution-log.md"
SOCKET="/tmp/openclaw-agents.sock"

# 确保目录存在
mkdir -p "$WORKSPACE/memory"

# 1. 收集今日工作数据
collect_metrics() {
    echo "📊 收集工作指标..."
    
    # Agent 恢复次数
    local claude_recoveries=$(redis-cli HGET "openclaw:agent:recovery" "claude-agent_count" 2>/dev/null || echo 0)
    local gemini_recoveries=$(redis-cli HGET "openclaw:agent:recovery" "gemini-agent_count" 2>/dev/null || echo 0)
    local codex_recoveries=$(redis-cli HGET "openclaw:agent:recovery" "codex-agent_count" 2>/dev/null || echo 0)
    
    # 死锁统计
    local total_deadlocks=$(redis-cli HGET "openclaw:deadlock:stats" "total_recoveries" 2>/dev/null || echo 0)
    
    # Context 溢出次数
    local context_overflows=$(redis-cli GET "openclaw:context:overflow_count" 2>/dev/null || echo 0)
    
    # 任务完成统计
    local tasks_completed=$(redis-cli SCARD "openclaw:tasks:completed" 2>/dev/null || echo 0)
    local tasks_failed=$(redis-cli SCARD "openclaw:tasks:failed" 2>/dev/null || echo 0)
    
    echo "claude_recoveries=$claude_recoveries"
    echo "gemini_recoveries=$gemini_recoveries"
    echo "codex_recoveries=$codex_recoveries"
    echo "total_deadlocks=$total_deadlocks"
    echo "context_overflows=$context_overflows"
    echo "tasks_completed=$tasks_completed"
    echo "tasks_failed=$tasks_failed"
}

# 2. 分析问题模式
analyze_patterns() {
    echo "🔍 分析问题模式..."
    
    local issues=()
    
    # 检查 agent 恢复原因
    for agent in claude-agent gemini-agent codex-agent; do
        local reason=$(redis-cli HGET "openclaw:agent:recovery" "${agent}_reason" 2>/dev/null)
        if [[ -n "$reason" ]]; then
            issues+=("$agent: $reason")
        fi
    done
    
    # 检查学习库中的重复问题
    local repeated=$(redis-cli KEYS "openclaw:learning:*" 2>/dev/null | wc -l)
    if [[ $repeated -gt 0 ]]; then
        echo "发现 $repeated 个已学习的问题模式"
    fi
    
    # 输出问题
    for issue in "${issues[@]}"; do
        echo "  - $issue"
    done
}

# 3. 生成改进建议
generate_improvements() {
    echo "💡 生成改进建议..."
    
    local suggestions=()
    
    # 基于恢复次数
    local total_recoveries=$(redis-cli HGET "openclaw:agent:recovery" "claude-agent_count" 2>/dev/null || echo 0)
    total_recoveries=$((total_recoveries + $(redis-cli HGET "openclaw:agent:recovery" "gemini-agent_count" 2>/dev/null || echo 0)))
    total_recoveries=$((total_recoveries + $(redis-cli HGET "openclaw:agent:recovery" "codex-agent_count" 2>/dev/null || echo 0)))
    
    if [[ $total_recoveries -gt 10 ]]; then
        suggestions+=("恢复次数过多($total_recoveries)，考虑优化 agent 启动参数或任务分配")
    fi
    
    # 基于 context 使用
    for agent in claude-agent gemini-agent codex-agent; do
        local ctx=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null | grep -oE "[0-9]+%\s*context" | head -1 | grep -oE "[0-9]+")
        if [[ -n "$ctx" && $ctx -lt 30 ]]; then
            suggestions+=("$agent context 剩余 $ctx%，考虑重启或压缩")
        fi
    done
    
    # 输出建议
    for s in "${suggestions[@]}"; do
        echo "  → $s"
    done
}

# 4. 记录进化日志
log_evolution() {
    local date=$(date +%Y-%m-%d)
    local time=$(date +%H:%M)
    
    # 如果今天的条目不存在，创建标题
    if ! grep -q "## $date" "$EVOLUTION_LOG" 2>/dev/null; then
        echo -e "\n## $date\n" >> "$EVOLUTION_LOG"
    fi
    
    echo "### $time 自我检查" >> "$EVOLUTION_LOG"
    echo "" >> "$EVOLUTION_LOG"
    
    # 记录指标
    echo "**指标**:" >> "$EVOLUTION_LOG"
    collect_metrics | grep "=" | while read line; do
        echo "- $line" >> "$EVOLUTION_LOG"
    done
    echo "" >> "$EVOLUTION_LOG"
    
    # 记录问题
    echo "**发现的问题**:" >> "$EVOLUTION_LOG"
    analyze_patterns | grep "  -" >> "$EVOLUTION_LOG" || echo "- 无明显问题" >> "$EVOLUTION_LOG"
    echo "" >> "$EVOLUTION_LOG"
    
    # 记录建议
    echo "**改进建议**:" >> "$EVOLUTION_LOG"
    generate_improvements | grep "  →" >> "$EVOLUTION_LOG" || echo "- 系统运行良好" >> "$EVOLUTION_LOG"
    echo "" >> "$EVOLUTION_LOG"
}

# 5. 自动应用简单修复
auto_fix() {
    echo "🔧 尝试自动修复..."
    
    # 检查并重启 context 过低的 agent
    for agent in claude-agent gemini-agent codex-agent; do
        local ctx=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null | grep -oE "[0-9]+%\s*context" | head -1 | grep -oE "[0-9]+")
        if [[ -n "$ctx" && $ctx -lt 20 ]]; then
            echo "  → $agent context 仅剩 $ctx%，触发重启"
            "$WORKSPACE/scripts/start-agents.sh" restart "$agent"
        fi
    done
}

# 主流程
case "${1:-check}" in
    check)
        echo "🧬 自我进化检查 - $(date)"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        collect_metrics
        echo ""
        analyze_patterns
        echo ""
        generate_improvements
        ;;
    evolve)
        echo "🧬 执行自我进化 - $(date)"
        log_evolution
        auto_fix
        echo "✅ 进化记录已保存到 $EVOLUTION_LOG"
        ;;
    log)
        cat "$EVOLUTION_LOG" 2>/dev/null || echo "暂无进化日志"
        ;;
    *)
        echo "用法: $0 [check|evolve|log]"
        echo "  check  - 检查当前状态和问题"
        echo "  evolve - 执行进化（记录+自动修复）"
        echo "  log    - 查看进化日志"
        ;;
esac
