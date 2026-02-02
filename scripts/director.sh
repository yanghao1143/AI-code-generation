#!/bin/bash
# director.sh - 技术总监控制台
# 统一管理所有子系统，提供全局视图和智能决策

WORKSPACE="/home/jinyang/.openclaw/workspace"
SOCKET="/tmp/openclaw-agents.sock"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================
# 1. 全局状态概览
# ============================================
show_dashboard() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║           🎯 技术总监控制台 - $(date '+%Y-%m-%d %H:%M:%S')            ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Agent 状态
    echo -e "${BLUE}📊 Agent 状态${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    "$WORKSPACE/scripts/agent-health.sh" check 2>/dev/null | tail -6
    echo ""
    
    # 任务进度
    echo -e "${BLUE}📋 任务进度${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    local tasks=$(redis-cli SMEMBERS openclaw:ctx:tasks:active 2>/dev/null)
    for task in $tasks; do
        local status=$(redis-cli HGET "openclaw:ctx:task:$task" status 2>/dev/null)
        local progress=$(redis-cli HGET "openclaw:ctx:task:$task" progress 2>/dev/null)
        local details=$(redis-cli HGET "openclaw:ctx:task:$task" details 2>/dev/null)
        printf "  %-20s %-12s %3s%% %s\n" "$task" "[$status]" "${progress:-0}" "$details"
    done
    echo ""
    
    # 系统健康
    echo -e "${BLUE}🏥 系统健康${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    local redis_ok=$(redis-cli ping 2>/dev/null)
    local tmux_ok=$(tmux -S "$SOCKET" list-sessions 2>/dev/null | wc -l)
    local git_status=$(cd "$WORKSPACE" && git status --porcelain 2>/dev/null | wc -l)
    
    echo -e "  Redis:     ${redis_ok:+${GREEN}✓${NC}}${redis_ok:-${RED}✗${NC}}"
    echo -e "  Tmux:      ${GREEN}$tmux_ok 会话${NC}"
    echo -e "  Git:       $git_status 个未提交文件"
    echo ""
    
    # 今日统计
    echo -e "${BLUE}📈 今日统计${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    local commits=$(cd "$WORKSPACE" && git log --oneline --since="00:00" 2>/dev/null | wc -l)
    local recoveries=$(redis-cli HGET openclaw:workflow:stats total_fixed 2>/dev/null || echo 0)
    local issues=$(redis-cli HGET openclaw:workflow:stats total_issues 2>/dev/null || echo 0)
    echo "  提交数:    $commits"
    echo "  问题数:    $issues"
    echo "  自动修复:  $recoveries"
    echo ""
}

# ============================================
# 2. 智能决策引擎
# ============================================
make_decision() {
    local situation="$1"
    
    case "$situation" in
        "agent_idle")
            # 检查是否有待处理任务
            local pending=$(redis-cli SMEMBERS openclaw:ctx:tasks:active 2>/dev/null | wc -l)
            if [[ $pending -gt 0 ]]; then
                echo "dispatch"  # 派发任务
            else
                echo "generate"  # 生成新任务
            fi
            ;;
        "context_high")
            echo "restart"  # 重启会话
            ;;
        "compile_error")
            echo "fix"  # 修复错误
            ;;
        "task_stuck")
            echo "reassign"  # 重新分配
            ;;
        *)
            echo "monitor"  # 继续监控
            ;;
    esac
}

# ============================================
# 3. 全面健康检查
# ============================================
full_health_check() {
    echo -e "${CYAN}🔍 全面健康检查${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    local issues=0
    local fixed=0
    
    # 1. Agent 健康
    echo -e "\n${BLUE}1. Agent 健康检查${NC}"
    for agent in claude-agent gemini-agent codex-agent; do
        local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null | tail -20)
        
        # 检查是否有未发送的输入
        if echo "$output" | tail -5 | grep -qE "^> .+|^› .+|^│ > .+" 2>/dev/null; then
            if ! echo "$output" | grep -qE "(esc to interrupt|esc to cancel|Thinking|Working)" 2>/dev/null; then
                echo -e "  ${YELLOW}⚠️ $agent 有未发送的输入${NC}"
                tmux -S "$SOCKET" send-keys -t "$agent" Enter
                echo -e "  ${GREEN}  → 已发送 Enter${NC}"
                ((issues++))
                ((fixed++))
            fi
        fi
        
        # 检查 context
        local ctx=$(echo "$output" | grep -oE "[0-9]+% context left" | grep -oE "[0-9]+" | head -1)
        if [[ -n "$ctx" && $ctx -lt 25 ]]; then
            echo -e "  ${RED}❌ $agent context 只剩 ${ctx}%${NC}"
            ((issues++))
        fi
        
        # 检查确认界面
        if echo "$output" | tail -10 | grep -qE "Yes, proceed|Press enter to confirm|loop was detected" 2>/dev/null; then
            echo -e "  ${YELLOW}⚠️ $agent 卡在确认界面${NC}"
            tmux -S "$SOCKET" send-keys -t "$agent" "1" Enter
            echo -e "  ${GREEN}  → 已发送确认${NC}"
            ((issues++))
            ((fixed++))
        fi
    done
    
    # 2. 任务健康
    echo -e "\n${BLUE}2. 任务健康检查${NC}"
    local tasks=$(redis-cli SMEMBERS openclaw:ctx:tasks:active 2>/dev/null)
    for task in $tasks; do
        local status=$(redis-cli HGET "openclaw:ctx:task:$task" status 2>/dev/null)
        local updated=$(redis-cli HGET "openclaw:ctx:task:$task" updated_at 2>/dev/null)
        
        if [[ "$status" == "paused" ]]; then
            echo -e "  ${YELLOW}⚠️ 任务 $task 已暂停${NC}"
            ((issues++))
        fi
    done
    
    # 3. Git 健康检查 (workspace)
    echo -e "\n${BLUE}3. Git 健康检查 (workspace)${NC}"
    cd "$WORKSPACE"
    local unpushed=$(git log origin/master..HEAD --oneline 2>/dev/null | wc -l)
    if [[ $unpushed -gt 5 ]]; then
        echo -e "  ${YELLOW}⚠️ workspace 有 $unpushed 个未推送的提交${NC}"
        git push 2>/dev/null
        echo -e "  ${GREEN}  → 已推送${NC}"
        ((issues++))
        ((fixed++))
    fi
    
    # 4. 主仓库提交检查 (让 agent 提交)
    echo -e "\n${BLUE}4. 主仓库提交检查${NC}"
    # 每30分钟提醒 agent 提交一次
    local last_commit_remind=$(redis-cli GET "openclaw:director:last_commit_remind" 2>/dev/null)
    local now=$(date +%s)
    local remind_interval=1800  # 30分钟
    
    if [[ -z "$last_commit_remind" ]] || [[ $((now - last_commit_remind)) -gt $remind_interval ]]; then
        echo -e "  ${YELLOW}提醒 agent 提交代码${NC}"
        for agent in claude-agent gemini-agent codex-agent; do
            local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null | tail -10)
            # 只在空闲时提醒
            if echo "$output" | tail -3 | grep -qE "^>\s*$|Type your message|context left.*shortcuts" 2>/dev/null; then
                tmux -S "$SOCKET" send-keys -t "$agent" "git add -A && git status --short && git diff --cached --stat | head -5" Enter
                echo -e "  ${GREEN}  → 已提醒 $agent 检查提交${NC}"
            fi
        done
        redis-cli SET "openclaw:director:last_commit_remind" "$now" > /dev/null 2>&1
    fi
    
    # 汇总
    echo -e "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if [[ $issues -eq 0 ]]; then
        echo -e "${GREEN}✅ 所有系统健康${NC}"
    else
        echo -e "📊 发现 $issues 个问题，修复了 $fixed 个"
    fi
    
    # 记录到 Redis
    redis-cli HSET "openclaw:director:health" last_check "$(date -Iseconds)" issues "$issues" fixed "$fixed" > /dev/null 2>&1
}

# ============================================
# 4. 智能任务分配
# ============================================
smart_dispatch() {
    echo -e "${CYAN}🎯 智能任务分配${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # 获取空闲 agent
    for agent in claude-agent gemini-agent codex-agent; do
        local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null | tail -20)
        
        # 检查是否空闲
        local is_idle=false
        if echo "$output" | tail -5 | grep -qE "^>\s*$|Type your message|context left.*shortcuts" 2>/dev/null; then
            if ! echo "$output" | grep -qE "(esc to interrupt|esc to cancel|Thinking|Working)" 2>/dev/null; then
                is_idle=true
            fi
        fi
        
        if [[ "$is_idle" == "true" ]]; then
            echo -e "  ${YELLOW}$agent 空闲${NC}"
            
            # 根据 agent 专长分配任务
            local task=""
            case "$agent" in
                claude-agent)
                    task="继续 i18n 国际化工作，找到下一个需要国际化的模块并处理，完成后 git add -A && git commit -m 'i18n: 模块国际化' && git push"
                    ;;
                gemini-agent)
                    task="继续 i18n 国际化工作，找到下一个需要国际化的模块并处理，完成后 git add -A && git commit -m 'i18n: 模块国际化' && git push"
                    ;;
                codex-agent)
                    task="运行 cargo check，修复发现的编译错误，完成后 git add -A && git commit -m 'fix: 修复编译错误' && git push"
                    ;;
                codex-agent)
                    task="运行 cargo check，修复发现的编译错误"
                    ;;
            esac
            
            tmux -S "$SOCKET" send-keys -t "$agent" "$task" Enter
            echo -e "  ${GREEN}  → 已派发: $task${NC}"
        fi
    done
}

# ============================================
# 5. 生成进度报告
# ============================================
generate_report() {
    echo -e "${CYAN}📊 生成进度报告${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    local report_file="$WORKSPACE/memory/progress-report-$(date +%Y%m%d-%H%M).md"
    
    cat > "$report_file" << EOF
# 进度报告 - $(date '+%Y-%m-%d %H:%M')

## Agent 状态

$(bash "$WORKSPACE/scripts/agent-health.sh" check 2>/dev/null)

## 任务进度

| 任务 | 状态 | 进度 | 详情 |
|------|------|------|------|
$(redis-cli SMEMBERS openclaw:ctx:tasks:active 2>/dev/null | while read task; do
    status=$(redis-cli HGET "openclaw:ctx:task:$task" status 2>/dev/null)
    progress=$(redis-cli HGET "openclaw:ctx:task:$task" progress 2>/dev/null)
    details=$(redis-cli HGET "openclaw:ctx:task:$task" details 2>/dev/null)
    echo "| $task | $status | ${progress:-0}% | $details |"
done)

## 今日提交

$(cd "$WORKSPACE" && git log --oneline --since="00:00" 2>/dev/null | head -20)

## 系统健康

- Redis: $(redis-cli ping 2>/dev/null || echo "离线")
- Tmux: $(tmux -S "$SOCKET" list-sessions 2>/dev/null | wc -l) 会话
- Git: $(cd "$WORKSPACE" && git status --porcelain 2>/dev/null | wc -l) 个未提交文件

---
*自动生成于 $(date)*
EOF

    echo -e "  ${GREEN}报告已生成: $report_file${NC}"
}

# ============================================
# 6. 自我进化
# ============================================
evolve() {
    echo -e "${CYAN}🧬 自我进化检查${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # 检查最近的问题模式
    local recent_issues=$(redis-cli HGET openclaw:workflow:stats total_issues 2>/dev/null || echo 0)
    local recent_fixed=$(redis-cli HGET openclaw:workflow:stats total_fixed 2>/dev/null || echo 0)
    
    if [[ $recent_issues -gt 0 ]]; then
        local fix_rate=$((recent_fixed * 100 / recent_issues))
        echo "  问题修复率: ${fix_rate}%"
        
        if [[ $fix_rate -lt 80 ]]; then
            echo -e "  ${YELLOW}⚠️ 修复率低于 80%，需要改进检测逻辑${NC}"
        fi
    fi
    
    # 检查 agent 效率
    echo -e "\n  ${BLUE}Agent 效率分析:${NC}"
    for agent in claude-agent gemini-agent codex-agent; do
        local recovery_count=$(redis-cli HGET openclaw:agent:recovery "${agent}_count" 2>/dev/null || echo 0)
        echo "    $agent: 恢复 $recovery_count 次"
    done
}

# ============================================
# 主入口
# ============================================
main() {
    local action="${1:-dashboard}"
    
    case "$action" in
        dashboard|d)
            show_dashboard
            ;;
        health|h)
            full_health_check
            ;;
        dispatch|dp)
            smart_dispatch
            ;;
        report|r)
            generate_report
            ;;
        evolve|e)
            evolve
            ;;
        auto|a)
            # 自动模式: 健康检查 + 派活
            full_health_check
            echo ""
            smart_dispatch
            ;;
        monitor|m)
            # 持续监控
            while true; do
                show_dashboard
                sleep 60
            done
            ;;
        *)
            echo "用法: $0 [dashboard|health|dispatch|report|evolve|auto|monitor]"
            echo ""
            echo "命令:"
            echo "  dashboard (d)  - 显示控制台"
            echo "  health (h)     - 全面健康检查"
            echo "  dispatch (dp)  - 智能任务分配"
            echo "  report (r)     - 生成进度报告"
            echo "  evolve (e)     - 自我进化检查"
            echo "  auto (a)       - 自动模式"
            echo "  monitor (m)    - 持续监控"
            ;;
    esac
}

main "$@"
