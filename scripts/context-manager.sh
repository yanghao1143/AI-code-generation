#!/bin/bash
# context-manager.sh - 上下文压缩与管理
# 解决上下文窗口爆满问题 (400K tokens)
# 新增: 使用 API 自动摘要长对话

WORKSPACE="/home/jinyang/.openclaw/workspace"
MEMORY_DIR="$WORKSPACE/memory"
ARCHIVE_DIR="$MEMORY_DIR/archive"

# Redis 配置
REDIS_PREFIX="openclaw:ctx"

# PostgreSQL 配置
DB_HOST="localhost"
DB_USER="openclaw"
DB_PASS="openclaw123"
DB_NAME="openclaw"
export PGPASSWORD="$DB_PASS"

# API 配置 (Claude API for summarization)
ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-sk-MgjQOD5s4xdnBfueHBgAiCxrtvgfN0xU1J24SyRIl1JUMUu2}"
ANTHROPIC_BASE_URL="${ANTHROPIC_BASE_URL:-https://claude.chiddns.com}"
SUMMARY_MODEL="claude-3-5-haiku-20241022"  # 使用 Haiku 节省成本

# 压缩阈值
MAX_DAILY_LOG_KB=10      # 每日日志超过 10KB 就压缩
MAX_MEMORY_MD_KB=5       # MEMORY.md 超过 5KB 就警告
ARCHIVE_DAYS=3           # 3天前的日志归档
SUMMARY_THRESHOLD_KB=5   # 超过 5KB 的内容需要 API 摘要
MAX_SUMMARY_TOKENS=500   # 摘要最大 token 数

log() {
    echo "[$(date '+%H:%M:%S')] $1"
}

# ============ API 摘要生成 ============
# 使用 Claude API 生成智能摘要
generate_summary_via_api() {
    local content="$1"
    local max_tokens="${2:-$MAX_SUMMARY_TOKENS}"
    local context_type="${3:-general}"  # general, conversation, log, code

    # 根据类型选择提示词
    local system_prompt=""
    case "$context_type" in
        conversation)
            system_prompt="你是一个对话摘要专家。请用中文总结以下对话的关键点：
1. 讨论的主题和目标
2. 做出的重要决定
3. 待办事项或后续步骤
4. 遇到的问题和解决方案
保持简洁，使用要点格式。"
            ;;
        log)
            system_prompt="你是一个日志分析专家。请用中文总结以下日志的关键信息：
1. 完成的任务 (✅)
2. 遇到的问题 (❌/🚨)
3. 重要的状态变化
4. 需要关注的事项
保持简洁，使用要点格式。"
            ;;
        code)
            system_prompt="你是一个代码审查专家。请用中文总结以下代码变更：
1. 修改了哪些文件/模块
2. 主要的功能变化
3. 修复的问题
4. 潜在的影响
保持简洁，使用要点格式。"
            ;;
        *)
            system_prompt="请用中文简洁地总结以下内容的关键点，保持要点格式。"
            ;;
    esac

    # 构建 API 请求
    local request_body=$(jq -n \
        --arg model "$SUMMARY_MODEL" \
        --arg system "$system_prompt" \
        --arg content "$content" \
        --argjson max_tokens "$max_tokens" \
        '{
            model: $model,
            max_tokens: $max_tokens,
            system: $system,
            messages: [
                {role: "user", content: $content}
            ]
        }')

    # 调用 API
    local response=$(curl -s -X POST "${ANTHROPIC_BASE_URL}/v1/messages" \
        -H "Content-Type: application/json" \
        -H "x-api-key: $ANTHROPIC_API_KEY" \
        -H "anthropic-version: 2023-06-01" \
        -d "$request_body" \
        --max-time 30)

    # 解析响应
    local summary=$(echo "$response" | jq -r '.content[0].text // empty')

    if [[ -n "$summary" ]]; then
        echo "$summary"
        return 0
    else
        # API 调用失败，返回错误信息
        local error=$(echo "$response" | jq -r '.error.message // "Unknown error"')
        log "⚠️ API 摘要失败: $error"
        return 1
    fi
}

# ============ 智能摘要 (带回退) ============
# 优先使用 API，失败时回退到简单截断
generate_summary() {
    local content="$1"
    local max_len="${2:-500}"
    local context_type="${3:-general}"

    local content_size=$(echo "$content" | wc -c)
    local content_kb=$((content_size / 1024))

    # 如果内容较小，直接返回
    if [[ $content_kb -lt $SUMMARY_THRESHOLD_KB ]]; then
        echo "$content"
        return 0
    fi

    log "📝 内容较大 (${content_kb}KB)，尝试 API 摘要..."

    # 尝试 API 摘要
    local summary=$(generate_summary_via_api "$content" "$max_len" "$context_type")

    if [[ $? -eq 0 && -n "$summary" ]]; then
        log "✅ API 摘要成功"
        echo "$summary"
        return 0
    fi

    # 回退: 简单截断 + 提取关键行
    log "⚠️ 回退到简单摘要"
    local key_lines=$(echo "$content" | grep -E "^###|^##|✅|❌|🚨|重要|完成|问题|TODO" | head -20)
    local truncated=$(echo "$content" | head -c $max_len)

    echo -e "## 关键点\n$key_lines\n\n## 内容预览\n$truncated..."
}

# ============ 对话摘要 (新增) ============
# 自动摘要长对话并归档
summarize_conversation() {
    local conversation_file="$1"
    local session_id="${2:-$(basename "$conversation_file" .md)}"

    if [[ ! -f "$conversation_file" ]]; then
        log "❌ 文件不存在: $conversation_file"
        return 1
    fi

    local content=$(cat "$conversation_file")
    local content_kb=$(echo "$content" | wc -c | awk '{print int($1/1024)}')

    log "📊 对话大小: ${content_kb}KB"

    if [[ $content_kb -lt $SUMMARY_THRESHOLD_KB ]]; then
        log "✅ 对话较短，无需摘要"
        return 0
    fi

    log "🤖 生成对话摘要..."

    # 使用 API 生成摘要
    local summary=$(generate_summary_via_api "$content" 800 "conversation")

    if [[ $? -ne 0 || -z "$summary" ]]; then
        log "⚠️ API 摘要失败，使用简单摘要"
        summary=$(echo "$content" | grep -E "^###|^##|user:|assistant:|✅|❌" | head -30)
    fi

    # 保存摘要到 Redis (短期访问)
    redis-cli SETEX "${REDIS_PREFIX}:conversation:${session_id}:summary" 86400 "$summary" > /dev/null

    # 保存完整对话和摘要到 PostgreSQL
    PGPASSWORD=$DB_PASS psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -q \
        -c "INSERT INTO conversations (session_id, role, content)
            VALUES ('$session_id', 'full', \$\$$content\$\$)
            ON CONFLICT (session_id, role) WHERE role = 'full' DO UPDATE SET content = EXCLUDED.content;"

    PGPASSWORD=$DB_PASS psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -q \
        -c "INSERT INTO conversations (session_id, role, content)
            VALUES ('$session_id', 'summary', \$\$$summary\$\$)
            ON CONFLICT (session_id, role) WHERE role = 'summary' DO UPDATE SET content = EXCLUDED.content;"

    # 替换原文件为摘要版本
    cat > "$conversation_file" << EOF
# 对话摘要: $session_id

> 完整对话已归档到 PostgreSQL
> 查询: \`./scripts/pg-memory.sh conversation "$session_id"\`

## 摘要

$summary

---
*摘要生成时间: $(date '+%Y-%m-%d %H:%M')*
*原始大小: ${content_kb}KB*
EOF

    local new_size=$(du -k "$conversation_file" | cut -f1)
    log "✅ 对话摘要完成: ${content_kb}KB → ${new_size}KB"

    echo "$summary"
}

# ============ 批量摘要对话 ============
summarize_all_conversations() {
    local min_size_kb="${1:-$SUMMARY_THRESHOLD_KB}"

    log "🔍 扫描需要摘要的对话..."

    local count=0
    for conv_file in "$MEMORY_DIR"/*.md "$MEMORY_DIR"/conversations/*.md; do
        [[ -f "$conv_file" ]] || continue

        # 跳过已经是摘要的文件
        if grep -q "^# 对话摘要:" "$conv_file" 2>/dev/null; then
            continue
        fi

        local size_kb=$(du -k "$conv_file" | cut -f1)

        if [[ $size_kb -ge $min_size_kb ]]; then
            log "📝 处理: $(basename "$conv_file") (${size_kb}KB)"
            summarize_conversation "$conv_file"
            ((count++))

            # 避免 API 限流
            sleep 2
        fi
    done

    log "✅ 批量摘要完成: $count 个文件"
}

# ============ 每日日志压缩 ============
compress_daily_log() {
    local date="${1:-$(date +%Y-%m-%d)}"
    local log_file="$MEMORY_DIR/$date.md"
    
    if [[ ! -f "$log_file" ]]; then
        log "📝 $date 日志不存在"
        return 0
    fi
    
    local size_kb=$(du -k "$log_file" | cut -f1)
    
    if [[ $size_kb -lt $MAX_DAILY_LOG_KB ]]; then
        log "✅ $date 日志大小正常 (${size_kb}KB)"
        return 0
    fi
    
    log "🗜️ 压缩 $date 日志 (${size_kb}KB > ${MAX_DAILY_LOG_KB}KB)"
    
    # 提取关键信息
    local key_events=$(grep -E "^###|✅|❌|🚨|重要|完成|问题" "$log_file" | head -20)
    
    # 保存完整版到 PostgreSQL
    local full_content=$(cat "$log_file")
    PGPASSWORD=$DB_PASS psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -q \
        -c "INSERT INTO memories (content, category, importance, metadata) 
            VALUES (\$\$日志归档 $date: $full_content\$\$, 'daily_log', 5, 
            '{\"date\": \"$date\", \"type\": \"archive\"}');"
    
    # 压缩原文件
    cat > "$log_file" << EOF
# $date 日志 (已压缩)

> 完整日志已归档到 PostgreSQL，查询: \`./scripts/pg-memory.sh search "$date"\`

## 关键事件

$key_events

---
*压缩时间: $(date '+%Y-%m-%d %H:%M')*
EOF
    
    local new_size=$(du -k "$log_file" | cut -f1)
    log "✅ 压缩完成: ${size_kb}KB → ${new_size}KB"
}

# ============ 归档旧日志 (支持 API 摘要) ============
archive_old_logs() {
    local use_api="${1:-true}"  # 默认使用 API 摘要

    log "📦 归档 ${ARCHIVE_DAYS} 天前的日志..."

    mkdir -p "$ARCHIVE_DIR"

    local count=0
    local summarized=0
    for log_file in "$MEMORY_DIR"/????-??-??.md; do
        [[ -f "$log_file" ]] || continue

        local filename=$(basename "$log_file")
        local file_date="${filename%.md}"
        local cutoff_date=$(date -d "$ARCHIVE_DAYS days ago" +%Y-%m-%d)

        if [[ "$file_date" < "$cutoff_date" ]]; then
            local content=$(cat "$log_file")
            local content_kb=$(echo "$content" | wc -c | awk '{print int($1/1024)}')

            # 如果内容较大且启用 API，先生成摘要
            local summary=""
            if [[ "$use_api" == "true" && $content_kb -ge $SUMMARY_THRESHOLD_KB ]]; then
                log "🤖 生成 $file_date 日志摘要..."
                summary=$(generate_summary_via_api "$content" 600 "log")
                if [[ $? -eq 0 && -n "$summary" ]]; then
                    ((summarized++))
                fi
                sleep 1  # 避免 API 限流
            fi

            # 保存完整内容到 PostgreSQL
            PGPASSWORD=$DB_PASS psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -q \
                -c "INSERT INTO memories (content, category, importance, metadata)
                    VALUES (\$\$归档日志 $file_date: $content\$\$, 'archive', 3,
                    '{\"date\": \"$file_date\", \"type\": \"full_archive\"}')
                    ON CONFLICT DO NOTHING;"

            # 如果有摘要，也保存摘要
            if [[ -n "$summary" ]]; then
                PGPASSWORD=$DB_PASS psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -q \
                    -c "INSERT INTO memories (content, category, importance, metadata)
                        VALUES (\$\$日志摘要 $file_date: $summary\$\$, 'log_summary', 6,
                        '{\"date\": \"$file_date\", \"type\": \"summary\", \"original_size_kb\": $content_kb}')
                        ON CONFLICT DO NOTHING;"
            fi

            # 创建归档版本 (包含摘要)
            if [[ -n "$summary" ]]; then
                cat > "$ARCHIVE_DIR/$filename" << EOF
# $file_date 日志 (已归档)

> 完整日志已保存到 PostgreSQL
> 查询: \`./scripts/pg-memory.sh search "$file_date"\`

## AI 摘要

$summary

---
*归档时间: $(date '+%Y-%m-%d %H:%M')*
*原始大小: ${content_kb}KB*
EOF
            else
                mv "$log_file" "$ARCHIVE_DIR/"
            fi

            # 删除原文件 (如果还在)
            [[ -f "$log_file" ]] && rm "$log_file"

            ((count++))
            log "  📁 归档: $filename (${content_kb}KB)"
        fi
    done

    log "✅ 归档完成: $count 个文件, $summarized 个使用了 AI 摘要"
}

# ============ Redis 上下文缓存 ============
cache_context() {
    local key="$1"
    local value="$2"
    local ttl="${3:-3600}"  # 默认 1 小时
    
    redis-cli SETEX "${REDIS_PREFIX}:${key}" "$ttl" "$value" > /dev/null
    log "💾 缓存: $key (TTL: ${ttl}s)"
}

get_cached_context() {
    local key="$1"
    redis-cli GET "${REDIS_PREFIX}:${key}"
}

# ============ 会话摘要 ============
save_session_summary() {
    local summary="$1"
    local session_id="${2:-main}"
    
    # 保存到 Redis (短期)
    cache_context "session:$session_id:summary" "$summary" 7200
    
    # 保存到 PostgreSQL (长期)
    PGPASSWORD=$DB_PASS psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -q \
        -c "INSERT INTO conversations (session_id, role, content) 
            VALUES ('$session_id', 'summary', \$\$$summary\$\$);"
    
    log "✅ 会话摘要已保存"
}

# ============ 上下文状态报告 ============
status() {
    echo "=== 📊 上下文管理状态 ==="
    echo ""
    
    echo "📁 文件大小:"
    echo "  MEMORY.md: $(du -h "$WORKSPACE/MEMORY.md" 2>/dev/null | cut -f1)"
    for f in "$MEMORY_DIR"/*.md; do
        [[ -f "$f" ]] && echo "  $(basename "$f"): $(du -h "$f" | cut -f1)"
    done
    
    echo ""
    echo "📦 归档文件: $(ls "$ARCHIVE_DIR"/*.md 2>/dev/null | wc -l) 个"
    
    echo ""
    echo "💾 Redis 缓存:"
    echo "  Keys: $(redis-cli KEYS "${REDIS_PREFIX}:*" 2>/dev/null | wc -l)"
    echo "  内存: $(redis-cli INFO memory 2>/dev/null | grep used_memory_human | cut -d: -f2)"
    
    echo ""
    echo "🗄️ PostgreSQL:"
    echo "  记忆数: $(PGPASSWORD=$DB_PASS psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT COUNT(*) FROM memories;")"
    echo "  对话数: $(PGPASSWORD=$DB_PASS psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT COUNT(*) FROM conversations;")"
    echo "  数据库大小: $(PGPASSWORD=$DB_PASS psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT pg_size_pretty(pg_database_size('openclaw'));")"
}

# ============ 自动清理 ============
auto_cleanup() {
    log "🧹 开始自动清理..."
    
    # 1. 压缩今天的日志 (如果太大)
    compress_daily_log "$(date +%Y-%m-%d)"
    
    # 2. 归档旧日志
    archive_old_logs
    
    # 3. 清理过期的 Redis 缓存 (Redis 自动处理 TTL)
    
    # 4. 检查 MEMORY.md 大小
    local memory_size=$(du -k "$WORKSPACE/MEMORY.md" 2>/dev/null | cut -f1)
    if [[ $memory_size -gt $MAX_MEMORY_MD_KB ]]; then
        log "⚠️ MEMORY.md 较大 (${memory_size}KB)，建议手动精简"
    fi
    
    log "✅ 自动清理完成"
}

# ============ 生成精简上下文 ============
generate_slim_context() {
    log "📝 生成精简上下文..."
    
    # 从各个来源收集关键信息
    local context=""
    
    # 1. 当前工作计划 (Redis)
    local work_plan=$(redis-cli GET "openclaw:work:plan" 2>/dev/null)
    if [[ -n "$work_plan" ]]; then
        context+="## 当前工作\n$work_plan\n\n"
    fi
    
    # 2. 最近的重要记忆 (PostgreSQL)
    local recent_memories=$(PGPASSWORD=$DB_PASS psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -A \
        -c "SELECT content FROM memories WHERE importance >= 8 ORDER BY created_at DESC LIMIT 5;")
    if [[ -n "$recent_memories" ]]; then
        context+="## 重要记忆\n$recent_memories\n\n"
    fi
    
    # 3. 今天的关键事件
    local today=$(date +%Y-%m-%d)
    if [[ -f "$MEMORY_DIR/$today.md" ]]; then
        local today_events=$(grep -E "^###|✅|❌|🚨" "$MEMORY_DIR/$today.md" | head -10)
        context+="## 今日事件\n$today_events\n\n"
    fi
    
    echo -e "$context"
}

case "$1" in
    compress)
        shift
        compress_daily_log "$@"
        ;;
    archive)
        shift
        use_api="${1:-true}"
        archive_old_logs "$use_api"
        ;;
    archive-no-api)
        archive_old_logs "false"
        ;;
    cache)
        shift
        cache_context "$@"
        ;;
    get)
        shift
        get_cached_context "$@"
        ;;
    summary)
        shift
        save_session_summary "$@"
        ;;
    summarize)
        # 摘要单个文件
        shift
        if [[ -z "$1" ]]; then
            echo "用法: $0 summarize <file> [session_id]"
            exit 1
        fi
        summarize_conversation "$@"
        ;;
    summarize-all)
        # 批量摘要所有大文件
        shift
        min_size="${1:-$SUMMARY_THRESHOLD_KB}"
        summarize_all_conversations "$min_size"
        ;;
    test-api)
        # 测试 API 连接
        log "🔍 测试 API 连接..."
        test_content="这是一段测试内容。今天完成了以下工作：
1. ✅ 修复了编译错误
2. ✅ 添加了新功能
3. ❌ 测试失败需要修复
4. 🚨 发现性能问题"
        result=$(generate_summary_via_api "$test_content" 200 "log")
        if [[ $? -eq 0 && -n "$result" ]]; then
            echo "✅ API 连接正常"
            echo ""
            echo "测试摘要:"
            echo "$result"
        else
            echo "❌ API 连接失败"
        fi
        ;;
    slim)
        generate_slim_context
        ;;
    cleanup)
        auto_cleanup
        ;;
    status)
        status
        ;;
    *)
        echo "📊 上下文压缩与管理 (支持 AI 摘要)"
        echo ""
        echo "用法: $0 <command> [args...]"
        echo ""
        echo "命令:"
        echo "  compress [date]       - 压缩指定日期的日志"
        echo "  archive [use_api]     - 归档旧日志 (默认使用 AI 摘要)"
        echo "  archive-no-api        - 归档旧日志 (不使用 AI)"
        echo "  cache <key> <value>   - 缓存上下文到 Redis"
        echo "  get <key>             - 获取缓存的上下文"
        echo "  summary <text>        - 保存会话摘要"
        echo "  summarize <file>      - 使用 AI 摘要单个对话文件"
        echo "  summarize-all [kb]    - 批量摘要大于指定 KB 的文件"
        echo "  test-api              - 测试 AI API 连接"
        echo "  slim                  - 生成精简上下文"
        echo "  cleanup               - 自动清理 (压缩+归档)"
        echo "  status                - 查看状态"
        echo ""
        echo "配置:"
        echo "  MAX_DAILY_LOG_KB=$MAX_DAILY_LOG_KB"
        echo "  MAX_MEMORY_MD_KB=$MAX_MEMORY_MD_KB"
        echo "  ARCHIVE_DAYS=$ARCHIVE_DAYS"
        echo "  SUMMARY_THRESHOLD_KB=$SUMMARY_THRESHOLD_KB"
        echo "  SUMMARY_MODEL=$SUMMARY_MODEL"
        ;;
esac
