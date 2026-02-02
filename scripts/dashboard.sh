#!/bin/bash
# dashboard.sh - 实时监控仪表盘
# 功能: 实时显示所有 agent 状态、任务进度、系统健康

WORKSPACE="/home/jinyang/.openclaw/workspace"
SOCKET="/tmp/openclaw-agents.sock"
REDIS_PREFIX="openclaw:evo"
AGENTS=("claude-agent" "gemini-agent" "codex-agent")

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# 获取 agent 状态
get_agent_status() {
    local agent="$1"
    local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null)
    local last_20=$(echo "$output" | tail -20)
    
    # 状态检测
    local status="unknown"
    local status_icon="❓"
    local status_color="$NC"
    
    if echo "$last_20" | grep -qE "esc to interrupt|Thinking|Working|Searching|Reading|Writing|Transfiguring|Exploring" 2>/dev/null; then
        status="working"
        status_icon="🔄"
        status_color="$GREEN"
    elif echo "$last_20" | grep -qE "loop was detected" 2>/dev/null; then
        status="loop"
        status_icon="🔁"
        status_color="$RED"
    elif echo "$last_20" | grep -qE "Allow execution|Allow once|\[y/N\]" 2>/dev/null; then
        status="confirm"
        status_icon="⏳"
        status_color="$YELLOW"
    elif echo "$last_20" | grep -qE "^❯\s*$|^›\s*$|Type your message" 2>/dev/null; then
        status="idle"
        status_icon="💤"
        status_color="$BLUE"
    elif echo "$last_20" | grep -qE "Unable to connect|ERR_BAD_REQUEST" 2>/dev/null; then
        status="error"
        status_icon="❌"
        status_color="$RED"
    fi
    
    # Context 使用率
    local ctx=""
    ctx=$(echo "$output" | grep -oE "[0-9]+% context left" | tail -1 | grep -oE "^[0-9]+")
    if [[ -z "$ctx" ]]; then
        ctx=$(echo "$output" | tr '\n' ' ' | grep -oE "auto-compac[^0-9]*[0-9]+%" | tail -1 | grep -oE "[0-9]+")
    fi
    [[ -z "$ctx" ]] && ctx="--"
    
    # 当前任务 (从最后几行提取)
    local task=$(echo "$last_20" | grep -oE "继续|检查|修复|运行|完成" | head -1)
    [[ -z "$task" ]] && task="..."
    
    echo "$status|$status_icon|$status_color|$ctx|$task"
}

# 获取系统统计
get_stats() {
    local total_dispatched=$(redis-cli HGET "$REDIS_PREFIX:stats" "dispatched:claude-agent" 2>/dev/null || echo 0)
    total_dispatched=$((total_dispatched + $(redis-cli HGET "$REDIS_PREFIX:stats" "dispatched:gemini-agent" 2>/dev/null || echo 0)))
    total_dispatched=$((total_dispatched + $(redis-cli HGET "$REDIS_PREFIX:stats" "dispatched:codex-agent" 2>/dev/null || echo 0)))
    
    local queue_len=$(redis-cli LLEN "$REDIS_PREFIX:tasks:queue" 2>/dev/null || echo 0)
    local recoveries=$(redis-cli HGET "openclaw:deadlock:stats" "total_recoveries" 2>/dev/null || echo 0)
    
    echo "$total_dispatched|$queue_len|$recoveries"
}

# 绘制进度条
draw_progress_bar() {
    local percent="$1"
    local width=20
    
    if [[ "$percent" == "--" ]]; then
        printf "[%-${width}s]" "?"
        return
    fi
    
    local filled=$((percent * width / 100))
    local empty=$((width - filled))
    
    local color="$GREEN"
    [[ $percent -lt 50 ]] && color="$YELLOW"
    [[ $percent -lt 30 ]] && color="$RED"
    
    printf "${color}["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "]${NC}"
}

# 主仪表盘
show_dashboard() {
    clear
    
    echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║           🤖 Multi-Agent 实时监控仪表盘                          ║${NC}"
    echo -e "${BOLD}${CYAN}║                    $(date '+%Y-%m-%d %H:%M:%S')                           ║${NC}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    # Agent 状态
    echo -e "${BOLD}📊 Agent 状态${NC}"
    echo -e "┌──────────────┬────────┬──────────────────────────┬────────┐"
    echo -e "│ Agent        │ 状态   │ Context                  │ 任务   │"
    echo -e "├──────────────┼────────┼──────────────────────────┼────────┤"
    
    for agent in "${AGENTS[@]}"; do
        IFS='|' read -r status icon color ctx task <<< "$(get_agent_status "$agent")"
        local short_name=$(echo "$agent" | sed 's/-agent//')
        
        printf "│ %-12s │ ${color}%-6s${NC} │ " "$short_name" "$icon $status"
        draw_progress_bar "$ctx"
        printf " %3s%% │ %-6s │\n" "$ctx" "$task"
    done
    
    echo -e "└──────────────┴────────┴──────────────────────────┴────────┘"
    echo
    
    # 系统统计
    IFS='|' read -r dispatched queue recoveries <<< "$(get_stats)"
    
    echo -e "${BOLD}📈 系统统计${NC}"
    echo -e "┌────────────────────┬────────────────────┬────────────────────┐"
    echo -e "│ 已派发任务         │ 队列中任务         │ 恢复次数           │"
    echo -e "├────────────────────┼────────────────────┼────────────────────┤"
    printf "│ %-18s │ %-18s │ %-18s │\n" "$dispatched" "$queue" "$recoveries"
    echo -e "└────────────────────┴────────────────────┴────────────────────┘"
    echo
    
    # 最近事件
    echo -e "${BOLD}📝 最近事件${NC}"
    local events=$(redis-cli LRANGE "$REDIS_PREFIX:events" 0 4 2>/dev/null)
    if [[ -n "$events" ]]; then
        echo "$events" | while read -r event; do
            echo "  • $event"
        done
    else
        echo "  (无最近事件)"
    fi
    echo
    
    echo -e "${CYAN}按 Ctrl+C 退出 | 每 5 秒刷新${NC}"
}

# 记录事件
log_event() {
    local event="$1"
    local timestamp=$(date '+%H:%M:%S')
    redis-cli LPUSH "$REDIS_PREFIX:events" "[$timestamp] $event" >/dev/null 2>&1
    redis-cli LTRIM "$REDIS_PREFIX:events" 0 99 >/dev/null 2>&1
}

# 单次显示
show_once() {
    echo "===== $(date '+%H:%M:%S') ====="
    for agent in "${AGENTS[@]}"; do
        IFS='|' read -r status icon color ctx task <<< "$(get_agent_status "$agent")"
        printf "%-14s %s %-12s ctx:%3s%%\n" "$agent" "$icon" "$status" "$ctx"
    done
}

# 入口
case "${1:-once}" in
    watch)
        while true; do
            show_dashboard
            sleep 5
        done
        ;;
    once)
        show_once
        ;;
    log)
        log_event "$2"
        ;;
    *)
        echo "用法: $0 {watch|once|log <event>}"
        ;;
esac
