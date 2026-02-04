"use strict";
/**
 * 技术总监 Workflow
 * 综合管理项目、团队、决策
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.directorDailyReviewWorkflow = directorDailyReviewWorkflow;
exports.intelligentTaskAssignmentWorkflow = intelligentTaskAssignmentWorkflow;
exports.recordTechDecisionWorkflow = recordTechDecisionWorkflow;
exports.weeklyReportWorkflow = weeklyReportWorkflow;
const workflow_1 = require("@temporalio/workflow");
const { getProjects, checkAllProjects, getProjectSummary, selectBestAgent, getTeamStatus, recordDecision, getRecentDecisions } = (0, workflow_1.proxyActivities)({
    startToCloseTimeout: '2 minutes',
    retry: { maximumAttempts: 2 }
});
const { generateHealthReport, autoFix } = (0, workflow_1.proxyActivities)({
    startToCloseTimeout: '1 minute',
    retry: { maximumAttempts: 3 }
});
const { sendMessageViaOpenClaw, dispatchTaskToAgent, addMemory } = (0, workflow_1.proxyActivities)({
    startToCloseTimeout: '2 minutes',
    retry: { maximumAttempts: 2 }
});
/**
 * 技术总监日常巡检
 * 每天运行，检查所有项目和团队状态
 */
async function directorDailyReviewWorkflow() {
    const issues = [];
    const actions = [];
    // 1. 检查所有项目
    const projectHealths = await checkAllProjects();
    const projectSummary = await getProjectSummary();
    for (const health of projectHealths) {
        if (health.hasErrors) {
            issues.push(`${health.project}: ${health.errorCount} 个 TypeScript 错误`);
            // 自动分配修复任务
            const assignment = await selectBestAgent(`修复 ${health.project} 的 TypeScript 错误`);
            await dispatchTaskToAgent(assignment.agent, `请检查并修复 ${health.project} 项目的 TypeScript 错误`);
            actions.push(`已派发修复任务给 ${assignment.agent}`);
        }
        if (health.uncommittedChanges > 5) {
            issues.push(`${health.project}: ${health.uncommittedChanges} 个未提交修改`);
        }
    }
    // 2. 检查团队状态
    const agentHealth = await generateHealthReport();
    const teamStatus = await getTeamStatus();
    for (const agent of agentHealth.agents) {
        if (!agent.alive) {
            issues.push(`${agent.name} 不可用`);
        }
        else if (agent.diagnosis === 'waiting_confirm') {
            await autoFix(`${agent.name} 等待确认`);
            actions.push(`已自动确认 ${agent.name}`);
        }
    }
    // 3. 记录巡检结果
    await addMemory(`技术总监日常巡检: ${projectHealths.length}个项目, ${issues.length}个问题, ${actions.length}个行动`, 'director-review', 7);
    return { projectSummary, teamStatus, issues, actions };
}
/**
 * 智能任务分配
 * 根据任务内容选择最佳 Agent
 */
async function intelligentTaskAssignmentWorkflow(task, priority = 'medium') {
    // 选择最佳 Agent
    const assignment = await selectBestAgent(task);
    // 派发任务
    const success = await dispatchTaskToAgent(assignment.agent, task);
    // 记录
    if (success) {
        await addMemory(`任务分配: "${task.slice(0, 50)}..." -> ${assignment.agent} (${assignment.reason})`, 'task-assignment', priority === 'high' ? 8 : 5);
    }
    return {
        agent: assignment.agent,
        reason: assignment.reason,
        success
    };
}
/**
 * 技术决策记录
 */
async function recordTechDecisionWorkflow(title, context, decision, consequences) {
    const id = await recordDecision({
        title,
        context,
        decision,
        consequences,
        status: 'accepted',
        date: new Date().toISOString(),
        tags: []
    });
    // 通知
    await sendMessageViaOpenClaw(`📝 技术决策已记录: ${title}`);
    return id;
}
/**
 * 周报生成
 */
async function weeklyReportWorkflow() {
    const lines = ['📊 本周技术总监周报\n'];
    // 项目状态
    const projectSummary = await getProjectSummary();
    lines.push(projectSummary);
    // 团队状态
    const teamStatus = await getTeamStatus();
    lines.push('\n' + teamStatus);
    // 最近决策
    const decisions = await getRecentDecisions(5);
    if (decisions.length > 0) {
        lines.push('\n📝 最近技术决策:');
        decisions.forEach(d => lines.push(`  - ${d.slice(0, 80)}...`));
    }
    const report = lines.join('\n');
    // 保存
    await addMemory(`周报生成: ${new Date().toISOString().split('T')[0]}`, 'weekly-report', 8);
    return report;
}
