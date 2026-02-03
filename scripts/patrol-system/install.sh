#!/bin/bash
# install.sh - 安装 Patrol System 到系统 crontab

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 设置执行权限
chmod +x "$SCRIPT_DIR"/*.sh

# 生成 crontab 条目
CRON_ENTRIES="
# Patrol System - 分层巡检架构
# Layer 0+1: 每分钟采集状态并自动修复
* * * * * $SCRIPT_DIR/patrol-collector.sh >/dev/null 2>&1 && $SCRIPT_DIR/patrol-fixer.sh >/dev/null 2>&1

# Layer 2: 每 5 分钟智能决策
*/5 * * * * $SCRIPT_DIR/patrol-brain.sh >/dev/null 2>&1

# Layer 3: 每 5 分钟处理通知
*/5 * * * * $SCRIPT_DIR/patrol-notify.sh >/dev/null 2>&1
"

echo "=== Patrol System Installer ==="
echo ""
echo "Will add the following cron entries:"
echo "$CRON_ENTRIES"
echo ""

read -p "Install to crontab? [y/N] " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # 备份现有 crontab
    crontab -l > /tmp/crontab.bak 2>/dev/null || true
    
    # 移除旧的 patrol 条目
    crontab -l 2>/dev/null | grep -v "patrol-" | grep -v "Patrol System" > /tmp/crontab.new || true
    
    # 添加新条目
    echo "$CRON_ENTRIES" >> /tmp/crontab.new
    
    # 安装
    crontab /tmp/crontab.new
    
    echo "✅ Installed successfully!"
    echo ""
    echo "Current crontab:"
    crontab -l
else
    echo "Cancelled."
fi
