#!/bin/bash
# tech-director-evolution.sh - 技术总监进化学习系统
# 分析问题模式，总结经验，持续改进

WORKSPACE="/home/jinyang/.openclaw/workspace"
DB_HOST="localhost"
DB_USER="openclaw"
DB_PASS="openclaw123"
DB_NAME="openclaw"
export PGPASSWORD="$DB_PASS"

# ============ 问题模式分析 ============
analyze_patterns() {
    echo "=== 🔍 问题模式分析 ==="
    echo ""
    
    # 从 PostgreSQL 分析高频问题
    echo "📊 高频问题类型:"
    psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c "
    SELECT category, COUNT(*) as count, AVG(importance)::numeric(3,1) as avg_importance
    FROM memories 
    WHERE category IN ('issue', 'code-quality', 'performance', 'agent-coordination')
    GROUP BY category
    ORDER BY count DESC;"
    
    echo ""
    echo "📊 反复出现的关键词:"
    
    # 分析日志中的高频问题词
    local log_file="$WORKSPACE/memory/$(date +%Y-%m-%d).md"
    if [[ -f "$log_file" ]]; then
        echo "  混合导入: $(grep -c '混合导入' "$log_file" 2>/dev/null || echo 0) 次"
        echo "  路径问题: $(grep -c '路径' "$log_file" 2>/dev/null || echo 0) 次"
        echo "  权限问题: $(grep -c '权限' "$log_file" 2>/dev/null || echo 0) 次"
        echo "  等待确认: $(grep -c '等待' "$log_file" 2>/dev/null || echo 0) 次"
        echo "  循环依赖: $(grep -c '循环' "$log_file" 2>/dev/null || echo 0) 次"
    fi
}

# ============ 经验总结 ============
summarize_learnings() {
    echo ""
    echo "=== 📚 学习经验总结 ==="
    echo ""
    
    psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c "
    SELECT id, LEFT(content, 120) as learning, importance
    FROM memories 
    WHERE category = 'learning'
    ORDER BY importance DESC, created_at DESC
    LIMIT 10;"
}

# ============ 进化建议 ============
evolution_suggestions() {
    echo ""
    echo "=== 🧬 进化建议 ==="
    echo ""
    
    echo "1️⃣ **Agent 协调优化**"
    echo "   - 问题: Agent 经常等待确认，效率低"
    echo "   - 建议: 实现自动确认机制，区分只读/写入操作"
    echo "   - 脚本: evolution-v4.sh 已有部分实现"
    echo ""
    
    echo "2️⃣ **路径转换标准化**"
    echo "   - 问题: WSL/Windows 路径混乱"
    echo "   - 建议: 所有任务描述使用标准化路径格式"
    echo "   - 已完成: evolution-v4.sh 路径转换 (commit 3af1df6)"
    echo ""
    
    echo "3️⃣ **代码分割最佳实践**"
    echo "   - 问题: 混合导入导致代码分割失效"
    echo "   - 建议: 建立导入规范，避免同一模块混合导入"
    echo "   - 模式: 动态导入包装器 (timeline.ts, core.ts)"
    echo ""
    
    echo "4️⃣ **持续监控机制**"
    echo "   - 问题: 问题修复后缺乏验证"
    echo "   - 建议: 每次修复后自动运行 build 验证"
    echo "   - 脚本: evolution-loop.sh verify_fix()"
    echo ""
    
    echo "5️⃣ **知识沉淀**"
    echo "   - 问题: 经验分散在日志中"
    echo "   - 建议: 定期整理到 PostgreSQL，支持语义搜索"
    echo "   - 工具: vector-memory.sh"
}

# ============ 待解决问题 ============
pending_issues() {
    echo ""
    echo "=== ⏳ 待解决问题 ==="
    echo ""
    
    echo "🔴 紧急:"
    redis-cli GET openclaw:issues:urgent 2>/dev/null | tr ',' '\n' | while read issue; do
        [[ -n "$issue" ]] && echo "   - $issue"
    done
    
    echo ""
    echo "🟡 中等:"
    redis-cli GET openclaw:issues:medium 2>/dev/null | tr ',' '\n' | while read issue; do
        [[ -n "$issue" ]] && echo "   - $issue"
    done
}

# ============ 生成进化报告 ============
generate_report() {
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║           🧬 技术总监进化学习报告                                ║"
    echo "║           $(date '+%Y-%m-%d %H:%M')                                        ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo ""
    
    analyze_patterns
    summarize_learnings
    evolution_suggestions
    pending_issues
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "报告生成完成。建议定期运行此脚本进行自我进化。"
}

case "$1" in
    patterns)
        analyze_patterns
        ;;
    learnings)
        summarize_learnings
        ;;
    suggestions)
        evolution_suggestions
        ;;
    pending)
        pending_issues
        ;;
    report)
        generate_report
        ;;
    *)
        generate_report
        ;;
esac
