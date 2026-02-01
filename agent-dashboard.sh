#!/bin/bash
# 三模型协作看板 - 实时监控 Claude/Gemini/Codex CLI 状态

SOCKET="/tmp/openclaw-agents.sock"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

clear_screen() {
    clear
}

get_status_icon() {
    local text="$1"
    if echo "$text" | grep -qiE "error|failed|错误"; then
        echo "❌"
    elif echo "$text" | grep -qiE "building|compiling|编译|thinking|contemplating|思考"; then
        echo "🔄"
    elif echo "$text" | grep -qiE "waiting|等待|Do you want|confirm"; then
        echo "⏸️"
    elif echo "$text" | grep -qiE "success|完成|finished|done"; then
        echo "✅"
    else
        echo "🔵"
    fi
}

get_pane_content() {
    local session="$1"
    local lines="${2:-15}"
    tmux -S "$SOCKET" capture-pane -t "$session" -p 2>/dev/null | tail -n "$lines"
}

extract_progress() {
    local content="$1"
    # 提取类似 [=====> ] 1109/1114 的进度
    echo "$content" | grep -oE '\[[=#> -]+\] [0-9]+/[0-9]+' | tail -1
}

print_header() {
    echo -e "${BOLD}${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                    🤖 三模型协作指挥中心 - 实时看板                           ║"
    echo "║                         $(date '+%Y-%m-%d %H:%M:%S')                              ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_agent_panel() {
    local name="$1"
    local session="$2"
    local color="$3"
    
    local content=$(get_pane_content "$session" 20)
    local status_icon=$(get_status_icon "$content")
    local progress=$(extract_progress "$content")
    
    # 提取最后几行有意义的内容
    local summary=$(echo "$content" | grep -vE '^\s*$|^│|^╭|^╰|^╌|^─' | tail -3)
    
    echo -e "${color}${BOLD}┌─────────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${color}${BOLD}│ $status_icon $name ${NC}"
    if [ -n "$progress" ]; then
        echo -e "${color}│ 进度: $progress${NC}"
    fi
    echo -e "${color}├─────────────────────────────────────────────────────────────────────────────┤${NC}"
    
    # 显示最近的输出（限制宽度）
    echo "$content" | tail -8 | while IFS= read -r line; do
        # 截断过长的行
        truncated=$(echo "$line" | cut -c1-75)
        echo -e "${color}│${NC} $truncated"
    done
    
    echo -e "${color}${BOLD}└─────────────────────────────────────────────────────────────────────────────┘${NC}"
    echo ""
}

check_sessions() {
    if ! tmux -S "$SOCKET" list-sessions &>/dev/null; then
        echo -e "${RED}错误: tmux socket 不存在或无会话运行${NC}"
        echo "Socket: $SOCKET"
        exit 1
    fi
}

main_loop() {
    while true; do
        clear_screen
        print_header
        
        echo -e "${YELLOW}按 Ctrl+C 退出 | 每 5 秒自动刷新${NC}"
        echo ""
        
        print_agent_panel "CLAUDE CLI - i18n 国际化" "claude-agent" "$BLUE"
        print_agent_panel "GEMINI CLI - 模块编译" "gemini-agent" "$GREEN"  
        print_agent_panel "CODEX CLI - 错误修复" "codex-agent" "$CYAN"
        
        # 底部状态栏
        echo -e "${BOLD}════════════════════════════════════════════════════════════════════════════════${NC}"
        local sessions=$(tmux -S "$SOCKET" list-sessions 2>/dev/null | wc -l)
        echo -e "活跃会话: ${GREEN}$sessions${NC} | Socket: $SOCKET"
        
        sleep 5
    done
}

# 检查并运行
check_sessions
main_loop
