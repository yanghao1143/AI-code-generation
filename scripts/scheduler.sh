#!/bin/bash
# 任务调度器 - 纯 Redis + tmux，不调模型
# 用法: ./scheduler.sh (后台运行: nohup ./scheduler.sh &)

SOCKET="/tmp/openclaw-agents.sock"
POLL_INTERVAL=10  # 秒

log() { echo "[$(date '+%H:%M:%S')] $1"; }

# 获取空闲 agent
get_idle_agent() {
    for agent in claude-agent gemini-agent codex-agent; do
        # 检查是否有运行中任务
        running=$(redis-cli HGET openclaw:task:running "$agent" 2>/dev/null)
        if [ -z "$running" ]; then
            # 检查 pane 是否空闲 (最后一行是 $ 或 >)
            last_line=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null | tail -1)
            if [[ "$last_line" =~ [\$\>]$ ]]; then
                echo "$agent"
                return 0
            fi
        fi
    done
    return 1
}

# 派发任务
dispatch_task() {
    local task="$1"
    local agent="$2"
    local task_id=$(echo "$task" | jq -r '.id // "unknown"')
    local desc=$(echo "$task" | jq -r '.desc // .content // "task"')
    
    # 记录运行状态
    redis-cli HSET openclaw:task:running "$agent" "$task_id" >/dev/null
    redis-cli SET "openclaw:task:$task_id:start" "$(date +%s)" >/dev/null
    redis-cli SET "openclaw:task:$task_id:agent" "$agent" >/dev/null
    
    # 发送到 tmux
    tmux -S "$SOCKET" send-keys -t "$agent" "$desc" Enter
    log "📤 派发 [$task_id] → $agent"
}

# 检查完成状态
check_completion() {
    redis-cli HGETALL openclaw:task:running 2>/dev/null | while read -r agent; do
        read -r task_id
        [ -z "$agent" ] && continue
        
        # 检查输出是否有完成标志
        output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null | tail -20)
        
        if echo "$output" | grep -qE "(完成|done|finished|✓|✅)"; then
            redis-cli HDEL openclaw:task:running "$agent" >/dev/null
            redis-cli LPUSH openclaw:task:completed "$task_id" >/dev/null
            redis-cli SET "openclaw:task:$task_id:end" "$(date +%s)" >/dev/null
            log "✅ 完成 [$task_id] @ $agent"
        fi
        
        # 检查超时 (>10分钟)
        start=$(redis-cli GET "openclaw:task:$task_id:start" 2>/dev/null)
        if [ -n "$start" ]; then
            elapsed=$(($(date +%s) - start))
            if [ $elapsed -gt 600 ]; then
                log "⚠️ 超时 [$task_id] @ $agent (${elapsed}s)"
                # 可选: 发送 Ctrl+C
                # tmux -S "$SOCKET" send-keys -t "$agent" C-c
            fi
        fi
    done
}

# 主循环
log "🚀 调度器启动 (间隔 ${POLL_INTERVAL}s)"

while true; do
    # 1. 检查完成状态
    check_completion
    
    # 2. 取任务
    task=$(redis-cli RPOP openclaw:task:queue 2>/dev/null)
    
    if [ -n "$task" ]; then
        # 3. 找空闲 agent
        preferred=$(echo "$task" | jq -r '.agent // "auto"')
        
        if [ "$preferred" != "auto" ] && [ "$preferred" != "null" ]; then
            agent="${preferred}-agent"
            running=$(redis-cli HGET openclaw:task:running "$agent" 2>/dev/null)
            [ -n "$running" ] && agent=""
        else
            agent=$(get_idle_agent)
        fi
        
        if [ -n "$agent" ]; then
            dispatch_task "$task" "$agent"
        else
            # 没有空闲 agent，放回队列
            redis-cli LPUSH openclaw:task:queue "$task" >/dev/null
            log "⏳ 无空闲 agent，任务回队列"
        fi
    fi
    
    sleep $POLL_INTERVAL
done
