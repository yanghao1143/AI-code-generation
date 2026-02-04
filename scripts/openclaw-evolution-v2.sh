#!/bin/bash
# openclaw-evolution-v2.sh - OpenClaw 完整自我进化系统 v2
# 完整循环: 检查问题 → 分析原因 → 设计方案 → 实施修复 → 验证效果 → 总结学习 → 自我进化

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

AGENTS=("claude-agent" "gemini-agent" "codex-agent")

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

log() {
    local level="$1"
    local msg="$2"
    local timestamp=$(date '+%H:%M:%S')
    
    case "$level" in
        INFO)   echo -e "${CYAN}[$timestamp]${NC} $msg" ;;
        OK)     echo -e "${GREEN}[$timestamp] ✅${NC} $msg" ;;
        WARN)   echo -e "${YELLOW}[$timestamp] ⚠️${NC} $msg" ;;
        ERROR)  echo -e "${RED}[$timestamp] ❌${NC} $msg" ;;
        STEP)   echo -e "${MAGENTA}[$timestamp] 🔷${NC} $msg" ;;
        *)      echo -e "[$timestamp] $msg" ;;
    esac
    
    echo "- $timestamp: $msg" >> "$LOG_FILE"
}

# ═══════════════════════════════════════════════════════════════
# 阶段 1: 检查问题 (Check Problems)
# ═══════════════════════════════════════════════════════════════
step1_check_problems() {
    log STEP "═══ 阶段1: 检查问题 ═══"
    
    local problems=()
    local details=()
    
    # 编译项目获取完整输出
    log INFO "编译项目..."
    cd "$KOMA_DIR"
    local build_output=$(npm run build 2>&1)
    local build_status=$?
    
    # 保存编译输出供后续分析
    echo "$build_output" > /tmp/build_output.txt
    
    # 1. 检查编译错误
    if [[ $build_status -ne 0 ]]; then
        problems+=("编译失败")
        details+=("编译返回码: $build_status")
        log ERROR "编译失败"
    else
        log OK "编译成功"
    fi
    
    # 2. 检查循环依赖
    local circular=$(echo "$build_output" | grep "Circular chunk" | sort -u)
    local circular_count=$(echo "$circular" | grep -c "Circular" || echo 0)
    if [[ $circular_count -gt 0 ]]; then
        problems+=("循环依赖:${circular_count}个")
        details+=("$circular")
        log WARN "发现 $circular_count 个循环依赖"
    fi
    
    # 3. 检查混合导入
    local mixed=$(echo "$build_output" | grep "dynamically imported.*but also statically imported")
    local mixed_count=$(echo "$mixed" | grep -c "dynamically" || echo 0)
    if [[ $mixed_count -gt 0 ]]; then
        # 提取具体文件
        local mixed_files=$(echo "$build_output" | grep -oE "src/[^[:space:]]+" | grep -E "\.ts$" | sort -u | head -10)
        problems+=("混合导入:${mixed_count}个")
        details+=("涉及文件: $mixed_files")
        log WARN "发现 $mixed_count 个混合导入警告"
    fi
    
    # 4. 检查大文件
    local large_files=$(echo "$build_output" | grep -E "[0-9]+\.[0-9]+ kB" | awk '$1 > 1000 {print $0}')
    local large_count=$(echo "$large_files" | grep -c "kB" || echo 0)
    if [[ $large_count -gt 0 ]]; then
        problems+=("大文件:${large_count}个超过1MB")
        details+=("$large_files")
        log WARN "发现 $large_count 个大文件"
    fi
    
    # 保存问题到 Redis
    redis-cli SET openclaw:evo:problems "$(IFS=,; echo "${problems[*]}")" > /dev/null
    redis-cli SET openclaw:evo:details "$(IFS='|'; echo "${details[*]}")" > /dev/null
    
    log INFO "发现 ${#problems[@]} 个问题"
    
    # 返回问题列表
    echo "${problems[@]}"
}

# ═══════════════════════════════════════════════════════════════
# 阶段 2: 分析原因 (Analyze Root Cause)
# ═══════════════════════════════════════════════════════════════
step2_analyze_cause() {
    log STEP "═══ 阶段2: 分析原因 ═══"
    
    local problems="$1"
    local analysis=()
    
    # 读取编译输出
    local build_output=$(cat /tmp/build_output.txt 2>/dev/null)
    
    for problem in $problems; do
        case "$problem" in
            *循环依赖*)
                log INFO "分析循环依赖原因..."
                # 提取循环链
                local chains=$(echo "$build_output" | grep "Circular chunk" | sed 's/.*: //')
                analysis+=("循环依赖根因: $chains")
                
                # 分析 vite.config.ts
                local config=$(cat "$KOMA_DIR/frontend/vite.config.ts" 2>/dev/null | grep -A 50 "manualChunks")
                analysis+=("当前 manualChunks 配置可能导致循环引用")
                log INFO "根因: manualChunks 配置导致 chunk 间相互依赖"
                ;;
                
            *混合导入*)
                log INFO "分析混合导入原因..."
                # 找出问题文件
                local problem_files=$(echo "$build_output" | grep -oE "src/[^[:space:]]+\.ts" | sort | uniq -c | sort -rn | head -5)
                analysis+=("混合导入根因: 同一模块被不同文件以不同方式导入")
                analysis+=("高频问题文件: $problem_files")
                
                # 找出主要冲突源
                local main_source=$(echo "$build_output" | grep -oE "PluginAPI\.ts|index\.ts" | sort | uniq -c | sort -rn | head -1)
                analysis+=("主要冲突源: $main_source")
                log INFO "根因: PluginAPI.ts 动态导入与其他文件静态导入冲突"
                ;;
                
            *大文件*)
                log INFO "分析大文件原因..."
                local large=$(echo "$build_output" | grep -E "[0-9]+\.[0-9]+ kB" | awk '$1 > 1000')
                analysis+=("大文件根因: 第三方依赖未充分分割")
                analysis+=("具体文件: $large")
                log INFO "根因: vendor chunk 包含过多依赖"
                ;;
        esac
    done
    
    # 保存分析结果
    redis-cli SET openclaw:evo:analysis "$(IFS='|'; echo "${analysis[*]}")" > /dev/null
    
    # 记录到 PostgreSQL
    "$WORKSPACE/scripts/vector-memory.sh" add \
        "问题分析: $problems - 根因: ${analysis[*]}" \
        "analysis" 7 > /dev/null 2>&1
    
    log OK "原因分析完成"
}

# ═══════════════════════════════════════════════════════════════
# 阶段 3: 设计方案 (Design Solution)
# ═══════════════════════════════════════════════════════════════
step3_design_solution() {
    log STEP "═══ 阶段3: 设计方案 ═══"
    
    local problems="$1"
    local solutions=()
    
    for problem in $problems; do
        case "$problem" in
            *循环依赖*)
                log INFO "设计循环依赖解决方案..."
                solutions+=("方案: 合并相互依赖的 chunk 或调整 manualChunks 逻辑")
                solutions+=("具体: 将 vendor-other 和 vendor-ui 中相互依赖的部分合并")
                solutions+=("负责: Gemini (擅长配置优化)")
                ;;
                
            *混合导入*)
                log INFO "设计混合导入解决方案..."
                solutions+=("方案: 使用动态导入包装器模式")
                solutions+=("具体: 将静态导入改为 re-export 动态导入的结果")
                solutions+=("参考: timeline.ts, core.ts 的修复方式")
                solutions+=("负责: Claude (擅长代码重构)")
                ;;
                
            *大文件*)
                log INFO "设计大文件解决方案..."
                solutions+=("方案: 进一步分割 vendor chunk")
                solutions+=("具体: 按功能分离大型依赖 (antd, codemirror, xgplayer)")
                solutions+=("负责: Codex (擅长依赖分析)")
                ;;
        esac
    done
    
    # 保存方案
    redis-cli SET openclaw:evo:solutions "$(IFS='|'; echo "${solutions[*]}")" > /dev/null
    
    log OK "方案设计完成"
    
    # 显示方案
    echo ""
    log INFO "解决方案:"
    for sol in "${solutions[@]}"; do
        echo "  - $sol"
    done
}

# ═══════════════════════════════════════════════════════════════
# 阶段 4: 实施修复 (Implement Fix)
# ═══════════════════════════════════════════════════════════════
step4_implement_fix() {
    log STEP "═══ 阶段4: 实施修复 ═══"
    
    local problems="$1"
    
    # 找到空闲的 Agent
    local idle_agents=()
    for agent in "${AGENTS[@]}"; do
        local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null | tail -3)
        if echo "$output" | grep -qE "^❯\s*$|^›\s*$|Type your message"; then
            idle_agents+=("$agent")
        fi
    done
    
    log INFO "空闲 Agent: ${idle_agents[*]:-无}"
    
    if [[ ${#idle_agents[@]} -eq 0 ]]; then
        log WARN "没有空闲 Agent，等待..."
        sleep 30
        return 1
    fi
    
    # 根据方案分配任务
    local task_index=0
    for problem in $problems; do
        if [[ $task_index -ge ${#idle_agents[@]} ]]; then
            break
        fi
        
        local agent="${idle_agents[$task_index]}"
        local task=""
        
        case "$problem" in
            *循环依赖*)
                if [[ "$agent" == "gemini-agent" ]] || [[ $task_index -eq 0 ]]; then
                    task="fix circular dependency in $KOMA_DIR/frontend/vite.config.ts: merge vendor-other and vendor-ui dependencies that cause circular imports, or restructure manualChunks to avoid cycles"
                fi
                ;;
            *混合导入*)
                if [[ "$agent" == "claude-agent" ]] || [[ $task_index -eq 0 ]]; then
                    # 找出最高频的问题文件
                    local top_file=$(cat /tmp/build_output.txt | grep -oE "src/[^[:space:]]+\.ts" | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
                    task="fix mixed import conflict in $KOMA_DIR/frontend/$top_file using dynamic import wrapper pattern (like timeline.ts fix)"
                fi
                ;;
            *大文件*)
                if [[ "$agent" == "codex-agent" ]] || [[ $task_index -eq 0 ]]; then
                    task="analyze large vendor chunks in $KOMA_DIR/frontend and suggest which dependencies to split into separate chunks"
                fi
                ;;
        esac
        
        if [[ -n "$task" ]]; then
            log INFO "分配给 $agent: ${task:0:80}..."
            tmux -S "$SOCKET" send-keys -t "$agent" "$task" Enter
            ((task_index++))
            sleep 2
        fi
    done
    
    log OK "已分配 $task_index 个任务"
    
    # 等待执行
    log INFO "等待 Agent 执行 (60秒)..."
    sleep 60
}

# ═══════════════════════════════════════════════════════════════
# 阶段 5: 验证效果 (Verify Effect)
# ═══════════════════════════════════════════════════════════════
step5_verify_effect() {
    log STEP "═══ 阶段5: 验证效果 ═══"
    
    # 获取修复前的问题数
    local old_problems=$(redis-cli GET openclaw:evo:problems 2>/dev/null)
    local old_circular=$(echo "$old_problems" | grep -oE "循环依赖:[0-9]+" | grep -oE "[0-9]+" || echo 0)
    local old_mixed=$(echo "$old_problems" | grep -oE "混合导入:[0-9]+" | grep -oE "[0-9]+" || echo 0)
    
    # 重新编译验证
    log INFO "重新编译验证..."
    cd "$KOMA_DIR"
    local build_output=$(npm run build 2>&1)
    local build_status=$?
    
    # 统计新问题数
    local new_circular=$(echo "$build_output" | grep -c "Circular chunk" || echo 0)
    local new_mixed=$(echo "$build_output" | grep -c "dynamically imported.*but also statically imported" || echo 0)
    local build_time=$(echo "$build_output" | grep -oE "built in [0-9.]+s" | grep -oE "[0-9.]+" || echo 0)
    
    # 比较效果
    echo ""
    log INFO "验证结果:"
    echo "  ┌─────────────┬────────┬────────┬────────┐"
    echo "  │ 指标        │ 修复前 │ 修复后 │ 变化   │"
    echo "  ├─────────────┼────────┼────────┼────────┤"
    
    local circular_change=$((old_circular - new_circular))
    local circular_status="="
    [[ $circular_change -gt 0 ]] && circular_status="↓$circular_change"
    [[ $circular_change -lt 0 ]] && circular_status="↑${circular_change#-}"
    printf "  │ 循环依赖    │ %6s │ %6s │ %6s │\n" "$old_circular" "$new_circular" "$circular_status"
    
    local mixed_change=$((old_mixed - new_mixed))
    local mixed_status="="
    [[ $mixed_change -gt 0 ]] && mixed_status="↓$mixed_change"
    [[ $mixed_change -lt 0 ]] && mixed_status="↑${mixed_change#-}"
    printf "  │ 混合导入    │ %6s │ %6s │ %6s │\n" "$old_mixed" "$new_mixed" "$mixed_status"
    
    echo "  ├─────────────┼────────┼────────┼────────┤"
    printf "  │ 编译时间    │   -    │ %5.1fs │   -    │\n" "$build_time"
    printf "  │ 编译状态    │   -    │   %s   │   -    │\n" "$([[ $build_status -eq 0 ]] && echo '✅' || echo '❌')"
    echo "  └─────────────┴────────┴────────┴────────┘"
    
    # 判断是否有效
    local effective=false
    if [[ $circular_change -gt 0 ]] || [[ $mixed_change -gt 0 ]]; then
        effective=true
        log OK "修复有效! 减少了 $((circular_change + mixed_change)) 个问题"
    elif [[ $build_status -eq 0 ]]; then
        log WARN "问题数量未变化，但编译成功"
    else
        log ERROR "修复无效或引入新问题"
    fi
    
    # 保存验证结果
    redis-cli SET openclaw:evo:verify_result "$effective:circular=$new_circular,mixed=$new_mixed,time=$build_time" > /dev/null
    
    return $([[ "$effective" == "true" ]] && echo 0 || echo 1)
}

# ═══════════════════════════════════════════════════════════════
# 阶段 6: 总结学习 (Summarize Learning)
# ═══════════════════════════════════════════════════════════════
step6_summarize_learning() {
    log STEP "═══ 阶段6: 总结学习 ═══"
    
    # 收集 Agent 的工作成果
    local learnings=()
    
    for agent in "${AGENTS[@]}"; do
        local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p -S -50 2>/dev/null)
        
        # 提取 commit 信息
        if echo "$output" | grep -qE "Committed|commit [a-f0-9]"; then
            local commit=$(echo "$output" | grep -oE "[a-f0-9]{7}" | tail -1)
            local action=$(echo "$output" | grep -E "fix:|feat:|refactor:" | tail -1 | head -c 80)
            learnings+=("$agent: $action (commit: $commit)")
            log OK "$agent 完成: $action"
        fi
    done
    
    # 获取验证结果
    local verify=$(redis-cli GET openclaw:evo:verify_result 2>/dev/null)
    
    # 生成学习总结
    local summary="进化循环学习总结:\n"
    summary+="问题: $(redis-cli GET openclaw:evo:problems 2>/dev/null)\n"
    summary+="分析: $(redis-cli GET openclaw:evo:analysis 2>/dev/null | tr '|' '\n' | head -3)\n"
    summary+="方案: $(redis-cli GET openclaw:evo:solutions 2>/dev/null | tr '|' '\n' | head -3)\n"
    summary+="效果: $verify\n"
    summary+="成果: ${learnings[*]}"
    
    # 保存到 PostgreSQL
    "$WORKSPACE/scripts/vector-memory.sh" add \
        "$(echo -e "$summary")" \
        "learning" 8 > /dev/null 2>&1
    
    log OK "学习总结已保存"
    
    # 更新今日日志
    cat >> "$LOG_FILE" << EOF

### $(date '+%H:%M') - 进化循环学习

**问题**: $(redis-cli GET openclaw:evo:problems 2>/dev/null)
**根因**: $(redis-cli GET openclaw:evo:analysis 2>/dev/null | tr '|' '\n' | head -1)
**方案**: $(redis-cli GET openclaw:evo:solutions 2>/dev/null | tr '|' '\n' | head -1)
**效果**: $verify
**成果**: ${learnings[*]:-无}
EOF
}

# ═══════════════════════════════════════════════════════════════
# 阶段 7: 自我进化 (Self Evolution)
# ═══════════════════════════════════════════════════════════════
step7_self_evolve() {
    log STEP "═══ 阶段7: 自我进化 ═══"
    
    # 更新进化计数
    redis-cli INCR openclaw:evo:cycles > /dev/null
    local cycles=$(redis-cli GET openclaw:evo:cycles)
    redis-cli SET openclaw:evo:last_run "$(date '+%Y-%m-%d %H:%M:%S')" > /dev/null
    
    log INFO "已完成 $cycles 次进化循环"
    
    # 每 3 次循环进行深度分析
    if [[ $((cycles % 3)) -eq 0 ]]; then
        log INFO "进行深度进化分析..."
        
        # 分析问题模式
        local pattern=$("$WORKSPACE/scripts/tech-director-evolution.sh" patterns 2>/dev/null)
        
        # 生成进化报告
        "$WORKSPACE/scripts/tech-director-evolution.sh" report > "$WORKSPACE/memory/evolution-report-$(date +%Y%m%d-%H%M).md" 2>/dev/null
        
        # 压缩旧日志
        "$WORKSPACE/scripts/context-manager.sh" cleanup > /dev/null 2>&1
        
        log OK "深度分析完成"
    fi
    
    # 检查是否需要调整策略
    local verify=$(redis-cli GET openclaw:evo:verify_result 2>/dev/null)
    if [[ "$verify" == "false:"* ]]; then
        log WARN "上次修复无效，需要调整策略"
        # 记录失败经验
        "$WORKSPACE/scripts/vector-memory.sh" add \
            "进化失败经验: 修复无效，需要重新分析问题或更换方案" \
            "evolution" 7 > /dev/null 2>&1
    fi
    
    log OK "自我进化完成"
}

# ═══════════════════════════════════════════════════════════════
# 完整进化循环
# ═══════════════════════════════════════════════════════════════
full_cycle() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║           🧬 OpenClaw 完整自我进化循环 v2                        ║"
    echo "║           $(date '+%Y-%m-%d %H:%M:%S')                                     ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "  检查问题 → 分析原因 → 设计方案 → 实施修复 → 验证效果 → 总结学习 → 自我进化"
    echo "      ↑                                                          ↓"
    echo "      └────────────────────── 循环 ←─────────────────────────────┘"
    echo ""
    
    # 阶段 1
    local problems=$(step1_check_problems)
    echo ""
    
    if [[ -z "$problems" ]]; then
        log OK "没有发现问题，跳过后续步骤"
        return 0
    fi
    
    # 阶段 2
    step2_analyze_cause "$problems"
    echo ""
    
    # 阶段 3
    step3_design_solution "$problems"
    echo ""
    
    # 阶段 4
    step4_implement_fix "$problems"
    echo ""
    
    # 阶段 5
    step5_verify_effect
    echo ""
    
    # 阶段 6
    step6_summarize_learning
    echo ""
    
    # 阶段 7
    step7_self_evolve
    echo ""
    
    echo "═══════════════════════════════════════════════════════════════════"
    echo "进化循环完成! 运行 '$0 status' 查看状态"
    echo "═══════════════════════════════════════════════════════════════════"
}

# ═══════════════════════════════════════════════════════════════
# 状态报告
# ═══════════════════════════════════════════════════════════════
status() {
    echo "=== 🧬 OpenClaw 进化系统状态 v2 ==="
    echo ""
    
    echo "📊 进化统计:"
    echo "  循环次数: $(redis-cli GET openclaw:evo:cycles 2>/dev/null || echo 0)"
    echo "  上次运行: $(redis-cli GET openclaw:evo:last_run 2>/dev/null || echo '从未')"
    echo ""
    
    echo "📋 当前问题:"
    echo "  $(redis-cli GET openclaw:evo:problems 2>/dev/null || echo '无')"
    echo ""
    
    echo "🔍 上次分析:"
    redis-cli GET openclaw:evo:analysis 2>/dev/null | tr '|' '\n' | head -3 | while read line; do
        echo "  - $line"
    done
    echo ""
    
    echo "💡 上次方案:"
    redis-cli GET openclaw:evo:solutions 2>/dev/null | tr '|' '\n' | head -3 | while read line; do
        echo "  - $line"
    done
    echo ""
    
    echo "✅ 上次验证:"
    echo "  $(redis-cli GET openclaw:evo:verify_result 2>/dev/null || echo '无')"
    echo ""
    
    echo "📚 知识库:"
    echo "  总记忆: $(psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT COUNT(*) FROM memories;")"
    echo "  学习经验: $(psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT COUNT(*) FROM memories WHERE category='learning';")"
    echo "  分析记录: $(psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT COUNT(*) FROM memories WHERE category='analysis';")"
}

# ═══════════════════════════════════════════════════════════════
# 主入口
# ═══════════════════════════════════════════════════════════════
case "$1" in
    cycle)
        full_cycle
        ;;
    check)
        step1_check_problems
        ;;
    analyze)
        step2_analyze_cause "$(redis-cli GET openclaw:evo:problems)"
        ;;
    design)
        step3_design_solution "$(redis-cli GET openclaw:evo:problems)"
        ;;
    implement)
        step4_implement_fix "$(redis-cli GET openclaw:evo:problems)"
        ;;
    verify)
        step5_verify_effect
        ;;
    learn)
        step6_summarize_learning
        ;;
    evolve)
        step7_self_evolve
        ;;
    status)
        status
        ;;
    *)
        echo "🧬 OpenClaw 完整自我进化系统 v2"
        echo ""
        echo "用法: $0 <command>"
        echo ""
        echo "命令:"
        echo "  cycle     - 运行完整 7 步进化循环"
        echo "  check     - 步骤1: 检查问题"
        echo "  analyze   - 步骤2: 分析原因"
        echo "  design    - 步骤3: 设计方案"
        echo "  implement - 步骤4: 实施修复"
        echo "  verify    - 步骤5: 验证效果"
        echo "  learn     - 步骤6: 总结学习"
        echo "  evolve    - 步骤7: 自我进化"
        echo "  status    - 查看状态"
        echo ""
        echo "完整进化循环:"
        echo "  检查问题 → 分析原因 → 设计方案 → 实施修复 → 验证效果 → 总结学习 → 自我进化"
        echo "      ↑                                                          ↓"
        echo "      └────────────────────── 循环 ←─────────────────────────────┘"
        ;;
esac
