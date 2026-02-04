/**
 * 好大儿的神经系统 - 扩展 Activities
 * 代码审查、学习、记忆管理
 */
export interface CodeReviewResult {
    hasErrors: boolean;
    errorCount: number;
    errors: string[];
    hasWarnings: boolean;
    warningCount: number;
    buildTime?: number;
}
export declare function runTypeScriptCheck(projectPath: string): Promise<CodeReviewResult>;
export declare function runBuildCheck(projectPath: string): Promise<CodeReviewResult>;
export interface GitStatus {
    branch: string;
    ahead: number;
    behind: number;
    modified: number;
    untracked: number;
    lastCommit: string;
    lastCommitTime: string;
}
export declare function getGitStatus(repoPath: string): Promise<GitStatus>;
export interface Memory {
    id: number;
    content: string;
    category: string;
    importance: number;
    createdAt: string;
}
export declare function searchMemories(query: string, limit?: number): Promise<Memory[]>;
export declare function addMemory(content: string, category: string, importance: number): Promise<number>;
export interface DailySummary {
    date: string;
    healthChecks: number;
    issuesFound: number;
    issuesFixed: number;
    agentActivity: Record<string, string>;
    commits: number;
    learnings: string[];
}
export declare function generateDailySummary(): Promise<DailySummary>;
export declare function saveDailySummary(summary: DailySummary): Promise<void>;
export interface LearningInsight {
    pattern: string;
    frequency: number;
    suggestion: string;
    confidence: number;
}
export declare function analyzePatterns(): Promise<LearningInsight[]>;
export declare function extractLearnings(): Promise<string[]>;
export declare function recordLearning(insight: LearningInsight): Promise<void>;
export declare function shouldNotifyUser(event: string, severity: 'low' | 'medium' | 'high'): Promise<boolean>;
export declare function sendNotification(message: string): Promise<void>;
export declare function sendMessageViaOpenClaw(message: string): Promise<boolean>;
export interface SystemHealth {
    redis: boolean;
    postgres: boolean;
    temporal: boolean;
    diskUsage: number;
    memoryUsage: number;
}
export declare function checkSystemHealth(): Promise<SystemHealth>;
export declare function dispatchTaskToAgent(agent: string, task: string): Promise<boolean>;
export declare function getAgentWorkload(): Promise<Record<string, number>>;
