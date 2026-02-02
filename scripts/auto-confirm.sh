#!/bin/bash
# auto-confirm.sh - 自动确认 agent 的权限请求 v3
# 支持 Claude, Gemini, Codex 的各种确认格式

SOCKET="/tmp/openclaw-agents.sock"
AGENTS=("claude-agent" "gemini-agent" "codex-agent")

declare -A LAST_HASH

auto_confirm() {
    local agent="$1"
    local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null | tail -20)
    local output_hash=$(echo "$output" | md5sum | cut -d' ' -f1)
    
    # 避免重复确认
    if [[ "${LAST_HASH[$agent]}" == "$output_hash" ]]; then
        return 1
    fi
    
    local last_lines=$(echo "$output" | tail -10)
    local confirmed=false
    
    # Claude 格式: > 1. Yes / 2. Yes, allow...
    if echo "$last_lines" | grep -qE ">\s*1\.\s*Yes" 2>/dev/null; then
        if echo "$last_lines" | grep -qE "2\.\s*Yes.*allow" 2>/dev/null; then
            tmux -S "$SOCKET" send-keys -t "$agent" "2" Enter
            echo "[$(date +%H:%M:%S)] $agent: Claude 确认 (选项2)"
            confirmed=true
        fi
    fi
    
    # Codex 格式: › 1. Yes, proceed (y)
    if echo "$last_lines" | grep -qE "›\s*1\.\s*Yes.*proceed" 2>/dev/null; then
        tmux -S "$SOCKET" send-keys -t "$agent" Enter
        echo "[$(date +%H:%M:%S)] $agent: Codex 确认 (Enter)"
        confirmed=true
    fi
    
    # Gemini 格式: ● 1. Allow once / 2. Allow for this session
    if echo "$last_lines" | grep -qE "●\s*1\.\s*Allow once" 2>/dev/null; then
        tmux -S "$SOCKET" send-keys -t "$agent" "2" Enter
        echo "[$(date +%H:%M:%S)] $agent: Gemini 确认 (选项2)"
        confirmed=true
    fi
    
    # 通用 Y/N
    if echo "$last_lines" | grep -qE "\[Y/n\]|\[y/N\]" 2>/dev/null; then
        tmux -S "$SOCKET" send-keys -t "$agent" "y" Enter
        echo "[$(date +%H:%M:%S)] $agent: Y/N 确认"
        confirmed=true
    fi
    
    # Apply this change?
    if echo "$last_lines" | grep -qE "Apply this change\?" 2>/dev/null; then
        tmux -S "$SOCKET" send-keys -t "$agent" "2" Enter
        echo "[$(date +%H:%M:%S)] $agent: 编辑确认"
        confirmed=true
    fi
    
    if [[ "$confirmed" == "true" ]]; then
        LAST_HASH[$agent]="$output_hash"
        return 0
    fi
    
    return 1
}

echo "🤖 自动确认服务 v3 - $(date)"
echo "监控: ${AGENTS[*]}"
echo ""

while true; do
    for agent in "${AGENTS[@]}"; do
        auto_confirm "$agent"
    done
    sleep 3
done
