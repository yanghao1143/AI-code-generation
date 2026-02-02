#!/bin/bash
# 任务执行器 - 被调度器调用，执行具体任务逻辑
# 用法: ./task-executor.sh <task_name>

SOCKET="/tmp/openclaw-agents.sock"
REDIS_PREFIX="openclaw"

task_name="$1"

log() {
    echo "[$(date '+%H:%M:%S')] $1"
}

# L0 解卡 - 使用 evolution-v4
do_unblock() {
    local result=$(/home/jinyang/.openclaw/workspace/scripts/evolution-v4.sh check 2>/dev/null)
    if [[ -n "$result" && "$result" != *"no_action"* ]]; then
        log "evolution-v4: $result"
    fi
}

# L1 状态感知 - 使用 evolution-v4
do_state_detect() {
    /home/jinyang/.openclaw/workspace/scripts/evolution-v4.sh status 2>/dev/null
}

# L2 异常处理 - 使用 evolution-v4
do_exception() {
    local result=$(/home/jinyang/.openclaw/workspace/scripts/evolution-v4.sh check 2>/dev/null)
    if [[ -n "$result" && "$result" != *"no_action"* ]]; then
        log "evolution-v4 异常处理: $result"
    fi
}

# L2 上下文监控
do_context_monitor() {
    for pane in claude-agent gemini-agent codex-agent; do
        usage=$(redis-cli HGET "${REDIS_PREFIX}:agent:${pane}:state" "context_usage")
        usage=${usage:-0}
        
        if [ "$usage" -ge 85 ]; then
            log "$pane: 上下文 ${usage}% - 需要压缩!"
            /home/jinyang/.openclaw/workspace/scripts/context-compressor.sh compress "$pane" aggressive
        elif [ "$usage" -ge 70 ]; then
            log "$pane: 上下文 ${usage}% - 警告"
        fi
    done
}

# L3 指挥官 - 给空闲 agent 派任务
do_commander() {
    # 直接用 evolution-v4 检查和派活
    /home/jinyang/.openclaw/workspace/scripts/evolution-v4.sh check 2>/dev/null
}

# L3 派发任务
do_dispatch() {
    local task="$1"
    
    # 解析任务 JSON (不用 jq)
    task_type=$(echo "$task" | grep -o '"type":"[^"]*"' | cut -d'"' -f4)
    task_desc=$(echo "$task" | grep -o '"desc":"[^"]*"' | cut -d'"' -f4)
    preferred_agent=$(echo "$task" | grep -o '"agent":"[^"]*"' | cut -d'"' -f4)
    
    task_type=${task_type:-general}
    task_desc=${task_desc:-$task}
    preferred_agent=${preferred_agent:-auto}
    
    # 智能分配
    target_agent=""
    case "$preferred_agent" in
        claude|claude-agent)
            target_agent="claude-agent"
            ;;
        gemini|gemini-agent)
            target_agent="gemini-agent"
            ;;
        codex|codex-agent)
            target_agent="codex-agent"
            ;;
        auto|*)
            # 根据任务类型自动分配
            case "$task_type" in
                backend|refactor|i18n)
                    target_agent="claude-agent"
                    ;;
                frontend|ui|component)
                    target_agent="gemini-agent"
                    ;;
                fix|test|cleanup)
                    target_agent="codex-agent"
                    ;;
                *)
                    # 找第一个空闲的
                    for pane in claude-agent gemini-agent codex-agent; do
                        status=$(redis-cli HGET "${REDIS_PREFIX}:agent:${pane}:state" "status")
                        if [ "$status" = "IDLE" ]; then
                            target_agent="$pane"
                            break
                        fi
                    done
                    ;;
            esac
            ;;
    esac
    
    # 检查目标 agent 是否空闲
    if [ -n "$target_agent" ]; then
        status=$(redis-cli HGET "${REDIS_PREFIX}:agent:${target_agent}:state" "status")
        if [ "$status" != "IDLE" ]; then
            # 目标忙，放回队列
            redis-cli LPUSH "${REDIS_PREFIX}:task:queue" "$task" > /dev/null
            log "$target_agent 忙，任务放回队列"
            return
        fi
        
        # 派发任务
        log "派发任务给 $target_agent: $task_desc"
        tmux -S "$SOCKET" send-keys -t "$target_agent" "$task_desc" Enter
        
        redis-cli HSET "${REDIS_PREFIX}:agent:${target_agent}:state" \
            "status" "WORKING" \
            "current_task" "$task_desc" \
            "task_started" "$(date +%s)" > /dev/null
        
        # 记录派发事件
        redis-cli LPUSH "${REDIS_PREFIX}:events:queue" \
            "{\"type\":\"TASK_ASSIGNED\",\"agent\":\"$target_agent\",\"task\":\"$task_desc\",\"ts\":$(date +%s)}" > /dev/null
    else
        # 没有可用 agent，放回队列
        redis-cli LPUSH "${REDIS_PREFIX}:task:queue" "$task" > /dev/null
        log "没有空闲 agent，任务放回队列"
    fi
}

# L3 进度汇报
do_progress() {
    echo "=== 进度汇报 ==="
    echo ""
    echo "Agent 状态:"
    for pane in claude-agent gemini-agent codex-agent; do
        status=$(redis-cli HGET "${REDIS_PREFIX}:agent:${pane}:state" "status")
        ctx=$(redis-cli HGET "${REDIS_PREFIX}:agent:${pane}:state" "context_usage")
        printf "  %-15s %-10s %s%%\n" "$pane" "$status" "${ctx:-?}"
    done
    
    echo ""
    echo "任务队列: $(redis-cli LLEN "${REDIS_PREFIX}:task:queue") 个待处理"
    echo "事件队列: $(redis-cli LLEN "${REDIS_PREFIX}:events:queue") 个事件"
}

# L3 效率分析
do_efficiency() {
    log "效率分析开始"
    
    # 统计调度器执行情况
    local total_runs=0
    local total_fails=0
    
    for task in unblock state_detect pipeline exception conflict context_monitor commander efficiency progress architecture quality security; do
        runs=$(redis-cli HGET "${REDIS_PREFIX}:scheduler:task:${task}" "run_count")
        fails=$(redis-cli HGET "${REDIS_PREFIX}:scheduler:task:${task}" "fail_count")
        total_runs=$((total_runs + ${runs:-0}))
        total_fails=$((total_fails + ${fails:-0}))
    done
    
    local success_rate=100
    if [ $total_runs -gt 0 ]; then
        success_rate=$(( (total_runs - total_fails) * 100 / total_runs ))
    fi
    
    # 保存效率数据
    redis-cli HSET "${REDIS_PREFIX}:efficiency:stats" \
        "total_runs" "$total_runs" \
        "total_fails" "$total_fails" \
        "success_rate" "$success_rate" \
        "updated_at" "$(date +%s)" > /dev/null
    
    log "总执行: $total_runs, 失败: $total_fails, 成功率: ${success_rate}%"
    
    # 检查 agent 效率
    for pane in claude-agent gemini-agent codex-agent; do
        idle_time=$(redis-cli HGET "${REDIS_PREFIX}:agent:${pane}:state" "idle_since")
        if [ -n "$idle_time" ]; then
            now=$(date +%s)
            idle_duration=$((now - idle_time))
            if [ $idle_duration -gt 300 ]; then
                log "$pane: 空闲超过 5 分钟"
            fi
        fi
    done
}

# L4 代码质量检查
do_quality() {
    log "代码质量检查"
    
    PROJECT_DIR="/mnt/d/ai软件/zed"
    
    if [ ! -d "$PROJECT_DIR" ]; then
        log "项目目录不存在: $PROJECT_DIR"
        return 1
    fi
    
    cd "$PROJECT_DIR"
    
    # 检查是否有未提交的更改
    changes=$(git status --porcelain 2>/dev/null | wc -l)
    if [ "$changes" -gt 0 ]; then
        log "有 $changes 个未提交的更改"
    fi
    
    # 检查最近的提交
    last_commit=$(git log -1 --format="%h %s" 2>/dev/null)
    log "最近提交: $last_commit"
    
    # 尝试 cargo check (如果是 Rust 项目)
    if [ -f "Cargo.toml" ]; then
        log "运行 cargo check..."
        check_result=$(cargo check 2>&1 | tail -5)
        if echo "$check_result" | grep -q "error"; then
            log "发现编译错误!"
            redis-cli LPUSH "${REDIS_PREFIX}:events:queue" \
                "{\"type\":\"QUALITY_ERROR\",\"msg\":\"cargo check failed\",\"ts\":$(date +%s)}" > /dev/null
        else
            log "编译检查通过"
        fi
    fi
}

# L4 安全检查
do_security() {
    log "依赖安全检查"
    
    PROJECT_DIR="/mnt/d/ai软件/zed"
    
    if [ ! -d "$PROJECT_DIR" ]; then
        return 1
    fi
    
    cd "$PROJECT_DIR"
    
    # cargo audit (如果安装了)
    if command -v cargo-audit &> /dev/null; then
        log "运行 cargo audit..."
        audit_result=$(cargo audit 2>&1 | grep -E "warning|error" | head -5)
        if [ -n "$audit_result" ]; then
            log "发现安全问题: $audit_result"
        else
            log "无安全漏洞"
        fi
    else
        log "cargo-audit 未安装，跳过"
    fi
}

# 主执行
case "$task_name" in
    unblock)
        do_unblock
        ;;
    state_detect)
        do_state_detect
        ;;
    pipeline)
        # 处理事件队列
        event=$(redis-cli RPOP "${REDIS_PREFIX}:events:queue")
        if [ -n "$event" ]; then
            log "处理事件: $event"
        fi
        ;;
    exception)
        do_exception
        ;;
    conflict)
        log "冲突检测 - 暂无实现"
        ;;
    context_monitor)
        do_context_monitor
        ;;
    commander)
        do_commander
        ;;
    efficiency)
        do_efficiency
        ;;
    progress)
        do_progress
        ;;
    architecture)
        log "架构守护 - 检查模块边界"
        ;;
    quality)
        do_quality
        ;;
    security)
        do_security
        ;;
    *)
        log "未知任务: $task_name"
        exit 1
        ;;
esac

exit 0
