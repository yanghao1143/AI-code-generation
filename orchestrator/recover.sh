#!/bin/bash
# recover.sh - 启动时恢复上下文

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_DIR="/home/jinyang/.openclaw/workspace/memory"

echo "=== OpenClaw 协作系统启动检查 ==="
echo ""

# 1. 检查 Redis
echo "[1/4] 检查 Redis..."
if redis-cli ping > /dev/null 2>&1; then
    echo "  ✓ Redis 正常"
else
    echo "  ✗ Redis 未运行，尝试启动..."
    sudo service redis-server start
    sleep 1
    if redis-cli ping > /dev/null 2>&1; then
        echo "  ✓ Redis 已启动"
    else
        echo "  ✗ Redis 启动失败！降级到纯文件模式"
    fi
fi

# 2. 检查备份目录
echo "[2/4] 检查备份目录..."
if [ -d "$BACKUP_DIR" ]; then
    echo "  ✓ 备份目录存在"
else
    mkdir -p "$BACKUP_DIR"
    echo "  ✓ 已创建备份目录"
fi

# 3. 恢复上下文
echo "[3/4] 恢复上下文..."
ctx=$(redis-cli GET "openclaw:context:current" 2>/dev/null)
if [ -n "$ctx" ] && [ "$ctx" != "(nil)" ]; then
    echo "  ✓ 从 Redis 恢复上下文"
    echo "  摘要: ${ctx:0:100}..."
else
    # 尝试从文件恢复
    if [ -f "$BACKUP_DIR/cache_context_current.json" ]; then
        ctx=$(cat "$BACKUP_DIR/cache_context_current.json")
        redis-cli SET "openclaw:context:current" "$ctx" > /dev/null
        echo "  ✓ 从文件恢复上下文到 Redis"
    else
        echo "  - 无缓存上下文（新会话）"
    fi
fi

# 4. 检查活跃任务
echo "[4/4] 检查未完成任务..."
tasks=$(redis-cli LRANGE "openclaw:tasks:active" 0 -1 2>/dev/null)
if [ -n "$tasks" ]; then
    echo "  发现未完成任务:"
    echo "$tasks" | while read task_id; do
        [ -n "$task_id" ] && echo "    - $task_id"
    done
else
    echo "  - 无未完成任务"
fi

echo ""
echo "=== 启动检查完成 ==="
