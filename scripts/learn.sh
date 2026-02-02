#!/bin/bash
# learn.sh - 即时学习：每次解决问题后记录
# 用法: ./learn.sh <问题类型> <agent> <解决方案> <是否成功>

WORKSPACE="/home/jinyang/.openclaw/workspace"
LOG="$WORKSPACE/memory/evolution-log.md"

problem="$1"
agent="$2"
solution="$3"
success="${4:-true}"

timestamp=$(date "+%H:%M:%S")
date_str=$(date "+%Y-%m-%d")

# 确保今天的标题存在
if ! grep -q "## $date_str" "$LOG" 2>/dev/null; then
    echo -e "\n## $date_str\n" >> "$LOG"
fi

# 记录到 Redis 学习库
redis-cli HINCRBY "openclaw:learn:$problem" "count" 1 > /dev/null 2>&1
redis-cli HSET "openclaw:learn:$problem" "last_solution" "$solution" > /dev/null 2>&1
redis-cli HSET "openclaw:learn:$problem" "last_agent" "$agent" > /dev/null 2>&1
redis-cli HSET "openclaw:learn:$problem" "last_time" "$timestamp" > /dev/null 2>&1

if [[ "$success" == "true" ]]; then
    redis-cli HINCRBY "openclaw:learn:$problem" "success" 1 > /dev/null 2>&1
fi

# 记录到日志（简洁格式）
echo "- \`$timestamp\` **$problem** @ $agent → $solution" >> "$LOG"
