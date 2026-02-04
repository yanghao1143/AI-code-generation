#!/bin/bash
# Nightly Build - 好大儿的夜间构建脚本
# 在 jinyang 睡觉时运行，做一件有价值的事

set -e

WORKSPACE="/home/jinyang/.openclaw/workspace"
LOG_FILE="$WORKSPACE/memory/nightly-build.log"
DATE=$(date +%Y-%m-%d)
TIME=$(date +%H:%M:%S)

log() {
    echo "[$DATE $TIME] $1" >> "$LOG_FILE"
    echo "$1"
}

# 检查是否在合适的时间运行 (23:00 - 07:00)
HOUR=$(date +%H)
if [ "$HOUR" -ge 7 ] && [ "$HOUR" -lt 23 ]; then
    log "⚠️ 不在夜间时段 (23:00-07:00)，跳过"
    exit 0
fi

log "🌙 Nightly Build 开始"

# 任务 1: 检查 workspace 健康状态
log "📊 检查 workspace 状态..."
MEMORY_FILES=$(find "$WORKSPACE/memory" -name "*.md" | wc -l)
ARCHIVE_SIZE=$(du -sh "$WORKSPACE/archive" 2>/dev/null | cut -f1 || echo "0")
log "  - Memory 文件数: $MEMORY_FILES"
log "  - Archive 大小: $ARCHIVE_SIZE"

# 任务 2: 检查 Redis 连接
log "🔗 检查 Redis..."
if redis-cli ping > /dev/null 2>&1; then
    log "  - Redis: ✅ 连接正常"
else
    log "  - Redis: ❌ 连接失败"
fi

# 任务 3: 检查 PostgreSQL 连接
log "🐘 检查 PostgreSQL..."
if PGPASSWORD=openclaw123 psql -h localhost -U openclaw -d openclaw -c "SELECT 1" > /dev/null 2>&1; then
    log "  - PostgreSQL: ✅ 连接正常"
else
    log "  - PostgreSQL: ❌ 连接失败"
fi

# 任务 4: 清理临时文件
log "🧹 清理临时文件..."
CLEANED=$(find /tmp -name "oc_*.txt" -mtime +1 -delete -print 2>/dev/null | wc -l)
log "  - 清理了 $CLEANED 个旧临时文件"

# 任务 5: 生成每日摘要
log "📝 生成每日摘要..."
DAILY_LOG="$WORKSPACE/memory/$DATE.md"
if [ -f "$DAILY_LOG" ]; then
    LINES=$(wc -l < "$DAILY_LOG")
    log "  - 今日日志: $LINES 行"
fi

log "🌙 Nightly Build 完成"
log "---"

# 输出摘要
echo ""
echo "=== Nightly Build 摘要 ==="
echo "时间: $DATE $TIME"
echo "Memory 文件: $MEMORY_FILES"
echo "清理临时文件: $CLEANED"
echo "=========================="
