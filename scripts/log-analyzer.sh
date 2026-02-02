#!/bin/bash
# log-analyzer.sh - 日志分析器
# 分析历史日志，发现模式和问题

WORKSPACE="/home/jinyang/.openclaw/workspace"
REDIS_PREFIX="openclaw:logs"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# 分析事件统计
analyze_events() {
    local hours="${1:-24}"
    local since=$(($(date +%s) - hours * 3600))
    
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    📊 事件统计 (最近 ${hours}h)                      ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # 恢复次数
    local recoveries=$(redis-cli HGET "openclaw:evo:stats" "recovered:total" 2>/dev/null || echo 0)
    echo -e "恢复次数: ${YELLOW}$recoveries${NC}"
    
    # 派发任务数
    local dispatched=$(redis-cli HGET "openclaw:evo:stats" "dispatched:total" 2>/dev/null || echo 0)
    echo -e "派发任务: ${GREEN}$dispatched${NC}"
    
    # 错误次数
    local errors=$(redis-cli HGET "openclaw:evo:stats" "errors:total" 2>/dev/null || echo 0)
    echo -e "错误次数: ${RED}$errors${NC}"
    
    echo ""
}

# 分析 agent 统计
analyze_agents() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    👥 Agent 统计                                  ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    for agent in claude-agent gemini-agent codex-agent; do
        echo -e "${GREEN}$agent:${NC}"
        
        local dispatched=$(redis-cli HGET "openclaw:evo:stats" "dispatched:$agent" 2>/dev/null || echo 0)
        local recovered=$(redis-cli HGET "openclaw:evo:stats" "recovered:$agent" 2>/dev/null || echo 0)
        local retries=$(redis-cli HGET "openclaw:evo:retry:$agent" "count" 2>/dev/null || echo 0)
        
        echo "  派发任务: $dispatched"
        echo "  恢复次数: $recovered"
        echo "  当前重试: $retries"
        echo ""
    done
}

# 识别问题模式
identify_patterns() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    🔍 问题模式识别                                ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    local issues=()
    
    # 检查高重试率
    for agent in claude-agent gemini-agent codex-agent; do
        local retries=$(redis-cli HGET "openclaw:evo:retry:$agent" "count" 2>/dev/null || echo 0)
        if [[ $retries -gt 5 ]]; then
            issues+=("$agent 重试次数过高 ($retries)")
        fi
    done
    
    # 检查网络问题
    for agent in claude-agent gemini-agent codex-agent; do
        local net_retries=$(redis-cli GET "openclaw:predict:retries:$agent" 2>/dev/null || echo 0)
        if [[ $net_retries -gt 5 ]]; then
            issues+=("$agent 网络重试频繁 ($net_retries)")
        fi
    done
    
    if [[ ${#issues[@]} -gt 0 ]]; then
        echo -e "${RED}发现问题:${NC}"
        for issue in "${issues[@]}"; do
            echo "  ⚠️ $issue"
        done
    else
        echo -e "${GREEN}✓ 未发现明显问题模式${NC}"
    fi
    
    echo ""
}

# 生成健康报告
health_report() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    🏥 系统健康报告                                ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # 检查各组件
    echo -e "${GREEN}组件状态:${NC}"
    
    # Redis
    if redis-cli ping >/dev/null 2>&1; then
        echo -e "  Redis: ${GREEN}✓ 正常${NC}"
    else
        echo -e "  Redis: ${RED}✗ 异常${NC}"
    fi
    
    # tmux
    if tmux -S /tmp/openclaw-agents.sock list-sessions >/dev/null 2>&1; then
        echo -e "  tmux: ${GREEN}✓ 正常${NC}"
    else
        echo -e "  tmux: ${RED}✗ 异常${NC}"
    fi
    
    # Agents
    for agent in claude-agent gemini-agent codex-agent; do
        if tmux -S /tmp/openclaw-agents.sock has-session -t "$agent" 2>/dev/null; then
            echo -e "  $agent: ${GREEN}✓ 运行中${NC}"
        else
            echo -e "  $agent: ${RED}✗ 未运行${NC}"
        fi
    done
    
    echo ""
    
    # 待处理问题
    echo -e "${YELLOW}待处理问题:${NC}"
    local pending=0
    
    for agent in claude-agent gemini-agent codex-agent; do
        local needs_restart=$(redis-cli GET "openclaw:predict:needs_restart:$agent" 2>/dev/null)
        if [[ "$needs_restart" == "1" ]]; then
            echo "  - $agent 需要重启"
            ((pending++))
        fi
    done
    
    [[ $pending -eq 0 ]] && echo "  (无)"
    
    echo ""
}

# 生成优化建议
suggest_optimizations() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    💡 优化建议                                    ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    local suggestions=()
    
    # 检查 Gemini 重试
    local gemini_retries=$(redis-cli HGET "openclaw:evo:retry:gemini-agent" "count" 2>/dev/null || echo 0)
    if [[ $gemini_retries -gt 5 ]]; then
        suggestions+=("考虑增加 Gemini 的网络超时时间")
    fi
    
    # 检查任务分配
    local claude_tasks=$(redis-cli HGET "openclaw:evo:stats" "dispatched:claude-agent" 2>/dev/null || echo 0)
    local gemini_tasks=$(redis-cli HGET "openclaw:evo:stats" "dispatched:gemini-agent" 2>/dev/null || echo 0)
    local codex_tasks=$(redis-cli HGET "openclaw:evo:stats" "dispatched:codex-agent" 2>/dev/null || echo 0)
    
    local total=$((claude_tasks + gemini_tasks + codex_tasks))
    if [[ $total -gt 0 ]]; then
        local claude_pct=$((claude_tasks * 100 / total))
        local gemini_pct=$((gemini_tasks * 100 / total))
        local codex_pct=$((codex_tasks * 100 / total))
        
        if [[ $claude_pct -gt 50 ]]; then
            suggestions+=("Claude 任务占比过高 ($claude_pct%)，考虑分散负载")
        fi
    fi
    
    if [[ ${#suggestions[@]} -gt 0 ]]; then
        for suggestion in "${suggestions[@]}"; do
            echo "  • $suggestion"
        done
    else
        echo "  暂无优化建议"
    fi
    
    echo ""
}

# 完整分析
full_analysis() {
    local hours="${1:-6}"
    
    analyze_events "$hours"
    analyze_agents
    identify_patterns
    health_report
    suggest_optimizations
}

# 主入口
case "${1:-full}" in
    events)
        analyze_events "${2:-24}"
        ;;
    agents)
        analyze_agents
        ;;
    patterns)
        identify_patterns
        ;;
    health)
        health_report
        ;;
    suggest)
        suggest_optimizations
        ;;
    full)
        full_analysis "${2:-6}"
        ;;
    *)
        echo "用法: $0 <command> [args...]"
        echo ""
        echo "命令:"
        echo "  events [hours]  - 事件统计"
        echo "  agents          - Agent 统计"
        echo "  patterns        - 问题模式识别"
        echo "  health          - 健康报告"
        echo "  suggest         - 优化建议"
        echo "  full [hours]    - 完整分析"
        ;;
esac
