#!/bin/bash
# predictor.sh - 异常预测系统
# 功能: 基于历史数据预测可能出现的问题

WORKSPACE="/home/jinyang/.openclaw/workspace"
SOCKET="/tmp/openclaw-agents.sock"
REDIS_PREFIX="openclaw:predict"
AGENTS=("claude-agent" "gemini-agent" "codex-agent")

# ============ 收集历史数据 ============
collect_history() {
    local agent="$1"
    local timestamp=$(date +%s)
    local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null)
    
    # Context 使用率
    local ctx=$(echo "$output" | grep -oE "[0-9]+% context" | tail -1 | grep -oE "^[0-9]+")
    [[ -z "$ctx" ]] && ctx=100
    
    # 错误计数
    local errors=$(echo "$output" | grep -ciE "error|failed|unable" 2>/dev/null || echo 0)
    
    # 循环检测
    local loops=$(echo "$output" | grep -c "loop was detected" 2>/dev/null || echo 0)
    
    # 网络重试
    local retries=$(echo "$output" | grep -c "Trying to reach" 2>/dev/null || echo 0)
    
    # 存储
    redis-cli ZADD "$REDIS_PREFIX:ctx:$agent" "$timestamp" "$timestamp:$ctx" >/dev/null 2>&1
    redis-cli ZADD "$REDIS_PREFIX:errors:$agent" "$timestamp" "$timestamp:$errors" >/dev/null 2>&1
    redis-cli ZADD "$REDIS_PREFIX:loops:$agent" "$timestamp" "$timestamp:$loops" >/dev/null 2>&1
    redis-cli ZADD "$REDIS_PREFIX:retries:$agent" "$timestamp" "$timestamp:$retries" >/dev/null 2>&1
    
    # 保留最近 500 条
    for metric in ctx errors loops retries; do
        redis-cli ZREMRANGEBYRANK "$REDIS_PREFIX:$metric:$agent" 0 -501 >/dev/null 2>&1
    done
}

# ============ 计算趋势 ============
calc_trend() {
    local agent="$1"
    local metric="$2"
    local window="${3:-10}"  # 最近 N 条数据
    
    local values=$(redis-cli ZRANGE "$REDIS_PREFIX:$metric:$agent" -$window -1 2>/dev/null)
    
    if [[ -z "$values" ]]; then
        echo "0"
        return
    fi
    
    local prev=0
    local curr=0
    local count=0
    local trend=0
    
    while read -r entry; do
        local val=$(echo "$entry" | cut -d: -f2)
        prev=$curr
        curr=$val
        
        if [[ $count -gt 0 ]]; then
            trend=$((trend + curr - prev))
        fi
        ((count++))
    done <<< "$values"
    
    if [[ $count -gt 1 ]]; then
        trend=$((trend / (count - 1)))
    fi
    
    echo "$trend"
}

# ============ 预测 Context 耗尽 ============
predict_context_exhaustion() {
    local agent="$1"
    
    # 获取当前 context
    local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null)
    local ctx=$(echo "$output" | grep -oE "[0-9]+% context" | tail -1 | grep -oE "^[0-9]+")
    [[ -z "$ctx" ]] && ctx=100
    
    # 计算趋势 (每分钟下降多少)
    local trend=$(calc_trend "$agent" "ctx" 10)
    
    if [[ $trend -lt 0 ]]; then
        # Context 在下降
        local rate=$((-trend))
        if [[ $rate -gt 0 ]]; then
            local minutes_left=$((ctx / rate))
            echo "$agent: Context $ctx%, 下降速率 ${rate}%/样本, 预计 ${minutes_left} 个样本后耗尽"
            
            if [[ $minutes_left -lt 10 ]]; then
                echo "  ⚠️ 警告: 即将耗尽，建议重启会话"
                return 1
            fi
        fi
    else
        echo "$agent: Context $ctx%, 稳定或上升"
    fi
    
    return 0
}

# ============ 预测循环 ============
predict_loop() {
    local agent="$1"
    
    # 获取最近的循环次数
    local recent_loops=$(redis-cli ZRANGE "$REDIS_PREFIX:loops:$agent" -5 -1 2>/dev/null | while read -r entry; do
        echo "$entry" | cut -d: -f2
    done | awk '{sum+=$1} END {print sum}')
    
    [[ -z "$recent_loops" ]] && recent_loops=0
    
    if [[ $recent_loops -gt 2 ]]; then
        echo "$agent: 最近检测到 $recent_loops 次循环"
        echo "  ⚠️ 警告: 循环频繁，可能需要调整任务或重启"
        return 1
    fi
    
    return 0
}

# ============ 预测网络问题 ============
predict_network() {
    local agent="$1"
    
    local recent_retries=$(redis-cli ZRANGE "$REDIS_PREFIX:retries:$agent" -5 -1 2>/dev/null | while read -r entry; do
        echo "$entry" | cut -d: -f2
    done | awk '{sum+=$1} END {print sum}')
    
    [[ -z "$recent_retries" ]] && recent_retries=0
    
    if [[ $recent_retries -gt 3 ]]; then
        echo "$agent: 最近 $recent_retries 次网络重试"
        echo "  ⚠️ 警告: 网络不稳定，可能需要检查连接"
        return 1
    fi
    
    return 0
}

# ============ 综合预测 ============
predict_all() {
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║              🔮 异常预测报告                                     ║"
    echo "║                    $(date '+%Y-%m-%d %H:%M:%S')                           ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo ""
    
    local warnings=0
    
    for agent in "${AGENTS[@]}"; do
        echo "===== $agent ====="
        
        # 先收集数据
        collect_history "$agent"
        
        # 预测
        predict_context_exhaustion "$agent" || ((warnings++))
        predict_loop "$agent" || ((warnings++))
        predict_network "$agent" || ((warnings++))
        
        echo ""
    done
    
    echo "===== 总结 ====="
    if [[ $warnings -eq 0 ]]; then
        echo "✅ 所有 agent 状态良好，无异常预警"
    else
        echo "⚠️ 发现 $warnings 个潜在问题，建议关注"
    fi
}

# ============ 自动预防 ============
auto_prevent() {
    local prevented=0
    
    for agent in "${AGENTS[@]}"; do
        collect_history "$agent"
        
        # 检查 context
        local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null)
        local ctx=$(echo "$output" | grep -oE "[0-9]+% context" | tail -1 | grep -oE "^[0-9]+")
        
        if [[ -n "$ctx" && "$ctx" -lt 25 ]]; then
            echo "🔧 $agent: Context 低于 25%，自动重启"
            source "$WORKSPACE/scripts/evolution-v4.sh"
            restart_agent "$agent"
            ((prevented++))
        fi
        
        # 检查循环频率
        local recent_loops=$(redis-cli ZRANGE "$REDIS_PREFIX:loops:$agent" -3 -1 2>/dev/null | while read -r entry; do
            echo "$entry" | cut -d: -f2
        done | awk '{sum+=$1} END {print sum}')
        
        if [[ -n "$recent_loops" && "$recent_loops" -gt 3 ]]; then
            echo "🔧 $agent: 循环过于频繁，自动重启"
            source "$WORKSPACE/scripts/evolution-v4.sh"
            restart_agent "$agent"
            ((prevented++))
        fi
    done
    
    if [[ $prevented -eq 0 ]]; then
        echo "✅ 无需预防措施"
    else
        echo "🔧 已执行 $prevented 个预防措施"
    fi
}

# ============ 入口 ============
case "${1:-predict}" in
    collect)
        for agent in "${AGENTS[@]}"; do
            collect_history "$agent"
        done
        echo "✅ 数据已收集"
        ;;
    trend)
        for agent in "${AGENTS[@]}"; do
            echo "$agent:"
            echo "  Context 趋势: $(calc_trend "$agent" "ctx")"
            echo "  错误趋势: $(calc_trend "$agent" "errors")"
        done
        ;;
    predict)
        predict_all
        ;;
    prevent)
        auto_prevent
        ;;
    *)
        echo "用法: $0 {collect|trend|predict|prevent}"
        echo ""
        echo "  collect  - 收集历史数据"
        echo "  trend    - 显示趋势"
        echo "  predict  - 综合预测"
        echo "  prevent  - 自动预防"
        ;;
esac
