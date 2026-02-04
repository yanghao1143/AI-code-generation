#!/bin/bash
# scripts/health-check.sh - 器官健康检查
# 每次心跳运行，检查所有依赖服务

HEALTH_FILE="/tmp/openclaw_health.json"
ALERT_THRESHOLD=2  # 连续失败次数触发告警

check_redis() {
    if redis-cli ping > /dev/null 2>&1; then
        echo "ok"
    else
        echo "fail"
    fi
}

check_postgres() {
    if psql -h localhost -U openclaw -d openclaw -c "SELECT 1" > /dev/null 2>&1; then
        echo "ok"
    else
        echo "fail"
    fi
}

check_moltbook() {
    local status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
        "https://www.moltbook.com/api/v1/agents/me" \
        -H "Authorization: Bearer $MOLTBOOK_API_KEY")
    if [ "$status" = "200" ]; then
        echo "ok"
    else
        echo "fail:$status"
    fi
}

check_tmux_agents() {
    local count=$(tmux -S /tmp/openclaw-agents.sock list-sessions 2>/dev/null | wc -l)
    if [ "$count" -ge 3 ]; then
        echo "ok:$count"
    else
        echo "degraded:$count"
    fi
}

check_disk() {
    local usage=$(df -h /home/jinyang/.openclaw/workspace | tail -1 | awk '{print $5}' | tr -d '%')
    if [ "$usage" -lt 80 ]; then
        echo "ok:${usage}%"
    elif [ "$usage" -lt 95 ]; then
        echo "warning:${usage}%"
    else
        echo "critical:${usage}%"
    fi
}

# 运行所有检查
REDIS=$(check_redis)
POSTGRES=$(check_postgres)
MOLTBOOK=$(check_moltbook)
TMUX=$(check_tmux_agents)
DISK=$(check_disk)

# 生成报告
cat > "$HEALTH_FILE" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "services": {
    "redis": "$REDIS",
    "postgres": "$POSTGRES",
    "moltbook": "$MOLTBOOK",
    "tmux_agents": "$TMUX",
    "disk": "$DISK"
  },
  "overall": "$([ "$REDIS" = "ok" ] && [ "$POSTGRES" = "ok" ] && echo "healthy" || echo "degraded")"
}
EOF

# 输出摘要
echo "=== 健康检查 $(date +%H:%M:%S) ==="
echo "Redis: $REDIS"
echo "PostgreSQL: $POSTGRES"
echo "Moltbook: $MOLTBOOK"
echo "Agents: $TMUX"
echo "Disk: $DISK"

# 如果有问题，返回非零
if [ "$REDIS" != "ok" ] || [ "$POSTGRES" != "ok" ]; then
    exit 1
fi
