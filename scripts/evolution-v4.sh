#!/bin/bash
# evolution-v4.sh - 自我进化框架 v4
# 核心改进:
# 1. 网络重试状态检测
# 2. 环境问题自动修复
# 3. 更智能的任务分配
# 4. 自动学习和适应
# 5. 自动 WSL/Windows 路径转换

WORKSPACE="/home/jinyang/.openclaw/workspace"
SOCKET="/tmp/openclaw-agents.sock"
REDIS_PREFIX="openclaw:evo"
AGENTS=("claude-agent" "gemini-agent" "codex-agent")

# ============ 环境检测 v4 ============

# 检测是否在 WSL 环境中
is_wsl() {
    [[ -f /proc/version ]] && grep -qiE "(microsoft|wsl)" /proc/version 2>/dev/null
}

# 检测 WSL 版本 (1 或 2)
get_wsl_version() {
    if [[ -f /proc/version ]]; then
        if grep -qiE "microsoft.*WSL2|WSL2" /proc/version 2>/dev/null; then
            echo "2"
        elif grep -qiE "microsoft|wsl" /proc/version 2>/dev/null; then
            echo "1"
        else
            echo "0"
        fi
    else
        echo "0"
    fi
}

# 将 Linux/WSL 路径转换为 Windows 路径
# /mnt/c/Users/... -> C:\Users\...
# /mnt/d/ai软件/zed -> D:\ai软件\zed
linux_to_windows_path() {
    local linux_path="$1"
    local win_path=""

    # 检查是否是 /mnt/X/... 格式
    if [[ "$linux_path" =~ ^/mnt/([a-zA-Z])(/.*)?$ ]]; then
        local drive="${BASH_REMATCH[1]^^}"  # 转大写
        local rest="${BASH_REMATCH[2]}"
        # 将 / 替换为 \
        rest="${rest//\//\\}"
        win_path="${drive}:${rest}"
    # 检查是否已经是 Windows 路径格式
    elif [[ "$linux_path" =~ ^[A-Za-z]:\\ ]]; then
        win_path="$linux_path"
    # 其他情况尝试使用 wslpath (如果可用)
    elif command -v wslpath &>/dev/null; then
        win_path=$(wslpath -w "$linux_path" 2>/dev/null)
    else
        # 无法转换，返回原路径
        win_path="$linux_path"
    fi

    echo "$win_path"
}

# 将 Windows 路径转换为 Linux/WSL 路径
# C:\Users\... -> /mnt/c/Users/...
# D:\ai软件\zed -> /mnt/d/ai软件/zed
windows_to_linux_path() {
    local win_path="$1"
    local linux_path=""

    # 检查是否是 X:\... 或 X:/... 格式
    if [[ "$win_path" =~ ^([A-Za-z]):[/\\](.*)$ ]]; then
        local drive="${BASH_REMATCH[1],,}"  # 转小写
        local rest="${BASH_REMATCH[2]}"
        # 将 \ 替换为 /
        rest="${rest//\\//}"
        linux_path="/mnt/${drive}/${rest}"
    # 检查是否已经是 Linux 路径格式
    elif [[ "$win_path" =~ ^/ ]]; then
        linux_path="$win_path"
    # 其他情况尝试使用 wslpath (如果可用)
    elif command -v wslpath &>/dev/null; then
        linux_path=$(wslpath -u "$win_path" 2>/dev/null)
    else
        # 无法转换，返回原路径
        linux_path="$win_path"
    fi

    echo "$linux_path"
}

# 为 PowerShell 转义路径 (双反斜杠)
escape_for_powershell() {
    local path="$1"
    # 将单反斜杠替换为双反斜杠
    echo "${path//\\/\\\\}"
}

# 转换文本中的所有 Linux 路径为 Windows 路径
# 用于在发送任务给 Codex 时自动转换路径
convert_paths_in_text() {
    local text="$1"
    local result="$text"

    # 匹配 /mnt/X/... 格式的路径 (贪婪匹配到空格或引号)
    # 使用 sed 替换所有匹配的路径
    while [[ "$result" =~ (/mnt/[a-zA-Z](/[^[:space:]\"\']*)) ]]; do
        local linux_path="${BASH_REMATCH[1]}"
        local win_path=$(linux_to_windows_path "$linux_path")
        # 替换时需要转义特殊字符
        result="${result//$linux_path/$win_path}"
    done

    # 处理 crates/xxx 相对路径 - 转换为完整 Windows 路径
    # 例如: crates/terminal -> D:\ai软件\zed\crates\terminal
    local base_win=$(linux_to_windows_path "/mnt/d/ai软件/zed")

    # 使用更可靠的方法：用 sed 替换所有 crates/xxx 模式
    # 但要避免替换已经转换过的路径 (不含 \crates\)
    local temp_result=""
    local IFS=' '
    for word in $result; do
        if [[ "$word" =~ ^crates/([a-zA-Z_0-9]+)(.*)$ ]]; then
            local module="${BASH_REMATCH[1]}"
            local suffix="${BASH_REMATCH[2]}"
            # 构建 Windows 路径
            temp_result+="${base_win}\\crates\\${module}${suffix} "
        else
            temp_result+="${word} "
        fi
    done
    # 去掉末尾空格
    result="${temp_result% }"

    echo "$result"
}

# 获取适合当前环境的工作目录
get_workdir() {
    local agent="$1"
    local base_path="/mnt/d/ai软件/zed"

    case "$agent" in
        codex-agent)
            # Codex 通过 PowerShell 运行，需要 Windows 路径
            linux_to_windows_path "$base_path"
            ;;
        *)
            # 其他 agent 使用 Linux 路径
            echo "$base_path"
            ;;
    esac
}

# 构建 Codex 启动命令
build_codex_cmd() {
    local workdir="$1"
    local win_workdir=$(linux_to_windows_path "$workdir")
    local escaped_workdir=$(escape_for_powershell "$win_workdir")

    # 检测 PowerShell 路径
    local ps_path="/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"
    if [[ ! -x "$ps_path" ]]; then
        # 尝试 pwsh (PowerShell Core)
        ps_path=$(command -v pwsh.exe 2>/dev/null || echo "/mnt/c/Program Files/PowerShell/7/pwsh.exe")
    fi

    echo "$ps_path -Command 'cd ${escaped_workdir}; codex'"
}

# 动态初始化 Agent 配置
init_agent_config() {
    local base_workdir="/mnt/d/ai软件/zed"

    # Claude agent
    AGENT_CONFIG["claude-agent:cmd"]='ANTHROPIC_API_KEY="sk-MgjQOD5s4xdnBfueHBgAiCxrtvgfN0xU1J24SyRIl1JUMUu2" ANTHROPIC_BASE_URL="https://claude.chiddns.com" claude --dangerously-skip-permissions'
    AGENT_CONFIG["claude-agent:workdir"]="$base_workdir"

    # Gemini agent
    AGENT_CONFIG["gemini-agent:cmd"]="gemini"
    AGENT_CONFIG["gemini-agent:workdir"]="$base_workdir"

    # Codex agent - 动态构建命令
    if is_wsl; then
        AGENT_CONFIG["codex-agent:cmd"]=$(build_codex_cmd "$base_workdir")
        # Codex workdir 仍然用 Linux 路径 (tmux 需要)
        AGENT_CONFIG["codex-agent:workdir"]="$base_workdir"
    else
        # 非 WSL 环境，直接使用 codex
        AGENT_CONFIG["codex-agent:cmd"]="codex"
        AGENT_CONFIG["codex-agent:workdir"]="$base_workdir"
    fi

    # 日志输出当前配置
    if [[ "${DEBUG:-}" == "1" ]]; then
        echo "[DEBUG] WSL detected: $(is_wsl && echo 'yes' || echo 'no')"
        echo "[DEBUG] WSL version: $(get_wsl_version)"
        echo "[DEBUG] Codex cmd: ${AGENT_CONFIG[codex-agent:cmd]}"
    fi
}

# 声明关联数组并初始化
declare -A AGENT_CONFIG
init_agent_config

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
    
    # 4. 等待用户确认 (优先于 working 检测)
    # 包括 Codex 的 "Yes, proceed (y)" 确认界面
    if echo "$last_10" | grep -qE "Allow execution of|Allow once|Yes, I accept|Do you want to proceed|\[y/N\]|\(y/n\)|Waiting for user confirmation|Press Enter to continue|Yes, proceed|Press enter to confirm" 2>/dev/null; then
        echo "needs_confirm"; return
    fi
    
    # 5. 正在工作 - 有进度指示 (必须在最后几行)
    # 注意：Cogitated/Churned/Baked 表示已完成，不是正在工作
    if echo "$last_10" | grep -qE "esc to interrupt|esc to interr|esc to cancel" 2>/dev/null; then
        echo "working"; return
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
    # 检查是否有 ❯ 后面跟着实际内容（不是空的）
    if echo "$last_10" | grep -qE "^❯ .{5,}" 2>/dev/null; then
        # 有输入内容，检查是否正在执行
        if ! echo "$last_5" | grep -qE "esc to interrupt|esc to interr|esc to cancel" 2>/dev/null; then
            # 没有在执行，说明输入还没发送
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
            local last_5=$(echo "$output" | tail -5)
            
            # 检查是否是空闲状态（空提示符）
            if echo "$last_5" | grep -qE "^❯$|^❯ *$|^›$|^› *$|Type your message" 2>/dev/null; then
                # 空闲，直接派活
                dispatch_task "$agent"
                echo "idle_dispatched"
            # 检查是否有输入框堆积
            elif echo "$output" | grep -qE "^│ > .+[^│]|^❯ .+|^› .+" 2>/dev/null; then
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

    # 检测具体的环境错误类型
    if echo "$output" | grep -qE "cannot find path|路径不存在|The system cannot find the path" 2>/dev/null; then
        # 路径错误 - 可能是 Windows/Linux 路径混淆
        echo "检测到路径错误，尝试修复 $agent 配置..."

        # 重新初始化配置 (会重新计算路径)
        init_agent_config

        # 发送正确的 cd 命令
        if [[ "$agent" == "codex-agent" ]] && is_wsl; then
            local win_path=$(get_workdir "$agent")
            local escaped_path=$(escape_for_powershell "$win_path")
            tmux -S "$SOCKET" send-keys -t "$agent" "cd '$escaped_path'" Enter
            sleep 1
        fi
    elif echo "$output" | grep -qE "codex.*not found|command not found.*codex" 2>/dev/null; then
        # Codex 命令找不到 - 可能需要完整路径
        echo "检测到 codex 命令找不到，尝试使用完整路径..."
        if is_wsl; then
            # 尝试通过 PowerShell 查找 codex
            tmux -S "$SOCKET" send-keys -t "$agent" 'Get-Command codex -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source' Enter
            sleep 2
        fi
    fi

    # env_error 通常是 bash 层面的问题，不是 CLI 内部问题
    # 最好的处理方式是重启会话
    echo "检测到环境错误，重启 $agent 会话..."
    restart_agent "$agent"
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
    
    # 6. 使用喂食器生成的任务
    if [[ -z "$task" ]]; then
        task=$("$WORKSPACE/scripts/context-feeder.sh" generate "$agent" 2>/dev/null)
    fi
    
    # 7. 使用默认任务 - 具体命令，不要分析
    if [[ -z "$task" ]]; then
        # 从待处理模块列表取一个
        local next_mod=$(redis-cli HGET "openclaw:ctx:i18n" "remaining" 2>/dev/null | tr ' ' '\n' | shuf | head -1)
        next_mod=${next_mod:-terminal}
        
        case "$agent" in
            claude-agent)
                task="国际化 crates/$next_mod，用 t!() 包裹硬编码字符串，完成后 git commit"
                ;;
            gemini-agent)
                task="国际化 crates/$next_mod，完成后 git commit"
                ;;
            codex-agent)
                task="国际化 crates/$next_mod，完成后 git commit"
                ;;
        esac
    fi
    
    # 7. 如果有缓存的上下文，附加到任务
    if [[ -n "$cached_progress" || -n "$cached_findings" ]]; then
        task="$task (上次进度: $cached_progress, 发现: ${cached_findings:0:100})"
    fi

    # 8. 为 Codex agent 转换路径 (WSL -> Windows)
    local task_to_send="$task"
    if [[ "$agent" == "codex-agent" ]] && is_wsl; then
        task_to_send=$(convert_paths_in_text "$task")
        if [[ "$task_to_send" != "$task" ]]; then
            echo "[dispatch] 路径已转换为 Windows 格式"
        fi
    fi

    # 发送任务 (加延迟确保 Enter 生效)
    echo "[dispatch] 发送任务给 $agent: ${task_to_send:0:50}..."
    tmux -S "$SOCKET" send-keys -t "$agent" "$task_to_send"
    sleep 0.5
    tmux -S "$SOCKET" send-keys -t "$agent" Enter
    sleep 0.3
    # 再发一次 Enter 确保
    tmux -S "$SOCKET" send-keys -t "$agent" Enter
    sleep 0.2
    # 第三次 Enter
    tmux -S "$SOCKET" send-keys -t "$agent" Enter
    
    # 记录
    redis-cli HSET "$REDIS_PREFIX:task:$agent" "current" "${task:0:100}" "time" "$(date +%s)" 2>/dev/null
    redis-cli HINCRBY "$REDIS_PREFIX:stats" "dispatched:$agent" 1 2>/dev/null
    "$WORKSPACE/scripts/dashboard.sh" log "派发任务给 $agent: ${task:0:50}..." 2>/dev/null
}

# ============ 主检查 ============
run_check() {
    local mode="${1:-quick}"
    local issues=()
    
    # 先提取所有 agent 的上下文
    "$WORKSPACE/scripts/context-feeder.sh" extract 2>/dev/null
    
    # 检测产出：如果 5 分钟没有新提交，说明 agent 出工不出力
    local last_commit_time=$(redis-cli GET "openclaw:metrics:commit_time" 2>/dev/null)
    local last_commit_count=$(redis-cli GET "openclaw:metrics:commit_count" 2>/dev/null)
    local now=$(date +%s)
    local current_count=$(cd /mnt/d/ai软件/zed && git rev-list --count HEAD 2>/dev/null)
    
    if [[ -n "$last_commit_time" && -n "$last_commit_count" ]]; then
        local elapsed=$((now - last_commit_time))
        local new_commits=$((current_count - last_commit_count))
        
        # 如果 5 分钟没有新提交，强制中断所有 agent 重新派活
        if [[ $elapsed -gt 300 && $new_commits -eq 0 ]]; then
            for agent in "${AGENTS[@]}"; do
                tmux -S "$SOCKET" send-keys -t "$agent" Escape 2>/dev/null
                sleep 0.3
                tmux -S "$SOCKET" send-keys -t "$agent" C-c 2>/dev/null
                sleep 0.3
                dispatch_task "$agent"
            done
            issues+=("no_output_5min:force_redispatch")
            redis-cli SET "openclaw:metrics:commit_time" "$now" 2>/dev/null
        fi
    fi
    
    # 更新提交计数
    redis-cli SET "openclaw:metrics:commit_count" "$current_count" 2>/dev/null
    if [[ $current_count -gt ${last_commit_count:-0} ]]; then
        redis-cli SET "openclaw:metrics:commit_time" "$now" 2>/dev/null
    fi
    
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
            # 正在工作，重置计数器，保存上下文
            redis-cli HSET "$REDIS_PREFIX:retry:$agent" "count" 0 2>/dev/null
            redis-cli HSET "$REDIS_PREFIX:unknown:$agent" "count" 0 2>/dev/null
            "$WORKSPACE/scripts/context-cache.sh" save "$agent" 2>/dev/null
        fi
    done
    
    # 整理共享知识
    "$WORKSPACE/scripts/context-feeder.sh" compile 2>/dev/null
    
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
    test-paths)
        # 测试路径转换功能
        echo "🔧 测试路径转换功能:"
        echo ""
        echo "WSL 检测: $(is_wsl && echo '是 WSL 环境' || echo '非 WSL 环境')"
        echo "WSL 版本: $(get_wsl_version)"
        echo ""
        echo "路径转换测试:"
        test_paths=(
            "/mnt/c/Users/test"
            "/mnt/d/ai软件/zed"
            "/mnt/d/ai软件/zed/crates/terminal"
            "C:\\Windows\\System32"
        )
        for p in "${test_paths[@]}"; do
            echo "  Linux: $p"
            echo "  Win:   $(linux_to_windows_path "$p")"
            echo ""
        done
        echo "文本转换测试:"
        test_text="国际化 /mnt/d/ai软件/zed/crates/terminal 模块"
        echo "  原文: $test_text"
        echo "  转换: $(convert_paths_in_text "$test_text")"
        echo ""
        test_text2="修复 crates/acp_thread 和 crates/terminal 的编译错误"
        echo "  原文: $test_text2"
        echo "  转换: $(convert_paths_in_text "$test_text2")"
        ;;
    *) echo "用法: $0 {check|status|repair <agent>|diagnose <agent>|learn <agent> <problem> <solution>|report|trends|test-paths}" ;;
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
