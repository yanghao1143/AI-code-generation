/**
 * 好大儿的神经系统 - Workflows
 * 这些是编排逻辑，定义了任务的执行流程
 */
import type * as activities from './activities';
import type * as extActivities from './activities-extended';
/**
 * 健康监控 Workflow
 * 持续运行，定期检查 Agent 状态
 */
export declare function healthMonitorWorkflow(intervalMinutes?: number): Promise<void>;
/**
 * 单次健康检查 Workflow
 * 执行一次检查并返回结果
 */
export declare function singleHealthCheckWorkflow(): Promise<activities.HealthReport>;
/**
 * 每日总结 Workflow
 * 每天生成一份总结报告
 */
export declare function dailySummaryWorkflow(): Promise<extActivities.DailySummary>;
/**
 * 综合巡检 Workflow
 */
export declare function fullInspectionWorkflow(): Promise<{
    health: activities.HealthReport;
    codeReview: {
        typescript: extActivities.CodeReviewResult;
        build: extActivities.CodeReviewResult;
        git: extActivities.GitStatus;
    };
}>;
/**
 * 学习进化 Workflow
 * 分析历史数据，发现模式，生成学习
 */
export declare function learningEvolutionWorkflow(): Promise<{
    insights: extActivities.LearningInsight[];
    learnings: string[];
}>;
/**
 * 系统监控 Workflow
 * 监控基础设施健康状态
 */
export declare function systemMonitorWorkflow(): Promise<extActivities.SystemHealth>;
/**
 * 智能任务调度 Workflow
 * 根据 Agent 负载分配任务
 */
export declare function smartDispatchWorkflow(task: string): Promise<{
    agent: string;
    success: boolean;
}>;
/**
 * 主动汇报 Workflow
 * 定期向用户汇报状态
 */
export declare function proactiveReportWorkflow(): Promise<void>;
/**
 * 技术总监日常巡检
 */
export declare function directorDailyReviewWorkflow(): Promise<{
    projectSummary: string;
    teamStatus: string;
    issues: string[];
    actions: string[];
}>;
/**
 * 智能任务分配
 */
export declare function intelligentTaskAssignmentWorkflow(task: string): Promise<{
    agent: string;
    reason: string;
    success: boolean;
}>;
/**
 * 自愈 Workflow
 * 自动检测并修复问题
 */
export declare function selfHealingWorkflow(): Promise<{
    problemsFound: number;
    problemsFixed: number;
    notified: boolean;
}>;
/**
 * 深度学习 Workflow
 * 分析历史，提取模式，生成知识
 */
export declare function deepLearningWorkflow(): Promise<{
    patternsFound: number;
    insightsGenerated: number;
    knowledgeSaved: number;
}>;
