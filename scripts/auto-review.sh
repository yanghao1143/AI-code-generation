#!/bin/bash
# auto-review.sh - 自动代码审查系统
# 在 agent 完成任务后自动审查代码质量

WORKSPACE="/home/jinyang/.openclaw/workspace"
SOCKET="/tmp/openclaw-agents.sock"
REDIS_PREFIX="openclaw:review"
PROJECT_PATH="/mnt/d/ai软件/zed"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# 获取最近修改的文件
get_recent_changes() {
    local minutes="${1:-30}"
    cd "$PROJECT_PATH" || return
    
    # 获取最近修改的 Rust 文件
    find . -name "*.rs" -mmin -"$minutes" -type f 2>/dev/null | head -20
}

# 快速代码检查
quick_check() {
    local file="$1"
    local issues=()
    
    # 检查 unwrap 使用
    local unwrap_count=$(grep -c "\.unwrap()" "$file" 2>/dev/null || echo 0)
    [[ $unwrap_count -gt 5 ]] && issues+=("过多 unwrap ($unwrap_count)")
    
    # 检查 TODO/FIXME
    local todo_count=$(grep -cE "TODO|FIXME|XXX|HACK" "$file" 2>/dev/null || echo 0)
    [[ $todo_count -gt 0 ]] && issues+=("有 $todo_count 个 TODO/FIXME")
    
    # 检查超长行
    local long_lines=$(awk 'length > 120' "$file" 2>/dev/null | wc -l)
    [[ $long_lines -gt 5 ]] && issues+=("$long_lines 行超过 120 字符")
    
    # 检查空的 catch
    local empty_catch=$(grep -c "catch.*{}" "$file" 2>/dev/null || echo 0)
    [[ $empty_catch -gt 0 ]] && issues+=("$empty_catch 个空 catch")
    
    if [[ ${#issues[@]} -gt 0 ]]; then
        echo "${issues[*]}"
    else
        echo "OK"
    fi
}

# 运行 cargo check
run_cargo_check() {
    cd "$PROJECT_PATH" || return
    
    echo -e "${CYAN}运行 cargo check...${NC}"
    local output=$(cargo check 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        echo -e "${GREEN}✓ 编译通过${NC}"
        return 0
    else
        local error_count=$(echo "$output" | grep -c "^error")
        local warning_count=$(echo "$output" | grep -c "^warning")
        echo -e "${RED}✗ 编译失败: $error_count 错误, $warning_count 警告${NC}"
        
        # 保存错误到 Redis
        redis-cli SET "${REDIS_PREFIX}:last_errors" "$output" EX 3600 >/dev/null
        return 1
    fi
}

# 运行 clippy
run_clippy() {
    cd "$PROJECT_PATH" || return
    
    echo -e "${CYAN}运行 clippy...${NC}"
    local output=$(cargo clippy 2>&1 | head -100)
    local warning_count=$(echo "$output" | grep -c "^warning")
    
    echo -e "${YELLOW}Clippy 警告: $warning_count${NC}"
    
    # 保存到 Redis
    redis-cli SET "${REDIS_PREFIX}:clippy" "$output" EX 3600 >/dev/null
    
    return 0
}

# 审查报告
generate_review_report() {
    local minutes="${1:-30}"
    
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    📝 代码审查报告                                ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "审查时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "检查范围: 最近 ${minutes} 分钟修改的文件"
    echo ""
    
    # 获取修改的文件
    local files=$(get_recent_changes "$minutes")
    
    if [[ -z "$files" ]]; then
        echo -e "${GREEN}✓ 没有最近修改的文件${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}修改的文件:${NC}"
    local total_issues=0
    
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        local result=$(quick_check "$PROJECT_PATH/$file")
        if [[ "$result" == "OK" ]]; then
            echo -e "  ${GREEN}✓${NC} $file"
        else
            echo -e "  ${RED}✗${NC} $file: $result"
            ((total_issues++))
        fi
    done <<< "$files"
    
    echo ""
    
    # 编译检查
    run_cargo_check
    local compile_ok=$?
    
    echo ""
    
    # 总结
    echo -e "${CYAN}总结:${NC}"
    if [[ $compile_ok -eq 0 && $total_issues -eq 0 ]]; then
        echo -e "  ${GREEN}✓ 代码质量良好${NC}"
    else
        [[ $compile_ok -ne 0 ]] && echo -e "  ${RED}✗ 编译失败，需要修复${NC}"
        [[ $total_issues -gt 0 ]] && echo -e "  ${YELLOW}⚠ 发现 $total_issues 个代码问题${NC}"
    fi
    
    # 保存报告
    local report_id="review-$(date +%Y%m%d-%H%M%S)"
    redis-cli HSET "${REDIS_PREFIX}:${report_id}" \
        "timestamp" "$(date +%s)" \
        "files_checked" "$(echo "$files" | wc -l)" \
        "issues" "$total_issues" \
        "compile_ok" "$compile_ok" >/dev/null
    
    redis-cli SET "${REDIS_PREFIX}:latest" "$report_id" >/dev/null
}

# 自动审查 - 检测变更并审查
auto_review() {
    local last_check=$(redis-cli GET "${REDIS_PREFIX}:last_check" 2>/dev/null)
    local now=$(date +%s)
    
    # 如果 5 分钟内检查过，跳过
    if [[ -n "$last_check" ]]; then
        local diff=$((now - last_check))
        if [[ $diff -lt 300 ]]; then
            echo "最近已检查过 (${diff}s ago)，跳过"
            return 0
        fi
    fi
    
    # 检查是否有新的修改
    local recent_files=$(get_recent_changes 10)
    if [[ -z "$recent_files" ]]; then
        echo "没有最近修改，跳过审查"
        return 0
    fi
    
    # 运行审查
    generate_review_report 10
    
    # 更新检查时间
    redis-cli SET "${REDIS_PREFIX}:last_check" "$now" >/dev/null
}

# 获取上次审查结果
get_last_review() {
    local report_id=$(redis-cli GET "${REDIS_PREFIX}:latest" 2>/dev/null)
    
    if [[ -z "$report_id" ]]; then
        echo "没有审查记录"
        return
    fi
    
    echo -e "${CYAN}上次审查: $report_id${NC}"
    redis-cli HGETALL "${REDIS_PREFIX}:${report_id}" 2>/dev/null
}

# 主入口
case "${1:-report}" in
    report)
        generate_review_report "${2:-30}"
        ;;
    auto)
        auto_review
        ;;
    check)
        run_cargo_check
        ;;
    clippy)
        run_clippy
        ;;
    last)
        get_last_review
        ;;
    files)
        get_recent_changes "${2:-30}"
        ;;
    *)
        echo "用法: $0 <command> [args...]"
        echo ""
        echo "命令:"
        echo "  report [minutes]  - 生成审查报告 (默认 30 分钟)"
        echo "  auto              - 自动审查 (有变更时)"
        echo "  check             - 运行 cargo check"
        echo "  clippy            - 运行 clippy"
        echo "  last              - 查看上次审查结果"
        echo "  files [minutes]   - 列出最近修改的文件"
        ;;
esac
