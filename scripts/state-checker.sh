#!/bin/bash
# 状态机检查器 - 供 Haiku 调用
# 输出需要处理的项目，不做实际处理

STATE_FILE="${HOME}/.openclaw/workspace/state/machine.json"
NOW=$(date -Iseconds)

# 检查健康状态
check_health() {
  local issues=""
  
  # Redis
  if redis-cli ping >/dev/null 2>&1; then
    redis_status="ok"
  else
    redis_status="down"
    issues="${issues}redis_down "
  fi
  
  # PostgreSQL
  if psql -c "SELECT 1" >/dev/null 2>&1; then
    pg_status="ok"
  else
    pg_status="down"
    issues="${issues}postgres_down "
  fi
  
  echo "$issues"
}

# 检查待处理任务
check_tasks() {
  if [ -f "$STATE_FILE" ]; then
    jq -r '.tasks[] | select(.status == "pending" or .status == "active") | "\(.priority)|\(.id)|\(.summary)"' "$STATE_FILE" 2>/dev/null | sort -rn | head -5
  fi
}

# 检查告警
check_alerts() {
  if [ -f "$STATE_FILE" ]; then
    jq -r '.alerts[] | select(.resolved == false) | "\(.level)|\(.message)"' "$STATE_FILE" 2>/dev/null
  fi
}

# 主输出
echo "=== STATE CHECK $(date +%H:%M) ==="

health_issues=$(check_health)
if [ -n "$health_issues" ]; then
  echo "HEALTH: $health_issues"
else
  echo "HEALTH: ok"
fi

tasks=$(check_tasks)
if [ -n "$tasks" ]; then
  echo "TASKS:"
  echo "$tasks"
else
  echo "TASKS: none"
fi

alerts=$(check_alerts)
if [ -n "$alerts" ]; then
  echo "ALERTS:"
  echo "$alerts"
else
  echo "ALERTS: none"
fi
