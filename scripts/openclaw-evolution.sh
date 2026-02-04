#!/bin/bash
# openclaw-evolution.sh - OpenClaw 自我进化系统
# 完整循环: 检查问题 → 分配任务 → 验证修复 → 总结学习 → 自我进化

WORKSPACE="/home/jinyang/.openclaw/workspace"
SOCKET="/tmp/openclaw-agents.sock"
LOG_FILE="$WORKSPACE/memory/$(date +%Y-%m-%d).md"
KOMA_DIR="/home/jinyang/Koma"

# 数据库配置
DB_HOST="localhost"
DB_USER="openclaw"
DB_PASS="openclaw123"
DB_NAME="openclaw"
export PGPASSWORD="$DB_PASS"

# Agent 配置
AGENTS=("claude-agent" "gemini-agent" "codex-agent")

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log() {
    local level="$1"
    local msg="$2"
    local timestamp=$(date '+%H:%M:%S')
    
    case "$level" in
        INFO)  echo -e "${CYAN}[$timestamp]${NC} $msg" ;;
        OK)    echo -e "${GREEN}[$timestamp] ✅${NC} $msg" ;;
        WARN)  echo -e "${YELLOW}[$timestamp] ⚠️${NC} $msg" ;;
        ERROR) echo -e "${RED}[$timestamp] ❌${NC} $msg" ;;
        *)     echo -e "[$timestamp] $msg" ;;
    esac
    
    echo "- $timestamp: $msg" >> "$LOG_FILE"
}

# ═══════════════════════════════════════════════════════════════
# 阶段 1: 检查问题
# ═══════════════════════════════════════════════════════════════
check_problems() {
    log INFO "🔍 阶段1: 检查问题..."
    
    local problems=()
    
    # 1. 检查 TypeScript 编译
    log INFO "检查 TypeScript 编译..."
    cd "$KOMA_DIR"
    local build_output=$(npm run build 2>&1)
    
    if echo "$build_output" | grep -q "error TS"; then
        problems+=("TypeScript编译错误")
        log ERROR "TypeScript 编译有错误"
    else
        log OK "TypeScript 编译通过"
    fi
    
    # 2. 检查循环依赖
    if echo "$build_output" | grep -q "Circular chunk"; then
        local circular_count=$(echo "$build_output" | grep -c "Circular chunk")
        problems+=("循环依赖:${circular_count}个")
        log WARN "发现 $circular_count 个循环依赖"
    fi
    
    # 3. 检查 Bundle 大小
    local large_chunks=$(echo "$build_output" | grep -E "[0-9]+\.[0-9]+ kB" | awk '$1 > 500 {print $1}' | wc -l)
    if [[ $large_chunks -gt 3 ]]; then
        problems+=("Bundle过大:${large_chunks}个大文件")
        log WARN "有 $large_chunks 个 chunk 超过 500KB"
    fi
    
    # 4. 检查混合导入警告
    local mixed_imports=$(echo "$build_output" | grep -c "dynamically imported.*but also statically imported")
    if [[ $mixed_imports -gt 0 ]]; then
        problems+=("混合导入:${mixed_imports}个")
        log WARN "发现 $mixed_imports 个混合导入警告"
    fi
    
    # 5. 检查 Agent 状态
    for agent in "${AGENTS[@]}"; do
        local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null | tail -5)
        if echo "$output" | grep -qE "error|Error|failed|Failed"; then
            problems+=("${agent}有错误")
            log ERROR "$agent 有错误"
        fi
    done
    
    # 保存问题到 Redis
    if [[ ${#problems[@]} -gt 0 ]]; then
        redis-cli SET openclaw:evolution:problems "$(IFS=,; echo "${problems[*]}")" > /dev/null
        log INFO "发现 ${#problems[@]} 个问题: ${problems[*]}"
    else
        redis-cli DEL openclaw:evolution:problems > /dev/null
        log OK "没有发现问题"
    fi
    
    echo "${problems[@]}"
}

# ═══════════════════════════════════════════════════════════════
# 阶段 2: 分配任务
# ═══════════════════════════════════════════════════════════════
dispatch_tasks() {
    log INFO "📤 阶段2: 分配任务..."
    
    local problems="$1"
    
    if [[ -z "$problems" ]]; then
        log OK "没有问题需要处理"
        return 0
    fi
    
    # 找到空闲的 Agent
    local idle_agents=()
    for agent in "${AGENTS[@]}"; do
        local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null | tail -3)
        if echo "$output" | grep -qE "^❯\s*$|^›\s*$|Type your message"; then
            idle_agents+=("$agent")
        fi
    done
    
    log INFO "空闲 Agent: ${idle_agents[*]:-无}"
    
    # 根据问题类型分配任务
    local task_index=0
    for problem in $problems; do
        if [[ $task_index -ge ${#idle_agents[@]} ]]; then
            log WARN "没有足够的空闲 Agent"
            break
        fi
        
        local agent="${idle_agents[$task_index]}"
        local task=""
        
        case "$problem" in
            *循环依赖*)
                task="fix circular chunk dependencies in $KOMA_DIR/frontend/vite.config.ts - merge vendor-react and vendor-antd into vendor-ui"
                ;;
            *混合导入*)
                task="fix mixed import conflicts in $KOMA_DIR/frontend/src - use dynamic import wrapper pattern"
                ;;
            *TypeScript*)
                task="fix TypeScript compilation errors in $KOMA_DIR"
                ;;
            *Bundle*)
                task="optimize bundle size in $KOMA_DIR/frontend - split large chunks"
                ;;
            *)
                task="investigate and fix: $problem"
                ;;
        esac
        
        log INFO "分配给 $agent: $task"
        tmux -S "$SOCKET" send-keys -t "$agent" "$task" Enter
        
        # 记录任务
        psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -q \
            -c "INSERT INTO tasks (task_id, title, description, status, priority) 
                VALUES ('evo_$(date +%s)_$task_index', '$problem', '$task', 'assigned', 7);"
        
        ((task_index++))
        sleep 2
    done
    
    log OK "已分配 $task_index 个任务"
}

# ═══════════════════════════════════════════════════════════════
# 阶段 3: 验证修复
# ═══════════════════════════════════════════════════════════════
verify_fixes() {
    log INFO "✅ 阶段3: 验证修复..."
    
    # 等待 Agent 完成
    log INFO "等待 Agent 完成 (60秒)..."
    sleep 60
    
    # 重新检查问题
    local new_problems=$(check_problems)
    local old_problems=$(redis-cli GET openclaw:evolution:problems 2>/dev/null)
    
    # 比较问题数量
    local old_count=$(echo "$old_problems" | tr ',' '\n' | grep -c .)
    local new_count=$(echo "$new_problems" | wc -w)
    
    if [[ $new_count -lt $old_count ]]; then
        local fixed=$((old_count - new_count))
        log OK "修复了 $fixed 个问题"
        return 0
    elif [[ $new_count -eq 0 ]]; then
        log OK "所有问题已修复"
        return 0
    else
        log WARN "还有 $new_count 个问题未修复"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════
# 阶段 4: 总结学习
# ═══════════════════════════════════════════════════════════════
summarize_learning() {
    log INFO "📚 阶段4: 总结学习..."
    
    # 收集 Agent 的工作成果
    local learnings=""
    
    for agent in "${AGENTS[@]}"; do
        local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p -S -50 2>/dev/null)
        
        # 提取关键信息
        if echo "$output" | grep -qE "Committed|commit|Created|Fixed|Updated"; then
            local commit=$(echo "$output" | grep -oE "[a-f0-9]{7}" | tail -1)
            local action=$(echo "$output" | grep -E "Committed|Created|Fixed|Updated" | tail -1 | head -c 100)
            learnings+="$agent: $action (commit: $commit)\n"
            log OK "$agent 完成: $action"
        fi
    done
    
    # 保存学习经验到 PostgreSQL
    if [[ -n "$learnings" ]]; then
        "$WORKSPACE/scripts/vector-memory.sh" add \
            "进化循环学习: $(echo -e "$learnings")" \
            "evolution" 8
        log OK "学习经验已保存"
    fi
    
    # 更新 Redis 统计
    redis-cli INCR openclaw:evolution:cycles > /dev/null
    redis-cli SET openclaw:evolution:last_run "$(date '+%Y-%m-%d %H:%M:%S')" > /dev/null
}

# ═══════════════════════════════════════════════════════════════
# 阶段 5: 自我进化
# ═══════════════════════════════════════════════════════════════
self_evolve() {
    log INFO "🧬 阶段5: 自我进化..."
    
    # 分析问题模式
    local pattern_analysis=$("$WORKSPACE/scripts/tech-director-evolution.sh" patterns 2>/dev/null)
    
    # 检查是否需要更新脚本
    local cycles=$(redis-cli GET openclaw:evolution:cycles 2>/dev/null || echo 0)
    
    if [[ $cycles -gt 0 ]] && [[ $((cycles % 5)) -eq 0 ]]; then
        log INFO "每 5 个循环进行一次深度进化分析..."
        
        # 生成进化报告
        "$WORKSPACE/scripts/tech-director-evolution.sh" report > "$WORKSPACE/memory/evolution-report-$(date +%Y%m%d).md"
        
        # 压缩旧日志
        "$WORKSPACE/scripts/context-manager.sh" cleanup
        
        log OK "深度进化分析完成"
    fi
    
    # 更新 MEMORY.md 中的问题状态
    local resolved=$(redis-cli GET openclaw:issues:resolved 2>/dev/null | tr ',' '\n' | grep -c .)
    local urgent=$(redis-cli GET openclaw:issues:urgent 2>/dev/null | tr ',' '\n' | grep -c .)
    
    log OK "进化状态: 已解决 $resolved 个, 紧急 $urgent 个"
}

# ═══════════════════════════════════════════════════════════════
# 完整进化循环
# ═══════════════════════════════════════════════════════════════
evolution_cycle() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║           🧬 OpenClaw 自我进化循环                               ║"
    echo "║           $(date '+%Y-%m-%d %H:%M:%S')                                     ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo ""
    
    # 阶段 1: 检查问题
    local problems=$(check_problems)
    echo ""
    
    # 阶段 2: 分配任务
    dispatch_tasks "$problems"
    echo ""
    
    # 阶段 3: 验证修复
    verify_fixes
    echo ""
    
    # 阶段 4: 总结学习
    summarize_learning
    echo ""
    
    # 阶段 5: 自我进化
    self_evolve
    echo ""
    
    echo "═══════════════════════════════════════════════════════════════════"
    echo "进化循环完成。下次运行: ./scripts/openclaw-evolution.sh cycle"
    echo "═══════════════════════════════════════════════════════════════════"
}

# ═══════════════════════════════════════════════════════════════
# 状态报告
# ═══════════════════════════════════════════════════════════════
status() {
    echo "=== 🧬 OpenClaw 进化系统状态 ==="
    echo ""
    
    echo "📊 进化统计:"
    echo "  循环次数: $(redis-cli GET openclaw:evolution:cycles 2>/dev/null || echo 0)"
    echo "  上次运行: $(redis-cli GET openclaw:evolution:last_run 2>/dev/null || echo '从未')"
    echo ""
    
    echo "🤖 Agent 状态:"
    for agent in "${AGENTS[@]}"; do
        local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null | tail -3)
        if echo "$output" | grep -qE "esc to interrupt|Working"; then
            echo "  $agent: 🟢 工作中"
        elif echo "$output" | grep -qE "^❯\s*$|^›\s*$|Type your"; then
            echo "  $agent: 🟡 空闲"
        else
            echo "  $agent: 🔵 处理中"
        fi
    done
    echo ""
    
    echo "📊 问题统计:"
    echo "  当前问题: $(redis-cli GET openclaw:evolution:problems 2>/dev/null || echo '无')"
    echo "  紧急: $(redis-cli GET openclaw:issues:urgent 2>/dev/null | tr ',' '\n' | grep -c .)"
    echo "  已解决: $(redis-cli GET openclaw:issues:resolved 2>/dev/null | tr ',' '\n' | grep -c .)"
    echo ""
    
    echo "📚 知识库:"
    echo "  总记忆: $(psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT COUNT(*) FROM memories;")"
    echo "  学习经验: $(psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT COUNT(*) FROM memories WHERE category='learning';")"
    echo "  进化记录: $(psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT COUNT(*) FROM memories WHERE category='evolution';")"
}

# ═══════════════════════════════════════════════════════════════
# 主入口
# ═══════════════════════════════════════════════════════════════
case "$1" in
    cycle)
        evolution_cycle
        ;;
    check)
        check_problems
        ;;
    dispatch)
        dispatch_tasks "$(redis-cli GET openclaw:evolution:problems 2>/dev/null)"
        ;;
    verify)
        verify_fixes
        ;;
    learn)
        summarize_learning
        ;;
    evolve)
        self_evolve
        ;;
    status)
        status
        ;;
    *)
        echo "🧬 OpenClaw 自我进化系统"
        echo ""
        echo "用法: $0 <command>"
        echo ""
        echo "命令:"
        echo "  cycle    - 运行完整进化循环"
        echo "  check    - 只检查问题"
        echo "  dispatch - 分配任务给 Agent"
        echo "  verify   - 验证修复结果"
        echo "  learn    - 总结学习经验"
        echo "  evolve   - 自我进化"
        echo "  status   - 查看状态"
        echo ""
        echo "进化循环流程:"
        echo "  检查问题 → 分配任务 → 验证修复 → 总结学习 → 自我进化"
        echo "      ↑                                        ↓"
        echo "      └────────────── 循环 ←──────────────────┘"
        ;;
esac
