#!/bin/bash
# monitor.sh - 实时监控系统
# 提供实时状态更新和告警

WORKSPACE="/home/jinyang/.openclaw/workspace"
SOCKET="/tmp/openclaw-agents.sock"
REDIS_PREFIX="openclaw:monitor"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m'

# 获取 agent 状态摘要
get_agent_summary() {
    local agent="$1"
    local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null | tail -15)
    
    # 提取关键信息
    local status="unknown"
    local context=""
    local activity=""
    
    # 检测状态
    if echo "$output" | grep -qE "esc to cancel|esc to interrupt" 2>/dev/null; then
        status="working"
        # 提取活动描述
        activity=$(echo "$output" | grep -oE "(Thinking|Working|Searching|Reading|Writing|Mining|Baking|Navigating|Investigating|Analyzing)[^(]*" | tail -1)
    elif echo "$output" | grep -qE "Type your message|^❯\s*$|^›\s*$" 2>/dev/null; then
        status="idle"
    elif echo "$output" | grep -qE "Request cancelled|error" 2>/dev/null; then
        status="error"
    fi
    
    # 提取 context
    context=$(echo "$output" | grep -oE "[0-9]+% context" | tail -1)
    
    echo "$status|$context|$activity"
}

# 实时状态显示
show_realtime() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              🖥️  Multi-Agent 实时监控                             ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "更新时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    # Agent 状态
    echo -e "${GREEN}┌─────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${GREEN}│ Agent 状态                                                       │${NC}"
    echo -e "${GREEN}└─────────────────────────────────────────────────────────────────┘${NC}"
    
    for agent in claude-agent gemini-agent codex-agent; do
        local info=$(get_agent_summary "$agent")
        local status=$(echo "$info" | cut -d'|' -f1)
        local context=$(echo "$info" | cut -d'|' -f2)
        local activity=$(echo "$info" | cut -d'|' -f3)
        
        # 状态颜色
        local status_color=$YELLOW
        case "$status" in
            working) status_color=$GREEN ;;
            idle) status_color=$BLUE ;;
            error) status_color=$RED ;;
        esac
        
        printf "  %-15s " "$agent"
        echo -ne "${status_color}[$status]${NC}"
        [[ -n "$context" ]] && echo -ne " ${YELLOW}$context${NC}"
        [[ -n "$activity" ]] && echo -ne " - $activity"
        echo ""
    done
    
    echo ""
    
    # 系统指标
    echo -e "${GREEN}┌─────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${GREEN}│ 系统指标                                                         │${NC}"
    echo -e "${GREEN}└─────────────────────────────────────────────────────────────────┘${NC}"
    
    local dispatched=$(redis-cli HGET "openclaw:evo:stats" "dispatched:total" 2>/dev/null || echo 0)
    local recovered=$(redis-cli HGET "openclaw:evo:stats" "recovered:total" 2>/dev/null || echo 0)
    local errors=$(redis-cli HGET "openclaw:evo:stats" "errors:total" 2>/dev/null || echo 0)
    
    echo -e "  派发任务: ${GREEN}$dispatched${NC} | 恢复次数: ${YELLOW}$recovered${NC} | 错误: ${RED}$errors${NC}"
    
    # i18n 进度
    local i18n_done=$(redis-cli HGET "openclaw:progress:i18n" "done" 2>/dev/null || echo "?")
    local i18n_total=$(redis-cli HGET "openclaw:progress:i18n" "total" 2>/dev/null || echo "?")
    echo -e "  i18n 进度: ${CYAN}$i18n_done / $i18n_total${NC}"
    
    echo ""
    
    # 最近事件
    echo -e "${GREEN}┌─────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${GREEN}│ 最近事件                                                         │${NC}"
    echo -e "${GREEN}└─────────────────────────────────────────────────────────────────┘${NC}"
    
    redis-cli LRANGE "openclaw:events:log" 0 4 2>/dev/null | while read -r event; do
        echo "  $event"
    done
    
    echo ""
    echo -e "${YELLOW}按 Ctrl+C 退出${NC}"
}

# 记录事件
log_event() {
    local event="$1"
    local timestamp=$(date '+%H:%M:%S')
    redis-cli LPUSH "openclaw:events:log" "[$timestamp] $event" >/dev/null
    redis-cli LTRIM "openclaw:events:log" 0 99 >/dev/null
}

# 检查告警
check_alerts() {
    local alerts=()
    
    for agent in claude-agent gemini-agent codex-agent; do
        local info=$(get_agent_summary "$agent")
        local status=$(echo "$info" | cut -d'|' -f1)
        local context=$(echo "$info" | cut -d'|' -f2)
        
        # Context 低告警
        if [[ -n "$context" ]]; then
            local ctx_num=$(echo "$context" | grep -oE "[0-9]+")
            if [[ -n "$ctx_num" && $ctx_num -lt 20 ]]; then
                alerts+=("⚠️ $agent context 低 ($ctx_num%)")
            fi
        fi
        
        # 错误告警
        if [[ "$status" == "error" ]]; then
            alerts+=("🔴 $agent 出错")
        fi
    done
    
    if [[ ${#alerts[@]} -gt 0 ]]; then
        echo -e "${RED}告警:${NC}"
        for alert in "${alerts[@]}"; do
            echo "  $alert"
        done
    else
        echo -e "${GREEN}✓ 无告警${NC}"
    fi
}

# 持续监控
watch_mode() {
    while true; do
        show_realtime
        sleep "${1:-5}"
    done
}

# 主入口
case "${1:-once}" in
    once)
        show_realtime
        ;;
    watch)
        watch_mode "${2:-5}"
        ;;
    alerts)
        check_alerts
        ;;
    log)
        log_event "$2"
        ;;
    events)
        echo -e "${CYAN}最近事件:${NC}"
        redis-cli LRANGE "openclaw:events:log" 0 "${2:-20}" 2>/dev/null | while read -r event; do
            echo "  $event"
        done
        ;;
    *)
        echo "用法: $0 <command> [args...]"
        echo ""
        echo "命令:"
        echo "  once           - 显示一次状态"
        echo "  watch [sec]    - 持续监控 (默认 5 秒刷新)"
        echo "  alerts         - 检查告警"
        echo "  log <event>    - 记录事件"
        echo "  events [n]     - 查看最近 n 个事件"
        ;;
esac
