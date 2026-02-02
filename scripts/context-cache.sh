#!/bin/bash
# context-cache.sh - Agent 上下文缓存系统
# 保存 agent 的分析结果到 Redis，避免重复分析

SOCKET="/tmp/openclaw-agents.sock"
REDIS_PREFIX="openclaw:ctx"
AGENTS=("claude-agent" "gemini-agent" "codex-agent")

# 保存 agent 当前上下文摘要
save_context() {
    local agent="$1"
    local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null)
    
    # 提取关键信息
    local last_100=$(echo "$output" | tail -100)
    
    # 提取已完成的任务
    local completed=$(echo "$last_100" | grep -oE "✓.*|completed|done|finished|提交" | tail -5)
    
    # 提取发现的问题
    local findings=$(echo "$last_100" | grep -oE "Found [0-9]+ matches|发现.*|检测到.*" | tail -5)
    
    # 提取当前进度
    local progress=$(echo "$last_100" | grep -oE "[0-9]+%|进度.*" | tail -1)
    
    # 保存到 Redis
    redis-cli HSET "$REDIS_PREFIX:$agent" \
        "last_output" "${last_100:0:5000}" \
        "completed" "$completed" \
        "findings" "$findings" \
        "progress" "$progress" \
        "saved_at" "$(date +%s)" 2>/dev/null
    
    echo "已保存 $agent 上下文"
}

# 恢复 agent 上下文
restore_context() {
    local agent="$1"
    
    local data=$(redis-cli HGETALL "$REDIS_PREFIX:$agent" 2>/dev/null)
    if [[ -z "$data" ]]; then
        echo "没有找到 $agent 的缓存上下文"
        return 1
    fi
    
    local completed=$(redis-cli HGET "$REDIS_PREFIX:$agent" "completed" 2>/dev/null)
    local findings=$(redis-cli HGET "$REDIS_PREFIX:$agent" "findings" 2>/dev/null)
    local progress=$(redis-cli HGET "$REDIS_PREFIX:$agent" "progress" 2>/dev/null)
    
    echo "=== $agent 上下文恢复 ==="
    echo "已完成: $completed"
    echo "发现: $findings"
    echo "进度: $progress"
    
    # 生成恢复提示
    local restore_prompt="继续之前的工作。上次进度: $progress。已完成: $completed。发现: $findings。不要重复分析，直接继续。"
    echo ""
    echo "恢复提示: $restore_prompt"
}

# 保存所有 agent 上下文
save_all() {
    for agent in "${AGENTS[@]}"; do
        save_context "$agent"
    done
}

# 显示所有缓存
show_all() {
    for agent in "${AGENTS[@]}"; do
        echo "=== $agent ==="
        local saved_at=$(redis-cli HGET "$REDIS_PREFIX:$agent" "saved_at" 2>/dev/null)
        local progress=$(redis-cli HGET "$REDIS_PREFIX:$agent" "progress" 2>/dev/null)
        local completed=$(redis-cli HGET "$REDIS_PREFIX:$agent" "completed" 2>/dev/null)
        
        if [[ -n "$saved_at" ]]; then
            local age=$(($(date +%s) - saved_at))
            echo "  保存时间: ${age}秒前"
            echo "  进度: $progress"
            echo "  已完成: ${completed:0:100}"
        else
            echo "  无缓存"
        fi
        echo ""
    done
}

# 保存 i18n 进度详情
save_i18n_progress() {
    # 获取已处理的模块列表
    local processed=$(cd /mnt/d/ai软件/zed && git log --oneline --since="today" | grep -oE "crates/[a-z_]+" | sort -u)
    
    # 获取所有模块
    local all_modules=$(ls -d /mnt/d/ai软件/zed/crates/*/ 2>/dev/null | xargs -n1 basename | sort)
    
    # 计算未处理的模块
    local remaining=""
    for mod in $all_modules; do
        if ! echo "$processed" | grep -q "$mod"; then
            remaining="$remaining $mod"
        fi
    done
    
    redis-cli HSET "$REDIS_PREFIX:i18n" \
        "processed" "$processed" \
        "remaining" "$remaining" \
        "updated" "$(date +%s)" 2>/dev/null
    
    echo "已保存 i18n 进度"
    echo "已处理: $(echo "$processed" | wc -w) 个模块"
    echo "剩余: $(echo "$remaining" | wc -w) 个模块"
}

# 获取下一个待处理模块
get_next_module() {
    local remaining=$(redis-cli HGET "$REDIS_PREFIX:i18n" "remaining" 2>/dev/null)
    echo "$remaining" | tr ' ' '\n' | grep -v '^$' | head -1
}

case "${1:-help}" in
    save)
        if [[ -n "$2" ]]; then
            save_context "$2"
        else
            save_all
        fi
        ;;
    restore)
        restore_context "$2"
        ;;
    show)
        show_all
        ;;
    i18n)
        save_i18n_progress
        ;;
    next)
        get_next_module
        ;;
    *)
        echo "用法: $0 {save [agent]|restore <agent>|show|i18n|next}"
        ;;
esac
