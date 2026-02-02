#!/bin/bash
# evolution-v4.sh - 自我进化框架 v4
# 核心改进:
# 1. 网络重试状态检测
# 2. 环境问题自动修复
# 3. 更智能的任务分配
# 4. 自动学习和适应

WORKSPACE="/home/jinyang/.openclaw/workspace"
SOCKET="/tmp/openclaw-agents.sock"
REDIS_PREFIX="openclaw:evo"
AGENTS=("claude-agent" "gemini-agent" "codex-agent")

declare -A AGENT_CONFIG=(
    ["claude-agent:cmd"]='ANTHROPIC_AUTH_TOKEN="sk-KwfZ1MFGt3K28O1Osjdd6WpN5fRJde3fUVzGIlUSIL50AYZf" ANTHROPIC_BASE_URL="https://vip.chiddns.com" claude --dangerously-skip-permissions'
    ["claude-agent:workdir"]="/mnt/d/ai软件/zed"
    ["gemini-agent:cmd"]="gemini"
    ["gemini-agent:workdir"]="/mnt/d/ai软件/zed"
    ["codex-agent:cmd"]="/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -Command 'cd D:\\ai软件\\zed; codex'"
    ["codex-agent:workdir"]="/mnt/d/ai软件/zed"
)

# ============ 精准诊断 v4 ============
diagnose_agent() {
    local agent="$1"
    local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null)
    local last_30=$(echo "$output" | tail -30)
    local last_10=$(echo "$output" | tail -10)
    local last_5=$(echo "$output" | tail -5)
    local last_3=$(echo "$output" | tail -3)
    
    # 0. 先检测明确的空闲状态 (最高优先级)
    # 但要排除正在工作的情况
    local is_working=false
    if echo "$last_10" | grep -qE "esc to cancel|esc to interrupt|esc to interr" 2>/dev/null; then
        is_working=true
    fi
    
    if [[ "$is_working" == "false" ]]; then
        # Gemini 空闲: 最后几行有 "Type your message" 且没有进度指示
        if echo "$last_5" | grep -qE "Type your message" 2>/dev/null; then
            echo "idle"; return
        fi
        # Claude 空闲: 最后几行有空的 ❯ 提示符
        if echo "$last_3" | grep -qE "^❯\s*$" 2>/dev/null; then
            echo "idle"; return
        fi
        # Codex 空闲: 最后几行有空的 › 提示符
        if echo "$last_3" | grep -qE "^›\s*$" 2>/dev/null; then
            echo "idle"; return
        fi
    fi

    # 1. 网络重试中 (新增)
    if echo "$last_10" | grep -qE "Trying to reach|Attempt [0-9]+/[0-9]+|Retrying|Reconnecting" 2>/dev/null; then
        echo "network_retry"; return
    fi
    
    # 2. API/连接错误 (严重)
    if echo "$output" | grep -qE "Unable to connect|ERR_BAD_REQUEST|Failed to connect|ECONNREFUSED|ETIMEDOUT" 2>/dev/null; then
        echo "api_failure"; return
    fi
    
    # 2.5. 崩溃检测 (v8 错误、段错误等)
    # 注意：panic 要匹配完整的错误格式，避免误判
    if echo "$last_30" | grep -qE "v8::Promise|SIGSEGV|Segmentation fault|SIGABRT|thread .* panicked|fatal error|FATAL ERROR" 2>/dev/null; then
        echo "crashed"; return
    fi
    
    # 3. 环境问题 (新增) - 命令找不到
    if echo "$last_30" | grep -qE "command not found|No such file or directory|not recognized as" 2>/dev/null; then
        echo "env_error"; return
    fi
    
    # 4. 正在工作 - 有进度指示 (必须在最后几行)
    if echo "$last_10" | grep -qE "esc to interrupt|esc to interr|esc to cancel|Thinking|Working|Searching|Reading|Writing|Shenaniganing|Buffering|Rickrolling|Flowing|Running cargo|Transfiguring|Exploring|Investigating|Analyzing|Processing|Clarifying|Mining|Baking|Navigating|Checking|Compiling|Building|Cogitated|Searching text|Mulling|Limiting|Considering|Enumerating" 2>/dev/null; then
        echo "working"; return
    fi
    
    # 5. 等待用户确认 (各种格式)
    if echo "$last_10" | grep -qE "Allow execution of|Allow once|Yes, I accept|Do you want to proceed|\[y/N\]|\(y/n\)|Waiting for user confirmation|Press Enter to continue" 2>/dev/null; then
        echo "needs_confirm"; return
    fi
    
    # 6. 工具/请求错误
    if echo "$last_10" | grep -qE "Request cancelled|params must have|Something went wrong|Tool execution failed" 2>/dev/null; then
        echo "tool_error"; return
    fi
    
    # 7. Context 低 (<30%)
    local ctx=""
    ctx=$(echo "$output" | grep -oE "[0-9]+% context left" | tail -1 | grep -oE "^[0-9]+")
    if [[ -z "$ctx" ]]; then
        ctx=$(echo "$output" | tr '\n' ' ' | grep -oE "auto-compac[^0-9]*[0-9]+%" | tail -1 | grep -oE "[0-9]+")
    fi
    if [[ -n "$ctx" && "$ctx" -lt 30 ]]; then
        echo "context_low"; return
    fi
    
    # 8. 循环检测 (扩大检测范围到 last_30)
    # 但如果输入框有新任务，说明正在准备执行，不算循环
    local has_pending_task=false
    if echo "$last_5" | grep -qE "^│ > .+[^│]|^❯ .+|^› .+" 2>/dev/null; then
        # 检查是否是有意义的任务（不是单个字符或数字）
        local input_content=$(echo "$last_5" | grep -oE "^│ > .+|^❯ .+|^› .+" | head -1 | sed 's/^[│❯›] > //' | sed 's/^[❯›] //')
        if [[ ${#input_content} -gt 10 ]]; then
            has_pending_task=true
        fi
    fi
    
    if [[ "$has_pending_task" == "false" ]] && echo "$last_30" | grep -qE "loop was detected|infinite loop|repetitive tool calls|potential loop" 2>/dev/null; then
        echo "loop_detected"; return
    fi
    
    # 9. 编译错误 (新增)
    if echo "$last_30" | grep -qE "error\[E[0-9]+\]|cannot find|unresolved import|mismatched types" 2>/dev/null; then
        # 但如果正在工作中，不算错误
        if ! echo "$last_10" | grep -qE "esc to interrupt|esc to interr|esc to cancel" 2>/dev/null; then
            echo "compile_error"; return
        fi
    fi
    
    # 10. Claude 特有: 有输入但未发送
    if echo "$last_5" | grep -qE "^❯ .+" 2>/dev/null; then
        if ! echo "$last_5" | grep -qE "esc to interrupt|bypass permissions" 2>/dev/null; then
            echo "pending_input"; return
        fi
    fi
    
    # 11. Gemini 特有: 输入框有内容
    if echo "$last_5" | grep -qE "^│ > .+[^│]" 2>/dev/null; then
        if ! echo "$last_5" | grep -qE "esc to cancel" 2>/dev/null; then
            echo "pending_input"; return
        fi
    fi
    
    # 12. Codex 特有: 有 › 提示符且有内容
    if echo "$last_5" | grep -qE "^› .+" 2>/dev/null; then
        if echo "$last_5" | grep -qE "Summarize recent|Write tests" 2>/dev/null; then
            echo "idle_with_suggestion"; return
        fi
        # 检查 last_10 是否有工作指示
        if ! echo "$last_10" | grep -qE "esc to interrupt|esc to interr|esc to cancel" 2>/dev/null; then
            echo "pending_input"; return
        fi
    fi
    
    # 13. 空闲 (空提示符)
    if echo "$last_5" | grep -qE "^❯\s*$|^›\s*$|Type your message" 2>/dev/null; then
        echo "idle"; return
    fi
    
    # 14. 刚完成任务
    if echo "$last_30" | grep -qE "Baked for|completed|finished|done|Successfully" 2>/dev/null; then
        if echo "$last_5" | grep -qE "^❯|^›|Type your message" 2>/dev/null; then
            echo "idle"; return
        fi
    fi
    
    echo "unknown"
}

# ============ 修复 v4 ============
repair_agent() {
    local agent="$1"
    local diagnosis="$2"
    
    # 记录诊断
    redis-cli HSET "$REDIS_PREFIX:diag:$agent" "last" "$diagnosis" "time" "$(date +%s)" 2>/dev/null
    
    case "$diagnosis" in
        network_retry)
            # 网络重试中，智能等待
            # Gemini 经常有网络问题，需要更耐心
            local retry_count=$(redis-cli HINCRBY "$REDIS_PREFIX:retry:$agent" "count" 1 2>/dev/null)
            
            # 根据重试次数决定策略
            if [[ "$retry_count" -gt 8 ]]; then
                # 重试太多次，重启会话
                tmux -S "$SOCKET" send-keys -t "$agent" C-c
                sleep 2
                restart_agent "$agent"
                redis-cli HSET "$REDIS_PREFIX:retry:$agent" "count" 0 2>/dev/null
                echo "restarted_after_retry"
            elif [[ "$retry_count" -gt 5 ]]; then
                # 尝试取消当前请求，让 agent 重新开始
                tmux -S "$SOCKET" send-keys -t "$agent" Escape
                sleep 2
                echo "cancelled_retry_$retry_count"
            else
                # 继续等待，网络可能会恢复
                echo "waiting_retry_$retry_count"
            fi
            ;;
        api_failure)
            # API 失败，重启
            tmux -S "$SOCKET" send-keys -t "$agent" C-c
            sleep 2
            restart_agent "$agent"
            echo "restarted"
            ;;
        crashed)
            # 崩溃，重启 CLI
            echo -e "${RED}$agent 崩溃，正在重启...${NC}"
            local cmd="${AGENT_CONFIG[${agent}:cmd]}"
            tmux -S "$SOCKET" send-keys -t "$agent" "$cmd" Enter
            sleep 3
            dispatch_task "$agent"
            echo "crash_recovered"
            ;;
        env_error)
            # 环境错误，尝试修复
            fix_env_error "$agent"
            echo "env_fixed"
            ;;
        needs_confirm)
            # 自动确认
            auto_confirm "$agent"
            # 重置 retry 计数器 (确认成功后)
            redis-cli HSET "$REDIS_PREFIX:retry:$agent" "count" 0 2>/dev/null
            echo "confirmed"
            ;;
        tool_error)
            # 工具错误，发送 Enter 继续
            tmux -S "$SOCKET" send-keys -t "$agent" Enter
            sleep 1
            echo "continued"
            ;;
        context_low)
            # Context 低，重启会话
            restart_agent "$agent"
            echo "context_reset"
            ;;
        loop_detected)
            # 循环检测，先清除输入，再发 Escape 取消，最后派新任务
            # 注意：不要先发 Enter，会把堆积的输入发出去
            
            # 1. 发 Escape 取消当前操作
            tmux -S "$SOCKET" send-keys -t "$agent" Escape
            sleep 1
            
            # 2. 清除输入框 (Gemini 需要更多 BSpace)
            for i in {1..100}; do
                tmux -S "$SOCKET" send-keys -t "$agent" BSpace
            done
            sleep 0.5
            
            # 3. 再发 Ctrl+U 清除整行 (对 Claude/Codex 有效)
            tmux -S "$SOCKET" send-keys -t "$agent" C-u
            sleep 0.3
            
            # 4. 再发一次 Escape 确保退出循环提示
            tmux -S "$SOCKET" send-keys -t "$agent" Escape
            sleep 0.5
            
            # 5. 验证输入框是否清空
            local check_output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p | tail -5)
            if echo "$check_output" | grep -qE "^│ > .+[^│]" 2>/dev/null; then
                # Gemini 输入框还有内容，继续清除
                for i in {1..100}; do
                    tmux -S "$SOCKET" send-keys -t "$agent" BSpace
                done
                sleep 0.3
            fi
            
            dispatch_task "$agent"
            echo "loop_broken"
            ;;
        compile_error)
            # 编译错误，让 agent 自己处理
            # 如果空闲，派修复任务
            if echo "$(tmux -S "$SOCKET" capture-pane -t "$agent" -p | tail -5)" | grep -qE "^❯\s*$|^›\s*$" 2>/dev/null; then
                tmux -S "$SOCKET" send-keys -t "$agent" "修复上面的编译错误" Enter
                echo "fix_dispatched"
            else
                echo "agent_handling"
            fi
            ;;
        pending_input)
            # 检查是否有多行堆积的输入 (Claude 用 ❯, Gemini 用 │ >)
            local input_lines=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null | tail -10 | grep -c "^❯ \|继续之前的任务\|^│ > ")
            if [[ $input_lines -gt 2 ]]; then
                # 多行堆积，先清理
                tmux -S "$SOCKET" send-keys -t "$agent" C-c
                sleep 0.3
                # Gemini 不响应 C-u，用多个 BSpace
                if [[ "$agent" == "gemini-agent" ]]; then
                    for i in {1..50}; do
                        tmux -S "$SOCKET" send-keys -t "$agent" BSpace
                    done
                    sleep 0.3
                else
                    tmux -S "$SOCKET" send-keys -t "$agent" C-u
                    sleep 0.3
                fi
                dispatch_task "$agent"
                echo "cleared_and_dispatched"
            else
                tmux -S "$SOCKET" send-keys -t "$agent" Enter
                echo "input_sent"
            fi
            ;;
        idle|idle_with_suggestion)
            tmux -S "$SOCKET" send-keys -t "$agent" C-u
            sleep 0.3
            dispatch_task "$agent"
            echo "dispatched"
            ;;
        working)
            # 正在工作，重置重试计数
            redis-cli HSET "$REDIS_PREFIX:retry:$agent" "count" 0 2>/dev/null
            echo "no_action"
            ;;
        unknown)
            # 未知状态，尝试诊断
            local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null | tail -30)
            
            # 检查是否有输入框堆积
            if echo "$output" | grep -qE "^│ > .+[^│]|^❯ .+|^› .+" 2>/dev/null; then
                # 有堆积输入，清除后派活
                tmux -S "$SOCKET" send-keys -t "$agent" Escape
                sleep 0.3
                for i in {1..30}; do
                    tmux -S "$SOCKET" send-keys -t "$agent" BSpace
                done
                sleep 0.3
                dispatch_task "$agent"
                echo "cleared_unknown"
            elif echo "$output" | grep -qE "params must have|Something went wrong" 2>/dev/null; then
                # 工具错误，发 Escape 取消
                tmux -S "$SOCKET" send-keys -t "$agent" Escape
                sleep 1
                dispatch_task "$agent"
                echo "error_recovered"
            else
                # 真的不知道，增加 unknown 计数
                local unknown_count=$(redis-cli HINCRBY "$REDIS_PREFIX:unknown:$agent" "count" 1 2>/dev/null)
                if [[ "$unknown_count" -gt 5 ]]; then
                    # 连续 5 次 unknown，重启
                    restart_agent "$agent"
                    redis-cli HSET "$REDIS_PREFIX:unknown:$agent" "count" 0 2>/dev/null
                    echo "restarted_unknown"
                else
                    echo "no_action"
                fi
            fi
            ;;
    esac
}

# ============ 环境修复 (新增) ============
fix_env_error() {
    local agent="$1"
    local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null)
    
    # 检测具体是什么命令找不到
    if echo "$output" | grep -qE "cargo: command not found|cargo: No such file" 2>/dev/null; then
        # cargo 找不到，可能是 PATH 问题
        # 在 WSL 中，需要 source cargo env
        tmux -S "$SOCKET" send-keys -t "$agent" C-c
        sleep 1
        # 告诉 agent 使用完整路径或设置环境
        tmux -S "$SOCKET" send-keys -t "$agent" "注意: cargo 命令找不到。请使用 'source ~/.cargo/env' 或使用完整路径 '~/.cargo/bin/cargo'。继续你的任务。" Enter
    elif echo "$output" | grep -qE "node: command not found" 2>/dev/null; then
        tmux -S "$SOCKET" send-keys -t "$agent" C-c
        sleep 1
        tmux -S "$SOCKET" send-keys -t "$agent" "注意: node 命令找不到。请使用 nvm 或完整路径。继续你的任务。" Enter
    else
        # 通用处理
        tmux -S "$SOCKET" send-keys -t "$agent" C-c
        sleep 1
        tmux -S "$SOCKET" send-keys -t "$agent" "遇到环境问题，请检查命令路径或使用替代方案。继续你的任务。" Enter
    fi
}

# ============ 重启 Agent ============
restart_agent() {
    local agent="$1"
    local cmd="${AGENT_CONFIG[$agent:cmd]}"
    local workdir="${AGENT_CONFIG[$agent:workdir]}"
    
    # 杀掉旧会话
    tmux -S "$SOCKET" kill-session -t "$agent" 2>/dev/null
    sleep 1
    
    # 创建新会话
    tmux -S "$SOCKET" new-session -d -s "$agent" -c "$workdir"
    sleep 1
    tmux -S "$SOCKET" send-keys -t "$agent" "$cmd" Enter
    sleep 8
    auto_confirm "$agent"
    dispatch_task "$agent"
    
    # 记录重启
    redis-cli HINCRBY "$REDIS_PREFIX:stats" "restarts:$agent" 1 2>/dev/null
    "$WORKSPACE/scripts/dashboard.sh" log "重启 $agent" 2>/dev/null
}

# ============ 自动确认 (进化版) ============
auto_confirm() {
    local agent="$1"
    local confirmed=false
    
    for i in {1..15}; do
        sleep 1
        local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p | tail -20)
        local last_5=$(echo "$output" | tail -5)
        
        # 先检查是否有循环检测消息，如果有就不要发送确认
        if echo "$output" | grep -qE "loop was detected|potential loop" 2>/dev/null; then
            # 有循环消息，不要发送 "1"，直接返回让 loop_detected 处理
            return 1
        fi
        
        # 检测各种确认界面并处理
        if echo "$last_5" | grep -qE "Yes, I accept" 2>/dev/null; then
            tmux -S "$SOCKET" send-keys -t "$agent" Down Enter
            confirmed=true
        elif echo "$last_5" | grep -qE "● 1\. Allow once|1\. Allow|Allow execution" 2>/dev/null; then
            # Gemini 多选确认界面 - 选择 2 (Allow for this session) 减少后续确认
            tmux -S "$SOCKET" send-keys -t "$agent" "2" Enter
            confirmed=true
        elif echo "$last_5" | grep -qE "Waiting for user confirmation" 2>/dev/null; then
            # Gemini 等待确认状态 - 发送 2 选择 Allow for this session
            tmux -S "$SOCKET" send-keys -t "$agent" "2" Enter
            confirmed=true
        elif echo "$last_5" | grep -qE "Enter to confirm|Press Enter|Dark mode|Light mode|trust this" 2>/dev/null; then
            tmux -S "$SOCKET" send-keys -t "$agent" Enter
            confirmed=true
        elif echo "$last_5" | grep -qE "\[y/N\]|\(y/n\)" 2>/dev/null; then
            tmux -S "$SOCKET" send-keys -t "$agent" "y" Enter
            confirmed=true
        elif echo "$last_5" | grep -qE "^❯\s*$|^›\s*$|context left|Type your message|esc to interrupt|esc to interr|esc to cancel" 2>/dev/null; then
            # 已经恢复正常，重置 retry 计数器
            redis-cli HSET "$REDIS_PREFIX:retry:$agent" "count" 0 2>/dev/null
            return 0
        fi
        
        # 如果刚确认了，等待一下看是否恢复
        if [[ "$confirmed" == "true" ]]; then
            sleep 2
            local new_output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p | tail -10)
            if echo "$new_output" | grep -qE "^❯\s*$|^›\s*$|context left|Type your message|esc to interrupt|esc to interr|esc to cancel" 2>/dev/null; then
                # 恢复正常，重置 retry 计数器
                redis-cli HSET "$REDIS_PREFIX:retry:$agent" "count" 0 2>/dev/null
                return 0
            fi
            confirmed=false
        fi
    done
    
    # 循环结束还没恢复，可能需要更强力的措施
    # 尝试发送 Escape 取消当前操作
    tmux -S "$SOCKET" send-keys -t "$agent" Escape
    sleep 1
}

# ============ 智能派活 v4 ============
dispatch_task() {
    local agent="$1"
    
    # 0. 先保存当前上下文
    "$WORKSPACE/scripts/context-cache.sh" save "$agent" 2>/dev/null
    
    # 1. 优先从优先级队列获取
    local task=$("$WORKSPACE/scripts/priority-queue.sh" get "$agent" 2>/dev/null)
    
    # 2. 从 Redis 任务队列获取
    if [[ -z "$task" ]]; then
        task=$(redis-cli LPOP "$REDIS_PREFIX:tasks:queue" 2>/dev/null)
    fi
    
    # 3. 获取缓存的上下文信息
    local cached_progress=$(redis-cli HGET "openclaw:ctx:$agent" "progress" 2>/dev/null)
    local cached_findings=$(redis-cli HGET "openclaw:ctx:$agent" "findings" 2>/dev/null)
    
    # 4. 检查是否有未完成的任务需要继续 (防止无限嵌套)
    if [[ -z "$task" ]]; then
        local last_task=$(redis-cli HGET "$REDIS_PREFIX:task:$agent" "current" 2>/dev/null)
        # 只有当 last_task 不包含 "继续之前的任务" 时才添加前缀
        if [[ -n "$last_task" && "$last_task" != "null" && ! "$last_task" =~ "继续之前的任务" ]]; then
            task="继续之前的任务: $last_task"
        fi
    fi
    
    # 5. 获取下一个待处理模块
    if [[ -z "$task" ]]; then
        local next_module=$("$WORKSPACE/scripts/context-cache.sh" next 2>/dev/null)
        if [[ -n "$next_module" ]]; then
            task="国际化 crates/$next_module 模块。直接修改代码，不要分析。完成后提交。"
        fi
    fi
    
    # 6. 使用默认任务
    if [[ -z "$task" ]]; then
        case "$agent" in
            claude-agent)
                task="批量国际化 crates/ 下的模块。用 sed 批量替换硬编码字符串。直接改代码并提交。"
                ;;
            gemini-agent)
                task="国际化 crates/ 下的模块。直接修改代码，不要分析。完成后提交。"
                ;;
            codex-agent)
                task="国际化 crates/ 下的模块。直接修改代码，不要分析。完成后提交。"
                ;;
        esac
    fi
    
    # 7. 如果有缓存的上下文，附加到任务
    if [[ -n "$cached_progress" || -n "$cached_findings" ]]; then
        task="$task (上次进度: $cached_progress, 发现: ${cached_findings:0:100})"
    fi
    
    # 发送任务
    tmux -S "$SOCKET" send-keys -t "$agent" "$task" Enter
    
    # 记录
    redis-cli HSET "$REDIS_PREFIX:task:$agent" "current" "${task:0:100}" "time" "$(date +%s)" 2>/dev/null
    redis-cli HINCRBY "$REDIS_PREFIX:stats" "dispatched:$agent" 1 2>/dev/null
    "$WORKSPACE/scripts/dashboard.sh" log "派发任务给 $agent: ${task:0:50}..." 2>/dev/null
}

# ============ 主检查 ============
run_check() {
    local mode="${1:-quick}"
    local issues=()
    
    for agent in "${AGENTS[@]}"; do
        # 检查会话是否存在
        if ! tmux -S "$SOCKET" has-session -t "$agent" 2>/dev/null; then
            restart_agent "$agent"
            issues+=("$agent:created")
            continue
        fi
        
        local diagnosis=$(diagnose_agent "$agent")
        
        if [[ "$diagnosis" != "working" ]]; then
            local result=$(repair_agent "$agent" "$diagnosis")
            if [[ "$result" != "no_action" ]]; then
                issues+=("$agent:$diagnosis→$result")
                # 自动学习：记录成功的修复
                if [[ "$result" != *"failed"* && "$result" != *"unknown"* ]]; then
                    redis-cli HINCRBY "$REDIS_PREFIX:learn:$diagnosis" "success" 1 2>/dev/null
                    # 记录事件日志
                    redis-cli LPUSH "$REDIS_PREFIX:events" "$(date +%s):$agent:$diagnosis:$result" 2>/dev/null
                    redis-cli LTRIM "$REDIS_PREFIX:events" 0 999 2>/dev/null  # 保留最近 1000 条
                fi
            fi
        else
            # 正在工作，重置计数器
            redis-cli HSET "$REDIS_PREFIX:retry:$agent" "count" 0 2>/dev/null
            redis-cli HSET "$REDIS_PREFIX:unknown:$agent" "count" 0 2>/dev/null
        fi
    done
    
    if [[ ${#issues[@]} -gt 0 ]]; then
        echo "🔧 ${issues[*]}"
    fi
}

# ============ 状态 ============
status() {
    echo "===== Evolution v4 - $(date '+%H:%M:%S') ====="
    for agent in "${AGENTS[@]}"; do
        local diag=$(diagnose_agent "$agent")
        local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null)
        local ctx=$(echo "$output" | grep -oE "[0-9]+% context" | tail -1)
        if [[ -z "$ctx" ]]; then
            ctx=$(echo "$output" | tr '\n' ' ' | grep -oE "auto-compac[^0-9]*[0-9]+%" | tail -1 | sed 's/.*\([0-9]\+%\).*/\1 ctx/')
        fi
        local retry=$(redis-cli HGET "$REDIS_PREFIX:retry:$agent" "count" 2>/dev/null)
        printf "%-14s %-20s %-15s retry:%s\n" "$agent" "$diag" "${ctx:-}" "${retry:-0}"
    done
}

# ============ 学习 (新增) ============
learn() {
    local agent="$1"
    local problem="$2"
    local solution="$3"
    
    # 记录到知识库
    redis-cli HSET "$REDIS_PREFIX:knowledge:$problem" \
        "solution" "$solution" \
        "agent" "$agent" \
        "time" "$(date +%s)" \
        "success" "1" 2>/dev/null
    
    echo "学习记录: $problem → $solution"
}

# ============ 性能报告 (新增) ============
report() {
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                    📊 进化系统性能报告                           ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo ""
    
    # 1. 任务派发统计
    echo "📋 任务派发统计:"
    for agent in "${AGENTS[@]}"; do
        local dispatched=$(redis-cli HGET "$REDIS_PREFIX:stats" "dispatched:$agent" 2>/dev/null)
        local restarts=$(redis-cli HGET "$REDIS_PREFIX:stats" "restarts:$agent" 2>/dev/null)
        printf "  %-14s 派发: %-5s 重启: %s\n" "$agent" "${dispatched:-0}" "${restarts:-0}"
    done
    echo ""
    
    # 2. 学习记录
    echo "🧠 学习记录:"
    for key in $(redis-cli KEYS "$REDIS_PREFIX:learn:*" 2>/dev/null); do
        local problem=$(echo "$key" | sed "s|$REDIS_PREFIX:learn:||")
        local success=$(redis-cli HGET "$key" "success" 2>/dev/null)
        printf "  %-20s 成功修复: %s 次\n" "$problem" "${success:-0}"
    done
    echo ""
    
    # 3. 当前状态
    echo "🔍 当前状态:"
    for agent in "${AGENTS[@]}"; do
        local diag=$(diagnose_agent "$agent")
        local retry=$(redis-cli HGET "$REDIS_PREFIX:retry:$agent" "count" 2>/dev/null)
        local unknown=$(redis-cli HGET "$REDIS_PREFIX:unknown:$agent" "count" 2>/dev/null)
        printf "  %-14s 状态: %-15s retry:%s unknown:%s\n" "$agent" "$diag" "${retry:-0}" "${unknown:-0}"
    done
    echo ""
    
    # 4. 优化建议
    echo "💡 优化建议:"
    local total_restarts=0
    for agent in "${AGENTS[@]}"; do
        local restarts=$(redis-cli HGET "$REDIS_PREFIX:stats" "restarts:$agent" 2>/dev/null)
        total_restarts=$((total_restarts + ${restarts:-0}))
    done
    
    if [[ $total_restarts -gt 10 ]]; then
        echo "  ⚠️ 重启次数过多 ($total_restarts)，考虑检查网络或 API 稳定性"
    fi
    
    local gemini_confirms=$(redis-cli HGET "$REDIS_PREFIX:learn:needs_confirm" "success" 2>/dev/null)
    if [[ ${gemini_confirms:-0} -gt 20 ]]; then
        echo "  ⚠️ Gemini 确认次数过多 ($gemini_confirms)，考虑优化工作流"
    fi
    
    local loop_count=$(redis-cli HGET "$REDIS_PREFIX:learn:loop_detected" "success" 2>/dev/null)
    if [[ ${loop_count:-0} -gt 5 ]]; then
        echo "  ⚠️ 循环检测次数过多 ($loop_count)，考虑改进任务描述"
    fi
    
    echo ""
    echo "报告生成时间: $(date '+%Y-%m-%d %H:%M:%S')"
}

# ============ 趋势分析 (新增) ============
trends() {
    echo "📈 趋势分析 (最近 1 小时):"
    echo ""
    
    # 从 Redis 事件日志分析
    local events=$(redis-cli LRANGE "$REDIS_PREFIX:events" -100 -1 2>/dev/null)
    local confirm_count=0
    local loop_count=0
    local restart_count=0
    
    while IFS= read -r event; do
        if echo "$event" | grep -q "needs_confirm"; then
            ((confirm_count++))
        elif echo "$event" | grep -q "loop_detected"; then
            ((loop_count++))
        elif echo "$event" | grep -q "restart"; then
            ((restart_count++))
        fi
    done <<< "$events"
    
    echo "  确认事件: $confirm_count"
    echo "  循环事件: $loop_count"
    echo "  重启事件: $restart_count"
    echo ""
    
    # 健康评分
    local health_score=100
    health_score=$((health_score - confirm_count * 2))
    health_score=$((health_score - loop_count * 5))
    health_score=$((health_score - restart_count * 10))
    [[ $health_score -lt 0 ]] && health_score=0
    
    echo "  系统健康评分: $health_score/100"
    
    if [[ $health_score -lt 50 ]]; then
        echo "  ⚠️ 系统健康状况不佳，建议检查"
    elif [[ $health_score -lt 80 ]]; then
        echo "  📊 系统运行正常，有改进空间"
    else
        echo "  ✅ 系统运行良好"
    fi
}

# ============ 入口 ============
case "${1:-check}" in
    check) run_check quick ;;
    status) status ;;
    repair) 
        d=$(diagnose_agent "$2")
        r=$(repair_agent "$2" "$d")
        echo "$2: $d → $r"
        ;;
    diagnose)
        diagnose_agent "$2"
        ;;
    learn)
        learn "$2" "$3" "$4"
        ;;
    report)
        report
        ;;
    trends)
        trends
        ;;
    *) echo "用法: $0 {check|status|repair <agent>|diagnose <agent>|learn <agent> <problem> <solution>|report|trends}" ;;
esac

# ============ Agent 专长分析 (新增) ============
analyze_skills() {
    echo "🎯 Agent 专长分析:"
    echo ""
    
    # 从历史任务分析每个 agent 的专长
    for agent in "${AGENTS[@]}"; do
        echo "--- $agent ---"
        local tasks=$(redis-cli LRANGE "$REDIS_PREFIX:task_history:$agent" 0 -1 2>/dev/null)
        
        # 统计任务类型
        local i18n_count=0
        local fix_count=0
        local test_count=0
        local refactor_count=0
        
        while IFS= read -r task; do
            if echo "$task" | grep -qiE "国际化|i18n|翻译"; then
                ((i18n_count++))
            elif echo "$task" | grep -qiE "修复|fix|bug"; then
                ((fix_count++))
            elif echo "$task" | grep -qiE "测试|test"; then
                ((test_count++))
            elif echo "$task" | grep -qiE "重构|refactor"; then
                ((refactor_count++))
            fi
        done <<< "$tasks"
        
        echo "  国际化: $i18n_count"
        echo "  修复: $fix_count"
        echo "  测试: $test_count"
        echo "  重构: $refactor_count"
        echo ""
    done
}
