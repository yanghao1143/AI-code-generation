#!/bin/bash
# 每次心跳时自动记录上下文状态
# 400 发生后可以查看最后的快照

SNAPSHOT_FILE="$HOME/.openclaw/workspace/memory/context-snapshots.log"

# 获取当前时间
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# 记录（保留最近 50 条）
echo "[$TIMESTAMP] $1" >> "$SNAPSHOT_FILE"
tail -50 "$SNAPSHOT_FILE" > "$SNAPSHOT_FILE.tmp" && mv "$SNAPSHOT_FILE.tmp" "$SNAPSHOT_FILE"
