#!/bin/bash
# auto-commit.sh - 自动提交系统
# 功能: 监控代码变更，自动提交和推送

WORKSPACE="/home/jinyang/.openclaw/workspace"
ZED_REPO="/mnt/d/ai软件/zed"

# 检查并提交 workspace
commit_workspace() {
    cd "$WORKSPACE" || return 1
    
    local changes=$(git status --porcelain 2>/dev/null | wc -l)
    if [[ $changes -gt 0 ]]; then
        git add -A
        local msg="自动提交: $(date '+%Y-%m-%d %H:%M')"
        git commit -m "$msg" 2>/dev/null
        git push 2>/dev/null
        echo "✅ Workspace: 提交 $changes 个文件"
        return 0
    fi
    return 1
}

# 检查并提交 Zed 仓库
commit_zed() {
    cd "$ZED_REPO" || return 1
    
    local changes=$(git status --porcelain 2>/dev/null | wc -l)
    if [[ $changes -gt 0 ]]; then
        git add -A
        
        # 生成智能提交信息
        local msg=""
        local staged=$(git diff --cached --name-only 2>/dev/null)
        
        if echo "$staged" | grep -q "i18n\|locales\|zh-CN"; then
            msg="i18n: 中文化更新"
        elif echo "$staged" | grep -q "\.rs$"; then
            msg="feat: 代码更新"
        elif echo "$staged" | grep -q "\.md$"; then
            msg="docs: 文档更新"
        else
            msg="chore: 自动提交 $(date '+%H:%M')"
        fi
        
        git commit -m "$msg" 2>/dev/null
        git push 2>/dev/null
        echo "✅ Zed: 提交 $changes 个文件 - $msg"
        return 0
    fi
    return 1
}

# 检查所有仓库
check_all() {
    local committed=0
    
    commit_workspace && ((committed++))
    commit_zed && ((committed++))
    
    if [[ $committed -eq 0 ]]; then
        echo "📝 无待提交的更改"
    fi
}

# 强制提交 (即使没有变更也创建空提交)
force_commit() {
    cd "$ZED_REPO" || return 1
    
    local changes=$(git status --porcelain 2>/dev/null | wc -l)
    if [[ $changes -gt 0 ]]; then
        commit_zed
    else
        echo "📝 Zed: 无待提交的更改"
    fi
    
    cd "$WORKSPACE" || return 1
    changes=$(git status --porcelain 2>/dev/null | wc -l)
    if [[ $changes -gt 0 ]]; then
        commit_workspace
    else
        echo "📝 Workspace: 无待提交的更改"
    fi
}

# 状态检查
status() {
    echo "===== 仓库状态 ====="
    
    echo ""
    echo "📁 Workspace ($WORKSPACE):"
    cd "$WORKSPACE" 2>/dev/null && git status --short | head -10
    
    echo ""
    echo "📁 Zed ($ZED_REPO):"
    cd "$ZED_REPO" 2>/dev/null && git status --short | head -10
}

# 入口
case "${1:-check}" in
    check)
        check_all
        ;;
    force)
        force_commit
        ;;
    status)
        status
        ;;
    workspace)
        commit_workspace
        ;;
    zed)
        commit_zed
        ;;
    *)
        echo "用法: $0 {check|force|status|workspace|zed}"
        ;;
esac
