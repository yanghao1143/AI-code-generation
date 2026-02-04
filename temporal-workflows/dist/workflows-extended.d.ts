/**
 * 好大儿的神经系统 - 扩展 Workflows
 */
import type * as activities from './activities';
import type * as extActivities from './activities-extended';
/**
 * 代码审查 Workflow
 */
export declare function codeReviewWorkflow(projectPath: string): Promise<{
    typescript: extActivities.CodeReviewResult;
    build: extActivities.CodeReviewResult;
    git: extActivities.GitStatus;
}>;
/**
 * 每日总结 Workflow
 * 每天凌晨运行，生成当天总结
 */
export declare function dailySummaryWorkflow(): Promise<extActivities.DailySummary>;
/**
 * 学习进化 Workflow
 * 定期回顾记忆，提取模式
 */
export declare function learningWorkflow(): Promise<void>;
/**
 * 项目监控 Workflow
 * 持续监控项目状态
 */
export declare function projectMonitorWorkflow(projectPath: string, intervalMinutes?: number): Promise<void>;
/**
 * 综合巡检 Workflow
 * 一次性检查所有系统
 */
export declare function fullInspectionWorkflow(): Promise<{
    health: activities.HealthReport;
    codeReview: {
        typescript: extActivities.CodeReviewResult;
        build: extActivities.CodeReviewResult;
        git: extActivities.GitStatus;
    };
}>;
