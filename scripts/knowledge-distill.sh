#!/bin/bash
# knowledge-distill.sh - 知识提炼引擎
# 自动从每日日志提炼长期记忆

WORKSPACE="/home/jinyang/.openclaw/workspace"
MEMORY_DIR="$WORKSPACE/memory"
SCRIPTS_DIR="$WORKSPACE/scripts"

# PostgreSQL 配置
DB_HOST="localhost"
DB_USER="openclaw"
DB_PASS="openclaw123"
DB_NAME="openclaw"
export PGPASSWORD="$DB_PASS"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅${NC} $1"
}

error() {
    echo -e "${RED}❌${NC} $1"
}

warn() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

# ============ 提取结构化信息 ============
extract_events() {
    local log_file="$1"
    
    # 提取标记的事件
    grep -E "^###|✅|❌|🚨|⚠️|💡|🎯|📝" "$log_file" 2>/dev/null
}

extract_decisions() {
    local log_file="$1"
    
    # 提取决策相关内容
    grep -iE "决定|决策|选择|确定|方案" "$log_file" 2>/dev/null | head -10
}

extract_learnings() {
    local log_file="$1"
    
    # 提取学习和教训
    grep -iE "教训|学习|发现|总结|经验" "$log_file" 2>/dev/null | head -10
}

extract_tasks() {
    local log_file="$1"
    
    # 提取任务
    grep -E "^\- \[[ x]\]|TODO|待办|待完成" "$log_file" 2>/dev/null | head -10
}

# ============ 识别模式 ============
identify_patterns() {
    local events="$1"
    
    # 简单的模式识别: 统计关键词频率
    local patterns=""
    
    # 检查是否有重复的错误
    local error_count=$(echo "$events" | grep -c "❌\|错误\|失败")
    if [[ $error_count -gt 3 ]]; then
        patterns+="- 多次错误/失败 ($error_count 次)\n"
    fi
    
    # 检查是否有重复的成功
    local success_count=$(echo "$events" | grep -c "✅\|完成\|成功")
    if [[ $success_count -gt 5 ]]; then
        patterns+="- 高产出 ($success_count 个任务完成)\n"
    fi
    
    # 检查是否有警告
    local warn_count=$(echo "$events" | grep -c "⚠️\|警告\|注意")
    if [[ $warn_count -gt 2 ]]; then
        patterns+="- 需要关注的问题 ($warn_count 个警告)\n"
    fi
    
    echo -e "$patterns"
}

# ============ 生成摘要 ============
generate_summary() {
    local log_file="$1"
    local date="$2"
    
    log "生成 $date 的摘要..."
    
    # 提取各类信息
    local events=$(extract_events "$log_file")
    local decisions=$(extract_decisions "$log_file")
    local learnings=$(extract_learnings "$log_file")
    local tasks=$(extract_tasks "$log_file")
    local patterns=$(identify_patterns "$events")
    
    # 统计
    local event_count=$(echo "$events" | wc -l)
    local success_count=$(echo "$events" | grep -c "✅")
    local error_count=$(echo "$events" | grep -c "❌")
    
    # 生成摘要
    local summary="# $date 知识摘要

## 📊 统计
- 事件数: $event_count
- 完成: $success_count
- 错误: $error_count

## 🎯 关键事件
$events

## 💡 决策
$decisions

## 🎓 学习与教训
$learnings

## 📋 任务
$tasks

## 🔍 模式识别
$patterns

---
*自动生成于 $(date '+%Y-%m-%d %H:%M')*
"
    
    echo "$summary"
}

# ============ 使用 AI 生成摘要 ============
generate_ai_summary() {
    local content="$1"
    local date="$2"
    
    # 使用 context-manager.sh 的 API 摘要功能
    if [[ -x "$SCRIPTS_DIR/context-manager.sh" ]]; then
        log "使用 AI 生成摘要..."
        
        # 创建临时文件
        local temp_file="/tmp/distill_$date.md"
        echo "$content" > "$temp_file"
        
        # 调用 API 摘要
        local ai_summary=$("$SCRIPTS_DIR/context-manager.sh" summarize "$temp_file" "$date" 2>/dev/null)
        
        rm -f "$temp_file"
        
        if [[ -n "$ai_summary" ]]; then
            echo "$ai_summary"
            return 0
        fi
    fi
    
    # 回退: 使用简单摘要
    generate_summary "$1" "$2"
}

# ============ 保存到知识库 ============
save_to_knowledge_base() {
    local summary="$1"
    local date="$2"
    
    log "保存到知识库..."
    
    # 1. 保存到 PostgreSQL
    psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -q \
        -c "INSERT INTO memories (content, category, importance, metadata)
            VALUES (\$\$$summary\$\$, 'daily_summary', 7,
            '{\"date\": \"$date\", \"type\": \"distilled\"}')
            ON CONFLICT DO NOTHING;" 2>/dev/null
    
    # 2. 更新 MEMORY.md (追加索引)
    local index_entry="- **$date**: [查看详情](memory/$date.md) - $(echo "$summary" | head -1 | sed 's/^# //')"
    
    # 检查是否已存在
    if ! grep -q "$date" "$WORKSPACE/MEMORY.md" 2>/dev/null; then
        # 在 "最近记录" 部分追加
        if grep -q "## 最近记录" "$WORKSPACE/MEMORY.md" 2>/dev/null; then
            sed -i "/## 最近记录/a\\$index_entry" "$WORKSPACE/MEMORY.md"
        else
            echo -e "\n## 最近记录\n$index_entry" >> "$WORKSPACE/MEMORY.md"
        fi
    fi
    
    # 3. 缓存到 Redis (7天)
    redis-cli SETEX "openclaw:knowledge:daily:$date" 604800 "$summary" > /dev/null
    
    success "已保存到知识库"
}

# ============ 建立时序关联 ============
create_temporal_links() {
    local date="$1"
    
    # 查找前一天和后一天的记忆
    local prev_date=$(date -d "$date -1 day" +%Y-%m-%d 2>/dev/null)
    local next_date=$(date -d "$date +1 day" +%Y-%m-%d 2>/dev/null)
    
    # 在 PostgreSQL 中建立关联 (如果知识图谱已实现)
    # TODO: 实现知识图谱后启用
    
    log "时序关联: $prev_date ← $date → $next_date"
}

# ============ 主提炼流程 ============
distill() {
    local date="${1:-$(date -d yesterday +%Y-%m-%d)}"
    local log_file="$MEMORY_DIR/$date.md"
    
    log "开始提炼 $date 的知识..."
    echo ""
    
    # 1. 检查日志文件是否存在
    if [[ ! -f "$log_file" ]]; then
        error "日志文件不存在: $log_file"
        return 1
    fi
    
    # 2. 读取日志内容
    local content=$(cat "$log_file")
    local content_kb=$(echo "$content" | wc -c | awk '{print int($1/1024)}')
    
    log "日志大小: ${content_kb}KB"
    
    # 3. 生成摘要
    local summary=""
    if [[ $content_kb -gt 5 ]]; then
        # 大文件使用 AI 摘要
        summary=$(generate_ai_summary "$content" "$date")
    else
        # 小文件使用简单摘要
        summary=$(generate_summary "$log_file" "$date")
    fi
    
    # 4. 保存到知识库
    save_to_knowledge_base "$summary" "$date"
    
    # 5. 建立时序关联
    create_temporal_links "$date"
    
    # 6. 输出摘要预览
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "$summary" | head -20
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    success "知识提炼完成: $date"
}

# ============ 批量提炼 ============
batch_distill() {
    local start_date="${1:-$(date -d '7 days ago' +%Y-%m-%d)}"
    local end_date="${2:-$(date -d yesterday +%Y-%m-%d)}"
    
    log "批量提炼: $start_date 到 $end_date"
    echo ""
    
    local current="$start_date"
    local count=0
    
    while [[ "$current" < "$end_date" ]] || [[ "$current" == "$end_date" ]]; do
        if [[ -f "$MEMORY_DIR/$current.md" ]]; then
            distill "$current"
            ((count++))
            sleep 2  # 避免 API 限流
        fi
        
        current=$(date -d "$current +1 day" +%Y-%m-%d)
    done
    
    echo ""
    success "批量提炼完成: $count 个文件"
}

# ============ 自动提炼 (cron job) ============
auto_distill() {
    log "自动提炼任务启动..."
    
    # 提炼昨天的日志
    local yesterday=$(date -d yesterday +%Y-%m-%d)
    
    distill "$yesterday"
    
    # 记录到日志
    echo "$(date '+%Y-%m-%d %H:%M:%S') - 自动提炼: $yesterday" >> "$WORKSPACE/memory/distill.log"
}

# ============ 状态 ============
status() {
    echo "📚 知识提炼状态"
    echo ""
    
    # 统计已提炼的日志
    local distilled=$(psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -A \
        -c "SELECT COUNT(*) FROM memories WHERE category = 'daily_summary';" 2>/dev/null)
    
    echo "已提炼日志: ${distilled:-0}"
    
    # 最近提炼
    local last_distill=$(psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -A \
        -c "SELECT metadata->>'date' FROM memories WHERE category = 'daily_summary' ORDER BY created_at DESC LIMIT 1;" 2>/dev/null)
    
    echo "最近提炼: ${last_distill:-无}"
    
    # 待提炼日志
    local pending=0
    for log in "$MEMORY_DIR"/????-??-??.md; do
        [[ -f "$log" ]] || continue
        local date=$(basename "$log" .md)
        
        # 检查是否已提炼
        local exists=$(psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -A \
            -c "SELECT COUNT(*) FROM memories WHERE category = 'daily_summary' AND metadata->>'date' = '$date';" 2>/dev/null)
        
        if [[ "$exists" == "0" ]]; then
            ((pending++))
        fi
    done
    
    echo "待提炼日志: $pending"
}

# ============ 帮助 ============
help() {
    cat << EOF
📚 知识提炼引擎 - 自动从日志提炼长期记忆

用法: $0 <command> [args...]

命令:
  distill [date]              - 提炼指定日期的日志 (默认昨天)
  batch <start> <end>         - 批量提炼日期范围
  auto                        - 自动提炼 (用于 cron)
  status                      - 查看提炼状态

示例:
  $0 distill 2026-02-04       # 提炼指定日期
  $0 distill                  # 提炼昨天
  $0 batch 2026-02-01 2026-02-04  # 批量提炼
  $0 auto                     # 自动提炼 (cron)

Cron 配置:
  # 每天凌晨 1 点自动提炼昨天的日志
  0 1 * * * cd $WORKSPACE && $0 auto

工作流程:
  1. 读取每日日志
  2. 提取结构化信息 (事件、决策、学习)
  3. 识别模式和规律
  4. 生成摘要 (AI 或简单)
  5. 保存到 PostgreSQL + MEMORY.md
  6. 建立时序关联

输出:
  - PostgreSQL: memories 表 (category='daily_summary')
  - MEMORY.md: 索引条目
  - Redis: 缓存 (7天)
EOF
}

# ============ 主入口 ============
case "${1:-help}" in
    distill) shift; distill "$@" ;;
    batch) shift; batch_distill "$@" ;;
    auto) auto_distill ;;
    status) status ;;
    help|--help|-h) help ;;
    *)
        error "未知命令: $1"
        echo ""
        help
        exit 1
        ;;
esac
