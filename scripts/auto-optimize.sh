#!/bin/bash
# auto-optimize.sh - 自动优化器
# 根据分析结果自动调整参数

WORKSPACE="/home/jinyang/.openclaw/workspace"
SOCKET="/tmp/openclaw-agents.sock"
REDIS_PREFIX="openclaw:optimize"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# 优化 Gemini 网络设置
optimize_gemini() {
    local retries=$(redis-cli HGET "openclaw:evo:retry:gemini-agent" "count" 2>/dev/null || echo 0)
    
    if [[ $retries -gt 5 ]]; then
        echo -e "${YELLOW}Gemini 重试次数高 ($retries)，增加等待时间${NC}"
        redis-cli SET "${REDIS_PREFIX}:gemini:wait_multiplier" "2" >/dev/null
        return 1
    else
        redis-cli SET "${REDIS_PREFIX}:gemini:wait_multiplier" "1" >/dev/null
        return 0
    fi
}

# 优化 context 管理
optimize_context() {
    for agent in claude-agent gemini-agent codex-agent; do
        local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null | tail -20)
        local ctx=$(echo "$output" | grep -oE "[0-9]+% context" | tail -1 | grep -oE "^[0-9]+")
        
        if [[ -n "$ctx" && $ctx -lt 30 ]]; then
            echo -e "${YELLOW}$agent context 低 ($ctx%)，标记需要重启${NC}"
            redis-cli SET "openclaw:predict:needs_restart:$agent" "1" EX 3600 >/dev/null
        fi
    done
}

# 优化任务分配
optimize_dispatch() {
    local claude_tasks=$(redis-cli HGET "openclaw:evo:stats" "dispatched:claude-agent" 2>/dev/null || echo 0)
    local gemini_tasks=$(redis-cli HGET "openclaw:evo:stats" "dispatched:gemini-agent" 2>/dev/null || echo 0)
    local codex_tasks=$(redis-cli HGET "openclaw:evo:stats" "dispatched:codex-agent" 2>/dev/null || echo 0)
    
    local total=$((claude_tasks + gemini_tasks + codex_tasks))
    
    if [[ $total -gt 0 ]]; then
        local claude_pct=$((claude_tasks * 100 / total))
        local gemini_pct=$((gemini_tasks * 100 / total))
        local codex_pct=$((codex_tasks * 100 / total))
        
        echo -e "${CYAN}任务分配比例:${NC}"
        echo "  Claude: $claude_pct%"
        echo "  Gemini: $gemini_pct%"
        echo "  Codex: $codex_pct%"
        
        # 保存分析结果
        redis-cli HSET "${REDIS_PREFIX}:dispatch_ratio" \
            "claude" "$claude_pct" \
            "gemini" "$gemini_pct" \
            "codex" "$codex_pct" >/dev/null
    fi
}

# 运行所有优化
run_all() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    🔧 自动优化                                    ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${GREEN}1. 优化 Gemini 网络设置${NC}"
    optimize_gemini
    echo ""
    
    echo -e "${GREEN}2. 优化 Context 管理${NC}"
    optimize_context
    echo ""
    
    echo -e "${GREEN}3. 分析任务分配${NC}"
    optimize_dispatch
    echo ""
    
    echo -e "${GREEN}✓ 优化完成${NC}"
}

# 查看优化报告
show_report() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    📋 优化报告                                    ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Gemini 设置
    local gemini_wait=$(redis-cli GET "${REDIS_PREFIX}:gemini:wait_multiplier" 2>/dev/null || echo 1)
    echo -e "Gemini 等待倍数: $gemini_wait"
    
    # 需要重启的 agent
    echo -e "\n需要重启的 Agent:"
    for agent in claude-agent gemini-agent codex-agent; do
        local needs=$(redis-cli GET "openclaw:predict:needs_restart:$agent" 2>/dev/null)
        if [[ "$needs" == "1" ]]; then
            echo "  - $agent"
        fi
    done
    
    # 任务分配
    echo -e "\n任务分配比例:"
    redis-cli HGETALL "${REDIS_PREFIX}:dispatch_ratio" 2>/dev/null | while read -r key; do
        read -r value
        echo "  $key: $value%"
    done
}

# 清理过期数据
cleanup() {
    echo -e "${CYAN}清理过期数据...${NC}"
    
    # 清理旧的指标数据
    local cutoff=$(($(date +%s) - 86400))  # 24小时前
    
    for agent in claude-agent gemini-agent codex-agent; do
        redis-cli ZREMRANGEBYSCORE "openclaw:metrics:ctx:$agent" 0 "$cutoff" >/dev/null
        redis-cli ZREMRANGEBYSCORE "openclaw:metrics:work:$agent" 0 "$cutoff" >/dev/null
    done
    
    echo -e "${GREEN}✓ 清理完成${NC}"
}

# 主入口
case "${1:-run}" in
    run)
        run_all
        ;;
    gemini)
        optimize_gemini
        ;;
    context)
        optimize_context
        ;;
    dispatch)
        optimize_dispatch
        ;;
    report)
        show_report
        ;;
    cleanup)
        cleanup
        ;;
    *)
        echo "用法: $0 <command>"
        echo ""
        echo "命令:"
        echo "  run       - 运行所有优化"
        echo "  gemini    - 优化 Gemini 设置"
        echo "  context   - 优化 Context 管理"
        echo "  dispatch  - 分析任务分配"
        echo "  report    - 查看优化报告"
        echo "  cleanup   - 清理过期数据"
        ;;
esac
