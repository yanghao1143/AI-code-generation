#!/bin/bash
# task-decomposer.sh - 智能任务分解器
# 功能: 将大任务分解成可执行的小任务

WORKSPACE="/home/jinyang/.openclaw/workspace"
REDIS_PREFIX="openclaw:tasks"

# 任务模板
declare -A TASK_TEMPLATES=(
    # 国际化任务模板
    ["i18n"]='
        1. 扫描 {module} 模块的硬编码字符串
        2. 提取字符串到 i18n 文件
        3. 替换硬编码为 t() 调用
        4. 运行 cargo check 验证
        5. 提交代码
    '
    # Bug 修复模板
    ["bugfix"]='
        1. 复现问题
        2. 定位根因
        3. 编写修复代码
        4. 编写测试用例
        5. 运行测试验证
        6. 提交代码
    '
    # 功能开发模板
    ["feature"]='
        1. 分析需求
        2. 设计方案
        3. 实现核心逻辑
        4. 编写测试
        5. 集成测试
        6. 文档更新
        7. 提交代码
    '
    # 重构模板
    ["refactor"]='
        1. 分析现有代码
        2. 设计重构方案
        3. 逐步重构
        4. 保持测试通过
        5. 代码审查
        6. 提交代码
    '
)

# 分解任务
decompose() {
    local task="$1"
    local type="$2"
    local module="${3:-}"
    
    local template="${TASK_TEMPLATES[$type]}"
    
    if [[ -z "$template" ]]; then
        echo "❌ 未知任务类型: $type"
        echo "支持的类型: i18n, bugfix, feature, refactor"
        return 1
    fi
    
    # 替换变量
    template="${template//\{module\}/$module}"
    template="${template//\{task\}/$task}"
    
    echo "📋 任务分解: $task"
    echo "类型: $type"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "$template"
}

# 创建子任务
create_subtasks() {
    local parent_task="$1"
    local type="$2"
    local module="${3:-}"
    
    local template="${TASK_TEMPLATES[$type]}"
    
    if [[ -z "$template" ]]; then
        echo "❌ 未知任务类型: $type"
        return 1
    fi
    
    # 替换变量
    template="${template//\{module\}/$module}"
    
    # 解析步骤并创建子任务
    local step_num=0
    while IFS= read -r line; do
        # 跳过空行
        [[ -z "${line// }" ]] && continue
        
        # 提取步骤内容
        local step=$(echo "$line" | sed 's/^[[:space:]]*[0-9]*\.[[:space:]]*//')
        [[ -z "$step" ]] && continue
        
        ((step_num++))
        
        # 确定 agent
        local agent="any"
        case "$step" in
            *扫描*|*分析*|*设计*) agent="gemini-agent" ;;
            *测试*|*验证*|*check*) agent="codex-agent" ;;
            *实现*|*编写*|*替换*) agent="claude-agent" ;;
        esac
        
        # 确定优先级
        local priority="default"
        case "$step" in
            *复现*|*定位*) priority="bug" ;;
            *测试*) priority="test" ;;
            *提交*) priority="cleanup" ;;
        esac
        
        # 添加到队列
        "$WORKSPACE/scripts/priority-queue.sh" add "$step (来自: $parent_task)" "$priority" "$agent"
        
    done <<< "$template"
    
    echo "✅ 已创建 $step_num 个子任务"
}

# 智能分解 (根据任务内容自动判断类型)
smart_decompose() {
    local task="$1"
    
    local type="default"
    local module=""
    
    # 自动检测类型
    if echo "$task" | grep -qiE "国际化|i18n|中文化|翻译"; then
        type="i18n"
        # 提取模块名
        module=$(echo "$task" | grep -oE "crates/[a-z_]+" | head -1)
    elif echo "$task" | grep -qiE "bug|修复|fix|错误"; then
        type="bugfix"
    elif echo "$task" | grep -qiE "功能|feature|新增|添加"; then
        type="feature"
    elif echo "$task" | grep -qiE "重构|refactor|优化"; then
        type="refactor"
    fi
    
    echo "🔍 自动检测: 类型=$type, 模块=$module"
    create_subtasks "$task" "$type" "$module"
}

# 入口
case "${1:-help}" in
    decompose)
        decompose "$2" "$3" "$4"
        ;;
    create)
        create_subtasks "$2" "$3" "$4"
        ;;
    smart)
        smart_decompose "$2"
        ;;
    *)
        echo "用法: $0 {decompose|create|smart}"
        echo ""
        echo "  decompose <task> <type> [module]  - 显示任务分解"
        echo "  create <task> <type> [module]     - 创建子任务到队列"
        echo "  smart <task>                      - 智能分解并创建子任务"
        echo ""
        echo "类型: i18n, bugfix, feature, refactor"
        ;;
esac
