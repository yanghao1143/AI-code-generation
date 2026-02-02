#!/bin/bash
# daemon.sh - 自动恢复守护进程
# 功能: 持续监控 agent 状态，自动修复问题

WORKSPACE="/home/jinyang/.openclaw/workspace"
SOCKET="/tmp/openclaw-agents.sock"
REDIS_PREFIX="openclaw:daemon"
AGENTS=("claude-agent" "gemini-agent" "codex-agent")
PID_FILE="/tmp/openclaw-daemon.pid"
LOG_FILE="$WORKSPACE/logs/daemon.log"

# 确保日志目录存在
mkdir -p "$WORKSPACE/logs"

# ============ 日志函数 ============
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg" >> "$LOG_FILE"
    echo "$msg"
}

# ============ 单次检查 ============
check_once() {
    local issues=0
    
    for agent in "${AGENTS[@]}"; do
        # 使用 evolution-v4 诊断
        local diagnosis=$("$WORKSPACE/scripts/evolution-v4.sh" diagnose "$agent" 2>/dev/null)
        
        case "$diagnosis" in
            working|unknown)
                # 正常，重置计数
                redis-cli HSET "$REDIS_PREFIX:$agent" "consecutive_issues" 0 >/dev/null 2>&1
                ;;
            network_retry)
                # 网络重试，等待
                local retry_count=$(redis-cli HGET "$REDIS_PREFIX:$agent" "network_retries" 2>/dev/null || echo 0)
                ((retry_count++))
                redis-cli HSET "$REDIS_PREFIX:$agent" "network_retries" "$retry_count" >/dev/null 2>&1
                
                if [[ $retry_count -gt 10 ]]; then
                    log "🔧 $agent: 网络重试超过 10 次，重启"
                    "$WORKSPACE/scripts/evolution-v4.sh" repair "$agent" >/dev/null 2>&1
                    redis-cli HSET "$REDIS_PREFIX:$agent" "network_retries" 0 >/dev/null 2>&1
                fi
                ((issues++))
                ;;
            loop_detected)
                log "🔧 $agent: 检测到循环，修复"
                "$WORKSPACE/scripts/evolution-v4.sh" repair "$agent" >/dev/null 2>&1
                ((issues++))
                ;;
            needs_confirm)
                log "🔧 $agent: 需要确认，自动确认"
                "$WORKSPACE/scripts/evolution-v4.sh" repair "$agent" >/dev/null 2>&1
                ((issues++))
                ;;
            context_low)
                log "🔧 $agent: Context 低，重启"
                "$WORKSPACE/scripts/evolution-v4.sh" repair "$agent" >/dev/null 2>&1
                ((issues++))
                ;;
            idle|idle_with_suggestion)
                # 空闲，派活
                log "📋 $agent: 空闲，派发任务"
                "$WORKSPACE/scripts/evolution-v4.sh" repair "$agent" >/dev/null 2>&1
                ;;
            api_failure)
                log "🔧 $agent: API 失败，重启"
                "$WORKSPACE/scripts/evolution-v4.sh" repair "$agent" >/dev/null 2>&1
                ((issues++))
                ;;
            pending_input)
                log "🔧 $agent: 有未发送输入，发送"
                "$WORKSPACE/scripts/evolution-v4.sh" repair "$agent" >/dev/null 2>&1
                ;;
            *)
                # 其他问题，记录
                local consecutive=$(redis-cli HINCRBY "$REDIS_PREFIX:$agent" "consecutive_issues" 1 2>/dev/null)
                if [[ $consecutive -gt 5 ]]; then
                    log "⚠️ $agent: 连续 $consecutive 次异常状态 ($diagnosis)，尝试重启"
                    source "$WORKSPACE/scripts/evolution-v4.sh"
                    restart_agent "$agent"
                    redis-cli HSET "$REDIS_PREFIX:$agent" "consecutive_issues" 0 >/dev/null 2>&1
                fi
                ((issues++))
                ;;
        esac
    done
    
    return $issues
}

# ============ 守护进程主循环 ============
daemon_loop() {
    log "🚀 守护进程启动"
    
    while true; do
        check_once
        
        # 每 30 秒检查一次
        sleep 30
    done
}

# ============ 启动守护进程 ============
start_daemon() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo "守护进程已在运行 (PID: $pid)"
            return 1
        fi
    fi
    
    # 后台启动
    nohup "$0" loop >> "$LOG_FILE" 2>&1 &
    local pid=$!
    echo "$pid" > "$PID_FILE"
    echo "✅ 守护进程已启动 (PID: $pid)"
    echo "日志: $LOG_FILE"
}

# ============ 停止守护进程 ============
stop_daemon() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            rm -f "$PID_FILE"
            echo "✅ 守护进程已停止"
            return 0
        fi
    fi
    echo "守护进程未运行"
}

# ============ 状态 ============
daemon_status() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo "✅ 守护进程运行中 (PID: $pid)"
            echo ""
            echo "最近日志:"
            tail -10 "$LOG_FILE" 2>/dev/null
            return 0
        fi
    fi
    echo "❌ 守护进程未运行"
}

# ============ 入口 ============
case "${1:-status}" in
    start)
        start_daemon
        ;;
    stop)
        stop_daemon
        ;;
    restart)
        stop_daemon
        sleep 1
        start_daemon
        ;;
    status)
        daemon_status
        ;;
    loop)
        daemon_loop
        ;;
    once)
        check_once
        echo "检查完成"
        ;;
    log)
        tail -${2:-50} "$LOG_FILE" 2>/dev/null || echo "无日志"
        ;;
    *)
        echo "用法: $0 {start|stop|restart|status|once|log}"
        echo ""
        echo "  start   - 启动守护进程"
        echo "  stop    - 停止守护进程"
        echo "  restart - 重启守护进程"
        echo "  status  - 查看状态"
        echo "  once    - 单次检查"
        echo "  log [n] - 查看最近 n 行日志"
        ;;
esac
