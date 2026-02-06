#!/bin/bash
# 更新状态机 - 由 cron 或心跳调用

STATE_FILE="${HOME}/.openclaw/workspace/state/machine.json"
NOW=$(date -Iseconds)

# Redis
REDIS_STATUS="unknown"
timeout 2 redis-cli ping >/dev/null 2>&1 && REDIS_STATUS="ok" || REDIS_STATUS="down"

# PostgreSQL (用脚本检查)
PG_STATUS="unknown"
if [ -f "./scripts/pg-memory.sh" ]; then
  timeout 3 ./scripts/pg-memory.sh status >/dev/null 2>&1 && PG_STATUS="ok" || PG_STATUS="down"
fi

cat > "$STATE_FILE" << EOF
{
  "version": 1,
  "updated": "$NOW",
  "health": {
    "redis": "$REDIS_STATUS",
    "postgres": "$PG_STATUS"
  },
  "tasks": [],
  "alerts": []
}
EOF

echo "ok"
