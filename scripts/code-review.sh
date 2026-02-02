#!/bin/bash
# code-review.sh - 代码审计与合并系统
# 技术总监职责: 审核代码、合并分支、质量把关

WORKSPACE="/home/jinyang/.openclaw/workspace"
SOCKET="/tmp/openclaw-agents.sock"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 获取主仓库最新提交
get_recent_commits() {
    echo -e "${BLUE}📋 最近提交${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # 让 Claude 执行 git log
    tmux -S "$SOCKET" send-keys -t claude-agent 'git log --oneline -15 --format="%h %s (%cr)"' Enter
    sleep 3
    tmux -S "$SOCKET" capture-pane -t claude-agent -p 2>/dev/null | grep -E "^[a-f0-9]{7}" | head -15
}

# 检查未合并的分支
check_branches() {
    echo -e "\n${BLUE}🌿 分支状态${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    tmux -S "$SOCKET" send-keys -t claude-agent 'git branch -a --no-merged main 2>/dev/null | head -10' Enter
    sleep 2
    local branches=$(tmux -S "$SOCKET" capture-pane -t claude-agent -p 2>/dev/null | grep -E "^\s*(remotes/|origin/)" | head -10)
    
    if [[ -z "$branches" ]]; then
        echo -e "  ${GREEN}✓ 所有分支已合并${NC}"
    else
        echo "$branches"
    fi
}

# 代码质量检查
quality_check() {
    echo -e "\n${BLUE}🔍 代码质量检查${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # 让 Codex 运行 cargo check
    local codex_output=$(tmux -S "$SOCKET" capture-pane -t codex-agent -p 2>/dev/null | tail -30)
    
    # 检查编译错误
    if echo "$codex_output" | grep -qE "error\[E[0-9]+\]|error: could not compile" 2>/dev/null; then
        echo -e "  ${RED}❌ 存在编译错误${NC}"
        echo "$codex_output" | grep -E "error\[E[0-9]+\]" | head -5
        return 1
    else
        echo -e "  ${GREEN}✓ 编译检查通过${NC}"
    fi
    
    # 检查警告数量
    local warnings=$(echo "$codex_output" | grep -c "warning:" 2>/dev/null || echo 0)
    if [[ $warnings -gt 10 ]]; then
        echo -e "  ${YELLOW}⚠️ 有 $warnings 个警告${NC}"
    else
        echo -e "  ${GREEN}✓ 警告数量正常 ($warnings)${NC}"
    fi
    
    return 0
}

# 审计报告
audit_report() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║              📊 代码审计报告 - $(date '+%Y-%m-%d %H:%M')              ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    get_recent_commits
    check_branches
    quality_check
    
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✅ 审计完成${NC}"
    
    # 记录到 Redis
    redis-cli HSET "openclaw:code-review:latest" \
        timestamp "$(date -Iseconds)" \
        status "completed" > /dev/null 2>&1
}

# 触发合并
trigger_merge() {
    local branch="$1"
    
    if [[ -z "$branch" ]]; then
        echo "用法: $0 merge <branch>"
        return 1
    fi
    
    echo -e "${BLUE}🔀 合并分支: $branch${NC}"
    
    # 让 Claude 执行合并
    tmux -S "$SOCKET" send-keys -t claude-agent "git merge $branch --no-edit && git push" Enter
    
    echo -e "${GREEN}✓ 已发送合并命令${NC}"
}

# 拉取最新代码
pull_latest() {
    echo -e "${BLUE}📥 拉取最新代码${NC}"
    
    for agent in claude-agent gemini-agent codex-agent; do
        tmux -S "$SOCKET" send-keys -t "$agent" "git pull --rebase" Enter
        echo "  → $agent"
    done
    
    echo -e "${GREEN}✓ 已发送拉取命令${NC}"
}

# 同步所有 agent
sync_agents() {
    echo -e "${BLUE}🔄 同步所有 agent${NC}"
    
    # 1. 先让所有 agent 提交
    for agent in claude-agent gemini-agent codex-agent; do
        local output=$(tmux -S "$SOCKET" capture-pane -t "$agent" -p 2>/dev/null | tail -5)
        if echo "$output" | grep -qE "^>\s*$|Type your message|context left" 2>/dev/null; then
            tmux -S "$SOCKET" send-keys -t "$agent" "git add -u && git stash && git pull --rebase && git stash pop" Enter
            echo "  → $agent 同步中"
        fi
    done
    
    echo -e "${GREEN}✓ 同步命令已发送${NC}"
}

# 主入口
case "${1:-report}" in
    report|r)
        audit_report
        ;;
    commits|c)
        get_recent_commits
        ;;
    branches|b)
        check_branches
        ;;
    quality|q)
        quality_check
        ;;
    merge|m)
        trigger_merge "$2"
        ;;
    pull|p)
        pull_latest
        ;;
    sync|s)
        sync_agents
        ;;
    *)
        echo "用法: $0 [report|commits|branches|quality|merge|pull|sync]"
        echo ""
        echo "命令:"
        echo "  report (r)   - 完整审计报告"
        echo "  commits (c)  - 查看最近提交"
        echo "  branches (b) - 检查分支状态"
        echo "  quality (q)  - 代码质量检查"
        echo "  merge (m)    - 触发合并"
        echo "  pull (p)     - 拉取最新代码"
        echo "  sync (s)     - 同步所有 agent"
        ;;
esac
