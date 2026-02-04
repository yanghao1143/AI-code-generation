#!/bin/bash
# knowledge.sh - 统一知识管理接口
# 让知识像"小螃蟹"一样连在一起

WORKSPACE="/home/jinyang/.openclaw/workspace"
SCRIPTS_DIR="$WORKSPACE/scripts"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# ============ 统一搜索 ============
# 跨 Redis + PostgreSQL + 文件系统搜索
search() {
    local query="$1"
    local limit="${2:-10}"
    
    log "搜索: $query"
    echo ""
    
    # 1. PostgreSQL 全文搜索
    echo "📚 长期记忆 (PostgreSQL):"
    "$SCRIPTS_DIR/pg-memory.sh" search "$query" "$limit" 2>/dev/null | head -10
    echo ""
    
    # 2. Redis 实时状态
    echo "💾 实时状态 (Redis):"
    local redis_keys=$(redis-cli KEYS "*$query*" 2>/dev/null | head -5)
    if [[ -n "$redis_keys" ]]; then
        echo "$redis_keys" | while read key; do
            local value=$(redis-cli GET "$key" 2>/dev/null | head -c 100)
            echo "  $key: ${value}..."
        done
    else
        echo "  (无匹配)"
    fi
    echo ""
    
    # 3. 文件系统搜索
    echo "📝 每日日志 (文件系统):"
    grep -r "$query" "$WORKSPACE/memory/"*.md 2>/dev/null | head -5 | while read line; do
        echo "  $line"
    done
    echo ""
    
    # 4. 知识图谱搜索 (如果已实现)
    if [[ -x "$SCRIPTS_DIR/knowledge-graph.sh" ]]; then
        echo "🔗 知识图谱:"
        "$SCRIPTS_DIR/knowledge-graph.sh" find "$query" 2>/dev/null | head -5
    fi
}

# ============ 添加知识 ============
add() {
    local content="$1"
    local category="${2:-general}"
    local importance="${3:-5}"
    
    log "添加知识: ${content:0:50}..."
    
    # 1. 保存到 PostgreSQL
    "$SCRIPTS_DIR/pg-memory.sh" add-memory "$content" "$category" "$importance"
    
    # 2. 如果是高重要度，缓存到 Redis
    if [[ $importance -ge 8 ]]; then
        local key="openclaw:knowledge:important:$(date +%s)"
        redis-cli SETEX "$key" 86400 "$content" > /dev/null
        log "已缓存到 Redis (24h)"
    fi
    
    # 3. 如果知识图谱已实现，添加节点
    if [[ -x "$SCRIPTS_DIR/knowledge-graph.sh" ]]; then
        "$SCRIPTS_DIR/knowledge-graph.sh" add "$content" "$category" "$importance"
    fi
    
    success "知识已添加"
}

# ============ 建立关联 ============
link() {
    local from_id="$1"
    local to_id="$2"
    local link_type="${3:-reference}"
    
    if [[ ! -x "$SCRIPTS_DIR/knowledge-graph.sh" ]]; then
        error "知识图谱未实现"
        return 1
    fi
    
    log "建立关联: $from_id → $to_id ($link_type)"
    "$SCRIPTS_DIR/knowledge-graph.sh" link "$from_id" "$to_id" "$link_type"
    success "关联已建立"
}

# ============ 提炼知识 ============
distill() {
    local date="${1:-$(date -d yesterday +%Y-%m-%d)}"
    
    log "提炼 $date 的知识..."
    
    if [[ ! -x "$SCRIPTS_DIR/knowledge-distill.sh" ]]; then
        error "知识提炼引擎未实现"
        return 1
    fi
    
    "$SCRIPTS_DIR/knowledge-distill.sh" "$date"
}

# ============ 状态报告 ============
status() {
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                    🧠 知识系统状态                               ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo ""
    
    # 1. PostgreSQL 统计
    echo "📚 长期记忆 (PostgreSQL):"
    local pg_status=$("$SCRIPTS_DIR/pg-memory.sh" status 2>/dev/null)
    echo "$pg_status" | grep -E "记忆数量|对话数量|任务数量|决策数量"
    echo ""
    
    # 2. Redis 统计
    echo "💾 实时状态 (Redis):"
    local redis_keys=$(redis-cli DBSIZE 2>/dev/null)
    local redis_memory=$(redis-cli INFO memory 2>/dev/null | grep used_memory_human | cut -d: -f2)
    echo "  Keys: $redis_keys"
    echo "  内存: $redis_memory"
    echo ""
    
    # 3. 文件系统统计
    echo "📝 每日日志:"
    local log_count=$(ls "$WORKSPACE/memory/"*.md 2>/dev/null | wc -l)
    local log_size=$(du -sh "$WORKSPACE/memory/" 2>/dev/null | cut -f1)
    echo "  文件数: $log_count"
    echo "  总大小: $log_size"
    echo ""
    
    # 4. 上下文状态
    echo "🔍 上下文管理:"
    if [[ -x "$SCRIPTS_DIR/context-budget.sh" ]]; then
        "$SCRIPTS_DIR/context-budget.sh" status 2>/dev/null
    else
        "$SCRIPTS_DIR/context-manager.sh" status 2>/dev/null | head -10
    fi
    echo ""
    
    # 5. 错误学习
    echo "🎓 错误学习:"
    if [[ -x "$SCRIPTS_DIR/error-learn.sh" ]]; then
        "$SCRIPTS_DIR/error-learn.sh" status 2>/dev/null
    else
        local error_count=$(redis-cli LLEN "openclaw:errors:list" 2>/dev/null)
        echo "  错误记录: ${error_count:-0}"
    fi
}

# ============ 快速查询 ============
quick() {
    local topic="$1"
    
    case "$topic" in
        today)
            log "今天的工作"
            cat "$WORKSPACE/memory/$(date +%Y-%m-%d).md" 2>/dev/null || echo "今天还没有日志"
            ;;
        yesterday)
            log "昨天的工作"
            cat "$WORKSPACE/memory/$(date -d yesterday +%Y-%m-%d).md" 2>/dev/null || echo "昨天没有日志"
            ;;
        plan)
            log "当前工作计划"
            redis-cli GET "openclaw:work:plan" 2>/dev/null || echo "没有工作计划"
            ;;
        errors)
            log "最近的错误"
            redis-cli LRANGE "openclaw:errors:list" 0 5 2>/dev/null | jq -r '.message' 2>/dev/null || echo "没有错误记录"
            ;;
        important)
            log "重要记忆"
            "$SCRIPTS_DIR/pg-memory.sh" sql "SELECT LEFT(content, 100), importance FROM memories WHERE importance >= 8 ORDER BY created_at DESC LIMIT 5;" 2>/dev/null
            ;;
        *)
            error "未知主题: $topic"
            echo "可用主题: today, yesterday, plan, errors, important"
            ;;
    esac
}

# ============ 帮助 ============
help() {
    cat << EOF
🧠 统一知识管理系统

用法: $0 <command> [args...]

命令:
  search <query> [limit]     - 跨系统搜索知识
  add <content> [cat] [imp]  - 添加知识节点
  link <from> <to> [type]    - 建立知识关联
  distill [date]             - 提炼每日知识
  status                     - 查看系统状态
  quick <topic>              - 快速查询
    - today      今天的工作
    - yesterday  昨天的工作
    - plan       当前计划
    - errors     最近错误
    - important  重要记忆

示例:
  $0 search "上下文管理"
  $0 add "学会了新技能" "learning" 8
  $0 quick today
  $0 distill 2026-02-04

集成脚本:
  - pg-memory.sh       PostgreSQL 记忆管理
  - context-manager.sh 上下文压缩
  - knowledge-graph.sh 知识图谱 (待实现)
  - error-learn.sh     错误学习 (待实现)
EOF
}

# ============ 主入口 ============
case "${1:-help}" in
    search) shift; search "$@" ;;
    add) shift; add "$@" ;;
    link) shift; link "$@" ;;
    distill) shift; distill "$@" ;;
    status) status ;;
    quick) shift; quick "$@" ;;
    help|--help|-h) help ;;
    *)
        error "未知命令: $1"
        echo ""
        help
        exit 1
        ;;
esac
