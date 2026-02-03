#!/bin/bash
# patrol-director.sh - 技术总监级别分析
# 每小时运行一次，分析项目状态和效率

set -e

LOG_FILE="/tmp/patrol-director.log"
REPORT_FILE="/home/jinyang/.openclaw/workspace/DIRECTOR_REPORT.md"
PROJECT_DIR="/home/jinyang/Koma"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# 分析项目状态
analyze_project() {
    cd "$PROJECT_DIR"
    
    # TypeScript 错误
    local ts_errors=$(cd frontend && npx tsc --noEmit 2>&1 | grep -c "error TS" 2>/dev/null || echo "0")
    ts_errors=$(echo "$ts_errors" | tr -d '\n' | head -c 10)
    
    # TODO 数量
    local todo_count=$(grep -rn "TODO\|FIXME" frontend/src --include="*.ts" --include="*.tsx" 2>/dev/null | wc -l)
    
    # 今日提交
    local today_commits=$(git log --oneline --since="today" | wc -l)
    
    # 周提交
    local week_commits=$(git log --oneline --since="7 days ago" | wc -l)
    
    # 更新 Redis
    redis-cli HSET "openclaw:metrics:project" \
        "ts_errors" "$ts_errors" \
        "todo_count" "$todo_count" \
        "today_commits" "$today_commits" \
        "week_commits" "$week_commits" \
        "last_analyzed" "$(date +%s)" >/dev/null
    
    log "Project analyzed: ts_errors=$ts_errors, todo=$todo_count, today=$today_commits, week=$week_commits"
    
    # 如果有问题，加入通知队列
    if [[ "$ts_errors" -gt 0 ]]; then
        redis-cli LPUSH "patrol:notify:pending" "⚠️ TypeScript 错误: $ts_errors 个" >/dev/null
    fi
    
    if [[ "$todo_count" -gt 10 ]]; then
        redis-cli LPUSH "patrol:notify:pending" "⚠️ TODO/FIXME 过多: $todo_count 个" >/dev/null
    fi
}

# 分析 Agent 效率
analyze_efficiency() {
    local agents=("claude-agent" "gemini-agent" "codex-agent")
    
    for agent in "${agents[@]}"; do
        local state=$(redis-cli GET "patrol:agent:${agent}:state" 2>/dev/null)
        local idle_since=$(redis-cli GET "patrol:agent:${agent}:idle_since" 2>/dev/null)
        
        # 计算工作时间比例
        if [[ -n "$idle_since" ]]; then
            local now=$(date +%s)
            local idle_duration=$((now - idle_since))
            
            if [[ "$idle_duration" -gt 1800 ]]; then
                # 空闲超过 30 分钟
                redis-cli LPUSH "patrol:notify:pending" "⚠️ $agent 空闲超过 30 分钟" >/dev/null
                log "$agent: idle for ${idle_duration}s, needs attention"
            fi
        fi
    done
}

# 生成报告
generate_report() {
    local ts_errors=$(redis-cli HGET "openclaw:metrics:project" "ts_errors" 2>/dev/null || echo "?")
    local todo_count=$(redis-cli HGET "openclaw:metrics:project" "todo_count" 2>/dev/null || echo "?")
    local week_commits=$(redis-cli HGET "openclaw:metrics:project" "week_commits" 2>/dev/null || echo "?")
    
    local claude_state=$(redis-cli GET "patrol:agent:claude-agent:state" 2>/dev/null || echo "?")
    local gemini_state=$(redis-cli GET "patrol:agent:gemini-agent:state" 2>/dev/null || echo "?")
    local codex_state=$(redis-cli GET "patrol:agent:codex-agent:state" 2>/dev/null || echo "?")
    
    cat > "$REPORT_FILE" << EOF
# 🎯 技术总监自动报告

**生成时间**: $(date '+%Y-%m-%d %H:%M:%S')

## 📊 项目状态

| 指标 | 数值 |
|------|------|
| TypeScript 错误 | $ts_errors |
| TODO/FIXME | $todo_count |
| 周提交数 | $week_commits |

## 🤖 Agent 状态

| Agent | 状态 |
|-------|------|
| Claude | $claude_state |
| Gemini | $gemini_state |
| Codex | $codex_state |

## 📋 工作计划

$(redis-cli GET "openclaw:work:plan" 2>/dev/null || echo "无")

---
*此报告由 patrol-director.sh 自动生成*
EOF

    log "Report generated: $REPORT_FILE"
}

# 主函数
main() {
    log "=== Director analysis started ==="
    
    analyze_project
    analyze_efficiency
    generate_report
    
    log "=== Director analysis completed ==="
}

main "$@"
