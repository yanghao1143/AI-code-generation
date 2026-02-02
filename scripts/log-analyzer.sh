#!/bin/bash
# log-analyzer.sh - 实时日志分析器
# 功能: 分析 agent 输出，提取有价值的信息

WORKSPACE="/home/jinyang/.openclaw/workspace"
SOCKET="/tmp/openclaw-agents.sock"
REDIS_PREFIX="openclaw:logs"
AGENTS=("claude-agent" "gemini-agent" "codex-agent")

# ============ 提取关键信息 ============
extract_info() {
    local agent="$1"
    local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null)
    
    # 提取文件修改
    local files_modified=$(echo "$output" | grep -oE "(Update|Create|Delete|Read)\([^)]+\)" | tail -10)
    
    # 提取错误信息
    local errors=$(echo "$output" | grep -iE "error|failed|cannot|unable" | tail -5)
    
    # 提取成功信息
    local successes=$(echo "$output" | grep -iE "success|completed|done|baked" | tail -5)
    
    # 提取 git 操作
    local git_ops=$(echo "$output" | grep -oE "git (commit|push|pull|add|checkout)[^|]*" | tail -5)
    
    echo "===== $agent ====="
    
    if [[ -n "$files_modified" ]]; then
        echo "📁 文件操作:"
        echo "$files_modified" | while read -r line; do
            echo "  • $line"
        done
    fi
    
    if [[ -n "$errors" ]]; then
        echo "❌ 错误:"
        echo "$errors" | while read -r line; do
            echo "  • ${line:0:80}"
        done
    fi
    
    if [[ -n "$successes" ]]; then
        echo "✅ 成功:"
        echo "$successes" | while read -r line; do
            echo "  • ${line:0:80}"
        done
    fi
    
    if [[ -n "$git_ops" ]]; then
        echo "🔀 Git:"
        echo "$git_ops" | while read -r line; do
            echo "  • $line"
        done
    fi
    
    echo ""
}

# ============ 统计分析 ============
analyze_stats() {
    local agent="$1"
    local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null)
    
    # 统计各类操作
    local updates=$(echo "$output" | grep -c "Update(" 2>/dev/null || echo 0)
    local creates=$(echo "$output" | grep -c "Create(" 2>/dev/null || echo 0)
    local reads=$(echo "$output" | grep -c "Read(" 2>/dev/null || echo 0)
    local errors=$(echo "$output" | grep -ic "error" 2>/dev/null || echo 0)
    
    echo "$agent: U=$updates C=$creates R=$reads E=$errors"
    
    # 存储到 Redis
    redis-cli HSET "$REDIS_PREFIX:stats:$agent" \
        "updates" "$updates" \
        "creates" "$creates" \
        "reads" "$reads" \
        "errors" "$errors" \
        "timestamp" "$(date +%s)" 2>/dev/null
}

# ============ 提取进度 ============
extract_progress() {
    local agent="$1"
    local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null | tail -50)
    
    # 提取当前任务
    local current_task=""
    if echo "$output" | grep -qE "继续|检查|修复|运行|完成|国际化" 2>/dev/null; then
        current_task=$(echo "$output" | grep -oE "(继续|检查|修复|运行|完成|国际化)[^。]*" | tail -1)
    fi
    
    # 提取工作时间
    local work_time=$(echo "$output" | grep -oE "Worked for [0-9]+m [0-9]+s|[0-9]+m [0-9]+s" | tail -1)
    
    # 提取 context 使用率
    local ctx=$(echo "$output" | grep -oE "[0-9]+% context" | tail -1)
    
    echo "===== $agent 进度 ====="
    [[ -n "$current_task" ]] && echo "📋 任务: $current_task"
    [[ -n "$work_time" ]] && echo "⏱️ 时间: $work_time"
    [[ -n "$ctx" ]] && echo "📊 Context: $ctx"
    echo ""
}

# ============ 生成报告 ============
generate_report() {
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║              📊 Agent 日志分析报告                               ║"
    echo "║                    $(date '+%Y-%m-%d %H:%M:%S')                           ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo ""
    
    for agent in "${AGENTS[@]}"; do
        extract_info "$agent"
    done
    
    echo "===== 统计汇总 ====="
    for agent in "${AGENTS[@]}"; do
        analyze_stats "$agent"
    done
}

# ============ 实时监控 ============
watch_logs() {
    while true; do
        clear
        generate_report
        echo ""
        echo "按 Ctrl+C 退出 | 每 10 秒刷新"
        sleep 10
    done
}

# ============ 提取 i18n 进度 ============
i18n_progress() {
    echo "===== i18n 进度分析 ====="
    
    for agent in "${AGENTS[@]}"; do
        local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null)
        
        # 统计 i18n 相关操作
        local t_calls=$(echo "$output" | grep -c "t(" 2>/dev/null || echo 0)
        local t_args=$(echo "$output" | grep -c "t_args(" 2>/dev/null || echo 0)
        local locales=$(echo "$output" | grep -c "locales" 2>/dev/null || echo 0)
        
        echo "$agent: t()=$t_calls t_args()=$t_args locales=$locales"
    done
}

# ============ 入口 ============
case "${1:-report}" in
    info)
        if [[ -n "$2" ]]; then
            extract_info "$2"
        else
            for agent in "${AGENTS[@]}"; do
                extract_info "$agent"
            done
        fi
        ;;
    stats)
        for agent in "${AGENTS[@]}"; do
            analyze_stats "$agent"
        done
        ;;
    progress)
        for agent in "${AGENTS[@]}"; do
            extract_progress "$agent"
        done
        ;;
    report)
        generate_report
        ;;
    watch)
        watch_logs
        ;;
    i18n)
        i18n_progress
        ;;
    *)
        echo "用法: $0 {info|stats|progress|report|watch|i18n}"
        echo ""
        echo "  info [agent]   - 提取关键信息"
        echo "  stats          - 统计分析"
        echo "  progress       - 提取进度"
        echo "  report         - 生成完整报告"
        echo "  watch          - 实时监控"
        echo "  i18n           - i18n 进度分析"
        ;;
esac
