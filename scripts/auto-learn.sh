#!/bin/bash
# auto-learn.sh - 自动学习系统
# 功能: 从 agent 行为中学习，优化未来决策

WORKSPACE="/home/jinyang/.openclaw/workspace"
SOCKET="/tmp/openclaw-agents.sock"
REDIS_PREFIX="openclaw:learn"

# ============ 记录成功模式 ============
record_success() {
    local agent="$1"
    local action="$2"
    local context="$3"
    local timestamp=$(date +%s)
    local id=$(echo "$agent:$action:$timestamp" | md5sum | head -c 8)
    
    redis-cli HSET "$REDIS_PREFIX:success:$id" \
        "agent" "$agent" \
        "action" "$action" \
        "context" "$context" \
        "timestamp" "$timestamp" >/dev/null 2>&1
    
    # 更新成功计数
    redis-cli HINCRBY "$REDIS_PREFIX:stats:$agent" "success" 1 >/dev/null 2>&1
    redis-cli HINCRBY "$REDIS_PREFIX:action:$action" "success" 1 >/dev/null 2>&1
    
    echo "✅ 记录成功: $agent - $action"
}

# ============ 记录失败模式 ============
record_failure() {
    local agent="$1"
    local action="$2"
    local error="$3"
    local context="$4"
    local timestamp=$(date +%s)
    local id=$(echo "$agent:$action:$timestamp" | md5sum | head -c 8)
    
    redis-cli HSET "$REDIS_PREFIX:failure:$id" \
        "agent" "$agent" \
        "action" "$action" \
        "error" "$error" \
        "context" "$context" \
        "timestamp" "$timestamp" >/dev/null 2>&1
    
    # 更新失败计数
    redis-cli HINCRBY "$REDIS_PREFIX:stats:$agent" "failure" 1 >/dev/null 2>&1
    redis-cli HINCRBY "$REDIS_PREFIX:action:$action" "failure" 1 >/dev/null 2>&1
    
    echo "❌ 记录失败: $agent - $action - $error"
}

# ============ 分析 agent 表现 ============
analyze_agent() {
    local agent="$1"
    
    local success=$(redis-cli HGET "$REDIS_PREFIX:stats:$agent" "success" 2>/dev/null || echo 0)
    local failure=$(redis-cli HGET "$REDIS_PREFIX:stats:$agent" "failure" 2>/dev/null || echo 0)
    local total=$((success + failure))
    
    if [[ $total -eq 0 ]]; then
        echo "📊 $agent: 无数据"
        return
    fi
    
    local rate=$((success * 100 / total))
    
    echo "📊 $agent: 成功率 $rate% ($success/$total)"
    
    # 推荐
    if [[ $rate -lt 50 ]]; then
        echo "   ⚠️ 建议: 减少分配复杂任务给此 agent"
    elif [[ $rate -gt 80 ]]; then
        echo "   ✅ 建议: 可以分配更多任务给此 agent"
    fi
}

# ============ 分析动作效果 ============
analyze_action() {
    local action="$1"
    
    local success=$(redis-cli HGET "$REDIS_PREFIX:action:$action" "success" 2>/dev/null || echo 0)
    local failure=$(redis-cli HGET "$REDIS_PREFIX:action:$action" "failure" 2>/dev/null || echo 0)
    local total=$((success + failure))
    
    if [[ $total -eq 0 ]]; then
        echo "📊 $action: 无数据"
        return
    fi
    
    local rate=$((success * 100 / total))
    echo "📊 $action: 成功率 $rate% ($success/$total)"
}

# ============ 获取最佳 agent ============
get_best_agent() {
    local task_type="$1"
    local best_agent=""
    local best_rate=0
    
    for agent in claude-agent gemini-agent codex-agent; do
        local success=$(redis-cli HGET "$REDIS_PREFIX:stats:$agent" "success" 2>/dev/null || echo 0)
        local failure=$(redis-cli HGET "$REDIS_PREFIX:stats:$agent" "failure" 2>/dev/null || echo 0)
        local total=$((success + failure))
        
        if [[ $total -gt 5 ]]; then
            local rate=$((success * 100 / total))
            if [[ $rate -gt $best_rate ]]; then
                best_rate=$rate
                best_agent=$agent
            fi
        fi
    done
    
    if [[ -n "$best_agent" ]]; then
        echo "$best_agent"
    else
        # 默认轮询
        echo "claude-agent"
    fi
}

# ============ 学习报告 ============
report() {
    echo "===== 学习报告 $(date '+%Y-%m-%d %H:%M') ====="
    echo ""
    
    echo "📊 Agent 表现:"
    for agent in claude-agent gemini-agent codex-agent; do
        analyze_agent "$agent"
    done
    
    echo ""
    echo "📊 常见动作效果:"
    for action in dispatch confirm restart loop_break context_reset; do
        analyze_action "$action"
    done
    
    echo ""
    echo "📈 总体统计:"
    local total_success=0
    local total_failure=0
    for agent in claude-agent gemini-agent codex-agent; do
        local s=$(redis-cli HGET "$REDIS_PREFIX:stats:$agent" "success" 2>/dev/null || echo 0)
        local f=$(redis-cli HGET "$REDIS_PREFIX:stats:$agent" "failure" 2>/dev/null || echo 0)
        total_success=$((total_success + s))
        total_failure=$((total_failure + f))
    done
    
    local total=$((total_success + total_failure))
    if [[ $total -gt 0 ]]; then
        local rate=$((total_success * 100 / total))
        echo "  总成功率: $rate% ($total_success/$total)"
    else
        echo "  (无数据)"
    fi
}

# ============ 从输出学习 ============
learn_from_output() {
    local agent="$1"
    local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null | tail -30)
    
    # 检测成功模式
    if echo "$output" | grep -qE "Baked for|completed|finished|✓|Successfully" 2>/dev/null; then
        record_success "$agent" "task_complete" "auto_detected"
    fi
    
    # 检测失败模式
    if echo "$output" | grep -qE "error:|Error:|failed|Failed|❌" 2>/dev/null; then
        local error=$(echo "$output" | grep -oE "(error|Error|failed|Failed).*" | head -1 | cut -c1-50)
        record_failure "$agent" "task_error" "$error" "auto_detected"
    fi
    
    # 检测循环
    if echo "$output" | grep -qE "loop was detected" 2>/dev/null; then
        record_failure "$agent" "loop" "loop_detected" "auto_detected"
    fi
}

# ============ 自动学习 (定期运行) ============
auto_learn() {
    for agent in claude-agent gemini-agent codex-agent; do
        if tmux -S "$SOCKET" has-session -t "$agent" 2>/dev/null; then
            learn_from_output "$agent"
        fi
    done
}

# ============ 入口 ============
case "${1:-help}" in
    success)
        record_success "$2" "$3" "$4"
        ;;
    failure)
        record_failure "$2" "$3" "$4" "$5"
        ;;
    analyze)
        if [[ -n "$2" ]]; then
            analyze_agent "$2"
        else
            for agent in claude-agent gemini-agent codex-agent; do
                analyze_agent "$agent"
            done
        fi
        ;;
    best)
        get_best_agent "$2"
        ;;
    report)
        report
        ;;
    auto)
        auto_learn
        ;;
    *)
        echo "用法: $0 {success|failure|analyze|best|report|auto}"
        echo ""
        echo "  success <agent> <action> <context>  - 记录成功"
        echo "  failure <agent> <action> <error> <context>  - 记录失败"
        echo "  analyze [agent]                     - 分析表现"
        echo "  best [task_type]                    - 获取最佳 agent"
        echo "  report                              - 生成学习报告"
        echo "  auto                                - 自动从输出学习"
        ;;
esac
