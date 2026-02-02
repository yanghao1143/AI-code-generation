#!/bin/bash
# task-finder.sh - 智能任务发现器
# 自动从项目中发现需要做的任务

WORKSPACE="/home/jinyang/.openclaw/workspace"
PROJECT_PATH="/mnt/d/ai软件/zed"
REDIS_PREFIX="openclaw:tasks"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# 发现未国际化的模块
find_i18n_tasks() {
    cd "$PROJECT_PATH" || return
    
    echo -e "${CYAN}🔍 发现未国际化的模块:${NC}"
    
    for crate_dir in "$PROJECT_PATH"/crates/*/; do
        local crate_name=$(basename "$crate_dir")
        [[ ! -d "$crate_dir/src" ]] && continue
        
        local total=$(grep -r "\.to_string()" "$crate_dir/src" 2>/dev/null | wc -l)
        local i18n=$(grep -r 't("' "$crate_dir/src" 2>/dev/null | wc -l)
        
        [[ $total -eq 0 ]] && continue
        
        local percent=$((i18n * 100 / (total + i18n + 1)))
        
        # 只显示进度低于 50% 的模块
        if [[ $percent -lt 50 ]]; then
            echo -e "  ${YELLOW}$crate_name${NC}: $percent% ($i18n/$((total + i18n)))"
        fi
    done | sort -t: -k2 -n | head -10
}

# 发现编译错误
find_compile_errors() {
    cd "$PROJECT_PATH" || return
    
    echo -e "${CYAN}🔍 检查编译错误:${NC}"
    
    local errors=$(cargo check 2>&1 | grep -E "^error\[E[0-9]+\]" | head -5)
    
    if [[ -n "$errors" ]]; then
        echo -e "${RED}发现编译错误:${NC}"
        echo "$errors" | while read -r line; do
            echo "  $line"
        done
    else
        echo -e "  ${GREEN}✓ 无编译错误${NC}"
    fi
}

# 发现 TODO/FIXME
find_todos() {
    cd "$PROJECT_PATH" || return
    
    echo -e "${CYAN}🔍 发现 TODO/FIXME:${NC}"
    
    grep -rn "TODO\|FIXME\|XXX\|HACK" crates/*/src/*.rs 2>/dev/null | head -10 | while read -r line; do
        local file=$(echo "$line" | cut -d: -f1)
        local num=$(echo "$line" | cut -d: -f2)
        local content=$(echo "$line" | cut -d: -f3-)
        echo -e "  ${YELLOW}$file:$num${NC}: ${content:0:60}..."
    done
}

# 发现未使用的代码
find_dead_code() {
    cd "$PROJECT_PATH" || return
    
    echo -e "${CYAN}🔍 检查未使用代码 (clippy):${NC}"
    
    local warnings=$(cargo clippy 2>&1 | grep -E "warning:.*unused|warning:.*dead_code" | head -5)
    
    if [[ -n "$warnings" ]]; then
        echo "$warnings" | while read -r line; do
            echo "  $line"
        done
    else
        echo -e "  ${GREEN}✓ 无明显未使用代码${NC}"
    fi
}

# 生成任务建议
suggest_tasks() {
    local agent="${1:-any}"
    
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    💡 任务建议 for $agent                         ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    case "$agent" in
        claude-agent)
            # Claude 擅长: 重构、算法、后端
            echo -e "${GREEN}推荐任务 (Claude 专长):${NC}"
            echo "  1. 重构复杂函数"
            echo "  2. 优化算法性能"
            echo "  3. 代码审查"
            ;;
        gemini-agent)
            # Gemini 擅长: 前端、UI、架构
            echo -e "${GREEN}推荐任务 (Gemini 专长):${NC}"
            echo "  1. 国际化 UI 组件"
            echo "  2. 改进用户界面"
            echo "  3. 架构设计"
            ;;
        codex-agent)
            # Codex 擅长: 测试、修复、清理
            echo -e "${GREEN}推荐任务 (Codex 专长):${NC}"
            echo "  1. 编写测试用例"
            echo "  2. 修复编译错误"
            echo "  3. 代码清理"
            ;;
        *)
            echo -e "${GREEN}通用任务:${NC}"
            ;;
    esac
    
    echo ""
    find_i18n_tasks
    echo ""
}

# 获取下一个任务
get_next_task() {
    local agent="${1:-any}"
    
    cd "$PROJECT_PATH" || return
    
    # 1. 先检查编译错误
    local errors=$(cargo check 2>&1 | grep -c "^error")
    if [[ $errors -gt 0 ]]; then
        echo "修复 $errors 个编译错误"
        return
    fi
    
    # 2. 找进度最低的 i18n 模块
    local lowest_module=""
    local lowest_percent=100
    
    for crate_dir in "$PROJECT_PATH"/crates/*/; do
        local crate_name=$(basename "$crate_dir")
        [[ ! -d "$crate_dir/src" ]] && continue
        
        local total=$(grep -r "\.to_string()" "$crate_dir/src" 2>/dev/null | wc -l)
        local i18n=$(grep -r 't("' "$crate_dir/src" 2>/dev/null | wc -l)
        
        [[ $total -eq 0 ]] && continue
        
        local percent=$((i18n * 100 / (total + i18n + 1)))
        
        if [[ $percent -lt $lowest_percent ]]; then
            lowest_percent=$percent
            lowest_module=$crate_name
        fi
    done
    
    if [[ -n "$lowest_module" && $lowest_percent -lt 80 ]]; then
        echo "国际化 crates/$lowest_module 模块 (当前进度 $lowest_percent%)"
        return
    fi
    
    # 3. 默认任务
    echo "继续国际化工作，检查未完成的模块"
}

# 主入口
case "${1:-suggest}" in
    i18n)
        find_i18n_tasks
        ;;
    errors|compile)
        find_compile_errors
        ;;
    todos)
        find_todos
        ;;
    dead)
        find_dead_code
        ;;
    suggest)
        suggest_tasks "$2"
        ;;
    next)
        get_next_task "$2"
        ;;
    all)
        find_i18n_tasks
        echo ""
        find_compile_errors
        echo ""
        find_todos
        ;;
    *)
        echo "用法: $0 <command> [agent]"
        echo ""
        echo "命令:"
        echo "  suggest [agent]  - 任务建议"
        echo "  next [agent]     - 获取下一个任务"
        echo "  i18n             - 发现未国际化模块"
        echo "  errors           - 检查编译错误"
        echo "  todos            - 发现 TODO/FIXME"
        echo "  dead             - 检查未使用代码"
        echo "  all              - 全部检查"
        ;;
esac
