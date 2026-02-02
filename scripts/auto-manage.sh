#!/bin/bash
# auto-manage.sh - 自动管理系统 (健康检查 + 恢复 + 派活)
# 一个脚本搞定所有自动化

WORKSPACE="/home/jinyang/.openclaw/workspace"
SOCKET="/tmp/openclaw-agents.sock"

echo "🤖 自动管理系统 - $(date '+%H:%M:%S')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1. 健康检查 + 自动恢复
echo "📋 Step 1: 健康检查与恢复"
HEALTH_OUTPUT=$("$WORKSPACE/scripts/agent-health.sh" auto 2>&1)
echo "$HEALTH_OUTPUT"

# 检查是否有恢复操作
if echo "$HEALTH_OUTPUT" | grep -q "恢复"; then
    echo "⏳ 等待 agent 恢复..."
    sleep 3
fi

# 2. 自动派活
echo ""
echo "📋 Step 2: 自动派活"
"$WORKSPACE/scripts/auto-dispatch.sh" auto 2>&1

# 3. 记录状态到 Redis
echo ""
echo "📋 Step 3: 更新状态"
redis-cli HSET "openclaw:auto-manage" last_run "$(date -Iseconds)" > /dev/null 2>&1
redis-cli HINCRBY "openclaw:auto-manage" run_count 1 > /dev/null 2>&1

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ 自动管理完成"
