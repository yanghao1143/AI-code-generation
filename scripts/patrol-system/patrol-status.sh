#!/bin/bash
# patrol-status.sh - 查看巡检系统状态

SOCKET="/tmp/openclaw-agents.sock"
AGENTS=("claude-agent" "gemini-agent" "codex-agent")
REDIS_PREFIX="patrol:agent"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           🛡️  Patrol System Status                           ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Agent 状态
echo -e "${YELLOW}📊 Agent Status${NC}"
echo "┌─────────────────┬──────────────────┬──────────┬─────────────────────┐"
echo "│ Agent           │ State            │ Context  │ Idle Since          │"
echo "├─────────────────┼──────────────────┼──────────┼─────────────────────┤"

for agent in "${AGENTS[@]}"; do
    state=$(redis-cli GET "${REDIS_PREFIX}:${agent}:state" 2>/dev/null || echo "unknown")
    context=$(redis-cli GET "${REDIS_PREFIX}:${agent}:context" 2>/dev/null || echo "-")
    idle_since=$(redis-cli GET "${REDIS_PREFIX}:${agent}:idle_since" 2>/dev/null)
    
    # 状态颜色
    case "$state" in
        "working") state_color="${GREEN}${state}${NC}" ;;
        "idle") state_color="${YELLOW}${state}${NC}" ;;
        "session_missing"|"bash_shell") state_color="${RED}${state}${NC}" ;;
        *) state_color="$state" ;;
    esac
    
    # 空闲时间
    if [[ -n "$idle_since" ]]; then
        now=$(date +%s)
        idle_duration=$((now - idle_since))
        idle_str="${idle_duration}s ago"
    else
        idle_str="-"
    fi
    
    printf "│ %-15s │ %-16s │ %-8s │ %-19s │\n" "$agent" "$state" "$context%" "$idle_str"
done

echo "└─────────────────┴──────────────────┴──────────┴─────────────────────┘"
echo ""

# 队列状态
echo -e "${YELLOW}📬 Queue Status${NC}"
problems=$(redis-cli LLEN "patrol:queue:problems" 2>/dev/null || echo "0")
tasks=$(redis-cli LLEN "patrol:queue:tasks" 2>/dev/null || echo "0")
idle_agents=$(redis-cli LLEN "patrol:queue:idle_agents" 2>/dev/null || echo "0")
notifications=$(redis-cli LLEN "patrol:notify:pending" 2>/dev/null || echo "0")

echo "  Problems:      $problems"
echo "  Tasks:         $tasks"
echo "  Idle Agents:   $idle_agents"
echo "  Notifications: $notifications"
echo ""

# 统计
echo -e "${YELLOW}📈 Statistics${NC}"
total_fixes=$(redis-cli GET "patrol:stats:total_fixes" 2>/dev/null || echo "0")
dispatches=$(redis-cli GET "patrol:stats:dispatches" 2>/dev/null || echo "0")
restarts=$(redis-cli GET "patrol:stats:restarts" 2>/dev/null || echo "0")

echo "  Total Fixes:   $total_fixes"
echo "  Dispatches:    $dispatches"
echo "  Restarts:      $restarts"
echo ""

# 最后采集时间
last_collect=$(redis-cli GET "patrol:last_collect" 2>/dev/null)
if [[ -n "$last_collect" ]]; then
    now=$(date +%s)
    ago=$((now - last_collect))
    echo -e "${YELLOW}⏱️  Last Collection${NC}: ${ago}s ago"
else
    echo -e "${RED}⚠️  No collection data found${NC}"
fi
