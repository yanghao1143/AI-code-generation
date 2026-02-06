#!/bin/bash
# memory-stats.sh - 统计记忆文件的年龄、大小、访问频率
# 来自 @employee1

MEMORY_DIR="${1:-$HOME/.openclaw/workspace/memory}"
WORKSPACE_ROOT="${2:-$HOME/.openclaw/workspace}"

echo "=== 记忆统计报告 ==="
echo "生成时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "扫描目录: $MEMORY_DIR"
echo ""

if [ ! -d "$MEMORY_DIR" ]; then
    echo "目录不存在: $MEMORY_DIR"
    exit 1
fi

echo "--- 文件列表 (按修改时间排序) ---"
printf "%-40s %10s %12s %s\n" "文件名" "大小" "修改天数" "建议"

total_size=0
total_files=0

while IFS= read -r file; do
    [ -z "$file" ] && continue
    
    filename=$(basename "$file")
    size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)
    size_kb=$((size / 1024))
    
    mod_time=$(stat -c%Y "$file" 2>/dev/null || stat -f%m "$file" 2>/dev/null)
    now=$(date +%s)
    age_days=$(( (now - mod_time) / 86400 ))
    
    suggestion="保留"
    [ $age_days -gt 90 ] && suggestion="考虑归档"
    [ $age_days -gt 30 ] && [ $age_days -le 90 ] && suggestion="考虑压缩"
    [ $size -gt 51200 ] && suggestion="$suggestion (大文件)"
    
    printf "%-40s %8dKB %10d天 %s\n" "$filename" "$size_kb" "$age_days" "$suggestion"
    
    total_size=$((total_size + size))
    total_files=$((total_files + 1))
done < <(find "$MEMORY_DIR" -type f -name "*.md" | sort)

echo ""
echo "--- 汇总 ---"
echo "文件总数: $total_files"
echo "总大小: $((total_size / 1024)) KB"
echo ""

echo "--- 核心文件状态 ---"
for core_file in MEMORY.md SOUL.md IDENTITY.md USER.md; do
    full_path="$WORKSPACE_ROOT/$core_file"
    if [ -f "$full_path" ]; then
        size=$(stat -c%s "$full_path" 2>/dev/null || stat -f%z "$full_path" 2>/dev/null)
        echo "✓ $core_file (${size}B) - 永不衰减"
    else
        echo "✗ $core_file - 不存在"
    fi
done

echo "=== 报告结束 ==="
