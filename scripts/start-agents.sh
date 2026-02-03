#!/bin/bash
# start-agents.sh - 启动三模型协作系统 v2.0
# 自动配置，无需人工干预

SOCKET="/tmp/openclaw-agents.sock"
ZED_DIR="D:\\ai软件\\zed"

# 检查 tmux 会话是否存在
session_exists() {
    tmux -S "$SOCKET" has-session -t "$1" 2>/dev/null
}

# 启动 Claude Agent (跳过权限检查)
start_claude() {
    if session_exists "claude-agent"; then
        echo "claude-agent 已存在"
    else
        tmux -S "$SOCKET" new-session -d -s claude-agent
        sleep 1
    fi
    # 使用 --dangerously-skip-permissions 避免权限确认阻塞
    tmux -S "$SOCKET" send-keys -t claude-agent "/mnt/c/Windows/System32/cmd.exe /c 'cd /d $ZED_DIR && claude --dangerously-skip-permissions'" Enter
    echo "✅ claude-agent 启动 (权限检查已跳过)"
}

# 启动 Gemini Agent
start_gemini() {
    if session_exists "gemini-agent"; then
        echo "gemini-agent 已存在"
    else
        tmux -S "$SOCKET" new-session -d -s gemini-agent
        sleep 1
    fi
    tmux -S "$SOCKET" send-keys -t gemini-agent "/mnt/c/Windows/System32/cmd.exe /c 'cd /d $ZED_DIR && gemini'" Enter
    echo "✅ gemini-agent 启动"
}

# 启动 Codex Agent
start_codex() {
    if session_exists "codex-agent"; then
        echo "codex-agent 已存在"
    else
        tmux -S "$SOCKET" new-session -d -s codex-agent
        sleep 1
    fi
    tmux -S "$SOCKET" send-keys -t codex-agent "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -Command 'cd D:\\ai软件\\zed; codex'" Enter
    echo "✅ codex-agent 启动"
}

# 重启指定 agent
restart_agent() {
    local agent="$1"
    echo "重启 $agent..."
    tmux -S "$SOCKET" send-keys -t "$agent" C-c
    sleep 1
    tmux -S "$SOCKET" send-keys -t "$agent" "/exit" Enter 2>/dev/null
    sleep 1
    
    case "$agent" in
        claude-agent)
            tmux -S "$SOCKET" send-keys -t "$agent" "/mnt/c/Windows/System32/cmd.exe /c 'cd /d $ZED_DIR && claude --dangerously-skip-permissions'" Enter
            ;;
        gemini-agent)
            tmux -S "$SOCKET" send-keys -t "$agent" "/mnt/c/Windows/System32/cmd.exe /c 'cd /d $ZED_DIR && gemini'" Enter
            ;;
        codex-agent)
            tmux -S "$SOCKET" send-keys -t "$agent" "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -Command 'cd D:\\ai软件\\zed; codex'" Enter
            ;;
    esac
    echo "✅ $agent 已重启"
}

case "${1:-all}" in
    all)
        start_claude
        start_gemini
        start_codex
        ;;
    claude) start_claude ;;
    gemini) start_gemini ;;
    codex) start_codex ;;
    restart)
        restart_agent "${2:-claude-agent}"
        ;;
    *)
        echo "用法: $0 [all|claude|gemini|codex|restart <agent>]"
        ;;
esac
