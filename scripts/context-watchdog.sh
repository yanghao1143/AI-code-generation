#!/bin/bash
# 上下文监控守护进程
# 当上下文超过阈值时，自动触发 compaction 或通知

THRESHOLD_PERCENT=60
CHECK_INTERVAL=30
LOG_FILE="/tmp/openclaw/context-watchdog.log"

mkdir -p /tmp/openclaw

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

get_context_usage() {
    # 通过 gateway API 获取当前会话状态
    curl -s "http://127.0.0.1:18789/api/sessions" \
        -H "Authorization: Bearer openclaw2026" 2>/dev/null | \
        jq -r '.sessions[] | select(.key == "agent:main:main") | "\(.totalTokens)/\(.contextTokens)"' 2>/dev/null
}

trigger_compaction() {
    log "⚠️ 触发主动 compaction"
    # 发送 wake 事件让 agent 知道需要清理
    curl -s -X POST "http://127.0.0.1:18789/api/cron/wake" \
        -H "Authorization: Bearer openclaw2026" \
        -H "Content-Type: application/json" \
        -d '{"text": "[CONTEXT_WARNING] 上下文使用率超过 '"$THRESHOLD_PERCENT"'%，请精简回复或考虑开新会话", "mode": "now"}' 2>/dev/null
}

log "Context watchdog started (threshold: ${THRESHOLD_PERCENT}%)"

while true; do
    usage=$(get_context_usage)
    if [ -n "$usage" ]; then
        current=$(echo "$usage" | cut -d'/' -f1)
        max=$(echo "$usage" | cut -d'/' -f2)
        
        if [ -n "$current" ] && [ -n "$max" ] && [ "$max" -gt 0 ]; then
            percent=$((current * 100 / max))
            
            if [ "$percent" -ge "$THRESHOLD_PERCENT" ]; then
                log "🔴 Context at ${percent}% (${current}/${max}) - ALERT"
                trigger_compaction
                # 触发后等待更长时间
                sleep 120
            else
                log "✅ Context at ${percent}% (${current}/${max})"
            fi
        fi
    fi
    sleep "$CHECK_INTERVAL"
done
