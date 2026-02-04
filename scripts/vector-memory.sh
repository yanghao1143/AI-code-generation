#!/bin/bash
# vector-memory.sh - 向量记忆系统 (PostgreSQL + Embeddings API)
# 支持多模型容错和自动重试

WORKSPACE="/home/jinyang/.openclaw/workspace"
DB_HOST="localhost"
DB_USER="openclaw"
DB_PASS="openclaw123"
DB_NAME="openclaw"

# API 配置
API_KEY="${OPENAI_API_KEY:-sk-MgjQOD5s4xdnBfueHBgAiCxrtvgfN0xU1J24SyRIl1JUMUu2}"
API_BASE="${OPENAI_BASE_URL:-https://claude.chiddns.com/v1}"

# 多模型容错配置 (按优先级排序)
# 格式: "模型名:维度"
EMBED_MODELS=(
    "baai/bge-m3:1024"
    "nvidia/nv-embed-v1:4096"
)

# 当前使用的模型 (会自动选择)
CURRENT_MODEL=""
CURRENT_DIM=1024

# 重试配置
MAX_RETRIES=3
RETRY_DELAY=2

export PGPASSWORD="$DB_PASS"

# 日志函数
log() {
    echo "[$(date '+%H:%M:%S')] $1"
}

# 生成嵌入向量 (带容错)
generate_embedding() {
    local text="$1"
    local embedding=""
    
    for model_config in "${EMBED_MODELS[@]}"; do
        local model="${model_config%%:*}"
        local dim="${model_config##*:}"
        
        for ((retry=1; retry<=MAX_RETRIES; retry++)); do
            # 调用 API
            local response=$(curl -s --max-time 30 "$API_BASE/embeddings" \
                -H "Authorization: Bearer $API_KEY" \
                -H "Content-Type: application/json" \
                -d "{
                    \"model\": \"$model\",
                    \"input\": $(echo "$text" | jq -Rs .)
                }" 2>/dev/null)
            
            # 检查响应
            embedding=$(echo "$response" | jq -r '.data[0].embedding | @json' 2>/dev/null)
            
            if [[ -n "$embedding" ]] && [[ "$embedding" != "null" ]] && [[ "$embedding" != "[]" ]]; then
                CURRENT_MODEL="$model"
                CURRENT_DIM="$dim"
                echo "$embedding"
                return 0
            fi
            
            # 检查错误信息
            local error=$(echo "$response" | jq -r '.error.message // empty' 2>/dev/null)
            if [[ -n "$error" ]]; then
                log "⚠️ $model 错误: $error (重试 $retry/$MAX_RETRIES)"
            else
                log "⚠️ $model 无响应 (重试 $retry/$MAX_RETRIES)"
            fi
            
            sleep $RETRY_DELAY
        done
        
        log "❌ $model 失败，尝试下一个模型..."
    done
    
    log "❌ 所有模型都失败了"
    echo ""
    return 1
}

# 确保表结构支持当前维度
ensure_table_dimension() {
    local dim="$1"
    local current_dim=$(psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -A \
        -c "SELECT atttypmod FROM pg_attribute WHERE attrelid = 'memories'::regclass AND attname = 'embedding';" 2>/dev/null)
    
    # atttypmod = dim + 4 for vector type
    local expected=$((dim + 4))
    
    if [[ "$current_dim" != "$expected" ]]; then
        log "🔧 调整向量维度: $current_dim -> $expected ($dim 维)"
        psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -q << EOF
DROP INDEX IF EXISTS memories_embedding_hnsw;
ALTER TABLE memories ALTER COLUMN embedding TYPE vector($dim);
ALTER TABLE conversations ALTER COLUMN embedding TYPE vector($dim);
ALTER TABLE decisions ALTER COLUMN embedding TYPE vector($dim);
EOF
        # 只有 <= 2000 维才能用 HNSW
        if [[ $dim -le 2000 ]]; then
            psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -q \
                -c "CREATE INDEX IF NOT EXISTS memories_embedding_hnsw ON memories USING hnsw (embedding vector_cosine_ops);"
        fi
    fi
}

# 添加记忆 (带向量)
add_memory() {
    local content="$1"
    local category="${2:-general}"
    local importance="${3:-5}"
    
    log "🧠 生成嵌入向量..."
    local embedding=$(generate_embedding "$content")
    
    if [[ -z "$embedding" ]]; then
        log "⚠️ 无法生成向量，仅保存文本"
        local id=$(psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -A \
            -c "INSERT INTO memories (content, category, importance) VALUES (\$\$${content}\$\$, '$category', $importance) RETURNING id;")
        log "✅ 记忆已保存 (无向量) ID: $id"
    else
        # 确保维度匹配
        ensure_table_dimension "$CURRENT_DIM"
        
        local id=$(psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -A \
            -c "INSERT INTO memories (content, category, importance, embedding) VALUES (\$\$${content}\$\$, '$category', $importance, '$embedding') RETURNING id;")
        log "✅ 记忆已保存 (向量: $CURRENT_MODEL) ID: $id"
    fi
}

# 语义搜索记忆
semantic_search() {
    local query="$1"
    local limit="${2:-5}"
    
    log "🔍 生成查询向量..."
    local embedding=$(generate_embedding "$query")
    
    if [[ -z "$embedding" ]]; then
        log "⚠️ 无法生成向量，使用关键词搜索"
        psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" \
            -c "SELECT id, LEFT(content, 200) as content, category, importance FROM memories WHERE content ILIKE '%$query%' ORDER BY importance DESC LIMIT $limit;"
    else
        log "📊 语义搜索 (模型: $CURRENT_MODEL)"
        psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" \
            -c "SELECT id, LEFT(content, 150) as content, category, importance, 
                ROUND((1 - (embedding <=> '$embedding'))::numeric, 4) as similarity
                FROM memories 
                WHERE embedding IS NOT NULL
                ORDER BY embedding <=> '$embedding'
                LIMIT $limit;"
    fi
}

# 为现有记忆生成向量
backfill_embeddings() {
    log "🔄 为现有记忆生成向量..."
    
    local ids=$(psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -A \
        -c "SELECT id FROM memories WHERE embedding IS NULL;")
    
    if [[ -z "$ids" ]]; then
        log "✅ 所有记忆都已有向量"
        return 0
    fi
    
    local count=0
    local failed=0
    
    for id in $ids; do
        local content=$(psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -A \
            -c "SELECT content FROM memories WHERE id=$id;")
        
        log "  处理 ID $id..."
        local embedding=$(generate_embedding "$content")
        
        if [[ -n "$embedding" ]]; then
            ensure_table_dimension "$CURRENT_DIM"
            psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -q \
                -c "UPDATE memories SET embedding='$embedding' WHERE id=$id;"
            ((count++))
        else
            ((failed++))
        fi
        
        sleep 0.5  # 避免 API 限流
    done
    
    log "✅ 完成: $count 成功, $failed 失败"
}

# 测试所有模型
test_models() {
    log "🧪 测试所有 Embedding 模型..."
    echo ""
    
    for model_config in "${EMBED_MODELS[@]}"; do
        local model="${model_config%%:*}"
        local expected_dim="${model_config##*:}"
        
        echo -n "  $model ($expected_dim 维): "
        
        local response=$(curl -s --max-time 15 "$API_BASE/embeddings" \
            -H "Authorization: Bearer $API_KEY" \
            -H "Content-Type: application/json" \
            -d "{\"model\": \"$model\", \"input\": \"测试\"}" 2>/dev/null)
        
        local dim=$(echo "$response" | jq '.data[0].embedding | length' 2>/dev/null)
        local error=$(echo "$response" | jq -r '.error.message // empty' 2>/dev/null)
        
        if [[ "$dim" == "$expected_dim" ]]; then
            echo "✅ 正常"
        elif [[ -n "$error" ]]; then
            echo "❌ $error"
        else
            echo "❌ 返回维度: $dim"
        fi
    done
    echo ""
}

# 状态
status() {
    echo "=== 🧠 向量记忆系统状态 ==="
    echo ""
    echo "📦 数据库: PostgreSQL $(psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -A -c "SHOW server_version;" | head -1)"
    echo "🔌 pgvector: $(psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT extversion FROM pg_extension WHERE extname='vector';")"
    echo "🌐 API: $API_BASE"
    echo ""
    echo "🤖 Embedding 模型 (按优先级):"
    for model_config in "${EMBED_MODELS[@]}"; do
        local model="${model_config%%:*}"
        local dim="${model_config##*:}"
        echo "  - $model ($dim 维)"
    done
    echo ""
    echo "📊 记忆统计:"
    echo "  总数: $(psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT COUNT(*) FROM memories;")"
    echo "  有向量: $(psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT COUNT(*) FROM memories WHERE embedding IS NOT NULL;")"
    echo "  无向量: $(psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT COUNT(*) FROM memories WHERE embedding IS NULL;")"
}

case "$1" in
    add)
        shift
        add_memory "$@"
        ;;
    search)
        shift
        semantic_search "$@"
        ;;
    backfill)
        backfill_embeddings
        ;;
    status)
        status
        ;;
    test)
        test_models
        ;;
    *)
        echo "🧠 向量记忆系统 (多模型容错版)"
        echo ""
        echo "用法: $0 <command> [args...]"
        echo ""
        echo "命令:"
        echo "  add <content> [category] [importance]  - 添加记忆 (带向量)"
        echo "  search <query> [limit]                 - 语义搜索"
        echo "  backfill                               - 为现有记忆生成向量"
        echo "  status                                 - 系统状态"
        echo "  test                                   - 测试所有模型"
        echo ""
        echo "容错机制:"
        echo "  - 多模型自动切换"
        echo "  - 每个模型最多重试 $MAX_RETRIES 次"
        echo "  - 自动适配向量维度"
        ;;
esac
