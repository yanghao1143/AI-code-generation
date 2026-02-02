#!/bin/bash
# smart-router.sh - 智能任务路由器
# 功能: 根据任务内容自动选择最合适的 agent

WORKSPACE="/home/jinyang/.openclaw/workspace"
SOCKET="/tmp/openclaw-agents.sock"
REDIS_PREFIX="openclaw:router"

# Agent 能力矩阵
declare -A AGENT_SKILLS=(
    # Claude: 擅长复杂推理、代码重构、算法
    ["claude-agent:i18n"]=8
    ["claude-agent:refactor"]=9
    ["claude-agent:algorithm"]=9
    ["claude-agent:review"]=8
    ["claude-agent:backend"]=8
    ["claude-agent:debug"]=7
    ["claude-agent:test"]=6
    ["claude-agent:docs"]=7
    
    # Gemini: 擅长分析、架构设计、前端
    ["gemini-agent:i18n"]=8
    ["gemini-agent:frontend"]=9
    ["gemini-agent:ui"]=9
    ["gemini-agent:architecture"]=8
    ["gemini-agent:design"]=8
    ["gemini-agent:analysis"]=9
    ["gemini-agent:docs"]=8
    ["gemini-agent:test"]=6
    
    # Codex: 擅长快速修复、测试、优化
    ["codex-agent:fix"]=9
    ["codex-agent:test"]=9
    ["codex-agent:optimize"]=8
    ["codex-agent:debug"]=8
    ["codex-agent:cleanup"]=9
    ["codex-agent:compile"]=9
    ["codex-agent:i18n"]=6
    ["codex-agent:docs"]=5
)

# 任务关键词映射
declare -A TASK_KEYWORDS=(
    ["i18n"]="国际化|i18n|中文化|翻译|locales|t\(|t_args"
    ["refactor"]="重构|refactor|优化结构|整理代码"
    ["algorithm"]="算法|algorithm|性能|复杂度"
    ["review"]="审查|review|检查代码|code review"
    ["backend"]="后端|backend|服务端|api|数据库"
    ["frontend"]="前端|frontend|ui|界面|样式"
    ["ui"]="ui|界面|组件|widget|button|panel"
    ["architecture"]="架构|architecture|设计|模块化"
    ["design"]="设计|design|方案|规划"
    ["analysis"]="分析|analysis|调研|研究"
    ["fix"]="修复|fix|bug|错误|问题"
    ["test"]="测试|test|单元测试|集成测试"
    ["optimize"]="优化|optimize|性能|速度"
    ["debug"]="调试|debug|排查|定位"
    ["cleanup"]="清理|cleanup|删除|移除|整理"
    ["compile"]="编译|compile|cargo|build"
    ["docs"]="文档|docs|readme|注释"
)

# ============ 分析任务类型 ============
analyze_task() {
    local task="$1"
    local detected_types=()
    
    for type in "${!TASK_KEYWORDS[@]}"; do
        local pattern="${TASK_KEYWORDS[$type]}"
        if echo "$task" | grep -qiE "$pattern" 2>/dev/null; then
            detected_types+=("$type")
        fi
    done
    
    if [[ ${#detected_types[@]} -eq 0 ]]; then
        echo "general"
    else
        echo "${detected_types[*]}"
    fi
}

# ============ 选择最佳 Agent ============
select_best_agent() {
    local task="$1"
    local types=$(analyze_task "$task")
    
    local best_agent=""
    local best_score=0
    
    for agent in claude-agent gemini-agent codex-agent; do
        local score=0
        
        for type in $types; do
            local skill="${AGENT_SKILLS[$agent:$type]:-5}"
            score=$((score + skill))
        done
        
        # 考虑当前状态
        local status=$(get_agent_status "$agent")
        case "$status" in
            idle) score=$((score + 3)) ;;      # 空闲加分
            working) score=$((score - 2)) ;;   # 工作中减分
            error) score=$((score - 10)) ;;    # 错误大减分
        esac
        
        # 考虑 context 使用率
        local ctx=$(get_context_usage "$agent")
        if [[ -n "$ctx" && "$ctx" -lt 50 ]]; then
            score=$((score + 2))  # context 充足加分
        elif [[ -n "$ctx" && "$ctx" -lt 30 ]]; then
            score=$((score - 3))  # context 不足减分
        fi
        
        if [[ $score -gt $best_score ]]; then
            best_score=$score
            best_agent=$agent
        fi
    done
    
    echo "$best_agent"
}

# ============ 获取 Agent 状态 ============
get_agent_status() {
    local agent="$1"
    local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null | tail -10)
    
    if echo "$output" | grep -qE "esc to interrupt|esc to cancel|Thinking|Working" 2>/dev/null; then
        echo "working"
    elif echo "$output" | grep -qE "error|Error|failed|Failed" 2>/dev/null; then
        echo "error"
    elif echo "$output" | grep -qE "^❯\s*$|^›\s*$|Type your message" 2>/dev/null; then
        echo "idle"
    else
        echo "unknown"
    fi
}

# ============ 获取 Context 使用率 ============
get_context_usage() {
    local agent="$1"
    local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null)
    
    local ctx=$(echo "$output" | grep -oE "[0-9]+% context" | tail -1 | grep -oE "^[0-9]+")
    echo "$ctx"
}

# ============ 路由任务 ============
route_task() {
    local task="$1"
    local force_agent="$2"
    
    local agent=""
    if [[ -n "$force_agent" ]]; then
        agent="$force_agent"
    else
        agent=$(select_best_agent "$task")
    fi
    
    local types=$(analyze_task "$task")
    
    echo "📋 任务: $task"
    echo "🏷️ 类型: $types"
    echo "🤖 路由到: $agent"
    
    # 发送任务
    tmux -S "$SOCKET" send-keys -t "$agent" C-u
    sleep 0.3
    tmux -S "$SOCKET" send-keys -t "$agent" "$task" Enter
    
    # 记录路由
    redis-cli LPUSH "$REDIS_PREFIX:history" "$(date +%s)|$agent|$types|${task:0:50}" 2>/dev/null
    redis-cli LTRIM "$REDIS_PREFIX:history" 0 99 2>/dev/null
    
    echo "✅ 已发送"
}

# ============ 显示路由建议 ============
suggest() {
    local task="$1"
    local types=$(analyze_task "$task")
    
    echo "📋 任务: $task"
    echo "🏷️ 检测类型: $types"
    echo ""
    echo "🤖 Agent 评分:"
    
    for agent in claude-agent gemini-agent codex-agent; do
        local score=0
        for type in $types; do
            local skill="${AGENT_SKILLS[$agent:$type]:-5}"
            score=$((score + skill))
        done
        
        local status=$(get_agent_status "$agent")
        local ctx=$(get_context_usage "$agent")
        
        printf "  %-14s 分数:%-3d 状态:%-8s Context:%s%%\n" "$agent" "$score" "$status" "${ctx:-??}"
    done
    
    echo ""
    local best=$(select_best_agent "$task")
    echo "📌 推荐: $best"
}

# ============ 历史记录 ============
history() {
    echo "===== 路由历史 ====="
    redis-cli LRANGE "$REDIS_PREFIX:history" 0 19 2>/dev/null | while read -r line; do
        IFS='|' read -r ts agent types task <<< "$line"
        local time=$(date -d "@$ts" '+%H:%M:%S' 2>/dev/null || echo "$ts")
        printf "[%s] %-14s %-15s %s\n" "$time" "$agent" "$types" "$task"
    done
}

# ============ 入口 ============
case "${1:-help}" in
    route)
        route_task "$2" "$3"
        ;;
    suggest)
        suggest "$2"
        ;;
    analyze)
        types=$(analyze_task "$2")
        echo "检测类型: $types"
        ;;
    history)
        history
        ;;
    *)
        echo "用法: $0 {route|suggest|analyze|history}"
        echo ""
        echo "  route <task> [agent]  - 路由任务到最佳 agent"
        echo "  suggest <task>        - 显示路由建议"
        echo "  analyze <task>        - 分析任务类型"
        echo "  history               - 显示路由历史"
        echo ""
        echo "示例:"
        echo "  $0 route '修复编译错误'"
        echo "  $0 suggest '国际化 terminal 模块'"
        ;;
esac
