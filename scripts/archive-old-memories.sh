#!/bin/bash
# archive-old-memories.sh - 归档旧记忆，提取重要内容到 MEMORY.md
# 用法: ./archive-old-memories.sh [天数，默认30]

set -e

DAYS_OLD="${1:-30}"
WORKSPACE_DIR="${OPENCLAW_DIR:-$HOME/.openclaw}/workspace"
MEMORY_DIR="$WORKSPACE_DIR/memory"
ARCHIVE_DIR="$MEMORY_DIR/archive"
MEMORY_FILE="$WORKSPACE_DIR/MEMORY.md"
TIMESTAMP=$(date +%Y-%m-%d_%H%M%S)

# 颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[archive]${NC} $1"; }
warn() { echo -e "${YELLOW}[archive]${NC} $1"; }

# 创建归档目录
mkdir -p "$ARCHIVE_DIR"

log "扫描 $DAYS_OLD 天前的记忆文件..."

# 找到需要归档的文件（排除 archive 目录和非日期格式的文件）
OLD_FILES=$(find "$MEMORY_DIR" -maxdepth 1 -name "*.md" -type f -mtime +$DAYS_OLD 2>/dev/null | grep -E '[0-9]{4}-[0-9]{2}-[0-9]{2}' || true)

if [ -z "$OLD_FILES" ]; then
    log "没有找到需要归档的文件（$DAYS_OLD 天内）"
    exit 0
fi

log "找到以下文件需要归档："
echo "$OLD_FILES"

# 处理每个文件
for file in $OLD_FILES; do
    filename=$(basename "$file")
    log "处理: $filename"
    
    # 读取文件内容（限制大小）
    content=$(head -200 "$file")
    
    # 尝试用 LLM 生成摘要（如果有 oracle 命令）
    summary=""
    if command -v oracle &> /dev/null; then
        log "  生成摘要..."
        summary=$(echo "$content" | oracle -p "请用 3-5 句话总结以下日志的重要内容（决策、教训、待办）。如果没有重要内容，回复'无重要内容'。

日志内容：
$content" 2>/dev/null || echo "")
    fi
    
    # 如果有重要摘要，追加到 MEMORY.md
    if [ -n "$summary" ] && [ "$summary" != "无重要内容" ]; then
        log "  追加摘要到 MEMORY.md"
        echo "" >> "$MEMORY_FILE"
        echo "### 归档摘要 - $filename" >> "$MEMORY_FILE"
        echo "$summary" >> "$MEMORY_FILE"
        echo "" >> "$MEMORY_FILE"
    fi
    
    # 移动到归档目录
    mv "$file" "$ARCHIVE_DIR/"
    log "  已归档到: archive/$filename"
done

log "✅ 归档完成！"
log "  归档目录: $ARCHIVE_DIR"
log "  摘要已追加到: $MEMORY_FILE"
