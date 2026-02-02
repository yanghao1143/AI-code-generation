#!/bin/bash
# smart-router-v2.sh - 智能任务路由器 v2
# 根据 agent 能力、状态、context 智能分配任务

WORKSPACE="/home/jinyang/.openclaw/workspace"
SOCKET="/tmp/openclaw-agents.sock"
REDIS_PREFIX="openclaw:router"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Agent 能力矩阵 (0-100 分)
declare -A AGENT_SKILLS
AGENT_SKILLS=(
    ["claude-agent:i18n"]=90
    ["claude-agent:refactor"]=95
    ["claude-agent:backend"]=90
    ["claude-agent:algorithm"]=95
    ["claude-agent:review"]=90
    ["claude-agent:test"]=70
    ["claude-agent:fix"]=85
    
    ["gemini-agent:i18n"]=95
    ["gemini-agent:frontend"]=90
    ["gemini-agent:ui"]=95
    ["gemini-agent:architecture"]=85
    ["gemini-agent:design"]=90
    ["gemini-agent:test"]=75
    ["gemini-agent:fix"]=80
    
    ["codex-agent:cleanup"]=90
    ["codex-agent:test"]=95
    ["codex-agent:fix"]=90
    ["codex-agent:optimize"]=85
    ["codex-agent:debug"]=90
    ["codex-agent:i18n"]=70
    ["codex-agent:refactor"]=75
)

# 任务类型关键词
declare -A TASK_KEYWORDS
TASK_KEYWORDS=(
    ["i18n"]="国际化|internationalization|翻译|translate|t\(|localize"
    ["refactor"]="重构|refactor|优化结构|restructure"
    ["fix"]="修复|fix|bug|错误|error|问题"
    ["test"]="测试|test|spec|验证"
    ["cleanup"]="清理|cleanup|删除|remove|unused"
    ["frontend"]="前端|frontend|ui|界面|component"
    ["backend"]="后端|backend|api|server"
    ["algorithm"]="算法|algorithm|性能|performance"
)

# 检测任务类型
detect_task_type() {
    local task="$1"
    
    for type in "${!TASK_KEYWORDS[@]}"; do
        if echo "$task" | grep -qiE "${TASK_KEYWORDS[$type]}" 2>/dev/null; then
            echo "$type"
            return
        fi
    done
    
    echo "general"
}

# 获取 agent 当前状态评分 (0-100)
get_agent_status_score() {
    local agent="$1"
    local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null | tail -15)
    
    local score=100
    
    # 检查是否在工作
    if echo "$output" | grep -qE "esc to cancel|esc to interrupt" 2>/dev/null; then
        score=$((score - 50))  # 正在工作，降低优先级
    fi
    
    # 检查 context
    local ctx=$(echo "$output" | grep -oE "[0-9]+% context" | tail -1 | grep -oE "^[0-9]+")
    if [[ -n "$ctx" ]]; then
        if [[ $ctx -lt 20 ]]; then
            score=$((score - 40))  # context 很低
        elif [[ $ctx -lt 40 ]]; then
            score=$((score - 20))  # context 较低
        fi
    fi
    
    # 检查错误状态
    if echo "$output" | grep -qE "error|Error|failed" 2>/dev/null; then
        score=$((score - 30))
    fi
    
    echo "$score"
}

# 计算综合评分
calculate_score() {
    local agent="$1"
    local task_type="$2"
    
    # 能力分
    local skill_score=${AGENT_SKILLS["${agent}:${task_type}"]:-50}
    
    # 状态分
    local status_score=$(get_agent_status_score "$agent")
    
    # 综合评分 (能力 60% + 状态 40%)
    local total=$((skill_score * 60 / 100 + status_score * 40 / 100))
    
    echo "$total"
}

# 路由任务
route_task() {
    local task="$1"
    
    # 检测任务类型
    local task_type=$(detect_task_type "$task")
    
    echo -e "${CYAN}任务类型: $task_type${NC}"
    echo ""
    
    local best_agent=""
    local best_score=0
    
    echo -e "${GREEN}Agent 评分:${NC}"
    for agent in claude-agent gemini-agent codex-agent; do
        local score=$(calculate_score "$agent" "$task_type")
        local skill=${AGENT_SKILLS["${agent}:${task_type}"]:-50}
        local status=$(get_agent_status_score "$agent")
        
        printf "  %-15s 综合:%3d (能力:%3d 状态:%3d)\n" "$agent" "$score" "$skill" "$status"
        
        if [[ $score -gt $best_score ]]; then
            best_score=$score
            best_agent=$agent
        fi
    done
    
    echo ""
    echo -e "${YELLOW}推荐: $best_agent (评分: $best_score)${NC}"
    
    # 记录路由决策
    redis-cli LPUSH "${REDIS_PREFIX}:history" "$(date +%s):$task_type:$best_agent:$best_score" >/dev/null 2>&1
    redis-cli LTRIM "${REDIS_PREFIX}:history" 0 99 >/dev/null 2>&1
    
    echo "$best_agent"
}

# 自动分配任务
auto_assign() {
    local task="$1"
    
    local best_agent=$(route_task "$task" | tail -1)
    
    if [[ -n "$best_agent" ]]; then
        echo ""
        echo -e "${GREEN}正在分配任务给 $best_agent...${NC}"
        tmux -S "$SOCKET" send-keys -t "$best_agent" "$task" Enter
        echo -e "${GREEN}✓ 任务已分配${NC}"
    fi
}

# 查看路由历史
show_history() {
    echo -e "${CYAN}路由历史:${NC}"
    redis-cli LRANGE "${REDIS_PREFIX}:history" 0 "${1:-10}" 2>/dev/null | while read -r entry; do
        local ts=$(echo "$entry" | cut -d: -f1)
        local type=$(echo "$entry" | cut -d: -f2)
        local agent=$(echo "$entry" | cut -d: -f3)
        local score=$(echo "$entry" | cut -d: -f4)
        local time=$(date -d "@$ts" '+%H:%M:%S' 2>/dev/null || echo "$ts")
        echo "  [$time] $type → $agent (score: $score)"
    done
}

# 主入口
case "${1:-help}" in
    route)
        route_task "$2"
        ;;
    assign)
        auto_assign "$2"
        ;;
    history)
        show_history "${2:-10}"
        ;;
    status)
        echo -e "${CYAN}Agent 状态评分:${NC}"
        for agent in claude-agent gemini-agent codex-agent; do
            local score=$(get_agent_status_score "$agent")
            printf "  %-15s %3d\n" "$agent" "$score"
        done
        ;;
    *)
        echo "用法: $0 <command> [args...]"
        echo ""
        echo "命令:"
        echo "  route <task>    - 路由任务 (只推荐)"
        echo "  assign <task>   - 自动分配任务"
        echo "  history [n]     - 查看路由历史"
        echo "  status          - 查看 agent 状态评分"
        ;;
esac
