#!/bin/bash
# PostgreSQL 向量记忆管理脚本
# 用法: ./pg-memory.sh <command> [args...]

DB_HOST="localhost"
DB_USER="openclaw"
DB_PASS="openclaw123"
DB_NAME="openclaw"

export PGPASSWORD="$DB_PASS"

psql_cmd() {
    psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -A "$@"
}

case "$1" in
    # 添加记忆
    add-memory)
        content="$2"
        category="${3:-general}"
        importance="${4:-5}"
        psql_cmd -c "INSERT INTO memories (content, category, importance) VALUES ('$content', '$category', $importance) RETURNING id;"
        ;;
    
    # 搜索记忆 (关键词)
    search)
        query="$2"
        limit="${3:-10}"
        psql_cmd -c "SELECT id, content, category, importance, created_at FROM memories WHERE content ILIKE '%$query%' ORDER BY importance DESC, created_at DESC LIMIT $limit;"
        ;;
    
    # 列出所有记忆
    list)
        limit="${1:-20}"
        psql_cmd -c "SELECT id, LEFT(content, 100) as content, category, importance, created_at FROM memories ORDER BY created_at DESC LIMIT $limit;"
        ;;
    
    # 添加任务
    add-task)
        task_id="$2"
        title="$3"
        description="$4"
        priority="${5:-5}"
        psql_cmd -c "INSERT INTO tasks (task_id, title, description, priority) VALUES ('$task_id', '$title', '$description', $priority) ON CONFLICT (task_id) DO UPDATE SET title='$title', description='$description', priority=$priority, updated_at=CURRENT_TIMESTAMP RETURNING id;"
        ;;
    
    # 更新任务状态
    update-task)
        task_id="$2"
        status="$3"
        psql_cmd -c "UPDATE tasks SET status='$status', updated_at=CURRENT_TIMESTAMP WHERE task_id='$task_id';"
        ;;
    
    # 列出任务
    list-tasks)
        status="${2:-all}"
        if [ "$status" = "all" ]; then
            psql_cmd -c "SELECT task_id, title, status, priority, created_at FROM tasks ORDER BY priority DESC, created_at DESC;"
        else
            psql_cmd -c "SELECT task_id, title, status, priority, created_at FROM tasks WHERE status='$status' ORDER BY priority DESC, created_at DESC;"
        fi
        ;;
    
    # 添加决策
    add-decision)
        decision="$2"
        reasoning="$3"
        context="$4"
        psql_cmd -c "INSERT INTO decisions (decision, reasoning, context) VALUES ('$decision', '$reasoning', '$context') RETURNING id;"
        ;;
    
    # 数据库状态
    status)
        echo "=== PostgreSQL 向量数据库状态 ==="
        echo ""
        echo "记忆数量: $(psql_cmd -c "SELECT COUNT(*) FROM memories;")"
        echo "对话数量: $(psql_cmd -c "SELECT COUNT(*) FROM conversations;")"
        echo "任务数量: $(psql_cmd -c "SELECT COUNT(*) FROM tasks;")"
        echo "决策数量: $(psql_cmd -c "SELECT COUNT(*) FROM decisions;")"
        echo ""
        echo "数据库大小: $(psql_cmd -c "SELECT pg_size_pretty(pg_database_size('openclaw'));")"
        ;;
    
    # 原始 SQL
    sql)
        shift
        psql_cmd -c "$*"
        ;;
    
    # 交互式
    shell)
        psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME"
        ;;
    
    # 记录访问（更新衰减分数）
    access)
        memory_id="$2"
        psql_cmd -c "UPDATE memories SET 
            last_accessed = CURRENT_TIMESTAMP, 
            access_count = access_count + 1,
            decay_score = calculate_decay_score(CURRENT_TIMESTAMP, access_count + 1)
            WHERE id = $memory_id RETURNING id, decay_score;"
        ;;
    
    # 按衰减分数排序搜索（优先返回最近/常用的）
    search-decay)
        query="$2"
        limit="${3:-10}"
        psql_cmd -c "SELECT id, LEFT(content, 100), category, importance, 
            ROUND(decay_score::numeric, 3) as decay,
            access_count, last_accessed::date
            FROM memories 
            WHERE content ILIKE '%$query%' 
            ORDER BY (importance * decay_score) DESC 
            LIMIT $limit;"
        ;;
    
    # 更新所有记忆的衰减分数
    refresh-decay)
        psql_cmd -c "UPDATE memories SET decay_score = calculate_decay_score(
            COALESCE(last_accessed, created_at), 
            COALESCE(access_count, 0)
        ); SELECT COUNT(*) || ' memories updated' FROM memories;"
        ;;
    
    # 显示衰减统计
    decay-stats)
        psql_cmd -c "SELECT 
            COUNT(*) as total,
            ROUND(AVG(decay_score)::numeric, 3) as avg_decay,
            ROUND(MIN(decay_score)::numeric, 3) as min_decay,
            ROUND(MAX(decay_score)::numeric, 3) as max_decay,
            COUNT(*) FILTER (WHERE decay_score < 0.5) as fading,
            COUNT(*) FILTER (WHERE decay_score >= 0.5) as active
            FROM memories;"
        ;;
    
    *)
        echo "PostgreSQL 向量记忆管理"
        echo ""
        echo "用法: $0 <command> [args...]"
        echo ""
        echo "命令:"
        echo "  add-memory <content> [category] [importance]  - 添加记忆"
        echo "  search <query> [limit]                        - 搜索记忆"
        echo "  list [limit]                                  - 列出记忆"
        echo "  add-task <id> <title> <desc> [priority]       - 添加任务"
        echo "  update-task <id> <status>                     - 更新任务状态"
        echo "  list-tasks [status]                           - 列出任务"
        echo "  add-decision <decision> <reasoning> <context> - 添加决策"
        echo "  status                                        - 数据库状态"
        echo "  sql <query>                                   - 执行 SQL"
        echo "  shell                                         - 交互式 psql"
        echo "  access <id>                                   - 记录访问（更新衰减）"
        echo "  search-decay <query> [limit]                  - 按衰减分数搜索"
        echo "  refresh-decay                                 - 刷新所有衰减分数"
        echo "  decay-stats                                   - 衰减统计"
        ;;
esac
