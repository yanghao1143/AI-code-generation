#!/bin/bash
# Redis Context Manager - 防止上下文窗口溢出
# 用法: ./redis-context-manager.sh <command> [args]

REDIS_PREFIX="openclaw:ctx"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 保存会话摘要
save_summary() {
    local session_id="${1:-main}"
    local summary="$2"
    local timestamp=$(date +%s)
    
    redis-cli HSET "${REDIS_PREFIX}:session:${session_id}" \
        "summary" "$summary" \
        "updated_at" "$timestamp" \
        "version" "1" > /dev/null
    
    # 保存到历史
    redis-cli LPUSH "${REDIS_PREFIX}:session:${session_id}:history" \
        "{\"ts\":$timestamp,\"summary\":\"$summary\"}" > /dev/null
    
    # 只保留最近 10 条历史
    redis-cli LTRIM "${REDIS_PREFIX}:session:${session_id}:history" 0 9 > /dev/null
    
    echo -e "${GREEN}✓ 摘要已保存${NC}"
}

# 读取会话摘要
get_summary() {
    local session_id="${1:-main}"
    redis-cli HGET "${REDIS_PREFIX}:session:${session_id}" "summary"
}

# 保存任务状态
save_task() {
    local task_id="$1"
    local status="$2"
    local progress="$3"
    local details="$4"
    local timestamp=$(date +%s)
    
    redis-cli HSET "${REDIS_PREFIX}:task:${task_id}" \
        "status" "$status" \
        "progress" "$progress" \
        "details" "$details" \
        "updated_at" "$timestamp" > /dev/null
    
    # 添加到活跃任务列表
    if [ "$status" != "completed" ] && [ "$status" != "failed" ]; then
        redis-cli SADD "${REDIS_PREFIX}:tasks:active" "$task_id" > /dev/null
    else
        redis-cli SREM "${REDIS_PREFIX}:tasks:active" "$task_id" > /dev/null
        redis-cli SADD "${REDIS_PREFIX}:tasks:done" "$task_id" > /dev/null
    fi
    
    echo -e "${GREEN}✓ 任务 ${task_id} 状态已更新: ${status} (${progress}%)${NC}"
}

# 获取任务状态
get_task() {
    local task_id="$1"
    redis-cli HGETALL "${REDIS_PREFIX}:task:${task_id}"
}

# 列出所有活跃任务
list_active_tasks() {
    echo -e "${BLUE}=== 活跃任务 ===${NC}"
    local tasks=$(redis-cli SMEMBERS "${REDIS_PREFIX}:tasks:active")
    
    if [ -z "$tasks" ]; then
        echo "无活跃任务"
        return
    fi
    
    for task in $tasks; do
        local status=$(redis-cli HGET "${REDIS_PREFIX}:task:${task}" "status")
        local progress=$(redis-cli HGET "${REDIS_PREFIX}:task:${task}" "progress")
        echo -e "  ${YELLOW}${task}${NC}: ${status} (${progress}%)"
    done
}

# 保存检查点 - 用于长任务恢复
save_checkpoint() {
    local task_id="$1"
    local checkpoint_data="$2"
    local timestamp=$(date +%s)
    
    redis-cli HSET "${REDIS_PREFIX}:checkpoint:${task_id}" \
        "data" "$checkpoint_data" \
        "created_at" "$timestamp" > /dev/null
    
    # 设置 24 小时过期
    redis-cli EXPIRE "${REDIS_PREFIX}:checkpoint:${task_id}" 86400 > /dev/null
    
    echo -e "${GREEN}✓ 检查点已保存 (24h 有效)${NC}"
}

# 恢复检查点
restore_checkpoint() {
    local task_id="$1"
    redis-cli HGET "${REDIS_PREFIX}:checkpoint:${task_id}" "data"
}

# 保存上下文快照 - 在上下文接近满时调用
save_context_snapshot() {
    local snapshot_name="${1:-auto}"
    local content="$2"
    local timestamp=$(date +%s)
    
    redis-cli HSET "${REDIS_PREFIX}:snapshot:${snapshot_name}" \
        "content" "$content" \
        "created_at" "$timestamp" > /dev/null
    
    # 保存快照索引
    redis-cli ZADD "${REDIS_PREFIX}:snapshots" "$timestamp" "$snapshot_name" > /dev/null
    
    # 只保留最近 20 个快照
    local count=$(redis-cli ZCARD "${REDIS_PREFIX}:snapshots")
    if [ "$count" -gt 20 ]; then
        local old=$(redis-cli ZRANGE "${REDIS_PREFIX}:snapshots" 0 0)
        redis-cli ZREM "${REDIS_PREFIX}:snapshots" "$old" > /dev/null
        redis-cli DEL "${REDIS_PREFIX}:snapshot:${old}" > /dev/null
    fi
    
    echo -e "${GREEN}✓ 上下文快照已保存: ${snapshot_name}${NC}"
}

# 获取最新快照
get_latest_snapshot() {
    local latest=$(redis-cli ZREVRANGE "${REDIS_PREFIX}:snapshots" 0 0)
    if [ -n "$latest" ]; then
        redis-cli HGET "${REDIS_PREFIX}:snapshot:${latest}" "content"
    fi
}

# 保存决策记录
save_decision() {
    local decision_id="$1"
    local decision="$2"
    local reason="$3"
    local timestamp=$(date +%s)
    
    redis-cli HSET "${REDIS_PREFIX}:decision:${decision_id}" \
        "decision" "$decision" \
        "reason" "$reason" \
        "timestamp" "$timestamp" > /dev/null
    
    redis-cli LPUSH "${REDIS_PREFIX}:decisions:log" \
        "{\"id\":\"$decision_id\",\"decision\":\"$decision\",\"ts\":$timestamp}" > /dev/null
    
    redis-cli LTRIM "${REDIS_PREFIX}:decisions:log" 0 49 > /dev/null
    
    echo -e "${GREEN}✓ 决策已记录: ${decision_id}${NC}"
}

# 获取所有决策
list_decisions() {
    echo -e "${BLUE}=== 最近决策 ===${NC}"
    redis-cli LRANGE "${REDIS_PREFIX}:decisions:log" 0 9
}

# 状态报告
status_report() {
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║     Redis Context Manager Status       ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo ""
    
    # 统计
    local total_keys=$(redis-cli KEYS "${REDIS_PREFIX}:*" | wc -l)
    local active_tasks=$(redis-cli SCARD "${REDIS_PREFIX}:tasks:active" 2>/dev/null || echo 0)
    local snapshots=$(redis-cli ZCARD "${REDIS_PREFIX}:snapshots" 2>/dev/null || echo 0)
    local decisions=$(redis-cli LLEN "${REDIS_PREFIX}:decisions:log" 2>/dev/null || echo 0)
    
    echo -e "  ${YELLOW}总 Keys:${NC}      $total_keys"
    echo -e "  ${YELLOW}活跃任务:${NC}    $active_tasks"
    echo -e "  ${YELLOW}快照数量:${NC}    $snapshots"
    echo -e "  ${YELLOW}决策记录:${NC}    $decisions"
    echo ""
    
    # 内存使用
    local memory=$(redis-cli INFO memory | grep used_memory_human | cut -d: -f2 | tr -d '\r')
    echo -e "  ${YELLOW}Redis 内存:${NC}  $memory"
    echo ""
    
    # 活跃任务列表
    if [ "$active_tasks" -gt 0 ]; then
        list_active_tasks
    fi
}

# 清理过期数据
cleanup() {
    echo -e "${YELLOW}清理过期数据...${NC}"
    
    # 清理已完成任务 (保留最近 50 个)
    local done_count=$(redis-cli SCARD "${REDIS_PREFIX}:tasks:done" 2>/dev/null || echo 0)
    if [ "$done_count" -gt 50 ]; then
        echo "  清理已完成任务..."
        # 这里可以添加更复杂的清理逻辑
    fi
    
    echo -e "${GREEN}✓ 清理完成${NC}"
}

# 导出所有数据 (用于备份)
export_all() {
    local output_file="${1:-redis-context-backup.json}"
    echo "{"
    echo "  \"exported_at\": \"$(date -Iseconds)\","
    echo "  \"keys\": ["
    
    local first=true
    for key in $(redis-cli KEYS "${REDIS_PREFIX}:*"); do
        local type=$(redis-cli TYPE "$key")
        if [ "$first" = true ]; then
            first=false
        else
            echo ","
        fi
        echo -n "    {\"key\": \"$key\", \"type\": \"$type\"}"
    done
    
    echo ""
    echo "  ]"
    echo "}"
}

# 主命令分发
case "$1" in
    save-summary)
        save_summary "$2" "$3"
        ;;
    get-summary)
        get_summary "$2"
        ;;
    save-task)
        save_task "$2" "$3" "$4" "$5"
        ;;
    get-task)
        get_task "$2"
        ;;
    list-tasks)
        list_active_tasks
        ;;
    save-checkpoint)
        save_checkpoint "$2" "$3"
        ;;
    restore-checkpoint)
        restore_checkpoint "$2"
        ;;
    save-snapshot)
        save_context_snapshot "$2" "$3"
        ;;
    get-snapshot)
        get_latest_snapshot
        ;;
    save-decision)
        save_decision "$2" "$3" "$4"
        ;;
    list-decisions)
        list_decisions
        ;;
    status)
        status_report
        ;;
    cleanup)
        cleanup
        ;;
    export)
        export_all "$2"
        ;;
    *)
        echo "Redis Context Manager - 防止上下文窗口溢出"
        echo ""
        echo "用法: $0 <command> [args]"
        echo ""
        echo "命令:"
        echo "  save-summary <session> <summary>  保存会话摘要"
        echo "  get-summary <session>             获取会话摘要"
        echo "  save-task <id> <status> <progress> <details>  保存任务状态"
        echo "  get-task <id>                     获取任务状态"
        echo "  list-tasks                        列出活跃任务"
        echo "  save-checkpoint <task> <data>     保存检查点"
        echo "  restore-checkpoint <task>         恢复检查点"
        echo "  save-snapshot <name> <content>    保存上下文快照"
        echo "  get-snapshot                      获取最新快照"
        echo "  save-decision <id> <decision> <reason>  记录决策"
        echo "  list-decisions                    列出决策"
        echo "  status                            状态报告"
        echo "  cleanup                           清理过期数据"
        echo "  export [file]                     导出备份"
        ;;
esac
