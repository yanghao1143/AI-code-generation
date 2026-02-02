#!/bin/bash
# metrics.sh - 性能指标收集器
# 功能: 收集和分析 agent 性能数据

WORKSPACE="/home/jinyang/.openclaw/workspace"
SOCKET="/tmp/openclaw-agents.sock"
REDIS_PREFIX="openclaw:metrics"
AGENTS=("claude-agent" "gemini-agent" "codex-agent")

# ============ 收集指标 ============
collect() {
    local timestamp=$(date +%s)
    
    for agent in "${AGENTS[@]}"; do
        local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null)
        
        # Context 使用率
        local ctx=$(echo "$output" | grep -oE "[0-9]+% context" | tail -1 | grep -oE "^[0-9]+")
        [[ -z "$ctx" ]] && ctx=$(echo "$output" | tr '\n' ' ' | grep -oE "auto-compac[^0-9]*[0-9]+%" | tail -1 | grep -oE "[0-9]+")
        
        # 工作时间
        local work_time=$(echo "$output" | grep -oE "[0-9]+m [0-9]+s" | tail -1)
        local work_seconds=0
        if [[ -n "$work_time" ]]; then
            local mins=$(echo "$work_time" | grep -oE "^[0-9]+")
            local secs=$(echo "$work_time" | grep -oE "[0-9]+s" | grep -oE "[0-9]+")
            work_seconds=$((mins * 60 + secs))
        fi
        
        # 状态
        local status="unknown"
        local last_10=$(echo "$output" | tail -10)
        if echo "$last_10" | grep -qE "esc to interrupt|esc to cancel|Thinking|Working|Searching|Reading" 2>/dev/null; then
            status="working"
        elif echo "$last_10" | grep -qE "^❯\s*$|^›\s*$|Type your message" 2>/dev/null; then
            status="idle"
        elif echo "$last_10" | grep -qE "Unable to connect|ERR_BAD_REQUEST|ECONNREFUSED" 2>/dev/null; then
            status="error"
        fi
        
        # 文件操作数
        local file_ops=$(echo "$output" | grep -cE "(Update|Create|Read)\(" 2>/dev/null || echo 0)
        
        # 存储到 Redis (时间序列)
        redis-cli ZADD "$REDIS_PREFIX:ctx:$agent" "$timestamp" "$timestamp:${ctx:-0}" 2>/dev/null
        redis-cli ZADD "$REDIS_PREFIX:work:$agent" "$timestamp" "$timestamp:$work_seconds" 2>/dev/null
        redis-cli ZADD "$REDIS_PREFIX:ops:$agent" "$timestamp" "$timestamp:$file_ops" 2>/dev/null
        
        # 保留最近 1000 条
        redis-cli ZREMRANGEBYRANK "$REDIS_PREFIX:ctx:$agent" 0 -1001 2>/dev/null
        redis-cli ZREMRANGEBYRANK "$REDIS_PREFIX:work:$agent" 0 -1001 2>/dev/null
        redis-cli ZREMRANGEBYRANK "$REDIS_PREFIX:ops:$agent" 0 -1001 2>/dev/null
        
        # 当前状态
        redis-cli HSET "$REDIS_PREFIX:current:$agent" \
            "ctx" "${ctx:-0}" \
            "status" "$status" \
            "work_seconds" "$work_seconds" \
            "file_ops" "$file_ops" \
            "timestamp" "$timestamp" 2>/dev/null
    done
    
    echo "✅ 指标已收集 $(date '+%H:%M:%S')"
}

# ============ 显示当前指标 ============
show_current() {
    echo "===== 当前指标 $(date '+%H:%M:%S') ====="
    printf "%-14s %-8s %-10s %-10s %-10s\n" "Agent" "状态" "Context" "工作时间" "文件操作"
    echo "────────────────────────────────────────────────────────────"
    
    for agent in "${AGENTS[@]}"; do
        local ctx=$(redis-cli HGET "$REDIS_PREFIX:current:$agent" "ctx" 2>/dev/null || echo "?")
        local status=$(redis-cli HGET "$REDIS_PREFIX:current:$agent" "status" 2>/dev/null || echo "?")
        local work=$(redis-cli HGET "$REDIS_PREFIX:current:$agent" "work_seconds" 2>/dev/null || echo "0")
        local ops=$(redis-cli HGET "$REDIS_PREFIX:current:$agent" "file_ops" 2>/dev/null || echo "0")
        
        local work_fmt="${work}s"
        if [[ "$work" -gt 60 ]]; then
            work_fmt="$((work / 60))m $((work % 60))s"
        fi
        
        printf "%-14s %-8s %-10s %-10s %-10s\n" "$agent" "$status" "${ctx}%" "$work_fmt" "$ops"
    done
}

# ============ 显示趋势 ============
show_trend() {
    local agent="${1:-claude-agent}"
    local metric="${2:-ctx}"
    local count="${3:-10}"
    
    echo "===== $agent $metric 趋势 (最近 $count 条) ====="
    
    redis-cli ZRANGE "$REDIS_PREFIX:$metric:$agent" -$count -1 2>/dev/null | while read -r entry; do
        local ts=$(echo "$entry" | cut -d: -f1)
        local val=$(echo "$entry" | cut -d: -f2)
        local time=$(date -d "@$ts" '+%H:%M:%S' 2>/dev/null || echo "$ts")
        echo "[$time] $val"
    done
}

# ============ 计算平均值 ============
calc_average() {
    local agent="${1:-claude-agent}"
    local metric="${2:-ctx}"
    local period="${3:-60}"  # 最近 N 分钟
    
    local now=$(date +%s)
    local start=$((now - period * 60))
    
    local values=$(redis-cli ZRANGEBYSCORE "$REDIS_PREFIX:$metric:$agent" "$start" "$now" 2>/dev/null)
    
    if [[ -z "$values" ]]; then
        echo "无数据"
        return
    fi
    
    local sum=0
    local count=0
    
    while read -r entry; do
        local val=$(echo "$entry" | cut -d: -f2)
        sum=$((sum + val))
        ((count++))
    done <<< "$values"
    
    if [[ $count -gt 0 ]]; then
        local avg=$((sum / count))
        echo "$agent $metric 平均值 (${period}分钟): $avg (样本数: $count)"
    fi
}

# ============ 生成报告 ============
report() {
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║              📊 性能指标报告                                     ║"
    echo "║                    $(date '+%Y-%m-%d %H:%M:%S')                           ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo ""
    
    show_current
    echo ""
    
    echo "===== 平均值 (最近 30 分钟) ====="
    for agent in "${AGENTS[@]}"; do
        calc_average "$agent" "ctx" 30
    done
    echo ""
    
    echo "===== Context 趋势 ====="
    for agent in "${AGENTS[@]}"; do
        echo "--- $agent ---"
        show_trend "$agent" "ctx" 5
    done
}

# ============ 入口 ============
case "${1:-current}" in
    collect)
        collect
        ;;
    current)
        show_current
        ;;
    trend)
        show_trend "$2" "$3" "$4"
        ;;
    average)
        calc_average "$2" "$3" "$4"
        ;;
    report)
        report
        ;;
    *)
        echo "用法: $0 {collect|current|trend|average|report}"
        echo ""
        echo "  collect              - 收集当前指标"
        echo "  current              - 显示当前指标"
        echo "  trend <agent> <metric> [count]  - 显示趋势"
        echo "  average <agent> <metric> [minutes]  - 计算平均值"
        echo "  report               - 生成完整报告"
        echo ""
        echo "指标: ctx (context), work (工作时间), ops (文件操作)"
        ;;
esac
