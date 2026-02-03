#!/bin/bash
# patrol-fixer.sh - Layer 1: 自动修复
# 基于规则引擎自动处理常见问题，不依赖 LLM

set -e

SOCKET="/tmp/openclaw-agents.sock"
AGENTS=("claude-agent" "gemini-agent" "codex-agent")
REDIS_PREFIX="patrol:agent"
LOG_FILE="/tmp/patrol-fixer.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# 发送按键
send_keys() {
    local agent="$1"
    shift
    tmux -S "$SOCKET" send-keys -t "$agent" "$@" 2>/dev/null
}

# 修复规则引擎
fix_agent() {
    local agent="$1"
    local state=$(redis-cli GET "${REDIS_PREFIX}:${agent}:state" 2>/dev/null)
    
    case "$state" in
        "gemini_confirm")
            # Gemini 多选确认 - 发送 "1" 选择 "Allow once"
            send_keys "$agent" "1" Enter
            log "$agent: gemini_confirm → sent '1' Enter"
            redis-cli INCR "patrol:stats:fixes:gemini_confirm" >/dev/null
            return 0
            ;;
            
        "loop_detected")
            # 循环检测 - 发送 Enter 确认，然后清除输入
            send_keys "$agent" Enter
            sleep 0.3
            # 清除可能堆积的输入
            for i in {1..20}; do send_keys "$agent" BSpace; done
            log "$agent: loop_detected → sent Enter + cleared input"
            redis-cli INCR "patrol:stats:fixes:loop_detected" >/dev/null
            return 0
            ;;
            
        "needs_confirm")
            # 通用确认 - 发送 Enter 或 y
            send_keys "$agent" Enter
            log "$agent: needs_confirm → sent Enter"
            redis-cli INCR "patrol:stats:fixes:needs_confirm" >/dev/null
            return 0
            ;;
            
        "pending_input")
            # 有待发送的输入 - 发送 Enter
            send_keys "$agent" Enter
            log "$agent: pending_input → sent Enter"
            redis-cli INCR "patrol:stats:fixes:pending_input" >/dev/null
            return 0
            ;;
            
        "tool_error")
            # 工具错误 - 发送 Enter 让 agent 继续
            send_keys "$agent" Enter
            log "$agent: tool_error → sent Enter"
            redis-cli INCR "patrol:stats:fixes:tool_error" >/dev/null
            return 0
            ;;
            
        "network_retry")
            # 网络重试 - 检查重试次数
            local retry_count=$(redis-cli INCR "${REDIS_PREFIX}:${agent}:retry_count" 2>/dev/null)
            redis-cli EXPIRE "${REDIS_PREFIX}:${agent}:retry_count" 600 >/dev/null
            
            if [[ "$retry_count" -gt 10 ]]; then
                # 重试太多次，加入问题队列
                redis-cli LPUSH "patrol:queue:problems" "{\"agent\":\"$agent\",\"type\":\"network_timeout\",\"time\":$(date +%s)}" >/dev/null
                redis-cli DEL "${REDIS_PREFIX}:${agent}:retry_count" >/dev/null
                log "$agent: network_retry → exceeded limit, queued for restart"
            else
                log "$agent: network_retry → waiting (attempt $retry_count)"
            fi
            return 0
            ;;
            
        "env_error")
            # 环境错误 - 加入问题队列
            redis-cli LPUSH "patrol:queue:problems" "{\"agent\":\"$agent\",\"type\":\"env_error\",\"time\":$(date +%s)}" >/dev/null
            log "$agent: env_error → queued for manual fix"
            return 0
            ;;
            
        "bash_shell")
            # CLI 退出到 bash - 加入问题队列
            redis-cli LPUSH "patrol:queue:problems" "{\"agent\":\"$agent\",\"type\":\"cli_exited\",\"time\":$(date +%s)}" >/dev/null
            log "$agent: bash_shell → queued for restart"
            return 0
            ;;
            
        "session_missing")
            # 会话不存在 - 加入问题队列
            redis-cli LPUSH "patrol:queue:problems" "{\"agent\":\"$agent\",\"type\":\"session_missing\",\"time\":$(date +%s)}" >/dev/null
            log "$agent: session_missing → queued for recreation"
            return 0
            ;;
            
        "idle")
            # 空闲 - 检查空闲时间
            local idle_since=$(redis-cli GET "${REDIS_PREFIX}:${agent}:idle_since" 2>/dev/null)
            if [[ -n "$idle_since" ]]; then
                local now=$(date +%s)
                local idle_duration=$((now - idle_since))
                
                if [[ "$idle_duration" -gt 300 ]]; then
                    # 空闲超过 5 分钟，加入任务队列
                    redis-cli LPUSH "patrol:queue:idle_agents" "$agent" >/dev/null
                    log "$agent: idle for ${idle_duration}s → queued for task"
                fi
            fi
            return 0
            ;;
            
        "working"|"unknown")
            # 正常工作或未知状态 - 不处理
            return 1
            ;;
    esac
    
    return 1
}

# 主循环
main() {
    local fixed=0
    
    for agent in "${AGENTS[@]}"; do
        if fix_agent "$agent"; then
            ((fixed++))
        fi
    done
    
    if [[ "$fixed" -gt 0 ]]; then
        log "Fixed $fixed agents"
        redis-cli INCRBY "patrol:stats:total_fixes" "$fixed" >/dev/null
    fi
}

main "$@"
