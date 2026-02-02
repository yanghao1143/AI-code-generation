#!/bin/bash
# log-analyzer.sh - 日志分析系统
# 分析事件日志，识别模式，生成报告

REDIS_PREFIX="openclaw"
WORKSPACE="/home/jinyang/.openclaw/workspace"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 分析事件队列
analyze_events() {
    local hours="${1:-24}"
    local cutoff=$(($(date +%s) - hours * 3600))
    
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}       📊 事件日志分析 (最近 ${hours}h)${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo ""
    
    # 统计各类事件
    local total=0
    local recovered=0
    local state_changes=0
    local errors=0
    
    declare -A agent_recovered
    declare -A agent_errors
    
    while read -r event; do
        [[ -z "$event" ]] && continue
        
        local ts=$(echo "$event" | grep -oP '"ts":\K[0-9]+')
        [[ -n "$ts" && "$ts" -lt "$cutoff" ]] && continue
        
        total=$((total + 1))
        
        local type=$(echo "$event" | grep -oP '"type":"\K[^"]+')
        local agent=$(echo "$event" | grep -oP '"agent":"\K[^"]+')
        
        case "$type" in
            RECOVERED)
                recovered=$((recovered + 1))
                agent_recovered[$agent]=$((${agent_recovered[$agent]:-0} + 1))
                ;;
            STATE_CHANGE)
                state_changes=$((state_changes + 1))
                local to=$(echo "$event" | grep -oP '"to":"\K[^"]+')
                if [[ "$to" == "ERROR" ]]; then
                    errors=$((errors + 1))
                    agent_errors[$agent]=$((${agent_errors[$agent]:-0} + 1))
                fi
                ;;
        esac
    done < <(redis-cli LRANGE "${REDIS_PREFIX}:events:queue" 0 200 2>/dev/null)
    
    echo -e "${CYAN}📈 总体统计${NC}"
    echo "  总事件数: $total"
    echo "  恢复次数: $recovered"
    echo "  状态变化: $state_changes"
    echo "  错误次数: $errors"
    echo ""
    
    echo -e "${CYAN}🤖 Agent 统计${NC}"
    for agent in claude-agent gemini-agent codex-agent; do
        local rec=${agent_recovered[$agent]:-0}
        local err=${agent_errors[$agent]:-0}
        local status="✅"
        [[ $rec -gt 3 ]] && status="⚠️"
        [[ $rec -gt 5 ]] && status="🔴"
        printf "  %-14s 恢复:%d 错误:%d %s\n" "$agent" "$rec" "$err" "$status"
    done
    echo ""
    
    # 识别问题模式
    echo -e "${CYAN}🔍 问题模式识别${NC}"
    
    # Gemini 网络问题
    if [[ ${agent_recovered[gemini-agent]:-0} -gt 3 ]]; then
        echo -e "  ${YELLOW}⚠️ Gemini 频繁恢复 (${agent_recovered[gemini-agent]}次)${NC}"
        echo "     → 可能是网络不稳定或 API 限流"
        echo "     → 建议: 增加重试等待时间"
    fi
    
    # Codex 错误
    if [[ ${agent_errors[codex-agent]:-0} -gt 2 ]]; then
        echo -e "  ${YELLOW}⚠️ Codex 频繁出错 (${agent_errors[codex-agent]}次)${NC}"
        echo "     → 可能是编译错误或权限问题"
        echo "     → 建议: 检查任务复杂度"
    fi
    
    # Claude 稳定
    if [[ ${agent_recovered[claude-agent]:-0} -eq 0 ]]; then
        echo -e "  ${GREEN}✅ Claude 运行稳定${NC}"
    fi
    
    echo ""
}

# 分析 evolution 统计
analyze_evolution() {
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}       🧬 Evolution 统计${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo ""
    
    echo -e "${CYAN}📤 任务派发${NC}"
    redis-cli HGETALL "openclaw:evo:stats" 2>/dev/null | while read -r key; do
        read -r value
        printf "  %-25s %s\n" "$key:" "$value"
    done
    echo ""
    
    echo -e "${CYAN}🔄 重试计数${NC}"
    for agent in claude-agent gemini-agent codex-agent; do
        local count=$(redis-cli HGET "openclaw:evo:retry:$agent" "count" 2>/dev/null)
        printf "  %-14s %s\n" "$agent:" "${count:-0}"
    done
    echo ""
    
    echo -e "${CYAN}📝 最近事件${NC}"
    redis-cli LRANGE "openclaw:evo:events" 0 5 2>/dev/null | while read -r event; do
        echo "  $event"
    done
    echo ""
}

# 生成健康报告
health_report() {
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}       🏥 系统健康报告${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo ""
    
    # 检查各组件
    echo -e "${CYAN}🔧 组件状态${NC}"
    
    # Redis
    if redis-cli ping &>/dev/null; then
        echo -e "  Redis:        ${GREEN}✅ 正常${NC}"
    else
        echo -e "  Redis:        ${RED}❌ 离线${NC}"
    fi
    
    # tmux
    if tmux -S /tmp/openclaw-agents.sock list-sessions &>/dev/null; then
        local sessions=$(tmux -S /tmp/openclaw-agents.sock list-sessions 2>/dev/null | wc -l)
        echo -e "  tmux:         ${GREEN}✅ $sessions 个会话${NC}"
    else
        echo -e "  tmux:         ${RED}❌ 无会话${NC}"
    fi
    
    # Agent 状态
    echo ""
    echo -e "${CYAN}🤖 Agent 状态${NC}"
    "$WORKSPACE/scripts/evolution-v4.sh" status 2>/dev/null | tail -3
    echo ""
    
    # 问题汇总
    echo -e "${CYAN}⚠️ 待处理问题${NC}"
    local issues=0
    
    # 检查 Gemini 网络
    local gemini_retry=$(redis-cli HGET "openclaw:evo:retry:gemini-agent" "count" 2>/dev/null)
    if [[ "${gemini_retry:-0}" -gt 0 ]]; then
        echo "  - Gemini 网络重试中 (${gemini_retry}次)"
        issues=$((issues + 1))
    fi
    
    # 检查编译错误
    local compile_errors=$(redis-cli GET "openclaw:compile:errors" 2>/dev/null)
    if [[ -n "$compile_errors" && "$compile_errors" != "0" ]]; then
        echo "  - 存在编译错误 ($compile_errors 个)"
        issues=$((issues + 1))
    fi
    
    if [[ $issues -eq 0 ]]; then
        echo -e "  ${GREEN}无待处理问题${NC}"
    fi
    echo ""
}

# 生成建议
generate_suggestions() {
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}       💡 优化建议${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo ""
    
    local suggestions=()
    
    # 分析 Gemini 恢复频率
    local gemini_rec=$(redis-cli LRANGE "openclaw:events:queue" 0 50 2>/dev/null | grep -c '"agent":"gemini-agent".*RECOVERED')
    if [[ $gemini_rec -gt 3 ]]; then
        suggestions+=("增加 Gemini 网络重试等待时间 (当前问题: 频繁恢复)")
    fi
    
    # 分析 context 使用
    local codex_ctx=$(tmux -S /tmp/openclaw-agents.sock capture-pane -t codex-agent -p 2>/dev/null | grep -oE "[0-9]+% context" | tail -1 | grep -oE "^[0-9]+")
    if [[ -n "$codex_ctx" && "$codex_ctx" -lt 50 ]]; then
        suggestions+=("Codex context 较低 (${codex_ctx}%)，考虑重启以获得更多空间")
    fi
    
    # 检查任务队列
    local queue_len=$(redis-cli LLEN "openclaw:evo:tasks:queue" 2>/dev/null)
    if [[ "${queue_len:-0}" -gt 10 ]]; then
        suggestions+=("任务队列积压 ($queue_len 个)，考虑增加并行度")
    fi
    
    if [[ ${#suggestions[@]} -eq 0 ]]; then
        echo -e "  ${GREEN}系统运行良好，暂无优化建议${NC}"
    else
        for i in "${!suggestions[@]}"; do
            echo "  $((i+1)). ${suggestions[$i]}"
        done
    fi
    echo ""
}

# 完整报告
full_report() {
    analyze_events "${1:-6}"
    analyze_evolution
    health_report
    generate_suggestions
}

# 入口
case "${1:-full}" in
    events) analyze_events "${2:-24}" ;;
    evolution) analyze_evolution ;;
    health) health_report ;;
    suggestions) generate_suggestions ;;
    full) full_report "${2:-6}" ;;
    *) echo "用法: $0 {events|evolution|health|suggestions|full} [hours]" ;;
esac
