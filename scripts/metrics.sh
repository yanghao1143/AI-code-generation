#!/bin/bash
# metrics.sh - 性能指标收集和分析
# 收集 agent 工作时间、任务完成率、context 使用趋势

WORKSPACE="/home/jinyang/.openclaw/workspace"
SOCKET="/tmp/openclaw-agents.sock"
REDIS_PREFIX="openclaw:metrics"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# 收集当前指标
collect_metrics() {
    local timestamp=$(date +%s)
    
    for agent in claude-agent gemini-agent codex-agent; do
        local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null)
        
        # Context 使用率
        local ctx=$(echo "$output" | grep -oE "[0-9]+% context" | tail -1 | grep -oE "^[0-9]+")
        if [[ -z "$ctx" ]]; then
            ctx=$(echo "$output" | tr '\n' ' ' | grep -oE "auto-compac[^0-9]*[0-9]+%" | tail -1 | grep -oE "[0-9]+")
        fi
        [[ -z "$ctx" ]] && ctx=100
        
        # 工作状态 (1=working, 0=idle)
        local working=0
        if echo "$output" | tail -10 | grep -qE "esc to cancel|esc to interrupt" 2>/dev/null; then
            working=1
        fi
        
        # 保存到 Redis 时间序列
        redis-cli ZADD "${REDIS_PREFIX}:ctx:${agent}" "$timestamp" "${timestamp}:${ctx}" >/dev/null 2>&1
        redis-cli ZADD "${REDIS_PREFIX}:work:${agent}" "$timestamp" "${timestamp}:${working}" >/dev/null 2>&1
        
        # 保留最近 1000 条
        redis-cli ZREMRANGEBYRANK "${REDIS_PREFIX}:ctx:${agent}" 0 -1001 >/dev/null 2>&1
        redis-cli ZREMRANGEBYRANK "${REDIS_PREFIX}:work:${agent}" 0 -1001 >/dev/null 2>&1
    done
    
    echo "指标已收集 @ $(date '+%H:%M:%S')"
}

# 分析 context 趋势
analyze_context_trend() {
    local agent="$1"
    local minutes="${2:-30}"
    local since=$(($(date +%s) - minutes * 60))
    
    echo -e "${CYAN}$agent Context 趋势 (最近 ${minutes} 分钟):${NC}"
    
    local data=$(redis-cli ZRANGEBYSCORE "${REDIS_PREFIX}:ctx:${agent}" "$since" "+inf" 2>/dev/null)
    
    if [[ -z "$data" ]]; then
        echo "  (无数据)"
        return
    fi
    
    local first_ctx=""
    local last_ctx=""
    local sum=0
    local count=0
    
    for entry in $data; do
        local ctx=$(echo "$entry" | cut -d: -f2)
        [[ -z "$first_ctx" ]] && first_ctx=$ctx
        last_ctx=$ctx
        sum=$((sum + ctx))
        ((count++))
    done
    
    if [[ $count -gt 0 ]]; then
        local avg=$((sum / count))
        local change=$((last_ctx - first_ctx))
        
        echo -e "  起始: ${first_ctx}% → 当前: ${last_ctx}%"
        echo -e "  平均: ${avg}%"
        
        if [[ $change -lt 0 ]]; then
            echo -e "  趋势: ${RED}下降 ${change}%${NC}"
        elif [[ $change -gt 0 ]]; then
            echo -e "  趋势: ${GREEN}上升 +${change}%${NC}"
        else
            echo -e "  趋势: 稳定"
        fi
    fi
}

# 分析工作效率
analyze_efficiency() {
    local agent="$1"
    local minutes="${2:-60}"
    local since=$(($(date +%s) - minutes * 60))
    
    echo -e "${CYAN}$agent 工作效率 (最近 ${minutes} 分钟):${NC}"
    
    local data=$(redis-cli ZRANGEBYSCORE "${REDIS_PREFIX}:work:${agent}" "$since" "+inf" 2>/dev/null)
    
    if [[ -z "$data" ]]; then
        echo "  (无数据)"
        return
    fi
    
    local working_count=0
    local total_count=0
    
    for entry in $data; do
        local status=$(echo "$entry" | cut -d: -f2)
        [[ "$status" == "1" ]] && ((working_count++))
        ((total_count++))
    done
    
    if [[ $total_count -gt 0 ]]; then
        local efficiency=$((working_count * 100 / total_count))
        echo -e "  工作时间占比: ${GREEN}${efficiency}%${NC} ($working_count/$total_count 采样)"
    fi
}

# 生成完整报告
generate_report() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    📊 性能指标报告                                ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "生成时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    for agent in claude-agent gemini-agent codex-agent; do
        echo -e "${GREEN}━━━ $agent ━━━${NC}"
        analyze_context_trend "$agent" 30
        analyze_efficiency "$agent" 60
        echo ""
    done
    
    # 总体统计
    echo -e "${GREEN}━━━ 总体统计 ━━━${NC}"
    local total_dispatched=$(redis-cli HGET "openclaw:evo:stats" "dispatched:total" 2>/dev/null || echo 0)
    local total_recovered=$(redis-cli HGET "openclaw:evo:stats" "recovered:total" 2>/dev/null || echo 0)
    echo -e "  总派发任务: $total_dispatched"
    echo -e "  总恢复次数: $total_recovered"
}

# 快速摘要
quick_summary() {
    echo -e "${CYAN}📊 指标摘要${NC}"
    
    for agent in claude-agent gemini-agent codex-agent; do
        local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null | tail -15)
        local ctx=$(echo "$output" | grep -oE "[0-9]+% context" | tail -1 | grep -oE "^[0-9]+")
        [[ -z "$ctx" ]] && ctx="?"
        
        local status="idle"
        if echo "$output" | grep -qE "esc to cancel|esc to interrupt" 2>/dev/null; then
            status="work"
        fi
        
        printf "  %-15s ctx:%3s%% [%s]\n" "$agent" "$ctx" "$status"
    done
}

# 主入口
case "${1:-summary}" in
    collect)
        collect_metrics
        ;;
    trend)
        analyze_context_trend "${2:-claude-agent}" "${3:-30}"
        ;;
    efficiency)
        analyze_efficiency "${2:-claude-agent}" "${3:-60}"
        ;;
    report)
        generate_report
        ;;
    summary)
        quick_summary
        ;;
    *)
        echo "用法: $0 <command> [args...]"
        echo ""
        echo "命令:"
        echo "  collect              - 收集当前指标"
        echo "  trend <agent> [min]  - 分析 context 趋势"
        echo "  efficiency <agent>   - 分析工作效率"
        echo "  report               - 生成完整报告"
        echo "  summary              - 快速摘要"
        ;;
esac
