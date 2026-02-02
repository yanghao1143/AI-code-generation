#!/bin/bash
# progress-tracker.sh - 项目进度追踪器
# 自动追踪 i18n 进度并记录到 Redis

PROJECT_PATH="/mnt/d/ai软件/zed"
REDIS_PREFIX="openclaw:progress"

# 快速计算 i18n 进度
calc_i18n_progress() {
    cd "$PROJECT_PATH" || return
    
    local total_strings=$(grep -r "\.to_string()" crates/*/src 2>/dev/null | wc -l)
    local i18n_strings=$(grep -r 't("' crates/*/src 2>/dev/null | wc -l)
    local total=$((total_strings + i18n_strings))
    
    if [[ $total -gt 0 ]]; then
        local percent=$((i18n_strings * 100 / total))
        echo "$i18n_strings/$total ($percent%)"
        
        # 记录到 Redis
        redis-cli HSET "$REDIS_PREFIX:i18n" \
            "total" "$total" \
            "done" "$i18n_strings" \
            "percent" "$percent" \
            "time" "$(date +%s)" 2>/dev/null
        
        # 记录历史
        redis-cli LPUSH "$REDIS_PREFIX:i18n:history" "$(date +%s):$percent" 2>/dev/null
        redis-cli LTRIM "$REDIS_PREFIX:i18n:history" 0 99 2>/dev/null
    fi
}

# 显示进度报告
show_progress() {
    echo "📊 项目进度报告"
    echo "==============="
    echo ""
    
    # i18n 进度
    local i18n_data=$(redis-cli HGETALL "$REDIS_PREFIX:i18n" 2>/dev/null)
    if [[ -n "$i18n_data" ]]; then
        local done=$(redis-cli HGET "$REDIS_PREFIX:i18n" "done" 2>/dev/null)
        local total=$(redis-cli HGET "$REDIS_PREFIX:i18n" "total" 2>/dev/null)
        local percent=$(redis-cli HGET "$REDIS_PREFIX:i18n" "percent" 2>/dev/null)
        echo "🌐 国际化进度: $done/$total ($percent%)"
        
        # 进度条
        local bar_len=30
        local filled=$((percent * bar_len / 100))
        local empty=$((bar_len - filled))
        printf "   ["
        for ((i=0; i<filled; i++)); do printf "#"; done
        for ((i=0; i<empty; i++)); do printf "-"; done
        printf "]\n"
    else
        echo "🌐 国际化进度: 未知 (运行 $0 update 更新)"
    fi
    echo ""
    
    # 今日提交
    cd "$PROJECT_PATH" 2>/dev/null
    local today_commits=$(git log --oneline --since="00:00" 2>/dev/null | wc -l)
    echo "📝 今日提交: $today_commits"
    
    # 最近提交
    echo ""
    echo "📋 最近提交:"
    git log --oneline -5 2>/dev/null | while read -r line; do
        echo "   $line"
    done
}

# 趋势分析
show_trends() {
    echo "📈 进度趋势 (最近 10 次记录):"
    echo ""
    
    local history=$(redis-cli LRANGE "$REDIS_PREFIX:i18n:history" 0 9 2>/dev/null)
    
    if [[ -n "$history" ]]; then
        echo "$history" | while read -r record; do
            local ts=$(echo "$record" | cut -d: -f1)
            local percent=$(echo "$record" | cut -d: -f2)
            local date=$(date -d "@$ts" '+%m-%d %H:%M' 2>/dev/null || date -r "$ts" '+%m-%d %H:%M' 2>/dev/null)
            printf "   %s: %s%%\n" "$date" "$percent"
        done
    else
        echo "   暂无历史数据"
    fi
}

case "${1:-show}" in
    update)
        echo "更新进度..."
        calc_i18n_progress
        ;;
    show)
        show_progress
        ;;
    trends)
        show_trends
        ;;
    *)
        echo "用法: $0 {update|show|trends}"
        ;;
esac
