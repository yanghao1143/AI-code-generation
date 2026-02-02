#!/bin/bash
# director.sh - 技术总监控制台
# 全局视角、智能决策、持续改进

WORKSPACE="/home/jinyang/.openclaw/workspace"
SOCKET="/tmp/openclaw-agents.sock"
REDIS_PREFIX="openclaw:director"
PROJECT_PATH="/mnt/d/ai软件/zed"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# ============ 全局状态仪表盘 ============
show_dashboard() {
    clear
    echo -e "${MAGENTA}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║                    🎯 技术总监控制台 - $(date '+%Y-%m-%d %H:%M:%S')                    ║${NC}"
    echo -e "${MAGENTA}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # 1. Agent 状态概览
    echo -e "${CYAN}┌─────────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│ 👥 Agent 状态                                                                │${NC}"
    echo -e "${CYAN}└─────────────────────────────────────────────────────────────────────────────┘${NC}"
    
    for agent in claude-agent gemini-agent codex-agent; do
        local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null | tail -20)
        local status="unknown"
        local ctx="?"
        local activity=""
        
        # 检测状态
        if echo "$output" | grep -qE "esc to cancel|esc to interrupt" 2>/dev/null; then
            status="${GREEN}工作中${NC}"
            activity=$(echo "$output" | grep -oE "(Thinking|Working|Searching|Reading|Writing|Mining|Baking|Navigating|Investigating|Analyzing|Mulling|Limiting)[^(]*" | tail -1 | head -c 30)
        elif echo "$output" | grep -qE "Type your message|^❯\s*$|^›\s*$" 2>/dev/null; then
            status="${BLUE}空闲${NC}"
        elif echo "$output" | grep -qE "error|Error|failed" 2>/dev/null; then
            status="${RED}错误${NC}"
        fi
        
        # 提取 context
        ctx=$(echo "$output" | grep -oE "[0-9]+% context" | tail -1 | grep -oE "^[0-9]+" || echo "?")
        
        printf "  %-15s [%b] ctx:%3s%% %s\n" "$agent" "$status" "$ctx" "$activity"
    done
    
    echo ""
    
    # 2. 项目进度
    echo -e "${CYAN}┌─────────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│ 📊 项目进度                                                                  │${NC}"
    echo -e "${CYAN}└─────────────────────────────────────────────────────────────────────────────┘${NC}"
    
    cd "$PROJECT_PATH" 2>/dev/null
    local i18n_done=$(grep -r 't("' crates/*/src/*.rs 2>/dev/null | wc -l)
    local i18n_total=$(grep -r "\.to_string()" crates/*/src/*.rs 2>/dev/null | wc -l)
    local i18n_pct=$((i18n_done * 100 / (i18n_done + i18n_total + 1)))
    local today_commits=$(git log --since="midnight" --oneline 2>/dev/null | wc -l)
    local errors=$(cargo check 2>&1 | grep -c "^error" || echo "?")
    
    echo -e "  i18n 进度: ${GREEN}$i18n_pct%${NC} ($i18n_done/$((i18n_done + i18n_total)))"
    echo -e "  今日提交: ${GREEN}$today_commits${NC}"
    echo -e "  编译错误: ${errors} 个"
    
    echo ""
    
    # 3. 系统健康
    echo -e "${CYAN}┌─────────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│ 🏥 系统健康                                                                  │${NC}"
    echo -e "${CYAN}└─────────────────────────────────────────────────────────────────────────────┘${NC}"
    
    local redis_ok=$(redis-cli ping 2>/dev/null | grep -c PONG)
    local tmux_ok=$(tmux -S "$SOCKET" list-sessions 2>/dev/null | wc -l)
    
    echo -ne "  Redis: "
    [[ $redis_ok -gt 0 ]] && echo -e "${GREEN}✓${NC}" || echo -e "${RED}✗${NC}"
    echo -ne "  tmux: "
    [[ $tmux_ok -gt 0 ]] && echo -e "${GREEN}✓ ($tmux_ok 会话)${NC}" || echo -e "${RED}✗${NC}"
    
    echo ""
}

# ============ 智能决策引擎 ============
make_decision() {
    local situation="$1"
    
    echo -e "${CYAN}🧠 分析情况: $situation${NC}"
    
    case "$situation" in
        "agent_idle")
            # 决定给空闲 agent 分配什么任务
            local agent="$2"
            local task=$("$WORKSPACE/scripts/task-finder.sh" next "$agent" 2>/dev/null)
            echo -e "${GREEN}决策: 分配任务 '$task' 给 $agent${NC}"
            echo "$task"
            ;;
        "compile_errors")
            # 决定谁来修复编译错误
            echo -e "${GREEN}决策: 优先让 Codex 修复编译错误${NC}"
            echo "codex-agent"
            ;;
        "context_low")
            # 决定是否重启 agent
            local agent="$2"
            local ctx="$3"
            if [[ $ctx -lt 20 ]]; then
                echo -e "${YELLOW}决策: $agent context 过低 ($ctx%)，建议重启${NC}"
                echo "restart"
            else
                echo -e "${GREEN}决策: $agent context 尚可 ($ctx%)，继续工作${NC}"
                echo "continue"
            fi
            ;;
        "high_retries")
            # 决定如何处理高重试率
            local agent="$2"
            echo -e "${YELLOW}决策: $agent 重试率高，检查网络或任务复杂度${NC}"
            echo "investigate"
            ;;
        *)
            echo -e "${YELLOW}未知情况，需要人工判断${NC}"
            echo "unknown"
            ;;
    esac
}

# ============ 全面健康检查 ============
full_health_check() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    🔍 全面健康检查                                ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    local issues=()
    
    # 1. 检查 Agent 状态
    echo -e "${GREEN}1. 检查 Agent 状态...${NC}"
    for agent in claude-agent gemini-agent codex-agent; do
        local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null | tail -20)
        
        # 检查 context
        local ctx=$(echo "$output" | grep -oE "[0-9]+% context" | tail -1 | grep -oE "^[0-9]+")
        if [[ -n "$ctx" && $ctx -lt 30 ]]; then
            issues+=("$agent context 低 ($ctx%)")
        fi
        
        # 检查错误
        if echo "$output" | grep -qE "error|Error|failed" 2>/dev/null; then
            if ! echo "$output" | grep -qE "esc to cancel|esc to interrupt" 2>/dev/null; then
                issues+=("$agent 可能有错误")
            fi
        fi
        
        # 检查空闲
        if echo "$output" | grep -qE "Type your message|^❯\s*$|^›\s*$" 2>/dev/null; then
            if ! echo "$output" | grep -qE "esc to cancel|esc to interrupt" 2>/dev/null; then
                issues+=("$agent 空闲中")
            fi
        fi
    done
    echo -e "  ${GREEN}✓ 完成${NC}"
    
    # 2. 检查编译状态
    echo -e "${GREEN}2. 检查编译状态...${NC}"
    cd "$PROJECT_PATH" 2>/dev/null
    local errors=$(cargo check 2>&1 | grep -c "^error" 2>/dev/null || echo 0)
    errors=$(echo "$errors" | head -1 | tr -d ' ')
    [[ -z "$errors" ]] && errors=0
    if [[ $errors -gt 0 ]]; then
        issues+=("有 $errors 个编译错误")
    fi
    echo -e "  ${GREEN}✓ 完成 ($errors 错误)${NC}"
    
    # 3. 检查 Redis
    echo -e "${GREEN}3. 检查 Redis...${NC}"
    if ! redis-cli ping >/dev/null 2>&1; then
        issues+=("Redis 连接失败")
    fi
    echo -e "  ${GREEN}✓ 完成${NC}"
    
    # 4. 检查 Git 状态
    echo -e "${GREEN}4. 检查 Git 状态...${NC}"
    local uncommitted=$(git status --porcelain 2>/dev/null | wc -l)
    if [[ $uncommitted -gt 10 ]]; then
        issues+=("有 $uncommitted 个未提交的更改")
    fi
    echo -e "  ${GREEN}✓ 完成${NC}"
    
    echo ""
    
    # 报告问题
    if [[ ${#issues[@]} -gt 0 ]]; then
        echo -e "${RED}发现 ${#issues[@]} 个问题:${NC}"
        for issue in "${issues[@]}"; do
            echo -e "  ${YELLOW}⚠️ $issue${NC}"
        done
    else
        echo -e "${GREEN}✓ 系统健康，无问题${NC}"
    fi
    
    # 保存检查结果
    redis-cli HSET "${REDIS_PREFIX}:health" \
        "last_check" "$(date +%s)" \
        "issues_count" "${#issues[@]}" \
        "issues" "${issues[*]}" >/dev/null 2>&1
}

# ============ 智能任务分配 ============
smart_assign() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    🎯 智能任务分配                                ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # 1. 检查编译错误
    cd "$PROJECT_PATH" 2>/dev/null
    local errors=$(cargo check 2>&1 | grep -c "^error" || echo 0)
    
    if [[ $errors -gt 0 ]]; then
        echo -e "${YELLOW}发现 $errors 个编译错误，优先修复${NC}"
        
        # 找一个空闲或 context 最高的 agent
        local best_agent=""
        local best_ctx=0
        
        for agent in claude-agent gemini-agent codex-agent; do
            local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null | tail -20)
            local ctx=$(echo "$output" | grep -oE "[0-9]+% context" | tail -1 | grep -oE "^[0-9]+" || echo 50)
            
            # 检查是否空闲
            if echo "$output" | grep -qE "Type your message|^❯\s*$|^›\s*$" 2>/dev/null; then
                if ! echo "$output" | grep -qE "esc to cancel|esc to interrupt" 2>/dev/null; then
                    best_agent="$agent"
                    break
                fi
            fi
            
            if [[ $ctx -gt $best_ctx ]]; then
                best_ctx=$ctx
                best_agent="$agent"
            fi
        done
        
        if [[ -n "$best_agent" ]]; then
            echo -e "${GREEN}分配给 $best_agent${NC}"
            tmux -S "$SOCKET" send-keys -t "$best_agent" C-u
            sleep 0.3
            tmux -S "$SOCKET" send-keys -t "$best_agent" "修复编译错误，运行 cargo check 查看错误详情" Enter
        fi
        return
    fi
    
    # 2. 检查空闲 agent 并分配 i18n 任务
    for agent in claude-agent gemini-agent codex-agent; do
        local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null | tail -20)
        
        # 检查是否空闲
        if echo "$output" | grep -qE "Type your message|^❯\s*$|^›\s*$" 2>/dev/null; then
            if ! echo "$output" | grep -qE "esc to cancel|esc to interrupt" 2>/dev/null; then
                echo -e "${YELLOW}$agent 空闲，分配任务${NC}"
                
                local task=$("$WORKSPACE/scripts/task-finder.sh" next "$agent" 2>/dev/null)
                if [[ -n "$task" ]]; then
                    tmux -S "$SOCKET" send-keys -t "$agent" C-u
                    sleep 0.3
                    tmux -S "$SOCKET" send-keys -t "$agent" "$task" Enter
                    echo -e "${GREEN}已分配: $task${NC}"
                fi
            fi
        fi
    done
    
    echo ""
    echo -e "${GREEN}✓ 任务分配完成${NC}"
}

# ============ 生成进度报告 ============
generate_report() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    📋 技术总监日报                                ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "报告时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    # 项目进度
    cd "$PROJECT_PATH" 2>/dev/null
    local i18n_done=$(grep -r 't("' crates/*/src/*.rs 2>/dev/null | wc -l)
    local i18n_total=$(grep -r "\.to_string()" crates/*/src/*.rs 2>/dev/null | wc -l)
    local i18n_pct=$((i18n_done * 100 / (i18n_done + i18n_total + 1)))
    
    echo -e "${GREEN}📊 项目进度${NC}"
    echo "  i18n 完成度: $i18n_pct% ($i18n_done/$((i18n_done + i18n_total)))"
    echo ""
    
    # 今日工作
    local today_commits=$(git log --since="midnight" --oneline 2>/dev/null | wc -l)
    local today_files=$(git log --since="midnight" --stat 2>/dev/null | grep -E "^\s+[0-9]+ file" | tail -1)
    
    echo -e "${GREEN}📝 今日工作${NC}"
    echo "  提交数: $today_commits"
    echo "  文件变更: $today_files"
    echo ""
    
    # Agent 效率
    echo -e "${GREEN}👥 Agent 效率${NC}"
    for agent in claude-agent gemini-agent codex-agent; do
        local dispatched=$(redis-cli HGET "openclaw:evo:stats" "dispatched:$agent" 2>/dev/null || echo 0)
        local recovered=$(redis-cli HGET "openclaw:evo:stats" "recovered:$agent" 2>/dev/null || echo 0)
        echo "  $agent: 派发 $dispatched, 恢复 $recovered"
    done
    echo ""
    
    # 问题和建议
    echo -e "${GREEN}⚠️ 问题和建议${NC}"
    local issues=$(redis-cli HGET "${REDIS_PREFIX}:health" "issues" 2>/dev/null)
    if [[ -n "$issues" && "$issues" != "" ]]; then
        echo "  $issues"
    else
        echo "  无重大问题"
    fi
}

# ============ 自我进化检查 ============
self_evolve_check() {
    echo -e "${CYAN}🧬 自我进化检查...${NC}"
    
    # 检查是否有新的模式需要学习
    local new_errors=$(redis-cli LRANGE "openclaw:events:log" 0 50 2>/dev/null | grep -c "error\|Error\|failed")
    
    if [[ $new_errors -gt 5 ]]; then
        echo -e "${YELLOW}发现 $new_errors 个错误事件，分析模式...${NC}"
        # 这里可以添加更复杂的学习逻辑
    fi
    
    # 检查效率趋势
    local total_dispatched=$(redis-cli HGET "openclaw:evo:stats" "dispatched:total" 2>/dev/null || echo 0)
    local total_recovered=$(redis-cli HGET "openclaw:evo:stats" "recovered:total" 2>/dev/null || echo 0)
    
    if [[ $total_dispatched -gt 0 ]]; then
        local recovery_rate=$((total_recovered * 100 / total_dispatched))
        if [[ $recovery_rate -gt 30 ]]; then
            echo -e "${YELLOW}恢复率较高 ($recovery_rate%)，需要优化任务分配${NC}"
        fi
    fi
    
    echo -e "${GREEN}✓ 自我进化检查完成${NC}"
}

# ============ 主入口 ============
case "${1:-dashboard}" in
    dashboard|dash)
        show_dashboard
        ;;
    decide)
        make_decision "$2" "$3" "$4"
        ;;
    health)
        full_health_check
        ;;
    assign)
        smart_assign
        ;;
    report)
        generate_report
        ;;
    evolve)
        self_evolve_check
        ;;
    all)
        show_dashboard
        echo ""
        full_health_check
        echo ""
        smart_assign
        ;;
    *)
        echo "用法: $0 <command>"
        echo ""
        echo "命令:"
        echo "  dashboard  - 全局状态仪表盘"
        echo "  health     - 全面健康检查"
        echo "  assign     - 智能任务分配"
        echo "  report     - 生成进度报告"
        echo "  evolve     - 自我进化检查"
        echo "  all        - 执行所有检查"
        ;;
esac
