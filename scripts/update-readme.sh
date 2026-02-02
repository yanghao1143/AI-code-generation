#!/bin/bash
# update-readme.sh - 自动更新 README.md 的开发进度
# 每次重要提交后调用

WORKSPACE="/home/jinyang/.openclaw/workspace"
README="$WORKSPACE/README.md"

# 获取最新提交信息
get_recent_commits() {
    cd "$WORKSPACE"
    git log --oneline -5 --format="- \`%h\` %s" 2>/dev/null
}

# 获取当前日期
TODAY=$(date +%Y-%m-%d)
NOW=$(date "+%Y-%m-%d %H:%M")

# 更新最后更新时间
update_timestamp() {
    sed -i "s/\*最后更新:.*/\*最后更新: $NOW\*/" "$README"
}

# 获取统计信息
get_stats() {
    cd "$WORKSPACE"
    local commits=$(git rev-list --count HEAD 2>/dev/null || echo "?")
    local recoveries=$(redis-cli HGET openclaw:deadlock:stats total_recoveries 2>/dev/null || echo "0")
    echo "commits=$commits recoveries=$recoveries"
}

# 主逻辑
case "${1:-update}" in
    update)
        echo "📝 更新 README.md"
        update_timestamp
        echo "✅ 时间戳已更新: $NOW"
        ;;
    
    stats)
        get_stats
        ;;
    
    commits)
        get_recent_commits
        ;;
    
    *)
        echo "用法: $0 [update|stats|commits]"
        ;;
esac
