#!/bin/bash
# Redis 任务队列调度器
# 用法: ./scheduler.sh

REDIS_CLI="redis-cli"
CONFIG_FILE="/home/jinyang/.openclaw/workspace/scheduler/config.json"

# 并发限制
MAX_TOTAL=6
MAX_OPUS=2
MAX_SONNET=3
MAX_HAIKU=5

# Redis Keys
QUEUE_PENDING="openclaw:scheduler:pending"
QUEUE_RUNNING="openclaw:scheduler:running"
TASK_PREFIX="openclaw:scheduler:task:"
LAST_RUN_PREFIX="openclaw:scheduler:last_run:"

# 获取当前运行中的任务数
get_running_count() {
    local model=$1
    if [ -z "$model" ]; then
        $REDIS_CLI SCARD $QUEUE_RUNNING 2>/dev/null || echo "0"
    else
        $REDIS_CLI SMEMBERS $QUEUE_RUNNING 2>/dev/null | while read task_id; do
            $REDIS_CLI HGET "${TASK_PREFIX}${task_id}" model 2>/dev/null
        done | grep -c "^${model}$" || echo "0"
    fi
}

# 检查是否可以执行任务
can_execute() {
    local model=$1
    local total=$(get_running_count)
    local model_count=$(get_running_count $model)
    
    [ "$total" -lt "$MAX_TOTAL" ] || return 1
    
    case $model in
        opus)   [ "$model_count" -lt "$MAX_OPUS" ] ;;
        sonnet) [ "$model_count" -lt "$MAX_SONNET" ] ;;
        haiku)  [ "$model_count" -lt "$MAX_HAIKU" ] ;;
        *)      return 0 ;;
    esac
}

# 检查任务是否到期
is_task_due() {
    local task_id=$1
    local interval=$2
    local last_run=$($REDIS_CLI GET "${LAST_RUN_PREFIX}${task_id}" 2>/dev/null)
    local now=$(date +%s%3N)
    
    if [ -z "$last_run" ]; then
        return 0  # 从未运行，需要执行
    fi
    
    local elapsed=$((now - last_run))
    [ "$elapsed" -ge "$interval" ]
}

# 添加任务到队列
enqueue_task() {
    local task_id=$1
    local priority=$2
    local model=$3
    local message=$4
    
    # 存储任务详情
    $REDIS_CLI HSET "${TASK_PREFIX}${task_id}" \
        model "$model" \
        message "$message" \
        status "pending" \
        enqueued_at "$(date +%s%3N)" \
        > /dev/null
    
    # 添加到待执行队列 (ZSET，按优先级排序)
    $REDIS_CLI ZADD $QUEUE_PENDING $priority $task_id > /dev/null
    
    echo "📥 入队: $task_id (优先级: $priority, 模型: $model)"
}

# 执行任务
execute_task() {
    local task_id=$1
    local model=$($REDIS_CLI HGET "${TASK_PREFIX}${task_id}" model)
    local message=$($REDIS_CLI HGET "${TASK_PREFIX}${task_id}" message)
    
    # 检查并发限制
    if ! can_execute $model; then
        echo "⏸️ 跳过 $task_id: $model 并发已满"
        return 1
    fi
    
    # 移动到运行队列
    $REDIS_CLI ZREM $QUEUE_PENDING $task_id > /dev/null
    $REDIS_CLI SADD $QUEUE_RUNNING $task_id > /dev/null
    $REDIS_CLI HSET "${TASK_PREFIX}${task_id}" status "running" started_at "$(date +%s%3N)" > /dev/null
    
    echo "🚀 执行: $task_id (模型: $model)"
    
    # 调用 OpenClaw sessions_spawn (后台执行)
    # 这里输出命令，实际执行由外部处理
    echo "SPAWN:$task_id:$model:$message"
    
    return 0
}

# 完成任务
complete_task() {
    local task_id=$1
    local status=$2  # ok/error
    
    $REDIS_CLI SREM $QUEUE_RUNNING $task_id > /dev/null
    $REDIS_CLI HSET "${TASK_PREFIX}${task_id}" status "$status" completed_at "$(date +%s%3N)" > /dev/null
    $REDIS_CLI SET "${LAST_RUN_PREFIX}${task_id}" "$(date +%s%3N)" > /dev/null
    
    echo "✅ 完成: $task_id ($status)"
}

# 调度循环
schedule() {
    echo "=== 调度器启动 $(date) ==="
    echo "并发限制: 总计=$MAX_TOTAL, opus=$MAX_OPUS, sonnet=$MAX_SONNET, haiku=$MAX_HAIKU"
    
    # 读取配置并检查到期任务
    local tasks=$(cat $CONFIG_FILE | jq -c '.tasks[]')
    
    echo "$tasks" | while read task; do
        local id=$(echo $task | jq -r '.id')
        local name=$(echo $task | jq -r '.name')
        local model=$(echo $task | jq -r '.model')
        local priority=$(echo $task | jq -r '.priority')
        local interval=$(echo $task | jq -r '.interval_ms')
        local message=$(echo $task | jq -r '.message')
        
        # 转换优先级
        case $priority in
            P0_CRITICAL) pri=0 ;;
            P1_HIGH) pri=100 ;;
            P2_MEDIUM) pri=200 ;;
            P3_LOW) pri=300 ;;
            *) pri=200 ;;
        esac
        
        # 检查是否到期
        if is_task_due $id $interval; then
            # 检查是否已在队列中
            local in_pending=$($REDIS_CLI ZSCORE $QUEUE_PENDING $id 2>/dev/null)
            local in_running=$($REDIS_CLI SISMEMBER $QUEUE_RUNNING $id 2>/dev/null)
            
            if [ -z "$in_pending" ] && [ "$in_running" != "1" ]; then
                enqueue_task $id $pri $model "$message"
            fi
        fi
    done
    
    # 执行队列中的任务
    local pending_count=$($REDIS_CLI ZCARD $QUEUE_PENDING 2>/dev/null || echo "0")
    echo "📋 待执行任务: $pending_count"
    
    # 按优先级取任务执行
    local tasks_to_run=$($REDIS_CLI ZRANGE $QUEUE_PENDING 0 $((MAX_TOTAL - 1)))
    
    for task_id in $tasks_to_run; do
        execute_task $task_id
    done
    
    # 显示状态
    echo ""
    echo "📊 当前状态:"
    echo "  - 运行中: $($REDIS_CLI SCARD $QUEUE_RUNNING 2>/dev/null || echo 0)"
    echo "  - 待执行: $($REDIS_CLI ZCARD $QUEUE_PENDING 2>/dev/null || echo 0)"
}

# 状态查看
status() {
    echo "=== 调度器状态 ==="
    echo ""
    echo "📊 队列状态:"
    echo "  运行中: $($REDIS_CLI SCARD $QUEUE_RUNNING 2>/dev/null || echo 0)"
    echo "  待执行: $($REDIS_CLI ZCARD $QUEUE_PENDING 2>/dev/null || echo 0)"
    echo ""
    echo "🔄 运行中的任务:"
    $REDIS_CLI SMEMBERS $QUEUE_RUNNING 2>/dev/null | while read task_id; do
        local model=$($REDIS_CLI HGET "${TASK_PREFIX}${task_id}" model 2>/dev/null)
        local started=$($REDIS_CLI HGET "${TASK_PREFIX}${task_id}" started_at 2>/dev/null)
        echo "  - $task_id ($model)"
    done
    echo ""
    echo "⏳ 待执行的任务:"
    $REDIS_CLI ZRANGE $QUEUE_PENDING 0 -1 WITHSCORES 2>/dev/null | paste - - | while read task_id score; do
        local model=$($REDIS_CLI HGET "${TASK_PREFIX}${task_id}" model 2>/dev/null)
        echo "  - $task_id (优先级: $score, 模型: $model)"
    done
}

# 清理
cleanup() {
    echo "🧹 清理队列..."
    $REDIS_CLI DEL $QUEUE_PENDING $QUEUE_RUNNING > /dev/null
    $REDIS_CLI KEYS "${TASK_PREFIX}*" | xargs -r $REDIS_CLI DEL > /dev/null
    $REDIS_CLI KEYS "${LAST_RUN_PREFIX}*" | xargs -r $REDIS_CLI DEL > /dev/null
    echo "✅ 清理完成"
}

# 主入口
case "${1:-schedule}" in
    schedule) schedule ;;
    status) status ;;
    cleanup) cleanup ;;
    complete) complete_task "$2" "$3" ;;
    *) echo "用法: $0 {schedule|status|cleanup|complete <task_id> <status>}" ;;
esac
