#!/bin/bash
# context-feeder.sh - 上下文喂食器
# 定期从 agent 输出中提取有价值的信息，整理后喂给它们

SOCKET="/tmp/openclaw-agents.sock"
REDIS_PREFIX="openclaw:feed"
PROJECT_PATH="/mnt/d/ai软件/zed"
AGENTS=("claude-agent" "gemini-agent" "codex-agent")

# 从 agent 输出中提取有价值的信息
extract_insights() {
    local agent="$1"
    local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null)
    
    # 提取已处理的文件
    local files_modified=$(echo "$output" | grep -oE "crates/[a-z_]+/[a-z_/]+\.rs" | sort -u | tail -20)
    
    # 提取发现的模式
    local patterns=$(echo "$output" | grep -oE '"[A-Z][a-z]+[^"]*"' | sort -u | tail -10)
    
    # 提取错误信息
    local errors=$(echo "$output" | grep -oE "error\[E[0-9]+\].*|Error:.*|failed.*" | tail -5)
    
    # 提取成功的操作
    local successes=$(echo "$output" | grep -oE "✓.*|✔.*|Successfully.*|committed.*" | tail -5)
    
    # 保存到 Redis
    redis-cli HSET "$REDIS_PREFIX:$agent" \
        "files" "$files_modified" \
        "patterns" "$patterns" \
        "errors" "$errors" \
        "successes" "$successes" \
        "extracted_at" "$(date +%s)" 2>/dev/null
}

# 整理所有 agent 的发现，生成共享知识
compile_knowledge() {
    echo "=== 整理共享知识 ==="
    
    # 收集所有已处理的文件
    local all_files=""
    for agent in "${AGENTS[@]}"; do
        local files=$(redis-cli HGET "$REDIS_PREFIX:$agent" "files" 2>/dev/null)
        all_files="$all_files $files"
    done
    
    # 去重
    local unique_files=$(echo "$all_files" | tr ' ' '\n' | sort -u | grep -v '^$')
    local file_count=$(echo "$unique_files" | wc -l)
    
    # 获取已处理的模块
    local processed_modules=$(echo "$unique_files" | grep -oE "crates/[a-z_]+" | sort -u)
    local module_count=$(echo "$processed_modules" | grep -v '^$' | wc -l)
    
    # 获取所有模块
    local all_modules=$(ls -d "$PROJECT_PATH"/crates/*/ 2>/dev/null | wc -l)
    
    # 计算剩余模块
    local remaining_modules=""
    for dir in "$PROJECT_PATH"/crates/*/; do
        local mod=$(basename "$dir")
        if ! echo "$processed_modules" | grep -q "crates/$mod"; then
            remaining_modules="$remaining_modules $mod"
        fi
    done
    
    # 保存共享知识
    redis-cli HSET "$REDIS_PREFIX:shared" \
        "processed_files" "$file_count" \
        "processed_modules" "$module_count" \
        "total_modules" "$all_modules" \
        "remaining" "$remaining_modules" \
        "compiled_at" "$(date +%s)" 2>/dev/null
    
    echo "已处理文件: $file_count"
    echo "已处理模块: $module_count / $all_modules"
    echo "剩余模块: $(echo "$remaining_modules" | wc -w)"
}

# 生成喂食内容
generate_feed() {
    local agent="$1"
    
    # 获取共享知识
    local remaining=$(redis-cli HGET "$REDIS_PREFIX:shared" "remaining" 2>/dev/null)
    local processed=$(redis-cli HGET "$REDIS_PREFIX:shared" "processed_modules" 2>/dev/null)
    local total=$(redis-cli HGET "$REDIS_PREFIX:shared" "total_modules" 2>/dev/null)
    
    # 获取其他 agent 的发现
    local other_findings=""
    for other in "${AGENTS[@]}"; do
        if [[ "$other" != "$agent" ]]; then
            local patterns=$(redis-cli HGET "$REDIS_PREFIX:$other" "patterns" 2>/dev/null)
            if [[ -n "$patterns" ]]; then
                other_findings="$other_findings [$other 发现: ${patterns:0:100}]"
            fi
        fi
    done
    
    # 选择下一个模块
    local next_module=$(echo "$remaining" | tr ' ' '\n' | grep -v '^$' | shuf | head -1)
    
    # 生成喂食内容
    local feed="当前进度: $processed/$total 模块。"
    if [[ -n "$next_module" ]]; then
        feed="$feed 下一个任务: 国际化 crates/$next_module 模块。"
    fi
    if [[ -n "$other_findings" ]]; then
        feed="$feed 其他 agent 发现: ${other_findings:0:200}"
    fi
    feed="$feed 直接修改代码并提交，不要重复分析。"
    
    echo "$feed"
}

# 喂食所有 agent
feed_all() {
    echo "=== 开始喂食 ==="
    
    # 先提取所有 agent 的信息
    for agent in "${AGENTS[@]}"; do
        extract_insights "$agent"
    done
    
    # 整理共享知识
    compile_knowledge
    
    # 检查哪些 agent 空闲
    for agent in "${AGENTS[@]}"; do
        local status=$(cd /home/jinyang/.openclaw/workspace && ./scripts/evolution-v4.sh diagnose "$agent" 2>/dev/null)
        
        if [[ "$status" == "idle" || "$status" == "idle_with_suggestion" ]]; then
            echo "喂食 $agent (状态: $status)"
            local feed=$(generate_feed "$agent")
            
            # 清除输入框并发送
            tmux -S "$SOCKET" send-keys -t "$agent" C-u 2>/dev/null
            sleep 0.2
            tmux -S "$SOCKET" send-keys -t "$agent" "$feed" Enter 2>/dev/null
            
            # 记录
            redis-cli HSET "$REDIS_PREFIX:$agent" "last_feed" "$feed" "fed_at" "$(date +%s)" 2>/dev/null
        else
            echo "$agent 正在工作 (状态: $status)，跳过"
        fi
    done
}

# 显示状态
show_status() {
    echo "=== 喂食器状态 ==="
    echo ""
    
    # 共享知识
    local processed=$(redis-cli HGET "$REDIS_PREFIX:shared" "processed_modules" 2>/dev/null)
    local total=$(redis-cli HGET "$REDIS_PREFIX:shared" "total_modules" 2>/dev/null)
    local remaining=$(redis-cli HGET "$REDIS_PREFIX:shared" "remaining" 2>/dev/null)
    
    echo "📊 整体进度: $processed/$total 模块"
    echo "📋 剩余模块: $(echo "$remaining" | wc -w) 个"
    echo ""
    
    # 各 agent 状态
    for agent in "${AGENTS[@]}"; do
        local extracted=$(redis-cli HGET "$REDIS_PREFIX:$agent" "extracted_at" 2>/dev/null)
        local fed=$(redis-cli HGET "$REDIS_PREFIX:$agent" "fed_at" 2>/dev/null)
        local files=$(redis-cli HGET "$REDIS_PREFIX:$agent" "files" 2>/dev/null | wc -w)
        
        echo "--- $agent ---"
        if [[ -n "$extracted" ]]; then
            local age=$(($(date +%s) - extracted))
            echo "  上次提取: ${age}秒前"
            echo "  处理文件: $files 个"
        else
            echo "  未提取"
        fi
        if [[ -n "$fed" ]]; then
            local fed_age=$(($(date +%s) - fed))
            echo "  上次喂食: ${fed_age}秒前"
        fi
        echo ""
    done
}

case "${1:-help}" in
    extract)
        for agent in "${AGENTS[@]}"; do
            extract_insights "$agent"
            echo "已提取 $agent"
        done
        ;;
    compile)
        compile_knowledge
        ;;
    feed)
        feed_all
        ;;
    status)
        show_status
        ;;
    generate)
        generate_feed "$2"
        ;;
    *)
        echo "用法: $0 {extract|compile|feed|status|generate <agent>}"
        ;;
esac
