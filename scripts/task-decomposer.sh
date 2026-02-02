#!/bin/bash
# task-decomposer.sh - 智能任务分解器
# 将大任务自动分解为小任务

WORKSPACE="/home/jinyang/.openclaw/workspace"
REDIS_PREFIX="openclaw:decompose"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# 分解 i18n 任务
decompose_i18n() {
    local module="$1"
    
    echo -e "${CYAN}分解 i18n 任务: $module${NC}"
    echo ""
    
    local subtasks=()
    
    # 1. 分析模块
    subtasks+=("分析 $module 模块，找出所有硬编码的英文字符串")
    
    # 2. 创建翻译键
    subtasks+=("为 $module 创建翻译键，添加到 locales 文件")
    
    # 3. 替换字符串
    subtasks+=("将 $module 中的硬编码字符串替换为 t() 调用")
    
    # 4. 测试
    subtasks+=("运行 cargo check 验证 $module 的修改")
    
    # 5. 提交
    subtasks+=("提交 $module 的国际化修改")
    
    echo -e "${GREEN}子任务:${NC}"
    local i=1
    for task in "${subtasks[@]}"; do
        echo "  $i. $task"
        ((i++))
    done
    
    # 保存到 Redis
    redis-cli DEL "${REDIS_PREFIX}:i18n:${module}" >/dev/null
    for task in "${subtasks[@]}"; do
        redis-cli RPUSH "${REDIS_PREFIX}:i18n:${module}" "$task" >/dev/null
    done
    
    echo ""
    echo -e "${YELLOW}已保存 ${#subtasks[@]} 个子任务${NC}"
}

# 分解 bugfix 任务
decompose_bugfix() {
    local bug_desc="$1"
    
    echo -e "${CYAN}分解 bugfix 任务: $bug_desc${NC}"
    echo ""
    
    local subtasks=()
    
    # 1. 复现
    subtasks+=("复现问题: $bug_desc")
    
    # 2. 定位
    subtasks+=("定位问题根因")
    
    # 3. 修复
    subtasks+=("实现修复方案")
    
    # 4. 测试
    subtasks+=("验证修复，确保不引入新问题")
    
    # 5. 提交
    subtasks+=("提交修复")
    
    echo -e "${GREEN}子任务:${NC}"
    local i=1
    for task in "${subtasks[@]}"; do
        echo "  $i. $task"
        ((i++))
    done
}

# 分解 feature 任务
decompose_feature() {
    local feature_desc="$1"
    
    echo -e "${CYAN}分解 feature 任务: $feature_desc${NC}"
    echo ""
    
    local subtasks=()
    
    # 1. 设计
    subtasks+=("设计功能架构: $feature_desc")
    
    # 2. 接口
    subtasks+=("定义接口和数据结构")
    
    # 3. 实现
    subtasks+=("实现核心逻辑")
    
    # 4. UI
    subtasks+=("实现用户界面")
    
    # 5. 测试
    subtasks+=("编写测试用例")
    
    # 6. 文档
    subtasks+=("更新文档")
    
    echo -e "${GREEN}子任务:${NC}"
    local i=1
    for task in "${subtasks[@]}"; do
        echo "  $i. $task"
        ((i++))
    done
}

# 智能分解 - 自动检测任务类型
smart_decompose() {
    local task="$1"
    
    # 检测任务类型
    if echo "$task" | grep -qiE "国际化|i18n|翻译|localize" 2>/dev/null; then
        local module=$(echo "$task" | grep -oE "crates/[a-z_]+" | head -1)
        [[ -z "$module" ]] && module="unknown"
        decompose_i18n "$module"
    elif echo "$task" | grep -qiE "修复|fix|bug|错误" 2>/dev/null; then
        decompose_bugfix "$task"
    elif echo "$task" | grep -qiE "功能|feature|新增|添加" 2>/dev/null; then
        decompose_feature "$task"
    else
        echo -e "${YELLOW}无法自动识别任务类型，请指定:${NC}"
        echo "  $0 i18n <module>"
        echo "  $0 bugfix <description>"
        echo "  $0 feature <description>"
    fi
}

# 获取下一个子任务
get_next_subtask() {
    local task_key="$1"
    
    local next=$(redis-cli LPOP "${REDIS_PREFIX}:${task_key}" 2>/dev/null)
    
    if [[ -n "$next" ]]; then
        echo "$next"
    else
        echo "(无更多子任务)"
    fi
}

# 主入口
case "${1:-help}" in
    i18n)
        decompose_i18n "$2"
        ;;
    bugfix)
        decompose_bugfix "$2"
        ;;
    feature)
        decompose_feature "$2"
        ;;
    smart)
        smart_decompose "$2"
        ;;
    next)
        get_next_subtask "$2"
        ;;
    *)
        echo "用法: $0 <command> [args...]"
        echo ""
        echo "命令:"
        echo "  i18n <module>       - 分解 i18n 任务"
        echo "  bugfix <desc>       - 分解 bugfix 任务"
        echo "  feature <desc>      - 分解 feature 任务"
        echo "  smart <task>        - 智能分解"
        echo "  next <task_key>     - 获取下一个子任务"
        ;;
esac
