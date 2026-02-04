"use strict";
/**
 * 好大儿的神经系统 - 扩展 Activities
 * 代码审查、学习、记忆管理
 */
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.runTypeScriptCheck = runTypeScriptCheck;
exports.runBuildCheck = runBuildCheck;
exports.getGitStatus = getGitStatus;
exports.searchMemories = searchMemories;
exports.addMemory = addMemory;
exports.generateDailySummary = generateDailySummary;
exports.saveDailySummary = saveDailySummary;
exports.analyzePatterns = analyzePatterns;
exports.extractLearnings = extractLearnings;
exports.recordLearning = recordLearning;
exports.shouldNotifyUser = shouldNotifyUser;
exports.sendNotification = sendNotification;
exports.sendMessageViaOpenClaw = sendMessageViaOpenClaw;
exports.checkSystemHealth = checkSystemHealth;
exports.dispatchTaskToAgent = dispatchTaskToAgent;
exports.getAgentWorkload = getAgentWorkload;
const child_process_1 = require("child_process");
const util_1 = require("util");
const fs = __importStar(require("fs/promises"));
const execAsync = (0, util_1.promisify)(child_process_1.exec);
async function runTypeScriptCheck(projectPath) {
    try {
        const { stdout, stderr } = await execAsync(`cd ${projectPath} && ./node_modules/.bin/tsc --noEmit 2>&1 || true`, { timeout: 120000 });
        const output = stdout + stderr;
        const errorMatches = output.match(/error TS\d+/g) || [];
        const errors = output.split('\n').filter(l => l.includes('error TS'));
        return {
            hasErrors: errorMatches.length > 0,
            errorCount: errorMatches.length,
            errors: errors.slice(0, 10), // 最多10条
            hasWarnings: false,
            warningCount: 0
        };
    }
    catch (error) {
        return {
            hasErrors: true,
            errorCount: 1,
            errors: [`检查失败: ${error}`],
            hasWarnings: false,
            warningCount: 0
        };
    }
}
async function runBuildCheck(projectPath) {
    try {
        const start = Date.now();
        // 使用 WSL 路径直接在 Linux 环境运行
        const { stdout, stderr } = await execAsync(`cd ${projectPath} && npm run build 2>&1 | tail -50`, { timeout: 180000 });
        const buildTime = Date.now() - start;
        const output = stdout + stderr;
        const hasErrors = output.includes('error') && !output.includes('built in');
        const warningMatches = output.match(/warning/gi) || [];
        const builtMatch = output.match(/built in ([\d.]+)s/);
        return {
            hasErrors,
            errorCount: hasErrors ? 1 : 0,
            errors: hasErrors ? [output.slice(-500)] : [],
            hasWarnings: warningMatches.length > 0,
            warningCount: warningMatches.length,
            buildTime: builtMatch ? parseFloat(builtMatch[1]) * 1000 : buildTime
        };
    }
    catch (error) {
        // 检查是否实际上构建成功了
        if (error.stdout && error.stdout.includes('built in')) {
            const builtMatch = error.stdout.match(/built in ([\d.]+)s/);
            const warningMatches = error.stdout.match(/warning/gi) || [];
            return {
                hasErrors: false,
                errorCount: 0,
                errors: [],
                hasWarnings: warningMatches.length > 0,
                warningCount: warningMatches.length,
                buildTime: builtMatch ? parseFloat(builtMatch[1]) * 1000 : 0
            };
        }
        return {
            hasErrors: true,
            errorCount: 1,
            errors: [`构建失败: ${error.message || error}`],
            hasWarnings: false,
            warningCount: 0
        };
    }
}
async function getGitStatus(repoPath) {
    try {
        const { stdout: branch } = await execAsync(`cd ${repoPath} && git branch --show-current`);
        const { stdout: status } = await execAsync(`cd ${repoPath} && git status --porcelain`);
        const { stdout: log } = await execAsync(`cd ${repoPath} && git log -1 --format="%s|%cr"`);
        const lines = status.trim().split('\n').filter(l => l);
        const modified = lines.filter(l => l.startsWith(' M') || l.startsWith('M ')).length;
        const untracked = lines.filter(l => l.startsWith('??')).length;
        const [lastCommit, lastCommitTime] = log.trim().split('|');
        return {
            branch: branch.trim(),
            ahead: 0,
            behind: 0,
            modified,
            untracked,
            lastCommit,
            lastCommitTime
        };
    }
    catch (error) {
        return {
            branch: 'unknown',
            ahead: 0,
            behind: 0,
            modified: 0,
            untracked: 0,
            lastCommit: 'error',
            lastCommitTime: 'unknown'
        };
    }
}
async function searchMemories(query, limit = 10) {
    try {
        const { stdout } = await execAsync(`cd /home/jinyang/.openclaw/workspace && ./scripts/pg-memory.sh sql "SELECT id, LEFT(content, 200) as content, category, importance, created_at FROM memories WHERE content ILIKE '%${query}%' ORDER BY importance DESC LIMIT ${limit};"`);
        // 简单解析输出
        const lines = stdout.trim().split('\n').filter(l => l && !l.startsWith('-'));
        return lines.map(line => {
            const parts = line.split('|').map(p => p.trim());
            return {
                id: parseInt(parts[0]) || 0,
                content: parts[1] || '',
                category: parts[2] || '',
                importance: parseInt(parts[3]) || 0,
                createdAt: parts[4] || ''
            };
        });
    }
    catch {
        return [];
    }
}
async function addMemory(content, category, importance) {
    try {
        const { stdout } = await execAsync(`cd /home/jinyang/.openclaw/workspace && ./scripts/pg-memory.sh add-memory "${content.replace(/"/g, '\\"')}" "${category}" ${importance}`);
        const match = stdout.match(/^(\d+)/);
        return match ? parseInt(match[1]) : 0;
    }
    catch {
        return 0;
    }
}
async function generateDailySummary() {
    const today = new Date().toISOString().split('T')[0];
    // 从 Redis 获取今天的健康检查历史
    const { stdout: historyRaw } = await execAsync(`redis-cli LRANGE "openclaw:health:history" 0 -1 2>/dev/null || echo "[]"`);
    let healthChecks = 0;
    let issuesFound = 0;
    let issuesFixed = 0;
    try {
        const history = historyRaw.trim().split('\n').filter(l => l);
        for (const item of history) {
            try {
                const report = JSON.parse(item);
                const reportDate = new Date(report.timestamp).toISOString().split('T')[0];
                if (reportDate === today) {
                    healthChecks++;
                    issuesFound += report.issues?.length || 0;
                }
            }
            catch { }
        }
    }
    catch { }
    // 获取 Git 提交数
    const { stdout: commitCount } = await execAsync(`cd /home/jinyang/Koma && git log --since="today 00:00" --oneline 2>/dev/null | wc -l || echo "0"`);
    return {
        date: today,
        healthChecks,
        issuesFound,
        issuesFixed,
        agentActivity: {},
        commits: parseInt(commitCount.trim()) || 0,
        learnings: []
    };
}
async function saveDailySummary(summary) {
    const content = `每日总结 ${summary.date}: 健康检查${summary.healthChecks}次, 发现问题${summary.issuesFound}个, 提交${summary.commits}个`;
    await addMemory(content, 'daily_summary', 7);
    // 保存到文件
    const summaryPath = `/home/jinyang/.openclaw/workspace/memory/${summary.date}.md`;
    const existing = await fs.readFile(summaryPath, 'utf-8').catch(() => '');
    const summaryText = `
## 每日总结 (自动生成)
- 健康检查: ${summary.healthChecks} 次
- 发现问题: ${summary.issuesFound} 个
- Git 提交: ${summary.commits} 个
`;
    if (!existing.includes('每日总结 (自动生成)')) {
        await fs.appendFile(summaryPath, summaryText);
    }
}
async function analyzePatterns() {
    const insights = [];
    try {
        // 分析健康检查历史，找出重复问题
        const { stdout: historyRaw } = await execAsync(`redis-cli LRANGE "openclaw:health:history" 0 99 2>/dev/null || echo ""`);
        const issueCount = {};
        const lines = historyRaw.trim().split('\n').filter(l => l);
        for (const line of lines) {
            try {
                const report = JSON.parse(line);
                for (const issue of report.issues || []) {
                    issueCount[issue] = (issueCount[issue] || 0) + 1;
                }
            }
            catch { }
        }
        // 找出频繁出现的问题
        for (const [issue, count] of Object.entries(issueCount)) {
            if (count >= 3) {
                insights.push({
                    pattern: issue,
                    frequency: count,
                    suggestion: `问题"${issue}"出现${count}次，需要根本解决`,
                    confidence: Math.min(count / 10, 1)
                });
            }
        }
    }
    catch { }
    return insights;
}
async function extractLearnings() {
    const learnings = [];
    try {
        // 从 PostgreSQL 获取最近的记忆
        const { stdout } = await execAsync(`cd /home/jinyang/.openclaw/workspace && ./scripts/pg-memory.sh sql "SELECT content FROM memories WHERE category IN ('learning', 'issue', 'milestone') ORDER BY created_at DESC LIMIT 20;" 2>/dev/null`);
        const lines = stdout.trim().split('\n').filter(l => l && !l.startsWith('-'));
        learnings.push(...lines.slice(0, 10));
    }
    catch { }
    return learnings;
}
async function recordLearning(insight) {
    await execAsync(`cd /home/jinyang/.openclaw/workspace && ./scripts/pg-memory.sh add-memory "模式发现: ${insight.pattern} (出现${insight.frequency}次) - ${insight.suggestion}" "pattern" 8`);
    // 同时记录到 Redis 知识库
    await execAsync(`redis-cli HSET "openclaw:knowledge:${insight.pattern.replace(/\s+/g, '_')}" "frequency" "${insight.frequency}" "suggestion" "${insight.suggestion}" "confidence" "${insight.confidence}"`);
}
// ============ 主动通知 ============
async function shouldNotifyUser(event, severity) {
    // 检查是否在工作时间
    const hour = new Date().getHours();
    const isWorkHours = hour >= 9 && hour <= 23;
    // 高优先级总是通知
    if (severity === 'high')
        return true;
    // 中优先级在工作时间通知
    if (severity === 'medium' && isWorkHours)
        return true;
    // 低优先级只在特定时间通知
    if (severity === 'low' && (hour === 10 || hour === 15 || hour === 20))
        return true;
    return false;
}
async function sendNotification(message) {
    // 通过 OpenClaw 发送消息
    // TODO: 实现与 OpenClaw 的集成
    console.log(`📢 通知: ${message}`);
    // 记录通知历史
    await execAsync(`redis-cli LPUSH "openclaw:notifications" "${JSON.stringify({ message, time: Date.now() }).replace(/"/g, '\\"')}"`);
    await execAsync(`redis-cli LTRIM "openclaw:notifications" 0 99`);
}
// ============ OpenClaw 集成 ============
async function sendMessageViaOpenClaw(message) {
    try {
        // 通过 cron wake 机制发送消息
        const { stdout } = await execAsync(`cd /home/jinyang/.openclaw/workspace && openclaw cron wake --text "${message.replace(/"/g, '\\"')}" --mode now 2>/dev/null || echo "fallback"`);
        if (stdout.includes('fallback')) {
            // 备用方案：写入文件让下次 heartbeat 读取
            const alertFile = '/home/jinyang/.openclaw/workspace/ALERT.md';
            await fs.writeFile(alertFile, `# 🚨 Alert\n\n${message}\n\n_Generated at ${new Date().toISOString()}_\n`);
            return true;
        }
        return true;
    }
    catch (error) {
        console.error('发送消息失败:', error);
        return false;
    }
}
async function checkSystemHealth() {
    const health = {
        redis: false,
        postgres: false,
        temporal: false,
        diskUsage: 0,
        memoryUsage: 0
    };
    // Redis
    try {
        const { stdout } = await execAsync('redis-cli ping 2>/dev/null');
        health.redis = stdout.trim() === 'PONG';
    }
    catch { }
    // PostgreSQL
    try {
        const { stdout } = await execAsync('pg_isready -h localhost -p 5432 2>/dev/null');
        health.postgres = stdout.includes('accepting');
    }
    catch { }
    // Temporal
    try {
        const { stdout } = await execAsync('temporal operator namespace list 2>/dev/null | head -1');
        health.temporal = stdout.includes('default');
    }
    catch { }
    // Disk
    try {
        const { stdout } = await execAsync("df -h / | tail -1 | awk '{print $5}' | tr -d '%'");
        health.diskUsage = parseInt(stdout.trim()) || 0;
    }
    catch { }
    // Memory
    try {
        const { stdout } = await execAsync("free | grep Mem | awk '{print int($3/$2 * 100)}'");
        health.memoryUsage = parseInt(stdout.trim()) || 0;
    }
    catch { }
    return health;
}
// ============ Agent 任务管理 ============
async function dispatchTaskToAgent(agent, task) {
    try {
        await execAsync(`tmux -S /tmp/openclaw-agents.sock send-keys -t ${agent} "${task.replace(/"/g, '\\"')}" Enter`);
        // 记录任务派发
        await execAsync(`redis-cli LPUSH "openclaw:tasks:dispatched" "${JSON.stringify({ agent, task, time: Date.now() }).replace(/"/g, '\\"')}"`);
        return true;
    }
    catch {
        return false;
    }
}
async function getAgentWorkload() {
    const workload = {
        'claude-agent': 0,
        'gemini-agent': 0,
        'codex-agent': 0
    };
    try {
        const { stdout } = await execAsync(`redis-cli LRANGE "openclaw:tasks:dispatched" 0 99 2>/dev/null || echo ""`);
        const lines = stdout.trim().split('\n').filter(l => l);
        const oneHourAgo = Date.now() - 3600000;
        for (const line of lines) {
            try {
                const task = JSON.parse(line);
                if (task.time > oneHourAgo && workload[task.agent] !== undefined) {
                    workload[task.agent]++;
                }
            }
            catch { }
        }
    }
    catch { }
    return workload;
}
