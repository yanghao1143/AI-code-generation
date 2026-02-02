#!/bin/bash
# pre-verify.sh - 预执行验证 (双 agent 审核)
# 用法: ./pre-verify.sh <task_description> [files...]

SOCKET="/tmp/openclaw-agents.sock"
TASK="$1"
shift
FILES="$@"

if [[ -z "$TASK" ]]; then
    echo "用法: $0 <task_description> [files...]"
    exit 1
fi

echo "🔍 预执行验证: $TASK"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1. Gemini 战略分析
echo ""
echo "📊 [Gemini] 战略分析..."
GEMINI_PROMPT="PURPOSE: 评估任务可行性和风险
TASK: 分析以下任务的战略影响
CONTEXT: 任务描述: $TASK
相关文件: $FILES
EXPECTED: 
- 可行性评分 (1-10)
- 潜在风险
- 建议的执行顺序
RULES: 只做分析，不执行任何修改"

tmux -S "$SOCKET" send-keys -t "gemini-agent" "$GEMINI_PROMPT" Enter

# 2. Codex 技术分析
echo "🔧 [Codex] 技术分析..."
CODEX_PROMPT="PURPOSE: 评估任务技术可行性
TASK: 分析以下任务的技术实现
CONTEXT: 任务描述: $TASK
相关文件: $FILES
EXPECTED:
- 技术复杂度评分 (1-10)
- 依赖检查
- 潜在的技术债务
RULES: 只做分析，不执行任何修改"

tmux -S "$SOCKET" send-keys -t "codex-agent" "$CODEX_PROMPT" Enter

echo ""
echo "✅ 验证请求已发送"
echo "   等待 Gemini 和 Codex 返回分析结果..."
echo "   查看结果: tmux -S $SOCKET attach"

# 记录验证请求
VERIFY_ID="verify-$(date +%s)"
redis-cli HSET "openclaw:verify:$VERIFY_ID" \
    task "$TASK" \
    files "$FILES" \
    status "pending" \
    created_at "$(date -Iseconds)" \
    > /dev/null

echo "   验证 ID: $VERIFY_ID"
