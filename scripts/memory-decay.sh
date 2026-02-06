#!/bin/bash
# 记忆衰减系统
# 实现 Ebbinghaus 曲线 + 访问频率增强

DB_HOST="localhost"
DB_USER="openclaw"
DB_PASS="openclaw123"
DB_NAME="openclaw"

export PGPASSWORD="$DB_PASS"

HALF_LIFE_DAYS=30  # 30天半衰期

psql_cmd() {
    psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -A "$@"
}

case "$1" in
    # 应用衰减（每日运行）
    apply-decay)
        echo "=== 应用记忆衰减 ==="
        # 衰减公式: decay_score = base_score * (0.5 ^ (days_since_access / half_life))
        # 访问增强: 每次访问 decay_score *= 1.2
        psql_cmd -c "
        UPDATE memories 
        SET decay_score = GREATEST(0.01, 
            decay_score * POWER(0.5, EXTRACT(EPOCH FROM (NOW() - last_accessed)) / (${HALF_LIFE_DAYS} * 86400))
        )
        WHERE last_accessed < NOW() - INTERVAL '1 day';
        "
        echo "衰减已应用"
        ;;
    
    # 记录访问（检索时调用）
    record-access)
        memory_id="$2"
        psql_cmd -c "
        UPDATE memories 
        SET last_accessed = NOW(),
            access_count = access_count + 1,
            decay_score = LEAST(10.0, decay_score * 1.2)
        WHERE id = $memory_id;
        "
        echo "已记录访问: $memory_id"
        ;;
    
    # 带衰减权重的搜索
    search-weighted)
        query="$2"
        limit="${3:-10}"
        psql_cmd -c "
        SELECT id, LEFT(content, 80) as content, category, 
               ROUND(decay_score::numeric, 2) as decay,
               access_count as hits,
               DATE(last_accessed) as last_hit
        FROM memories 
        WHERE content ILIKE '%$query%'
        ORDER BY (importance * decay_score) DESC, created_at DESC 
        LIMIT $limit;
        "
        ;;
    
    # 查看衰减统计
    stats)
        echo "=== 记忆衰减统计 ==="
        psql_cmd -c "
        SELECT 
            COUNT(*) as total,
            COUNT(*) FILTER (WHERE decay_score > 0.8) as strong,
            COUNT(*) FILTER (WHERE decay_score BETWEEN 0.3 AND 0.8) as medium,
            COUNT(*) FILTER (WHERE decay_score < 0.3) as weak,
            ROUND(AVG(decay_score)::numeric, 2) as avg_decay,
            ROUND(AVG(access_count)::numeric, 1) as avg_hits
        FROM memories;
        "
        ;;
    
    # 整合弱记忆（提取模式后可删除）
    consolidate)
        threshold="${2:-0.1}"
        echo "=== 弱记忆整合 (decay < $threshold) ==="
        psql_cmd -c "
        SELECT id, LEFT(content, 60), category, 
               ROUND(decay_score::numeric, 3) as decay,
               DATE(created_at) as created
        FROM memories 
        WHERE decay_score < $threshold
        ORDER BY decay_score ASC
        LIMIT 20;
        "
        echo ""
        echo "提示: 使用 './scripts/pg-memory.sh delete <id>' 删除"
        ;;
    
    # 重置所有衰减分数
    reset)
        echo "重置所有记忆的衰减分数..."
        psql_cmd -c "UPDATE memories SET decay_score = 1.0, last_accessed = NOW();"
        echo "完成"
        ;;
    
    *)
        echo "用法: $0 <command>"
        echo "命令:"
        echo "  apply-decay      - 应用衰减（每日运行）"
        echo "  record-access <id> - 记录访问"
        echo "  search-weighted <query> [limit] - 带权重搜索"
        echo "  stats            - 查看统计"
        echo "  consolidate [threshold] - 列出弱记忆"
        echo "  reset            - 重置所有衰减"
        ;;
esac
