#!/bin/bash
# 状态报告 - 供 Haiku 调用
STATE_FILE="${HOME}/.openclaw/workspace/state/machine.json"

[ ! -f "$STATE_FILE" ] && echo "NO_STATE" && exit 0

jq -r '"HEALTH: redis=\(.health.redis) pg=\(.health.postgres) | TASKS: \(.tasks|length) | ALERTS: \(.alerts|length)"' "$STATE_FILE" 2>/dev/null || echo "PARSE_ERROR"
