#!/bin/bash
# dispatch.sh - 任务分发给三个模型

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/cache.sh" 2>/dev/null

# Windows CLI 路径
CLAUDE_CMD="/mnt/c/Windows/System32/cmd.exe /c claude"
GEMINI_CMD="/mnt/c/Windows/System32/cmd.exe /c gemini"
CODEX_CMD="/mnt/c/Windows/System32/cmd.exe /c codex"

# 根据任务类型选择模型
select_model() {
    local task_type="$1"
    case "$task_type" in
        arch|debug|refactor|backend)
            echo "claude" ;;
        ui|frontend|design|css|html)
            echo "gemini" ;;
        script|test|auto|quick)
            echo "codex" ;;
        *)
            echo "claude" ;;  # 默认用 Claude
    esac
}

# 发送任务到指定模型
send_task() {
    local model="$1"
    local task="$2"
    local workdir="${3:-C:\\Projects}"
    
    local timestamp=$(date +%s)
    local task_id="task_${timestamp}"
    
    # 记录任务
    cache_set "tasks:${task_id}" "{\"model\":\"$model\",\"task\":\"$task\",\"status\":\"pending\",\"ts\":$timestamp}"
    cache_push "tasks:active" "$task_id"
    
    echo "=== 分发任务到 $model ==="
    echo "Task ID: $task_id"
    echo "任务: $task"
    echo ""
    
    case "$model" in
        claude)
            echo "执行: $CLAUDE_CMD \"$task\""
            ;;
        gemini)
            echo "执行: $GEMINI_CMD \"$task\""
            ;;
        codex)
            echo "执行: $CODEX_CMD \"$task\""
            ;;
    esac
}

# 并行分发多个任务
dispatch_parallel() {
    local tasks_json="$1"
    # TODO: 解析 JSON 并并行执行
    echo "并行分发: $tasks_json"
}

# 查看活跃任务
list_tasks() {
    echo "=== 活跃任务 ==="
    cache_list "tasks:active"
}

# CLI
case "$1" in
    select) select_model "$2" ;;
    send) send_task "$2" "$3" "$4" ;;
    parallel) dispatch_parallel "$2" ;;
    list) list_tasks ;;
    *) echo "Usage: dispatch.sh {select|send|parallel|list} [args]" ;;
esac
