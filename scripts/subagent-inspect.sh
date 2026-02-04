#!/bin/bash
# subagent-inspect.sh - 巡检 OpenClaw subagent 状态
# 用法: ./subagent-inspect.sh [watch]

GATEWAY_URL="http://127.0.0.1:18789"
GATEWAY_TOKEN="openclaw2026"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

inspect() {
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                    🔍 Subagent 巡检                              ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo ""
    
    # 获取所有 session
    local sessions=$(curl -s "$GATEWAY_URL/api/sessions" \
        -H "Authorization: Bearer $GATEWAY_TOKEN" 2>/dev/null)
    
    if [[ -z "$sessions" ]]; then
        echo -e "${RED}❌ 无法连接 Gateway${NC}"
        return 1
    fi
    
    # 解析 subagent
    echo "$sessions" | jq -r '.sessions[] | select(.key | contains("subagent")) | 
        "[\(.label // "unnamed")] \(.key)\n  状态: \(if .totalTokens > 0 then "运行中" else "等待中" end)\n  Tokens: \(.totalTokens)/\(.contextTokens // 200000)\n  更新: \(.updatedAt | . / 1000 | strftime("%H:%M:%S"))\n"' 2>/dev/null
    
    # 统计
    local total=$(echo "$sessions" | jq '[.sessions[] | select(.key | contains("subagent"))] | length' 2>/dev/null)
    local active=$(echo "$sessions" | jq '[.sessions[] | select(.key | contains("subagent")) | select(.totalTokens > 0)] | length' 2>/dev/null)
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "总计: ${BLUE}$total${NC} 个 subagent, ${GREEN}$active${NC} 个活跃"
    
    # 检查主会话上下文
    echo ""
    echo "📊 主会话状态:"
    echo "$sessions" | jq -r '.sessions[] | select(.key == "agent:main:main") | 
        "  Tokens: \(.totalTokens)/\(.contextTokens) (\(.totalTokens * 100 / .contextTokens | floor)%)"' 2>/dev/null
    
    local main_tokens=$(echo "$sessions" | jq '.sessions[] | select(.key == "agent:main:main") | .totalTokens' 2>/dev/null)
    local main_ctx=$(echo "$sessions" | jq '.sessions[] | select(.key == "agent:main:main") | .contextTokens' 2>/dev/null)
    
    if [[ -n "$main_tokens" && -n "$main_ctx" ]]; then
        local pct=$((main_tokens * 100 / main_ctx))
        if [[ $pct -ge 70 ]]; then
            echo -e "  ${RED}⚠️ 上下文使用率 $pct% - 建议开新会话${NC}"
        elif [[ $pct -ge 50 ]]; then
            echo -e "  ${YELLOW}⚠️ 上下文使用率 $pct% - 注意控制${NC}"
        else
            echo -e "  ${GREEN}✅ 上下文健康${NC}"
        fi
    fi
}

watch_mode() {
    while true; do
        clear
        inspect
        echo ""
        echo -e "${BLUE}[$(date '+%H:%M:%S')] 每 10 秒刷新，Ctrl+C 退出${NC}"
        sleep 10
    done
}

case "${1:-inspect}" in
    watch) watch_mode ;;
    *) inspect ;;
esac
