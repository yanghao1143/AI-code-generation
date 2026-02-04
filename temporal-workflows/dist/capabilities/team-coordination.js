"use strict";
/**
 * 团队协调能力
 * 管理 Agent 团队，优化协作
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.getAgentProfile = getAgentProfile;
exports.getAllProfiles = getAllProfiles;
exports.selectBestAgent = selectBestAgent;
exports.updateAgentStats = updateAgentStats;
exports.getTeamStatus = getTeamStatus;
const child_process_1 = require("child_process");
const util_1 = require("util");
const execAsync = (0, util_1.promisify)(child_process_1.exec);
// Agent 能力画像
const AGENT_PROFILES = {
    'claude-agent': {
        name: 'claude-agent',
        strengths: ['代码重构', '算法设计', '代码审查', '文档编写', '复杂逻辑'],
        weaknesses: ['UI 设计'],
        preferredTasks: ['refactor', 'review', 'algorithm', 'backend'],
        avgResponseTime: 120,
        successRate: 0.95
    },
    'gemini-agent': {
        name: 'gemini-agent',
        strengths: ['前端开发', 'UI/UX', '架构设计', '国际化'],
        weaknesses: ['WSL 环境', '构建命令'],
        preferredTasks: ['frontend', 'ui', 'i18n', 'architecture'],
        avgResponseTime: 90,
        successRate: 0.85
    },
    'codex-agent': {
        name: 'codex-agent',
        strengths: ['快速原型', '代码生成', '测试编写'],
        weaknesses: ['复杂重构', '需要 Windows 路径'],
        preferredTasks: ['prototype', 'generate', 'test'],
        avgResponseTime: 60,
        successRate: 0.80
    }
};
function getAgentProfile(agent) {
    return AGENT_PROFILES[agent];
}
function getAllProfiles() {
    return Object.values(AGENT_PROFILES);
}
async function selectBestAgent(taskDescription) {
    const taskLower = taskDescription.toLowerCase();
    let bestAgent = 'claude-agent';
    let bestScore = 0;
    let reason = '默认选择';
    for (const [agent, profile] of Object.entries(AGENT_PROFILES)) {
        let score = profile.successRate * 100;
        // 根据任务关键词匹配
        for (const strength of profile.strengths) {
            if (taskLower.includes(strength.toLowerCase())) {
                score += 20;
                reason = `擅长 ${strength}`;
            }
        }
        for (const preferred of profile.preferredTasks) {
            if (taskLower.includes(preferred)) {
                score += 15;
            }
        }
        // 减分项
        for (const weakness of profile.weaknesses) {
            if (taskLower.includes(weakness.toLowerCase())) {
                score -= 30;
            }
        }
        if (score > bestScore) {
            bestScore = score;
            bestAgent = agent;
        }
    }
    return {
        task: taskDescription,
        agent: bestAgent,
        reason,
        confidence: Math.min(bestScore / 150, 1)
    };
}
async function updateAgentStats(agent, success, responseTime) {
    // 记录到 Redis
    const key = `openclaw:agent:stats:${agent}`;
    await execAsync(`redis-cli HINCRBY "${key}" "total" 1`);
    if (success) {
        await execAsync(`redis-cli HINCRBY "${key}" "success" 1`);
    }
    await execAsync(`redis-cli LPUSH "openclaw:agent:response_times:${agent}" "${responseTime}"`);
    await execAsync(`redis-cli LTRIM "openclaw:agent:response_times:${agent}" 0 99`);
}
async function getTeamStatus() {
    const lines = ['👥 团队状态:'];
    for (const profile of Object.values(AGENT_PROFILES)) {
        lines.push(`\n${profile.name}:`);
        lines.push(`  擅长: ${profile.strengths.slice(0, 3).join(', ')}`);
        lines.push(`  成功率: ${(profile.successRate * 100).toFixed(0)}%`);
    }
    return lines.join('\n');
}
