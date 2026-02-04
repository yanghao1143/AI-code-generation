/**
 * 技术总监 Workflow
 * 综合管理项目、团队、决策
 */
/**
 * 技术总监日常巡检
 * 每天运行，检查所有项目和团队状态
 */
export declare function directorDailyReviewWorkflow(): Promise<{
    projectSummary: string;
    teamStatus: string;
    issues: string[];
    actions: string[];
}>;
/**
 * 智能任务分配
 * 根据任务内容选择最佳 Agent
 */
export declare function intelligentTaskAssignmentWorkflow(task: string, priority?: 'low' | 'medium' | 'high'): Promise<{
    agent: string;
    reason: string;
    success: boolean;
}>;
/**
 * 技术决策记录
 */
export declare function recordTechDecisionWorkflow(title: string, context: string, decision: string, consequences: string): Promise<number>;
/**
 * 周报生成
 */
export declare function weeklyReportWorkflow(): Promise<string>;
