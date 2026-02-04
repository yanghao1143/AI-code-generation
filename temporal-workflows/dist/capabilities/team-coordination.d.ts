/**
 * 团队协调能力
 * 管理 Agent 团队，优化协作
 */
export interface AgentProfile {
    name: string;
    strengths: string[];
    weaknesses: string[];
    preferredTasks: string[];
    avgResponseTime: number;
    successRate: number;
}
export interface TaskAssignment {
    task: string;
    agent: string;
    reason: string;
    confidence: number;
}
export declare function getAgentProfile(agent: string): AgentProfile | undefined;
export declare function getAllProfiles(): AgentProfile[];
export declare function selectBestAgent(taskDescription: string): Promise<TaskAssignment>;
export declare function updateAgentStats(agent: string, success: boolean, responseTime: number): Promise<void>;
export declare function getTeamStatus(): Promise<string>;
