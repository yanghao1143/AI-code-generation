#!/bin/bash
# evolution-loop.sh - 持续进化循环
# 自动检查问题 → 分配任务 → 验证修复 → 总结学习

WORKSPACE="/home/jinyang/.openclaw/workspace"
SOCKET="/tmp/openclaw-agents.sock"
LOG_FILE="$WORKSPACE/memory/$(date +%Y-%m-%d).md"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "[$(date '+%H:%M:%S')] $1"
    echo "- $(date '+%H:%M'): $1" >> "$LOG_FILE"
}

# ============ 1. 检查阶段 ============
check_issues() {
    log "${YELLOW}🔍 检查系统问题...${NC}"
    
    local issues=()
    
    # 检查 TypeScript 编译
    cd /home/jinyang/Koma
    local build_result=$(npm run build 2>&1)
    if echo "$build_result" | grep -q "error"; then
        issues+=("TypeScript编译错误")
    fi
    
    # 检查 bundle 大小
    if echo "$build_result" | grep -q "larger than 500 kB"; then
        issues+=("Bundle过大警告")
    fi
    
    # 检查 Agent 状态
    for agent in claude-agent gemini-agent codex-agent; do
        local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null | tail -5)
        if echo "$output" | grep -qE "error|Error|failed|Failed"; then
            issues+=("$agent 有错误")
        fi
    done
    
    echo "${issues[@]}"
}

# ============ 2. 分配阶段 ============
dispatch_fix() {
    local issue="$1"
    local agent="$2"
    local task="$3"
    
    log "${GREEN}📤 分配任务: $issue → $agent${NC}"
    
    tmux -S "$SOCKET" send-keys -t "$agent" "$task" Enter
    
    # 记录到 PostgreSQL
    PGPASSWORD=openclaw123 psql -h localhost -U openclaw -d openclaw -q \
        -c "INSERT INTO tasks (task_id, title, description, status, priority) 
            VALUES ('$(date +%s)', '$issue', '$task', 'assigned', 7);"
}

# ============ 3. 验证阶段 ============
verify_fix() {
    local issue="$1"
    
    log "${YELLOW}✅ 验证修复: $issue${NC}"
    
    # 重新编译检查
    cd /home/jinyang/Koma
    local result=$(npm run build 2>&1 | tail -5)
    
    if echo "$result" | grep -q "built in"; then
        log "${GREEN}✅ $issue 已修复${NC}"
        return 0
    else
        log "${RED}❌ $issue 未修复${NC}"
        return 1
    fi
}

# ============ 4. 学习阶段 ============
learn_from_fix() {
    local issue="$1"
    local solution="$2"
    
    log "${GREEN}📚 记录学习经验: $issue${NC}"
    
    # 保存到 PostgreSQL
    "$WORKSPACE/scripts/vector-memory.sh" add \
        "问题修复经验: $issue - 解决方案: $solution" \
        "learning" 8
    
    # 更新 Redis
    redis-cli LPUSH openclaw:learnings "$issue: $solution" > /dev/null
}

# ============ 主循环 ============
evolution_cycle() {
    log "🔄 开始进化循环..."
    
    # 1. 检查
    local issues=$(check_issues)
    
    if [[ -z "$issues" ]]; then
        log "${GREEN}✅ 没有发现问题${NC}"
        return 0
    fi
    
    log "发现问题: $issues"
    
    # 2. 分配 (根据问题类型选择 Agent)
    for issue in $issues; do
        case "$issue" in
            *编译*|*TypeScript*)
                dispatch_fix "$issue" "claude-agent" "fix TypeScript compilation errors"
                ;;
            *Bundle*|*bundle*)
                dispatch_fix "$issue" "codex-agent" "optimize bundle size"
                ;;
            *)
                dispatch_fix "$issue" "gemini-agent" "investigate and fix: $issue"
                ;;
        esac
    done
    
    # 3. 等待修复
    log "⏳ 等待 Agent 完成修复 (60s)..."
    sleep 60
    
    # 4. 验证
    for issue in $issues; do
        if verify_fix "$issue"; then
            learn_from_fix "$issue" "自动修复成功"
        fi
    done
    
    log "🔄 进化循环完成"
}

# ============ 状态报告 ============
status_report() {
    echo "=== 📊 进化状态报告 ==="
    echo ""
    
    echo "🤖 Agent 状态:"
    for agent in claude-agent gemini-agent codex-agent; do
        local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null | tail -3)
        if echo "$output" | grep -qE "esc to interrupt|Working"; then
            echo "  $agent: 🟢 工作中"
        elif echo "$output" | grep -qE "^❯|^›|Type your"; then
            echo "  $agent: 🟡 空闲"
        else
            echo "  $agent: 🔵 处理中"
        fi
    done
    
    echo ""
    echo "📊 问题统计:"
    echo "  紧急: $(redis-cli GET openclaw:issues:urgent 2>/dev/null | tr ',' '\n' | wc -l)"
    echo "  中等: $(redis-cli GET openclaw:issues:medium 2>/dev/null | tr ',' '\n' | wc -l)"
    echo "  已解决: $(redis-cli GET openclaw:issues:resolved 2>/dev/null | tr ',' '\n' | wc -l)"
    
    echo ""
    echo "📚 学习记录:"
    echo "  总数: $(PGPASSWORD=openclaw123 psql -h localhost -U openclaw -d openclaw -t -A -c "SELECT COUNT(*) FROM memories WHERE category='learning';")"
}

case "$1" in
    cycle)
        evolution_cycle
        ;;
    check)
        check_issues
        ;;
    status)
        status_report
        ;;
    *)
        echo "🧬 持续进化循环"
        echo ""
        echo "用法: $0 <command>"
        echo ""
        echo "命令:"
        echo "  cycle   - 运行一次进化循环 (检查→分配→验证→学习)"
        echo "  check   - 只检查问题"
        echo "  status  - 查看状态报告"
        ;;
esac
