#!/bin/bash
# 添加任务到队列
# 用法: ./add-task.sh <描述> [类型] [指定agent]
# 类型: backend/frontend/fix/test/general
# agent: claude/gemini/codex/auto

desc="$1"
type="${2:-general}"
agent="${3:-auto}"

if [ -z "$desc" ]; then
    echo "用法: $0 <任务描述> [类型] [agent]"
    echo ""
    echo "类型: backend, frontend, fix, test, general"
    echo "Agent: claude, gemini, codex, auto"
    echo ""
    echo "示例:"
    echo "  $0 '修复登录bug' fix codex"
    echo "  $0 '添加用户界面' frontend gemini"
    echo "  $0 '重构数据库模块' backend claude"
    exit 1
fi

task="{\"type\":\"$type\",\"desc\":\"$desc\",\"agent\":\"$agent\",\"created\":$(date +%s)}"

redis-cli LPUSH "openclaw:task:queue" "$task" > /dev/null

echo "✓ 任务已添加到队列"
echo "  描述: $desc"
echo "  类型: $type"
echo "  Agent: $agent"
echo ""
echo "队列长度: $(redis-cli LLEN 'openclaw:task:queue')"
