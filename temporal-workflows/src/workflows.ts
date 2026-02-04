/**
 * 好大儿的神经系统 - Workflows
 * 这些是编排逻辑，定义了任务的执行流程
 */

import { proxyActivities, sleep, continueAsNew } from '@temporalio/workflow';
import type * as activities from './activities';
import type * as extActivities from './activities-extended';

const {
  checkAgentStatus,
  generateHealthReport,
  saveReportToRedis,
  sendAlertIfNeeded,
  autoFix
} = proxyActivities<typeof activities>({
  startToCloseTimeout: '1 minute',
  retry: {
    maximumAttempts: 3,
    initialInterval: '1 second',
    maximumInterval: '10 seconds'
  }
});

const {
  runTypeScriptCheck,
  runBuildCheck,
  getGitStatus,
  addMemory,
  generateDailySummary,
  saveDailySummary,
  analyzePatterns,
  extractLearnings,
  recordLearning,
  shouldNotifyUser,
  sendNotification,
  sendMessageViaOpenClaw,
  checkSystemHealth,
  dispatchTaskToAgent,
  getAgentWorkload
} = proxyActivities<typeof extActivities>({
  startToCloseTimeout: '3 minutes',
  retry: { maximumAttempts: 2 }
});

/**
 * 健康监控 Workflow
 * 持续运行，定期检查 Agent 状态
 */
export async function healthMonitorWorkflow(intervalMinutes: number = 5): Promise<void> {
  let checkCount = 0;
  
  while (checkCount < 100) { // 每100次检查后重新开始（避免历史过长）
    // 生成健康报告
    const report = await generateHealthReport();
    
    // 保存到 Redis
    await saveReportToRedis(report);
    
    // 如果有问题，尝试自动修复
    if (report.issues.length > 0) {
      for (const issue of report.issues) {
        const fixed = await autoFix(issue);
        if (!fixed) {
          // 无法自动修复，发送告警
          await sendAlertIfNeeded(report);
        }
      }
    }
    
    checkCount++;
    
    // 等待下一次检查
    await sleep(`${intervalMinutes} minutes`);
  }
  
  // 继续执行（重置历史）
  await continueAsNew<typeof healthMonitorWorkflow>(intervalMinutes);
}

/**
 * 单次健康检查 Workflow
 * 执行一次检查并返回结果
 */
export async function singleHealthCheckWorkflow(): Promise<activities.HealthReport> {
  const report = await generateHealthReport();
  await saveReportToRedis(report);
  
  if (report.issues.length > 0) {
    for (const issue of report.issues) {
      await autoFix(issue);
    }
  }
  
  return report;
}

/**
 * 每日总结 Workflow
 * 每天生成一份总结报告
 */
export async function dailySummaryWorkflow(): Promise<extActivities.DailySummary> {
  const summary = await generateDailySummary();
  await saveDailySummary(summary);
  return summary;
}

/**
 * 综合巡检 Workflow
 */
export async function fullInspectionWorkflow(): Promise<{
  health: activities.HealthReport;
  codeReview: {
    typescript: extActivities.CodeReviewResult;
    build: extActivities.CodeReviewResult;
    git: extActivities.GitStatus;
  };
}> {
  const projectPath = '/home/jinyang/Koma/frontend';
  
  // 并行执行
  const [health, typescript, build, git] = await Promise.all([
    generateHealthReport(),
    runTypeScriptCheck(projectPath),
    runBuildCheck(projectPath),
    getGitStatus(projectPath)
  ]);
  
  // 保存健康报告
  await saveReportToRedis(health);
  
  // 自动修复
  for (const issue of health.issues) {
    await autoFix(issue);
  }
  
  // 记录到记忆
  if (typescript.hasErrors || build.hasErrors) {
    await addMemory(
      `巡检发现问题: TS错误${typescript.errorCount}个, 构建${build.hasErrors ? '失败' : '成功'}`,
      'inspection',
      8
    );
  }
  
  return {
    health,
    codeReview: { typescript, build, git }
  };
}

/**
 * 学习进化 Workflow
 * 分析历史数据，发现模式，生成学习
 */
export async function learningEvolutionWorkflow(): Promise<{
  insights: extActivities.LearningInsight[];
  learnings: string[];
}> {
  // 分析模式
  const insights = await analyzePatterns();
  
  // 记录发现的模式
  for (const insight of insights) {
    if (insight.confidence > 0.5) {
      await recordLearning(insight);
    }
  }
  
  // 提取历史学习
  const learnings = await extractLearnings();
  
  // 如果发现重要模式，通知用户
  const importantInsights = insights.filter(i => i.frequency >= 5);
  if (importantInsights.length > 0) {
    const shouldNotify = await shouldNotifyUser('pattern_discovered', 'medium');
    if (shouldNotify) {
      await sendNotification(
        `发现 ${importantInsights.length} 个重复模式需要关注`
      );
    }
  }
  
  return { insights, learnings };
}

/**
 * 系统监控 Workflow
 * 监控基础设施健康状态
 */
export async function systemMonitorWorkflow(): Promise<extActivities.SystemHealth> {
  const health = await checkSystemHealth();
  
  // 检查是否有问题
  const issues: string[] = [];
  if (!health.redis) issues.push('Redis 不可用');
  if (!health.postgres) issues.push('PostgreSQL 不可用');
  if (!health.temporal) issues.push('Temporal 不可用');
  if (health.diskUsage > 90) issues.push(`磁盘使用率过高: ${health.diskUsage}%`);
  if (health.memoryUsage > 90) issues.push(`内存使用率过高: ${health.memoryUsage}%`);
  
  // 如果有严重问题，发送告警
  if (issues.length > 0) {
    const shouldNotify = await shouldNotifyUser('system_issue', 'high');
    if (shouldNotify) {
      await sendMessageViaOpenClaw(`🚨 系统告警: ${issues.join(', ')}`);
    }
  }
  
  return health;
}

/**
 * 智能任务调度 Workflow
 * 根据 Agent 负载分配任务
 */
export async function smartDispatchWorkflow(task: string): Promise<{
  agent: string;
  success: boolean;
}> {
  // 获取各 Agent 负载
  const workload = await getAgentWorkload();
  
  // 获取各 Agent 状态
  const healthReport = await generateHealthReport();
  
  // 选择最佳 Agent
  let bestAgent = 'claude-agent';
  let minLoad = Infinity;
  
  for (const status of healthReport.agents) {
    if (status.alive && status.diagnosis !== 'error') {
      const load = workload[status.name] || 0;
      if (load < minLoad) {
        minLoad = load;
        bestAgent = status.name;
      }
    }
  }
  
  // 派发任务
  const success = await dispatchTaskToAgent(bestAgent, task);
  
  if (success) {
    await addMemory(`任务派发: "${task.slice(0, 50)}..." -> ${bestAgent}`, 'task-dispatch', 5);
  }
  
  return { agent: bestAgent, success };
}

/**
 * 主动汇报 Workflow
 * 定期向用户汇报状态
 */
export async function proactiveReportWorkflow(): Promise<void> {
  // 收集信息
  const health = await generateHealthReport();
  const systemHealth = await checkSystemHealth();
  const workload = await getAgentWorkload();
  
  // 生成汇报
  const lines: string[] = ['📊 状态汇报:'];
  
  // Agent 状态
  const activeAgents = health.agents.filter(a => a.alive && a.diagnosis !== 'error').length;
  lines.push(`• Agent: ${activeAgents}/3 活跃`);
  
  // 系统状态
  if (systemHealth.diskUsage > 80 || systemHealth.memoryUsage > 80) {
    lines.push(`• 资源: 磁盘 ${systemHealth.diskUsage}%, 内存 ${systemHealth.memoryUsage}%`);
  }
  
  // 任务负载
  const totalTasks = Object.values(workload).reduce((a, b) => a + b, 0);
  if (totalTasks > 0) {
    lines.push(`• 最近1小时任务: ${totalTasks} 个`);
  }
  
  // 问题
  if (health.issues.length > 0) {
    lines.push(`• 待处理问题: ${health.issues.length} 个`);
  }
  
  // 只有在有值得汇报的内容时才发送
  if (lines.length > 1) {
    const shouldNotify = await shouldNotifyUser('status_report', 'low');
    if (shouldNotify) {
      await sendMessageViaOpenClaw(lines.join('\n'));
    }
  }
}

// ============ 技术总监能力 ============

import type * as capabilities from './capabilities';

const {
  getProjects,
  checkAllProjects,
  getProjectSummary,
  selectBestAgent,
  getTeamStatus,
  recordDecision,
  getRecentDecisions
} = proxyActivities<typeof capabilities>({
  startToCloseTimeout: '2 minutes',
  retry: { maximumAttempts: 2 }
});

/**
 * 技术总监日常巡检
 */
export async function directorDailyReviewWorkflow(): Promise<{
  projectSummary: string;
  teamStatus: string;
  issues: string[];
  actions: string[];
}> {
  const issues: string[] = [];
  const actions: string[] = [];

  // 1. 检查所有项目
  const projectHealths = await checkAllProjects();
  const projectSummary = await getProjectSummary();
  
  for (const health of projectHealths) {
    if (health.hasErrors) {
      issues.push(`${health.project}: ${health.errorCount} 个 TypeScript 错误`);
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
    } else if (agent.diagnosis === 'waiting_confirm') {
      await autoFix(`${agent.name} 等待确认`);
      actions.push(`已自动确认 ${agent.name}`);
    }
  }

  await addMemory(
    `技术总监巡检: ${projectHealths.length}个项目, ${issues.length}个问题, ${actions.length}个行动`,
    'director-review',
    7
  );

  return { projectSummary, teamStatus, issues, actions };
}

/**
 * 智能任务分配
 */
export async function intelligentTaskAssignmentWorkflow(task: string): Promise<{
  agent: string;
  reason: string;
  success: boolean;
}> {
  const assignment = await selectBestAgent(task);
  const success = await dispatchTaskToAgent(assignment.agent, task);
  
  if (success) {
    await addMemory(`任务分配: "${task.slice(0, 50)}..." -> ${assignment.agent}`, 'task-assignment', 5);
  }
  
  return { agent: assignment.agent, reason: assignment.reason, success };
}

// ============ 自愈能力 ============

const {
  detectProblems,
  autoFixProblems,
  runSelfHealing
} = proxyActivities<typeof capabilities>({
  startToCloseTimeout: '2 minutes',
  retry: { maximumAttempts: 2 }
});

/**
 * 自愈 Workflow
 * 自动检测并修复问题
 */
export async function selfHealingWorkflow(): Promise<{
  problemsFound: number;
  problemsFixed: number;
  notified: boolean;
}> {
  const result = await runSelfHealing();
  
  let notified = false;
  
  // 如果有无法自动修复的问题，通知用户
  const unfixed = result.results.filter(r => !r.fixed);
  if (unfixed.length > 0) {
    const message = `⚠️ 发现 ${result.problemsFound} 个问题，修复了 ${result.problemsFixed} 个，还有 ${unfixed.length} 个需要手动处理：\n${unfixed.map(r => `- ${r.problem}: ${r.action}`).join('\n')}`;
    await sendMessageViaOpenClaw(message);
    notified = true;
  }
  
  // 记录
  if (result.problemsFound > 0) {
    await addMemory(
      `自愈运行: 发现${result.problemsFound}个问题, 修复${result.problemsFixed}个`,
      'self-healing',
      result.problemsFixed < result.problemsFound ? 8 : 5
    );
  }
  
  return {
    problemsFound: result.problemsFound,
    problemsFixed: result.problemsFixed,
    notified
  };
}

// ============ 深度学习 ============

const {
  analyzeIssuePatterns,
  analyzeSuccessPatterns,
  generateInsights,
  runDeepLearning
} = proxyActivities<typeof capabilities>({
  startToCloseTimeout: '3 minutes',
  retry: { maximumAttempts: 2 }
});

/**
 * 深度学习 Workflow
 * 分析历史，提取模式，生成知识
 */
export async function deepLearningWorkflow(): Promise<{
  patternsFound: number;
  insightsGenerated: number;
  knowledgeSaved: number;
}> {
  const result = await runDeepLearning();
  
  if (result.knowledgeSaved > 0) {
    await addMemory(
      `深度学习: 发现${result.patternsFound}个模式, 生成${result.insightsGenerated}个洞察, 保存${result.knowledgeSaved}条知识`,
      'deep-learning',
      7
    );
  }
  
  return result;
}
