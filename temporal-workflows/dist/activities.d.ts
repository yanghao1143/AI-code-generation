/**
 * 好大儿的神经系统 - Activities
 * 这些是实际执行的操作，可以访问外部系统
 */
export interface AgentStatus {
    name: string;
    alive: boolean;
    lastOutput: string;
    diagnosis: string;
}
export interface HealthReport {
    timestamp: number;
    agents: AgentStatus[];
    overallHealth: 'healthy' | 'degraded' | 'critical';
    issues: string[];
    recommendations: string[];
}
/**
 * 检查单个 Agent 的状态
 */
export declare function checkAgentStatus(agentName: string): Promise<AgentStatus>;
/**
 * 检查所有 Agent 并生成健康报告
 */
export declare function generateHealthReport(): Promise<HealthReport>;
/**
 * 保存报告到 Redis
 */
export declare function saveReportToRedis(report: HealthReport): Promise<void>;
/**
 * 发送告警（如果需要）
 */
export declare function sendAlertIfNeeded(report: HealthReport): Promise<boolean>;
/**
 * 自动修复常见问题
 */
export declare function autoFix(issue: string): Promise<boolean>;
