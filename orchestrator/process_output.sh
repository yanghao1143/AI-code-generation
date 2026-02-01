#!/bin/bash
# process_output.sh - 单独处理每个 CLI 的输出，及时摘要

SOCKET="/tmp/openclaw-agents.sock"
REDIS_PREFIX="openclaw:"

# 获取单个 agent 的输出（限制行数）
get_output() {
    local agent="$1"
    local lines="${2:-30}"  # 默认只取最后30行
    tmux -S "$SOCKET" capture-pane -p -t "$agent" -S -"$lines" 2>/dev/null
}

# 保存输出摘要到 Redis
save_summary() {
    local agent="$1"
    local summary="$2"
    local ts=$(date +%s)
    redis-cli SET "${REDIS_PREFIX}output:${agent}:latest" "$summary" > /dev/null
    redis-cli SET "${REDIS_PREFIX}output:${agent}:ts" "$ts" > /dev/null
}

# 检查 agent 是否完成（看到提示符）
is_done() {
    local agent="$1"
    local output=$(get_output "$agent" 5)
    
    # 检查各种完成标志
    if echo "$output" | grep -qE "(C:\\\\.*>|›.*context left|\$ $)"; then
        echo "done"
    else
        echo "running"
    fi
}

# 清理输出（去掉 ANSI codes 和多余空行）
clean_output() {
    sed 's/\x1b\[[0-9;]*m//g' | sed '/^$/d' | tail -20
}

# 主命令
case "$1" in
    get)
        get_output "$2" "$3"
        ;;
    status)
        is_done "$2"
        ;;
    save)
        save_summary "$2" "$3"
        ;;
    clean)
        get_output "$2" "$3" | clean_output
        ;;
    *)
        echo "Usage: process_output.sh {get|status|save|clean} <agent> [lines]"
        ;;
esac
