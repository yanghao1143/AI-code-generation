#!/bin/bash
# dispatch-task.sh - 标准化任务派发
# 用法: ./dispatch-task.sh <agent> <purpose> <task> [context] [expected] [rules]

SOCKET="/tmp/openclaw-agents.sock"
AGENT="$1"
PURPOSE="$2"
TASK="$3"
CONTEXT="${4:-无额外上下文}"
EXPECTED="${5:-完成任务}"
RULES="${6:-遵循项目规范}"

if [[ -z "$AGENT" || -z "$PURPOSE" || -z "$TASK" ]]; then
    echo "用法: $0 <agent> <purpose> <task> [context] [expected] [rules]"
    echo "示例: $0 claude-agent '修复测试' '解决 lock poisoning' 'tests/*.rs' '测试通过' '最小改动'"
    exit 1
fi

# 检查 tmux 会话是否存在
if ! tmux -S "$SOCKET" has-session -t "$AGENT" 2>/dev/null; then
    echo "❌ 会话不存在: $AGENT"
    echo "   请先启动 agent 会话"
    exit 1
fi

# 检查 agent 当前运行的命令
CURRENT_CMD=$(tmux -S "$SOCKET" display-message -t "$AGENT" -p '#{pane_current_command}')

# 如果是 bash/init，说明 CLI 没在运行
if [[ "$CURRENT_CMD" == "bash" || "$CURRENT_CMD" == "init" || "$CURRENT_CMD" == "zsh" ]]; then
    echo "⚠️  $AGENT 当前是 shell 状态 ($CURRENT_CMD)"
    echo "   需要先启动对应的 AI CLI"
    
    case "$AGENT" in
        claude-agent)
            echo "   建议: tmux -S $SOCKET send-keys -t $AGENT 'claude' Enter"
            ;;
        gemini-agent)
            echo "   建议: tmux -S $SOCKET send-keys -t $AGENT 'gemini' Enter"
            ;;
        codex-agent)
            echo "   建议: tmux -S $SOCKET send-keys -t $AGENT 'codex' Enter"
            ;;
    esac
    
    read -p "是否自动启动 CLI? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        case "$AGENT" in
            claude-agent) tmux -S "$SOCKET" send-keys -t "$AGENT" "claude" Enter ;;
            gemini-agent) tmux -S "$SOCKET" send-keys -t "$AGENT" "gemini" Enter ;;
            codex-agent)  tmux -S "$SOCKET" send-keys -t "$AGENT" "codex" Enter ;;
        esac
        echo "   等待 CLI 启动..."
        sleep 3
    else
        echo "   跳过任务派发"
        exit 1
    fi
fi

# 构建标准化 prompt
PROMPT="PURPOSE: $PURPOSE
TASK: $TASK
CONTEXT: $CONTEXT
EXPECTED: $EXPECTED
RULES: $RULES"

# 记录到 Redis
TASK_ID="task-$(date +%s)"
redis-cli HSET "openclaw:tasks:$TASK_ID" \
    agent "$AGENT" \
    purpose "$PURPOSE" \
    task "$TASK" \
    context "$CONTEXT" \
    expected "$EXPECTED" \
    rules "$RULES" \
    status "dispatched" \
    created_at "$(date -Iseconds)" \
    > /dev/null

redis-cli SADD "openclaw:tasks:active" "$TASK_ID" > /dev/null

echo "📋 派发任务到 $AGENT"
echo "---"
echo "$PROMPT"
echo "---"

# 发送到 tmux
tmux -S "$SOCKET" send-keys -t "$AGENT" "$PROMPT" Enter

echo "✅ 任务已派发 (ID: $TASK_ID)"
