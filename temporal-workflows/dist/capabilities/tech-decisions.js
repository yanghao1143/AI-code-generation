"use strict";
/**
 * 技术决策记录
 * 记录重要决策，形成知识库
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.recordDecision = recordDecision;
exports.searchDecisions = searchDecisions;
exports.getRecentDecisions = getRecentDecisions;
const child_process_1 = require("child_process");
const util_1 = require("util");
const execAsync = (0, util_1.promisify)(child_process_1.exec);
async function recordDecision(decision) {
    const content = `技术决策: ${decision.title} | 背景: ${decision.context} | 决定: ${decision.decision} | 后果: ${decision.consequences} | 状态: ${decision.status}`;
    try {
        const { stdout } = await execAsync(`cd /home/jinyang/.openclaw/workspace && ./scripts/pg-memory.sh add-memory "${content.replace(/"/g, '\\"')}" "tech-decision" 9`);
        const match = stdout.match(/^(\d+)/);
        return match ? parseInt(match[1]) : 0;
    }
    catch {
        return 0;
    }
}
async function searchDecisions(query) {
    try {
        const { stdout } = await execAsync(`cd /home/jinyang/.openclaw/workspace && ./scripts/pg-memory.sh sql "SELECT id, content FROM memories WHERE category = 'tech-decision' AND content ILIKE '%${query}%' ORDER BY created_at DESC LIMIT 10;"`);
        // 简单解析
        const decisions = [];
        const lines = stdout.trim().split('\n').filter(l => l && !l.startsWith('-'));
        for (const line of lines) {
            const parts = line.split('|');
            if (parts.length >= 2) {
                decisions.push({
                    id: parseInt(parts[0]) || 0,
                    title: parts[1]?.trim() || '',
                    context: '',
                    decision: '',
                    consequences: '',
                    status: 'accepted',
                    date: '',
                    tags: []
                });
            }
        }
        return decisions;
    }
    catch {
        return [];
    }
}
async function getRecentDecisions(limit = 10) {
    try {
        const { stdout } = await execAsync(`cd /home/jinyang/.openclaw/workspace && ./scripts/pg-memory.sh sql "SELECT LEFT(content, 150) FROM memories WHERE category = 'tech-decision' ORDER BY created_at DESC LIMIT ${limit};"`);
        return stdout.trim().split('\n').filter(l => l && !l.startsWith('-'));
    }
    catch {
        return [];
    }
}
