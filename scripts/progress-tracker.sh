#!/bin/bash
# progress-tracker.sh - 项目进度追踪和可视化
# 追踪 i18n 进度、任务完成率、agent 贡献

WORKSPACE="/home/jinyang/.openclaw/workspace"
PROJECT_PATH="/mnt/d/ai软件/zed"
REDIS_PREFIX="openclaw:progress"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m'

# 进度条
progress_bar() {
    local current=$1
    local total=$2
    local width=40
    local percent=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    printf "["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "] %3d%% (%d/%d)" "$percent" "$current" "$total"
}

# 统计 i18n 进度
count_i18n_progress() {
    cd "$PROJECT_PATH" || return
    
    # 统计已国际化的字符串
    local total_strings=$(grep -r "\.to_string()" crates/*/src/*.rs 2>/dev/null | wc -l)
    local i18n_strings=$(grep -r 't("' crates/*/src/*.rs 2>/dev/null | wc -l)
    
    # 统计各模块
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    📊 i18n 进度报告                               ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "统计时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    echo -e "${GREEN}总体进度:${NC}"
    echo -n "  "
    progress_bar "$i18n_strings" "$((total_strings + i18n_strings))"
    echo ""
    echo ""
    
    echo -e "${YELLOW}各模块进度:${NC}"
    
    for crate_dir in "$PROJECT_PATH"/crates/*/; do
        local crate_name=$(basename "$crate_dir")
        [[ ! -d "$crate_dir/src" ]] && continue
        
        local crate_total=$(grep -r "\.to_string()" "$crate_dir/src" 2>/dev/null | wc -l)
        local crate_i18n=$(grep -r 't("' "$crate_dir/src" 2>/dev/null | wc -l)
        
        # 只显示有内容的模块
        [[ $crate_total -eq 0 && $crate_i18n -eq 0 ]] && continue
        
        local total=$((crate_total + crate_i18n))
        [[ $total -eq 0 ]] && continue
        
        local percent=$((crate_i18n * 100 / total))
        
        # 颜色编码
        local color=$RED
        [[ $percent -ge 30 ]] && color=$YELLOW
        [[ $percent -ge 70 ]] && color=$GREEN
        
        printf "  %-25s " "$crate_name"
        echo -ne "${color}"
        progress_bar "$crate_i18n" "$total"
        echo -e "${NC}"
    done
    
    # 保存到 Redis
    redis-cli HSET "${REDIS_PREFIX}:i18n" \
        "total" "$total_strings" \
        "done" "$i18n_strings" \
        "updated_at" "$(date +%s)" >/dev/null
}

# 统计任务完成情况
count_task_progress() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    📋 任务完成统计                                ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    local completed=$(redis-cli SCARD "openclaw:tasks:completed" 2>/dev/null || echo 0)
    local in_progress=$(redis-cli SCARD "openclaw:tasks:active" 2>/dev/null || echo 0)
    local pending=$(redis-cli ZCARD "openclaw:pq:tasks" 2>/dev/null || echo 0)
    local total=$((completed + in_progress + pending))
    
    echo -e "${GREEN}任务统计:${NC}"
    echo -e "  已完成: ${GREEN}$completed${NC}"
    echo -e "  进行中: ${YELLOW}$in_progress${NC}"
    echo -e "  待处理: ${BLUE}$pending${NC}"
    echo -e "  总计:   $total"
    echo ""
    
    if [[ $total -gt 0 ]]; then
        echo -n "  完成率: "
        progress_bar "$completed" "$total"
        echo ""
    fi
}

# 统计 agent 贡献
count_agent_contributions() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    👥 Agent 贡献统计                              ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    for agent in claude-agent gemini-agent codex-agent; do
        local tasks=$(redis-cli GET "openclaw:stats:${agent}:tasks_completed" 2>/dev/null || echo 0)
        local files=$(redis-cli GET "openclaw:stats:${agent}:files_modified" 2>/dev/null || echo 0)
        local errors=$(redis-cli GET "openclaw:stats:${agent}:errors_fixed" 2>/dev/null || echo 0)
        
        echo -e "${YELLOW}$agent:${NC}"
        echo -e "  完成任务: $tasks"
        echo -e "  修改文件: $files"
        echo -e "  修复错误: $errors"
        echo ""
    done
}

# Git 统计
count_git_stats() {
    cd "$PROJECT_PATH" || return
    
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    📈 Git 统计                                    ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # 今日提交
    local today_commits=$(git log --since="midnight" --oneline 2>/dev/null | wc -l)
    echo -e "今日提交: ${GREEN}$today_commits${NC}"
    
    # 未提交的修改
    local staged=$(git diff --cached --stat 2>/dev/null | tail -1)
    local unstaged=$(git diff --stat 2>/dev/null | tail -1)
    
    echo -e "暂存区: $staged"
    echo -e "工作区: $unstaged"
    echo ""
    
    # 最近 5 个提交
    echo -e "${YELLOW}最近提交:${NC}"
    git log --oneline -5 2>/dev/null | while read -r line; do
        echo "  $line"
    done
}

# 生成完整报告
full_report() {
    count_i18n_progress
    echo ""
    count_task_progress
    echo ""
    count_agent_contributions
    echo ""
    count_git_stats
}

# 快速摘要
quick_summary() {
    cd "$PROJECT_PATH" || return
    
    local i18n_done=$(grep -r 't("' crates/*/src/*.rs 2>/dev/null | wc -l)
    local i18n_total=$(grep -r "\.to_string()" crates/*/src/*.rs 2>/dev/null | wc -l)
    local tasks_done=$(redis-cli SCARD "openclaw:tasks:completed" 2>/dev/null || echo 0)
    local tasks_pending=$(redis-cli ZCARD "openclaw:pq:tasks" 2>/dev/null || echo 0)
    local today_commits=$(git log --since="midnight" --oneline 2>/dev/null | wc -l)
    
    echo -e "${CYAN}📊 快速摘要${NC}"
    echo -e "  i18n: $i18n_done/$((i18n_done + i18n_total)) | 任务: $tasks_done 完成, $tasks_pending 待处理 | 今日提交: $today_commits"
}

# 主入口
case "${1:-summary}" in
    i18n)
        count_i18n_progress
        ;;
    tasks)
        count_task_progress
        ;;
    agents)
        count_agent_contributions
        ;;
    git)
        count_git_stats
        ;;
    full|report)
        full_report
        ;;
    summary)
        quick_summary
        ;;
    *)
        echo "用法: $0 <command>"
        echo ""
        echo "命令:"
        echo "  summary  - 快速摘要 (默认)"
        echo "  i18n     - i18n 进度"
        echo "  tasks    - 任务完成统计"
        echo "  agents   - Agent 贡献统计"
        echo "  git      - Git 统计"
        echo "  full     - 完整报告"
        ;;
esac
