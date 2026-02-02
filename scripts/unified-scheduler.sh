#!/bin/bash
# 统一任务调度器 - 用 Redis 管理所有定时任务，避免负载
# 单入口调度，按优先级和间隔执行

REDIS_PREFIX="openclaw:scheduler"
SCRIPT_DIR="$(dirname "$0")"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 任务定义 (name:interval_seconds:priority:type)
# priority: 1=最高(立即), 2=高, 3=中, 4=低
# type: check/action/report
TASKS=(
    "unblock:60:1:check"           # L0 解卡
    "state_detect:90:2:check"      # L1 状态感知
    "pipeline:120:2:action"        # L2 流水线
    "exception:120:2:action"       # L2 异常处理
    "conflict:180:3:check"         # L2 冲突检测
    "context_monitor:300:3:check"  # L2 上下文监控
    "commander:300:3:action"       # L3 指挥官
    "efficiency:900:4:report"      # L3 效率分析
    "progress:1800:4:report"       # L3 进度汇报
    "architecture:3600:4:check"    # L4 架构守护
    "quality:3600:4:check"         # L4 代码质量
    "security:3600:4:check"        # L4 依赖安全
)

# 初始化任务到 Redis
init_tasks() {
    echo -e "${BLUE}初始化任务调度...${NC}"
    
    local now=$(date +%s)
    
    for task_def in "${TASKS[@]}"; do
        IFS=':' read -r name interval priority type <<< "$task_def"
        
        # 检查是否已存在
        local exists=$(redis-cli EXISTS "${REDIS_PREFIX}:task:${name}")
        if [ "$exists" -eq 0 ]; then
            redis-cli HSET "${REDIS_PREFIX}:task:${name}" \
                "interval" "$interval" \
                "priority" "$priority" \
                "type" "$type" \
                "last_run" "0" \
                "next_run" "$now" \
                "enabled" "1" \
                "run_count" "0" \
                "fail_count" "0" > /dev/null
            echo -e "  ${GREEN}✓${NC} $name (每${interval}s, 优先级$priority)"
        fi
    done
    
    echo -e "${GREEN}✓ 初始化完成${NC}"
}

# 获取下一个要执行的任务
get_next_task() {
    local now=$(date +%s)
    local best_task=""
    local best_priority=999
    local best_overdue=0
    
    for task_def in "${TASKS[@]}"; do
        IFS=':' read -r name interval priority type <<< "$task_def"
        
        local enabled=$(redis-cli HGET "${REDIS_PREFIX}:task:${name}" "enabled")
        [ "$enabled" != "1" ] && continue
        
        local next_run=$(redis-cli HGET "${REDIS_PREFIX}:task:${name}" "next_run")
        next_run=${next_run:-0}
        
        if [ "$now" -ge "$next_run" ]; then
            local overdue=$((now - next_run))
            # 选择优先级最高的，或者同优先级中最过期的
            if [ "$priority" -lt "$best_priority" ] || \
               ([ "$priority" -eq "$best_priority" ] && [ "$overdue" -gt "$best_overdue" ]); then
                best_task="$name"
                best_priority="$priority"
                best_overdue="$overdue"
            fi
        fi
    done
    
    echo "$best_task"
}

# 标记任务开始
mark_task_start() {
    local name="$1"
    local now=$(date +%s)
    
    redis-cli HSET "${REDIS_PREFIX}:task:${name}" \
        "status" "running" \
        "started_at" "$now" > /dev/null
}

# 标记任务完成
mark_task_done() {
    local name="$1"
    local success="$2"  # 1=成功, 0=失败
    local now=$(date +%s)
    
    local interval=$(redis-cli HGET "${REDIS_PREFIX}:task:${name}" "interval")
    local next_run=$((now + interval))
    
    redis-cli HSET "${REDIS_PREFIX}:task:${name}" \
        "status" "idle" \
        "last_run" "$now" \
        "next_run" "$next_run" > /dev/null
    
    redis-cli HINCRBY "${REDIS_PREFIX}:task:${name}" "run_count" 1 > /dev/null
    
    if [ "$success" -eq 0 ]; then
        redis-cli HINCRBY "${REDIS_PREFIX}:task:${name}" "fail_count" 1 > /dev/null
    fi
}

# 执行单个任务 (返回要发送给 agent 的消息)
get_task_message() {
    local name="$1"
    
    case "$name" in
        unblock)
            echo "【L0-解卡】检测 tmux 会话是否有确认提示，有则自动确认。tmux -S /tmp/openclaw-agents.sock"
            ;;
        state_detect)
            echo "【L1-状态感知】capture-pane 检查各 agent 状态，写入 Redis: openclaw:agent:<name>:state"
            ;;
        pipeline)
            echo "【L2-流水线】检查 openclaw:events:queue，处理 COMPLETED/ERROR/BLOCKED 事件"
            ;;
        exception)
            echo "【L2-异常处理】检查异常并恢复：API Error/panic/死循环/长时间无输出"
            ;;
        conflict)
            echo "【L2-冲突检测】检查多 agent 是否改同一文件，有冲突则协调"
            ;;
        context_monitor)
            echo "【L2-上下文监控】检查 context 使用率，>85% 则压缩"
            ;;
        commander)
            echo "【L3-指挥官】检查空闲 agent，分配新任务。任务队列: openclaw:task:queue"
            ;;
        efficiency)
            echo "【L3-效率分析】分析任务完成率、耗时、失败率，更新学习库"
            ;;
        progress)
            echo "【L3-进度汇报】汇总当前进度：任务统计、agent 状态、最近完成"
            ;;
        architecture)
            echo "【L4-架构守护】检查模块边界、依赖方向、循环依赖"
            ;;
        quality)
            echo "【L4-代码质量】扫描 Critical/Major/Minor 问题"
            ;;
        security)
            echo "【L4-依赖安全】cargo audit 检查安全漏洞"
            ;;
        *)
            echo ""
            ;;
    esac
}

# 调度一轮 (由 cron 调用)
schedule_once() {
    local task=$(get_next_task)
    
    if [ -z "$task" ]; then
        echo "NO_TASK"
        return 0
    fi
    
    # 检查是否有任务正在运行 (防止并发)
    local running=$(redis-cli GET "${REDIS_PREFIX}:running")
    if [ -n "$running" ]; then
        local started=$(redis-cli HGET "${REDIS_PREFIX}:task:${running}" "started_at")
        local now=$(date +%s)
        local elapsed=$((now - started))
        
        # 超过 5 分钟认为卡住了
        if [ "$elapsed" -gt 300 ]; then
            echo -e "${YELLOW}任务 $running 超时，强制结束${NC}"
            mark_task_done "$running" 0
            redis-cli DEL "${REDIS_PREFIX}:running" > /dev/null
        else
            echo "BUSY:$running"
            return 0
        fi
    fi
    
    # 标记开始
    redis-cli SET "${REDIS_PREFIX}:running" "$task" EX 600 > /dev/null
    mark_task_start "$task"
    
    # 返回任务消息
    local msg=$(get_task_message "$task")
    echo "TASK:$task:$msg"
}

# 调度并执行 (自动模式) - 带负载控制
schedule_and_run() {
    # 负载检查
    local load=$("$(dirname "$0")/smart-router.sh" load 2>/dev/null || echo 0)
    if [ "$load" -ge 3 ]; then
        return 0
    fi
    
    # 执行最多 5 个过期任务
    local executed=0
    local max_tasks=5
    
    while [ $executed -lt $max_tasks ]; do
        local task=$(get_next_task)
        
        if [ -z "$task" ]; then
            break
        fi
        
        # 标记开始
        mark_task_start "$task"
        
        # 执行任务
        local executor="$(dirname "$0")/task-executor.sh"
        if [ -x "$executor" ]; then
            "$executor" "$task"
            local result=$?
            mark_task_done "$task" $((1 - result))
        else
            mark_task_done "$task" 0
        fi
        
        executed=$((executed + 1))
        echo "DONE:$task"
    done
    
    if [ $executed -eq 0 ]; then
        return 0
    fi
    
    redis-cli DEL "${REDIS_PREFIX}:running" > /dev/null
    echo "DONE:$task"
}

# 完成任务 (agent 执行完后调用)
complete_task() {
    local task="$1"
    local success="${2:-1}"
    
    mark_task_done "$task" "$success"
    redis-cli DEL "${REDIS_PREFIX}:running" > /dev/null
    
    echo -e "${GREEN}✓ 任务 $task 完成${NC}"
}

# 状态报告
status() {
    echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║         统一任务调度器状态                     ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    local running=$(redis-cli GET "${REDIS_PREFIX}:running")
    if [ -n "$running" ]; then
        echo -e "${YELLOW}当前运行: $running${NC}"
    else
        echo -e "${GREEN}当前空闲${NC}"
    fi
    echo ""
    
    local now=$(date +%s)
    
    echo -e "${BLUE}任务列表:${NC}"
    printf "  %-20s %-8s %-6s %-10s %-10s\n" "任务" "间隔" "优先级" "上次运行" "下次运行"
    echo "  ────────────────────────────────────────────────────────────"
    
    for task_def in "${TASKS[@]}"; do
        IFS=':' read -r name interval priority type <<< "$task_def"
        
        local enabled=$(redis-cli HGET "${REDIS_PREFIX}:task:${name}" "enabled")
        local last_run=$(redis-cli HGET "${REDIS_PREFIX}:task:${name}" "last_run")
        local next_run=$(redis-cli HGET "${REDIS_PREFIX}:task:${name}" "next_run")
        
        last_run=${last_run:-0}
        next_run=${next_run:-0}
        
        local last_ago="从未"
        local next_in="--"
        
        if [ "$last_run" -gt 0 ]; then
            last_ago="$((now - last_run))s前"
        fi
        
        if [ "$next_run" -gt 0 ]; then
            local diff=$((next_run - now))
            if [ "$diff" -le 0 ]; then
                next_in="${RED}已到期${NC}"
            else
                next_in="${diff}s后"
            fi
        fi
        
        local status_icon="✓"
        [ "$enabled" != "1" ] && status_icon="✗"
        
        printf "  %-20s %-8s P%-5s %-10s %-10b\n" "$name" "${interval}s" "$priority" "$last_ago" "$next_in"
    done
    
    echo ""
    echo -e "${BLUE}统计:${NC}"
    local total_runs=0
    local total_fails=0
    for task_def in "${TASKS[@]}"; do
        IFS=':' read -r name interval priority type <<< "$task_def"
        local runs=$(redis-cli HGET "${REDIS_PREFIX}:task:${name}" "run_count")
        local fails=$(redis-cli HGET "${REDIS_PREFIX}:task:${name}" "fail_count")
        total_runs=$((total_runs + ${runs:-0}))
        total_fails=$((total_fails + ${fails:-0}))
    done
    echo "  总执行次数: $total_runs"
    echo "  失败次数: $total_fails"
}

# 启用/禁用任务
toggle_task() {
    local name="$1"
    local enabled="$2"
    
    redis-cli HSET "${REDIS_PREFIX}:task:${name}" "enabled" "$enabled" > /dev/null
    
    if [ "$enabled" -eq 1 ]; then
        echo -e "${GREEN}✓ 任务 $name 已启用${NC}"
    else
        echo -e "${YELLOW}✗ 任务 $name 已禁用${NC}"
    fi
}

# 立即执行某任务
run_now() {
    local name="$1"
    local now=$(date +%s)
    
    redis-cli HSET "${REDIS_PREFIX}:task:${name}" "next_run" "$now" > /dev/null
    echo -e "${GREEN}✓ 任务 $name 已加入队列${NC}"
}

# 主命令
case "$1" in
    init)
        init_tasks
        ;;
    schedule)
        schedule_once
        ;;
    run-once)
        schedule_and_run
        ;;
    complete)
        complete_task "$2" "$3"
        ;;
    status)
        status
        ;;
    enable)
        toggle_task "$2" 1
        ;;
    disable)
        toggle_task "$2" 0
        ;;
    run)
        run_now "$2"
        ;;
    *)
        echo "统一任务调度器 - Redis 驱动的定时任务管理"
        echo ""
        echo "用法: $0 <command> [args]"
        echo ""
        echo "命令:"
        echo "  init              初始化所有任务"
        echo "  schedule          调度下一个任务 (cron 调用)"
        echo "  complete <task>   标记任务完成"
        echo "  status            查看状态"
        echo "  enable <task>     启用任务"
        echo "  disable <task>    禁用任务"
        echo "  run <task>        立即执行某任务"
        ;;
esac
