#!/bin/bash
# evolution-v2.sh - 自我进化框架 v2
# 核心理念: 检测-诊断-修复-学习 闭环

set -e
WORKSPACE="/home/jinyang/.openclaw/workspace"
SOCKET="/tmp/openclaw-agents.sock"
REDIS_PREFIX="openclaw:evo"
AGENTS=("claude-agent" "gemini-agent" "codex-agent")

# ============ 配置 ============
declare -A AGENT_CONFIG=(
    ["claude-agent:cmd"]='ANTHROPIC_AUTH_TOKEN="sk-KwfZ1MFGt3K28O1Osjdd6WpN5fRJde3fUVzGIlUSIL50AYZf" ANTHROPIC_BASE_URL="https://vip.chiddns.com" claude --dangerously-skip-permissions'
    ["claude-agent:workdir"]="/mnt/d/ai软件/zed"
    ["claude-agent:specialty"]="i18n,refactor,backend,algorithm"
    ["gemini-agent:cmd"]="gemini"
    ["gemini-agent:workdir"]="/mnt/d/ai软件/zed"
    ["gemini-agent:specialty"]="i18n,frontend,ui,architecture"
    ["codex-agent:cmd"]="codex"
    ["codex-agent:workdir"]="/mnt/d/ai软件/zed"
    ["codex-agent:specialty"]="fix,test,optimize,debug"
)

# ============ 诊断引擎 ============
diagnose_agent() {
    local agent="$1"
    local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null)
    local last_lines=$(echo "$output" | tail -20)
    local diagnosis=""
    
    # 1. API 连接失败
    if echo "$output" | grep -qE "Unable to connect|ERR_BAD_REQUEST|Failed to connect" 2>/dev/null; then
        diagnosis="api_failure"
    # 2. 等待确认 (多种格式)
    elif echo "$last_lines" | grep -qE "Yes, I accept|Yes, proceed|Press enter|Enter to confirm|Do you want to proceed|\[y/N\]|\(y/n\)" 2>/dev/null; then
        diagnosis="needs_confirm"
    # 3. Context 不足
    elif echo "$output" | grep -oE "[0-9]+% context left" | grep -qE "^[0-9]$|^1[0-9]$|^2[0-9]$" 2>/dev/null; then
        diagnosis="context_low"
    # 4. 循环检测
    elif echo "$last_lines" | grep -qE "loop was detected|infinite loop" 2>/dev/null; then
        diagnosis="loop_detected"
    # 5. 未发送输入
    elif echo "$last_lines" | grep -qE "^> .+[^$]|^› .+[^$]" 2>/dev/null; then
        if ! echo "$last_lines" | grep -qE "(esc to interrupt|Thinking|Working|Searching)" 2>/dev/null; then
            if ! echo "$last_lines" | grep -qE "Write tests for|Type your message|Summarize recent" 2>/dev/null; then
                diagnosis="pending_input"
            fi
        fi
    # 6. 空闲状态
    elif echo "$last_lines" | grep -qE "^>\s*$|context left.*shortcuts$" 2>/dev/null; then
        if ! echo "$last_lines" | grep -qE "(esc to interrupt|esc to cancel)" 2>/dev/null; then
            diagnosis="idle"
        fi
    # 7. 正常工作中
    elif echo "$last_lines" | grep -qE "(esc to interrupt|esc to cancel|Thinking|Working|Searching|Reading|Writing)" 2>/dev/null; then
        diagnosis="working"
    else
        diagnosis="unknown"
    fi
    
    echo "$diagnosis"
}

# ============ 修复引擎 ============
repair_agent() {
    local agent="$1"
    local diagnosis="$2"
    local result="ok"
    
    case "$diagnosis" in
        api_failure)
            # 重启并使用正确的环境变量
            tmux -S "$SOCKET" send-keys -t "$agent" C-c
            sleep 1
            local cmd="${AGENT_CONFIG[$agent:cmd]}"
            local workdir="${AGENT_CONFIG[$agent:workdir]}"
            tmux -S "$SOCKET" send-keys -t "$agent" "cd $workdir && $cmd" Enter
            # 等待启动并自动确认
            sleep 5
            auto_confirm_startup "$agent"
            result="restarted"
            ;;
        needs_confirm)
            # 智能确认
            local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p | tail -20)
            if echo "$output" | grep -qE "Yes, I accept" 2>/dev/null; then
                tmux -S "$SOCKET" send-keys -t "$agent" Down Enter
            elif echo "$output" | grep -qE "\[y/N\]|\(y/n\)" 2>/dev/null; then
                tmux -S "$SOCKET" send-keys -t "$agent" "y" Enter
            else
                tmux -S "$SOCKET" send-keys -t "$agent" Enter
            fi
            result="confirmed"
            ;;
        context_low)
            # 重启会话
            tmux -S "$SOCKET" send-keys -t "$agent" C-c
            sleep 1
            case "$agent" in
                codex-agent)
                    tmux -S "$SOCKET" send-keys -t "$agent" "/exit" Enter
                    sleep 2
                    ;;
            esac
            local cmd="${AGENT_CONFIG[$agent:cmd]}"
            local workdir="${AGENT_CONFIG[$agent:workdir]}"
            tmux -S "$SOCKET" send-keys -t "$agent" "cd $workdir && $cmd" Enter
            sleep 5
            auto_confirm_startup "$agent"
            result="context_reset"
            ;;
        loop_detected)
            tmux -S "$SOCKET" send-keys -t "$agent" "1" Enter
            result="loop_broken"
            ;;
        pending_input)
            tmux -S "$SOCKET" send-keys -t "$agent" Enter
            result="input_sent"
            ;;
        idle)
            dispatch_task "$agent"
            result="dispatched"
            ;;
        working|unknown)
            result="no_action"
            ;;
    esac
    
    # 记录到学习库
    if [[ "$result" != "no_action" ]]; then
        redis-cli HINCRBY "$REDIS_PREFIX:repairs" "$diagnosis:$result" 1 2>/dev/null
    fi
    
    echo "$result"
}

# ============ 自动确认启动流程 ============
auto_confirm_startup() {
    local agent="$1"
    local max_attempts=10
    
    for ((i=1; i<=max_attempts; i++)); do
        sleep 2
        local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p | tail -15)
        
        # 检查各种确认界面
        if echo "$output" | grep -qE "Yes, I accept" 2>/dev/null; then
            tmux -S "$SOCKET" send-keys -t "$agent" Down Enter
        elif echo "$output" | grep -qE "Enter to confirm|Press Enter" 2>/dev/null; then
            tmux -S "$SOCKET" send-keys -t "$agent" Enter
        elif echo "$output" | grep -qE "Dark mode|Light mode" 2>/dev/null; then
            tmux -S "$SOCKET" send-keys -t "$agent" Enter
        elif echo "$output" | grep -qE "Do you want to use this API key" 2>/dev/null; then
            tmux -S "$SOCKET" send-keys -t "$agent" Up Enter
        elif echo "$output" | grep -qE "^>\s*$|context left" 2>/dev/null; then
            # 启动完成
            return 0
        fi
    done
}

# ============ 智能派活 ============
dispatch_task() {
    local agent="$1"
    local specialty="${AGENT_CONFIG[$agent:specialty]}"
    
    # 从 Redis 获取待处理任务
    local task=$(redis-cli LPOP "$REDIS_PREFIX:tasks:queue" 2>/dev/null)
    
    if [[ -z "$task" ]]; then
        # 默认任务
        case "$agent" in
            claude-agent)
                task="继续 zed 中文化工作，检查 crates/ 目录下还有哪些文件需要翻译。完成后 git add -u && git commit -m 'i18n: 模块国际化' && git push"
                ;;
            gemini-agent)
                task="继续 zed 中文化工作，检查 crates/ 目录下还有哪些文件需要翻译。完成后 git add -u && git commit -m 'i18n: 模块国际化' && git push"
                ;;
            codex-agent)
                task="运行 cargo check，修复发现的编译错误。完成后 git add -u && git commit -m 'fix: 修复编译错误' && git push"
                ;;
        esac
    fi
    
    tmux -S "$SOCKET" send-keys -t "$agent" "$task" Enter
    redis-cli HINCRBY "$REDIS_PREFIX:stats" "dispatched:$agent" 1 2>/dev/null
}

# ============ 主循环 ============
run_check() {
    local mode="${1:-quick}"
    local issues=()
    
    for agent in "${AGENTS[@]}"; do
        # 检查 tmux 会话是否存在
        if ! tmux -S "$SOCKET" has-session -t "$agent" 2>/dev/null; then
            # 创建会话
            local workdir="${AGENT_CONFIG[$agent:workdir]}"
            tmux -S "$SOCKET" new-session -d -s "$agent" -c "$workdir"
            local cmd="${AGENT_CONFIG[$agent:cmd]}"
            tmux -S "$SOCKET" send-keys -t "$agent" "$cmd" Enter
            sleep 5
            auto_confirm_startup "$agent"
            issues+=("$agent:session_created")
            continue
        fi
        
        # 诊断
        local diagnosis=$(diagnose_agent "$agent")
        
        # 修复
        if [[ "$diagnosis" != "working" && "$diagnosis" != "unknown" ]]; then
            local result=$(repair_agent "$agent" "$diagnosis")
            if [[ "$result" != "no_action" ]]; then
                issues+=("$agent:$diagnosis->$result")
            fi
        fi
    done
    
    # 输出结果
    if [[ ${#issues[@]} -gt 0 ]]; then
        echo "🔧 修复: ${issues[*]}"
    elif [[ "$mode" == "verbose" ]]; then
        echo "✅ 全部正常"
    fi
}

# ============ 状态报告 ============
status_report() {
    echo "========== Agent 状态报告 =========="
    echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    for agent in "${AGENTS[@]}"; do
        local diagnosis=$(diagnose_agent "$agent")
        local ctx=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null | grep -oE "[0-9]+% context left" | head -1)
        echo "[$agent] 状态: $diagnosis | Context: ${ctx:-N/A}"
    done
    
    echo ""
    echo "========== 修复统计 =========="
    redis-cli HGETALL "$REDIS_PREFIX:repairs" 2>/dev/null | paste - - | while read key val; do
        echo "  $key: $val"
    done
}

# ============ 学习系统 ============
learn() {
    local symptom="$1"
    local solution="$2"
    local success="$3"
    
    redis-cli HSET "$REDIS_PREFIX:knowledge:$symptom" "solution" "$solution" "success_rate" "$success" 2>/dev/null
    echo "📚 已学习: $symptom -> $solution (成功率: $success%)"
}

# ============ 添加任务 ============
add_task() {
    local task="$1"
    local priority="${2:-normal}"
    
    if [[ "$priority" == "high" ]]; then
        redis-cli LPUSH "$REDIS_PREFIX:tasks:queue" "$task" 2>/dev/null
    else
        redis-cli RPUSH "$REDIS_PREFIX:tasks:queue" "$task" 2>/dev/null
    fi
    echo "📋 任务已添加: $task"
}

# ============ 入口 ============
case "${1:-check}" in
    check|quick)
        run_check quick
        ;;
    verbose)
        run_check verbose
        ;;
    status)
        status_report
        ;;
    learn)
        learn "$2" "$3" "$4"
        ;;
    add-task)
        add_task "$2" "$3"
        ;;
    repair)
        agent="$2"
        diagnosis=$(diagnose_agent "$agent")
        result=$(repair_agent "$agent" "$diagnosis")
        echo "[$agent] $diagnosis -> $result"
        ;;
    *)
        echo "用法: $0 {check|verbose|status|learn|add-task|repair}"
        ;;
esac
