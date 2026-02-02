#!/bin/bash
# predictor.sh - 异常预测系统
# 预测 context 耗尽、循环、网络问题等

WORKSPACE="/home/jinyang/.openclaw/workspace"
SOCKET="/tmp/openclaw-agents.sock"
REDIS_PREFIX="openclaw:predict"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# 预测 context 耗尽
predict_context_exhaustion() {
    local agent="$1"
    
    # 获取最近的 context 数据
    local since=$(($(date +%s) - 1800))  # 最近 30 分钟
    local data=$(redis-cli ZRANGEBYSCORE "openclaw:metrics:ctx:${agent}" "$since" "+inf" 2>/dev/null)
    
    if [[ -z "$data" ]]; then
        echo "unknown"
        return
    fi
    
    # 计算下降趋势
    local first_ctx=""
    local last_ctx=""
    local count=0
    
    for entry in $data; do
        local ctx=$(echo "$entry" | cut -d: -f2)
        [[ -z "$first_ctx" ]] && first_ctx=$ctx
        last_ctx=$ctx
        ((count++))
    done
    
    if [[ $count -lt 5 ]]; then
        echo "insufficient_data"
        return
    fi
    
    local change=$((last_ctx - first_ctx))
    
    # 如果下降超过 20%，预测可能耗尽
    if [[ $change -lt -20 ]]; then
        # 估算耗尽时间
        local rate=$((change * 60 / 30))  # 每小时下降率
        if [[ $rate -lt 0 ]]; then
            local minutes_left=$((last_ctx * 60 / (-rate)))
            echo "warning:${minutes_left}min"
            return
        fi
    fi
    
    echo "ok"
}

# 预测循环
predict_loop() {
    local agent="$1"
    
    # 检查最近的重试次数
    local retries=$(redis-cli HGET "openclaw:evo:retry:${agent}" "count" 2>/dev/null || echo 0)
    
    if [[ $retries -gt 5 ]]; then
        echo "high_risk"
    elif [[ $retries -gt 3 ]]; then
        echo "medium_risk"
    else
        echo "low_risk"
    fi
}

# 预测网络问题
predict_network_issues() {
    local agent="$1"
    
    # 检查最近的网络重试
    local retries=$(redis-cli GET "${REDIS_PREFIX}:retries:${agent}" 2>/dev/null || echo 0)
    
    if [[ $retries -gt 8 ]]; then
        echo "critical"
    elif [[ $retries -gt 5 ]]; then
        echo "warning"
    else
        echo "ok"
    fi
}

# 生成预测报告
generate_predictions() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    🔮 异常预测报告                                ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "预测时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    for agent in claude-agent gemini-agent codex-agent; do
        echo -e "${GREEN}━━━ $agent ━━━${NC}"
        
        # Context 预测
        local ctx_pred=$(predict_context_exhaustion "$agent")
        echo -n "  Context: "
        case "$ctx_pred" in
            ok)
                echo -e "${GREEN}正常${NC}"
                ;;
            warning:*)
                local mins=$(echo "$ctx_pred" | cut -d: -f2 | tr -d 'min')
                echo -e "${YELLOW}⚠️ 预计 ${mins} 分钟后耗尽${NC}"
                ;;
            *)
                echo -e "数据不足"
                ;;
        esac
        
        # 循环预测
        local loop_pred=$(predict_loop "$agent")
        echo -n "  循环风险: "
        case "$loop_pred" in
            low_risk)
                echo -e "${GREEN}低${NC}"
                ;;
            medium_risk)
                echo -e "${YELLOW}中${NC}"
                ;;
            high_risk)
                echo -e "${RED}高${NC}"
                ;;
        esac
        
        # 网络预测
        local net_pred=$(predict_network_issues "$agent")
        echo -n "  网络状态: "
        case "$net_pred" in
            ok)
                echo -e "${GREEN}正常${NC}"
                ;;
            warning)
                echo -e "${YELLOW}不稳定${NC}"
                ;;
            critical)
                echo -e "${RED}严重问题${NC}"
                ;;
        esac
        
        echo ""
    done
}

# 自动预防措施
auto_prevent() {
    echo -e "${CYAN}执行预防措施...${NC}"
    
    for agent in claude-agent gemini-agent codex-agent; do
        # Context 预防
        local ctx_pred=$(predict_context_exhaustion "$agent")
        if [[ "$ctx_pred" == warning:* ]]; then
            local mins=$(echo "$ctx_pred" | cut -d: -f2 | tr -d 'min')
            if [[ $mins -lt 30 ]]; then
                echo -e "${YELLOW}⚠️ $agent context 即将耗尽，标记需要重启${NC}"
                redis-cli SET "${REDIS_PREFIX}:needs_restart:${agent}" "1" EX 3600 >/dev/null
            fi
        fi
        
        # 循环预防
        local loop_pred=$(predict_loop "$agent")
        if [[ "$loop_pred" == "high_risk" ]]; then
            echo -e "${YELLOW}⚠️ $agent 循环风险高，重置重试计数${NC}"
            redis-cli HSET "openclaw:evo:retry:${agent}" "count" 0 >/dev/null
        fi
    done
    
    echo -e "${GREEN}✓ 预防措施完成${NC}"
}

# 主入口
case "${1:-predict}" in
    predict)
        generate_predictions
        ;;
    prevent)
        auto_prevent
        ;;
    context)
        predict_context_exhaustion "${2:-claude-agent}"
        ;;
    loop)
        predict_loop "${2:-claude-agent}"
        ;;
    network)
        predict_network_issues "${2:-claude-agent}"
        ;;
    *)
        echo "用法: $0 <command> [args...]"
        echo ""
        echo "命令:"
        echo "  predict           - 生成预测报告"
        echo "  prevent           - 执行预防措施"
        echo "  context <agent>   - 预测 context 耗尽"
        echo "  loop <agent>      - 预测循环风险"
        echo "  network <agent>   - 预测网络问题"
        ;;
esac
