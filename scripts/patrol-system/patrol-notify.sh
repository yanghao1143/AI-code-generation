#!/bin/bash
# patrol-notify.sh - Layer 3: 通知机制
# 将重要事件通知到主会话

REDIS_PREFIX="patrol:notify"
OPENCLAW_WORKSPACE="/home/jinyang/.openclaw/workspace"
NOTIFY_FILE="$OPENCLAW_WORKSPACE/PATROL_ALERTS.md"

# 处理待通知消息
process_notifications() {
    local count=0
    local messages=""
    
    while true; do
        local msg=$(redis-cli RPOP "${REDIS_PREFIX}:pending" 2>/dev/null)
        [[ -z "$msg" ]] && break
        
        messages+="- $(date '+%H:%M:%S') $msg\n"
        ((count++))
    done
    
    if [[ "$count" -gt 0 ]]; then
        # 写入通知文件
        echo -e "# Patrol Alerts\n\n## $(date '+%Y-%m-%d')\n\n$messages" > "$NOTIFY_FILE"
        
        # 也可以通过 OpenClaw 的 wake 机制通知
        # 但这需要 API 可用，所以作为备选
    fi
}

# 生成状态摘要
generate_summary() {
    local agents=("claude-agent" "gemini-agent" "codex-agent")
    local summary=""
    local issues=0
    
    for agent in "${agents[@]}"; do
        local state=$(redis-cli GET "patrol:agent:${agent}:state" 2>/dev/null)
        case "$state" in
            "session_missing"|"bash_shell"|"env_error")
                summary+="❌ $agent: $state\n"
                ((issues++))
                ;;
            "idle")
                local idle_since=$(redis-cli GET "patrol:agent:${agent}:idle_since" 2>/dev/null)
                if [[ -n "$idle_since" ]]; then
                    local now=$(date +%s)
                    local idle_duration=$((now - idle_since))
                    if [[ "$idle_duration" -gt 600 ]]; then
                        summary+="⚠️ $agent: idle for ${idle_duration}s\n"
                        ((issues++))
                    fi
                fi
                ;;
        esac
    done
    
    if [[ "$issues" -gt 0 ]]; then
        echo -e "# Patrol Summary\n\n**Issues Found: $issues**\n\n$summary" >> "$NOTIFY_FILE"
    fi
}

main() {
    process_notifications
    generate_summary
}

main "$@"
