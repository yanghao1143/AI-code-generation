"use strict";
/**
 * 好大儿的神经系统 - 扩展 Workflows
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.codeReviewWorkflow = codeReviewWorkflow;
exports.dailySummaryWorkflow = dailySummaryWorkflow;
exports.learningWorkflow = learningWorkflow;
exports.projectMonitorWorkflow = projectMonitorWorkflow;
exports.fullInspectionWorkflow = fullInspectionWorkflow;
const workflow_1 = require("@temporalio/workflow");
const { generateHealthReport, saveReportToRedis, sendAlertIfNeeded, autoFix } = (0, workflow_1.proxyActivities)({
    startToCloseTimeout: '1 minute',
    retry: { maximumAttempts: 3 }
});
const { runTypeScriptCheck, runBuildCheck, getGitStatus, searchMemories, addMemory, generateDailySummary, saveDailySummary } = (0, workflow_1.proxyActivities)({
    startToCloseTimeout: '3 minutes',
    retry: { maximumAttempts: 2 }
});
/**
 * 代码审查 Workflow
 */
async function codeReviewWorkflow(projectPath) {
    const [typescript, build, git] = await Promise.all([
        runTypeScriptCheck(projectPath),
        runBuildCheck(projectPath),
        getGitStatus(projectPath)
    ]);
    // 如果有错误，记录到记忆
    if (typescript.hasErrors || build.hasErrors) {
        await addMemory(`代码审查发现问题: TS错误${typescript.errorCount}个, 构建${build.hasErrors ? '失败' : '成功'}`, 'code-review', 8);
    }
    return { typescript, build, git };
}
/**
 * 每日总结 Workflow
 * 每天凌晨运行，生成当天总结
 */
async function dailySummaryWorkflow() {
    const summary = await generateDailySummary();
    await saveDailySummary(summary);
    return summary;
}
/**
 * 学习进化 Workflow
 * 定期回顾记忆，提取模式
 */
async function learningWorkflow() {
    // 搜索最近的问题和解决方案
    const recentIssues = await searchMemories('问题', 20);
    const recentLearnings = await searchMemories('学习', 20);
    // TODO: 用 LLM 分析模式，生成新的学习
    // 现在先简单记录
    if (recentIssues.length > 0) {
        await addMemory(`学习回顾: 发现${recentIssues.length}个历史问题记录，${recentLearnings.length}个学习记录`, 'learning-review', 6);
    }
}
/**
 * 项目监控 Workflow
 * 持续监控项目状态
 */
async function projectMonitorWorkflow(projectPath, intervalMinutes = 30) {
    let checkCount = 0;
    while (checkCount < 48) { // 24小时后重启
        const git = await getGitStatus(projectPath);
        // 如果有未提交的修改，记录
        if (git.modified > 0 || git.untracked > 0) {
            console.log(`项目有 ${git.modified} 个修改, ${git.untracked} 个未跟踪文件`);
        }
        checkCount++;
        await (0, workflow_1.sleep)(`${intervalMinutes} minutes`);
    }
    await (0, workflow_1.continueAsNew)(projectPath, intervalMinutes);
}
/**
 * 综合巡检 Workflow
 * 一次性检查所有系统
 */
async function fullInspectionWorkflow() {
    // 并行执行所有检查
    const [health, codeReview] = await Promise.all([
        generateHealthReport(),
        (async () => {
            const projectPath = '/home/jinyang/Koma/frontend';
            const [typescript, build, git] = await Promise.all([
                runTypeScriptCheck(projectPath),
                runBuildCheck(projectPath),
                getGitStatus(projectPath)
            ]);
            return { typescript, build, git };
        })()
    ]);
    // 保存健康报告
    await saveReportToRedis(health);
    // 自动修复问题
    for (const issue of health.issues) {
        await autoFix(issue);
    }
    return { health, codeReview };
}
