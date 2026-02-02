#!/bin/bash
# task-tracker.sh - JSON-First 任务状态管理 (无 jq 依赖版)
# 用法: ./task-tracker.sh <action> [args...]

REDIS_PREFIX="openclaw:task"

action="$1"
shift

case "$action" in
    create)
        # 创建任务: ./task-tracker.sh create <agent> <purpose> <task>
        AGENT="$1"
        PURPOSE="$2"
        TASK="$3"
        TASK_ID="task-$(date +%s)-$RANDOM"
        NOW=$(date -Iseconds)
        
        # 用 Redis Hash 存储 (不依赖 jq)
        redis-cli HSET "$REDIS_PREFIX:$TASK_ID" \
            id "$TASK_ID" \
            agent "$AGENT" \
            purpose "$PURPOSE" \
            task "$TASK" \
            status "pending" \
            created_at "$NOW" \
            updated_at "$NOW" \
            attempts "0" \
            > /dev/null
        
        redis-cli SADD "$REDIS_PREFIX:queue:pending" "$TASK_ID" > /dev/null
        echo "$TASK_ID"
        ;;
    
    start)
        # 开始任务: ./task-tracker.sh start <task_id>
        TASK_ID="$1"
        EXISTS=$(redis-cli EXISTS "$REDIS_PREFIX:$TASK_ID")
        if [[ "$EXISTS" == "0" ]]; then
            echo "❌ 任务不存在: $TASK_ID"
            exit 1
        fi
        
        NOW=$(date -Iseconds)
        ATTEMPTS=$(redis-cli HGET "$REDIS_PREFIX:$TASK_ID" attempts)
        ATTEMPTS=$((ATTEMPTS + 1))
        
        redis-cli HSET "$REDIS_PREFIX:$TASK_ID" \
            status "running" \
            updated_at "$NOW" \
            started_at "$NOW" \
            attempts "$ATTEMPTS" \
            > /dev/null
        
        redis-cli SMOVE "$REDIS_PREFIX:queue:pending" "$REDIS_PREFIX:queue:running" "$TASK_ID" > /dev/null
        echo "✅ 任务开始: $TASK_ID (第 $ATTEMPTS 次尝试)"
        ;;
    
    complete)
        # 完成任务: ./task-tracker.sh complete <task_id> [result]
        TASK_ID="$1"
        RESULT="${2:-success}"
        NOW=$(date -Iseconds)
        
        redis-cli HSET "$REDIS_PREFIX:$TASK_ID" \
            status "completed" \
            updated_at "$NOW" \
            completed_at "$NOW" \
            result "$RESULT" \
            > /dev/null
        
        redis-cli SMOVE "$REDIS_PREFIX:queue:running" "$REDIS_PREFIX:queue:completed" "$TASK_ID" > /dev/null
        echo "✅ 任务完成: $TASK_ID"
        ;;
    
    fail)
        # 任务失败: ./task-tracker.sh fail <task_id> <error>
        TASK_ID="$1"
        ERROR="$2"
        NOW=$(date -Iseconds)
        
        redis-cli HSET "$REDIS_PREFIX:$TASK_ID" \
            status "failed" \
            updated_at "$NOW" \
            error "$ERROR" \
            > /dev/null
        
        redis-cli SMOVE "$REDIS_PREFIX:queue:running" "$REDIS_PREFIX:queue:failed" "$TASK_ID" > /dev/null
        echo "❌ 任务失败: $TASK_ID - $ERROR"
        ;;
    
    retry)
        # 重试任务: ./task-tracker.sh retry <task_id>
        TASK_ID="$1"
        NOW=$(date -Iseconds)
        
        redis-cli HSET "$REDIS_PREFIX:$TASK_ID" \
            status "pending" \
            updated_at "$NOW" \
            > /dev/null
        redis-cli HDEL "$REDIS_PREFIX:$TASK_ID" error > /dev/null
        
        redis-cli SMOVE "$REDIS_PREFIX:queue:failed" "$REDIS_PREFIX:queue:pending" "$TASK_ID" > /dev/null
        echo "🔄 任务重试: $TASK_ID"
        ;;
    
    get)
        # 获取任务: ./task-tracker.sh get <task_id>
        TASK_ID="$1"
        echo "=== 任务详情: $TASK_ID ==="
        redis-cli HGETALL "$REDIS_PREFIX:$TASK_ID" | while read -r key; do
            read -r value
            printf "  %-12s: %s\n" "$key" "$value"
        done
        ;;
    
    list)
        # 列出任务: ./task-tracker.sh list [status]
        STATUS="${1:-all}"
        
        show_queue() {
            local queue="$1"
            local label="$2"
            local ids=$(redis-cli SMEMBERS "$REDIS_PREFIX:queue:$queue")
            if [[ -n "$ids" ]]; then
                echo "=== $label ==="
                for id in $ids; do
                    AGENT=$(redis-cli HGET "$REDIS_PREFIX:$id" agent)
                    PURPOSE=$(redis-cli HGET "$REDIS_PREFIX:$id" purpose)
                    STATUS=$(redis-cli HGET "$REDIS_PREFIX:$id" status)
                    printf "  %-25s %-15s %-10s %s\n" "$id" "$AGENT" "$STATUS" "$PURPOSE"
                done
            fi
        }
        
        if [[ "$STATUS" == "all" ]]; then
            show_queue "pending" "待处理"
            show_queue "running" "运行中"
            show_queue "completed" "已完成 (最近5个)"
            show_queue "failed" "失败"
        else
            show_queue "$STATUS" "$STATUS"
        fi
        ;;
    
    stats)
        # 统计: ./task-tracker.sh stats
        PENDING=$(redis-cli SCARD "$REDIS_PREFIX:queue:pending")
        RUNNING=$(redis-cli SCARD "$REDIS_PREFIX:queue:running")
        COMPLETED=$(redis-cli SCARD "$REDIS_PREFIX:queue:completed")
        FAILED=$(redis-cli SCARD "$REDIS_PREFIX:queue:failed")
        
        echo "📊 任务统计"
        echo "  待处理: $PENDING"
        echo "  运行中: $RUNNING"
        echo "  已完成: $COMPLETED"
        echo "  失败:   $FAILED"
        echo "  ─────────────"
        echo "  总计:   $((PENDING + RUNNING + COMPLETED + FAILED))"
        ;;
    
    clean)
        # 清理已完成任务: ./task-tracker.sh clean
        CLEANED=0
        for id in $(redis-cli SMEMBERS "$REDIS_PREFIX:queue:completed"); do
            redis-cli DEL "$REDIS_PREFIX:$id" > /dev/null
            redis-cli SREM "$REDIS_PREFIX:queue:completed" "$id" > /dev/null
            ((CLEANED++))
        done
        echo "🧹 清理了 $CLEANED 个已完成任务"
        ;;
    
    *)
        echo "用法: $0 <action> [args...]"
        echo ""
        echo "Actions:"
        echo "  create <agent> <purpose> <task>  - 创建任务"
        echo "  start <task_id>                  - 开始任务"
        echo "  complete <task_id> [result]      - 完成任务"
        echo "  fail <task_id> <error>           - 标记失败"
        echo "  retry <task_id>                  - 重试任务"
        echo "  get <task_id>                    - 获取任务详情"
        echo "  list [status]                    - 列出任务"
        echo "  stats                            - 统计信息"
        echo "  clean                            - 清理已完成任务"
        ;;
esac
