/**
 * 好大儿的神经系统 - 扩展 Workflows
 */

import { proxyActivities, sleep, continueAsNew } from '@temporalio/workflow';
import type * as activities from './activities';
import type * as extActivities from './activities-extended';

const {
  generateHealthReport,
  saveReportToRedis,
  sendAlertIfNeeded,
  autoFix
} = proxyActivities<typeof activities>({
  startToCloseTimeout: '1 minute',
  retry: { maximumAttempts: 3 }
});

const {
  runTypeScriptCheck,
  runBuildCheck,
  getGitStatus,
  searchMemories,
  addMemory,
  generateDailySummary,
  saveDailySummary
} = proxyActivities<typeof extActivities>({
  startToCloseTimeout: '3 minutes',
  retry: { maximumAttempts: 2 }
});

/**
 * 代码审查 Workflow
 */
export async function codeReviewWorkflow(projectPath: string): Promise<{
  typescript: extActivities.CodeReviewResult;
  build: extActivities.CodeReviewResult;
  git: extActivities.GitStatus;
}> {
  const [typescript, build, git] = await Promise.all([
    runTypeScriptCheck(projectPath),
    runBuildCheck(projectPath),
    getGitStatus(projectPath)
  ]);
  
  // 如果有错误，记录到记忆
  if (typescript.hasErrors || build.hasErrors) {
    await addMemory(
      `代码审查发现问题: TS错误${typescript.errorCount}个, 构建${build.hasErrors ? '失败' : '成功'}`,
      'code-review',
      8
    );
  }
  
  return { typescript, build, git };
}

/**
 * 每日总结 Workflow
 * 每天凌晨运行，生成当天总结
 */
export async function dailySummaryWorkflow(): Promise<extActivities.DailySummary> {
  const summary = await generateDailySummary();
  await saveDailySummary(summary);
  return summary;
}

/**
 * 学习进化 Workflow
 * 定期回顾记忆，提取模式
 */
export async function learningWorkflow(): Promise<void> {
  // 搜索最近的问题和解决方案
  const recentIssues = await searchMemories('问题', 20);
  const recentLearnings = await searchMemories('学习', 20);
  
  // TODO: 用 LLM 分析模式，生成新的学习
  // 现在先简单记录
  if (recentIssues.length > 0) {
    await addMemory(
      `学习回顾: 发现${recentIssues.length}个历史问题记录，${recentLearnings.length}个学习记录`,
      'learning-review',
      6
    );
  }
}

/**
 * 项目监控 Workflow
 * 持续监控项目状态
 */
export async function projectMonitorWorkflow(
  projectPath: string,
  intervalMinutes: number = 30
): Promise<void> {
  let checkCount = 0;
  
  while (checkCount < 48) { // 24小时后重启
    const git = await getGitStatus(projectPath);
    
    // 如果有未提交的修改，记录
    if (git.modified > 0 || git.untracked > 0) {
      console.log(`项目有 ${git.modified} 个修改, ${git.untracked} 个未跟踪文件`);
    }
    
    checkCount++;
    await sleep(`${intervalMinutes} minutes`);
  }
  
  await continueAsNew<typeof projectMonitorWorkflow>(projectPath, intervalMinutes);
}

/**
 * 综合巡检 Workflow
 * 一次性检查所有系统
 */
export async function fullInspectionWorkflow(): Promise<{
  health: activities.HealthReport;
  codeReview: {
    typescript: extActivities.CodeReviewResult;
    build: extActivities.CodeReviewResult;
    git: extActivities.GitStatus;
  };
}> {
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
