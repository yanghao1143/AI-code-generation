#!/bin/bash
# auto-learn.sh - 自动学习系统
# 从成功/失败中学习，改进策略

WORKSPACE="/home/jinyang/.openclaw/workspace"
SOCKET="/tmp/openclaw-agents.sock"
REDIS_PREFIX="openclaw:learn"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# 记录成功模式
record_success() {
    local agent="$1"
    local task_type="$2"
    local details="$3"
    
    local key="${REDIS_PREFIX}:success:${agent}:${task_type}"
    redis-cli HINCRBY "$key" "count" 1 >/dev/null
    redis-cli HSET "$key" "last_success" "$(date +%s)" >/dev/null
    redis-cli HSET "$key" "last_details" "$details" >/dev/null
    
    echo -e "${GREEN}✓ 记录成功: $agent - $task_type${NC}"
}

# 记录失败模式
record_failure() {
    local agent="$1"
    local failure_type="$2"
    local details="$3"
    
    local key="${REDIS_PREFIX}:failure:${agent}:${failure_type}"
    redis-cli HINCRBY "$key" "count" 1 >/dev/null
    redis-cli HSET "$key" "last_failure" "$(date +%s)" >/dev/null
    redis-cli HSET "$key" "last_details" "$details" >/dev/null
    
    echo -e "${RED}✗ 记录失败: $agent - $failure_type${NC}"
}

# 分析 agent 表现
analyze_agent() {
    local agent="$1"
    
    echo -e "${CYAN}━━━ $agent 学习分析 ━━━${NC}"
    
    # 成功统计
    echo -e "${GREEN}成功模式:${NC}"
    local success_keys=$(redis-cli KEYS "${REDIS_PREFIX}:success:${agent}:*" 2>/dev/null)
    if [[ -n "$success_keys" ]]; then
        for key in $success_keys; do
            local type=$(echo "$key" | rev | cut -d: -f1 | rev)
            local count=$(redis-cli HGET "$key" "count" 2>/dev/null)
            echo "  $type: $count 次"
        done
    else
        echo "  (无记录)"
    fi
    
    # 失败统计
    echo -e "${RED}失败模式:${NC}"
    local failure_keys=$(redis-cli KEYS "${REDIS_PREFIX}:failure:${agent}:*" 2>/dev/null)
    if [[ -n "$failure_keys" ]]; then
        for key in $failure_keys; do
            local type=$(echo "$key" | rev | cut -d: -f1 | rev)
            local count=$(redis-cli HGET "$key" "count" 2>/dev/null)
            echo "  $type: $count 次"
        done
    else
        echo "  (无记录)"
    fi
}

# 生成学习报告
generate_report() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    📚 学习报告                                    ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    for agent in claude-agent gemini-agent codex-agent; do
        analyze_agent "$agent"
        echo ""
    done
    
    # 总体建议
    echo -e "${YELLOW}━━━ 优化建议 ━━━${NC}"
    
    # 检查高失败率的模式
    for agent in claude-agent gemini-agent codex-agent; do
        local failure_keys=$(redis-cli KEYS "${REDIS_PREFIX}:failure:${agent}:*" 2>/dev/null)
        for key in $failure_keys; do
            local count=$(redis-cli HGET "$key" "count" 2>/dev/null || echo 0)
            if [[ $count -gt 5 ]]; then
                local type=$(echo "$key" | rev | cut -d: -f1 | rev)
                echo -e "  ${RED}⚠️ $agent 频繁出现 $type ($count 次)${NC}"
            fi
        done
    done
}

# 自动从当前状态学习
auto_learn() {
    for agent in claude-agent gemini-agent codex-agent; do
        local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null | tail -30)
        
        # 检测成功完成
        if echo "$output" | grep -qE "Successfully|completed|finished|Baked for" 2>/dev/null; then
            record_success "$agent" "task_completion" "自动检测"
        fi
        
        # 检测失败模式
        if echo "$output" | grep -qE "error\[E[0-9]+\]|Error:|failed" 2>/dev/null; then
            record_failure "$agent" "compile_error" "自动检测"
        fi
        
        if echo "$output" | grep -qE "Request cancelled|timeout" 2>/dev/null; then
            record_failure "$agent" "request_cancelled" "自动检测"
        fi
        
        if echo "$output" | grep -qE "loop was detected" 2>/dev/null; then
            record_failure "$agent" "loop_detected" "自动检测"
        fi
    done
}

# 主入口
case "${1:-report}" in
    success)
        record_success "$2" "$3" "$4"
        ;;
    failure)
        record_failure "$2" "$3" "$4"
        ;;
    analyze)
        analyze_agent "${2:-claude-agent}"
        ;;
    report)
        generate_report
        ;;
    auto)
        auto_learn
        ;;
    *)
        echo "用法: $0 <command> [args...]"
        echo ""
        echo "命令:"
        echo "  success <agent> <type> <details>  - 记录成功"
        echo "  failure <agent> <type> <details>  - 记录失败"
        echo "  analyze <agent>                   - 分析 agent"
        echo "  report                            - 生成报告"
        echo "  auto                              - 自动学习"
        ;;
esac
