"use strict";
/**
 * 深度学习能力
 * 从历史中提取模式，形成知识
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.analyzeIssuePatterns = analyzeIssuePatterns;
exports.analyzeSuccessPatterns = analyzeSuccessPatterns;
exports.generateInsights = generateInsights;
exports.saveKnowledge = saveKnowledge;
exports.runDeepLearning = runDeepLearning;
const child_process_1 = require("child_process");
const util_1 = require("util");
const execAsync = (0, util_1.promisify)(child_process_1.exec);
/**
 * 分析问题模式
 */
async function analyzeIssuePatterns() {
    const patterns = [];
    try {
        // 从 PostgreSQL 获取历史问题
        const { stdout } = await execAsync(`cd /home/jinyang/.openclaw/workspace && ./scripts/pg-memory.sh sql "SELECT content FROM memories WHERE category IN ('issue', 'self-healing', 'inspection') ORDER BY created_at DESC LIMIT 50;" 2>/dev/null`);
        const issues = stdout.trim().split('\n').filter(l => l && !l.startsWith('-'));
        const issueCount = {};
        for (const issue of issues) {
            // 提取关键词
            const keywords = ['等待确认', 'TypeScript 错误', '构建失败', '无响应', 'Redis', '磁盘'];
            for (const kw of keywords) {
                if (issue.includes(kw)) {
                    issueCount[kw] = (issueCount[kw] || 0) + 1;
                }
            }
        }
        for (const [issue, count] of Object.entries(issueCount)) {
            if (count >= 2) {
                patterns.push({
                    type: 'recurring_issue',
                    description: issue,
                    frequency: count,
                    lastSeen: new Date().toISOString()
                });
            }
        }
    }
    catch { }
    return patterns;
}
/**
 * 分析成功模式
 */
async function analyzeSuccessPatterns() {
    const patterns = [];
    try {
        // 从 Redis 获取任务派发历史
        const { stdout } = await execAsync(`redis-cli LRANGE "openclaw:tasks:dispatched" 0 99 2>/dev/null || echo ""`);
        const agentSuccess = {
            'claude-agent': { total: 0, keywords: [] },
            'gemini-agent': { total: 0, keywords: [] },
            'codex-agent': { total: 0, keywords: [] }
        };
        const lines = stdout.trim().split('\n').filter(l => l);
        for (const line of lines) {
            try {
                const task = JSON.parse(line);
                if (agentSuccess[task.agent]) {
                    agentSuccess[task.agent].total++;
                    // 提取任务关键词
                    const words = task.task?.toLowerCase().split(/\s+/) || [];
                    agentSuccess[task.agent].keywords.push(...words.slice(0, 3));
                }
            }
            catch { }
        }
        for (const [agent, data] of Object.entries(agentSuccess)) {
            if (data.total >= 3) {
                patterns.push({
                    type: 'agent_specialty',
                    description: `${agent} 处理了 ${data.total} 个任务`,
                    frequency: data.total,
                    lastSeen: new Date().toISOString()
                });
            }
        }
    }
    catch { }
    return patterns;
}
/**
 * 生成知识洞察
 */
async function generateInsights() {
    const insights = [];
    const issuePatterns = await analyzeIssuePatterns();
    const successPatterns = await analyzeSuccessPatterns();
    // 从问题模式生成洞察
    for (const pattern of issuePatterns) {
        if (pattern.frequency >= 3) {
            insights.push({
                topic: '重复问题',
                insight: `"${pattern.description}" 问题出现 ${pattern.frequency} 次，需要根本解决方案`,
                confidence: Math.min(pattern.frequency / 10, 0.9),
                source: 'issue_analysis',
                createdAt: new Date().toISOString()
            });
        }
    }
    // 从成功模式生成洞察
    for (const pattern of successPatterns) {
        insights.push({
            topic: 'Agent 能力',
            insight: pattern.description,
            confidence: 0.8,
            source: 'task_analysis',
            createdAt: new Date().toISOString()
        });
    }
    return insights;
}
/**
 * 保存知识到知识库
 */
async function saveKnowledge(knowledge) {
    const content = `知识: ${knowledge.topic} - ${knowledge.insight} (置信度: ${(knowledge.confidence * 100).toFixed(0)}%)`;
    await execAsync(`cd /home/jinyang/.openclaw/workspace && ./scripts/pg-memory.sh add-memory "${content.replace(/"/g, '\\"')}" "knowledge" 7`);
    // 同时保存到 Redis 便于快速查询
    await execAsync(`redis-cli HSET "openclaw:knowledge:${knowledge.topic.replace(/\s+/g, '_')}" "insight" "${knowledge.insight}" "confidence" "${knowledge.confidence}"`);
}
/**
 * 运行深度学习
 */
async function runDeepLearning() {
    const insights = await generateInsights();
    let saved = 0;
    for (const insight of insights) {
        if (insight.confidence >= 0.5) {
            await saveKnowledge(insight);
            saved++;
        }
    }
    return {
        patternsFound: insights.length,
        insightsGenerated: insights.length,
        knowledgeSaved: saved
    };
}
