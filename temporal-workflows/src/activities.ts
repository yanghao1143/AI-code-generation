/**
 * 好大儿的神经系统 - Activities
 * 这些是实际执行的操作，可以访问外部系统
 */

import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

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
export async function checkAgentStatus(agentName: string): Promise<AgentStatus> {
  try {
    const { stdout } = await execAsync(
      `tmux -S /tmp/openclaw-agents.sock capture-pane -t ${agentName} -p 2>/dev/null | tail -20`
    );
    
    const output = stdout.trim();
    const alive = output.length > 0;
    
    // 诊断状态
    let diagnosis = 'unknown';
    if (output.includes('bypass permissions')) diagnosis = 'waiting_confirm';
    else if (output.includes('Working') || output.includes('Thinking')) diagnosis = 'working';
    else if (output.includes('error') || output.includes('Error')) diagnosis = 'error';
    else if (output.includes('done') || output.includes('Done')) diagnosis = 'idle';
    else if (alive) diagnosis = 'active';
    
    return { name: agentName, alive, lastOutput: output.slice(-200), diagnosis };
  } catch (error) {
    return { name: agentName, alive: false, lastOutput: '', diagnosis: 'unreachable' };
  }
}

/**
 * 检查所有 Agent 并生成健康报告
 */
export async function generateHealthReport(): Promise<HealthReport> {
  const agents = ['claude-agent', 'gemini-agent', 'codex-agent'];
  const statuses = await Promise.all(agents.map(checkAgentStatus));
  
  const issues: string[] = [];
  const recommendations: string[] = [];
  
  for (const status of statuses) {
    if (!status.alive) {
      issues.push(`${status.name} 不可达`);
      recommendations.push(`重启 ${status.name}`);
    } else if (status.diagnosis === 'waiting_confirm') {
      issues.push(`${status.name} 等待确认`);
      recommendations.push(`给 ${status.name} 发送 Enter`);
    } else if (status.diagnosis === 'error') {
      issues.push(`${status.name} 遇到错误`);
    }
  }
  
  const aliveCount = statuses.filter(s => s.alive).length;
  let overallHealth: 'healthy' | 'degraded' | 'critical' = 'healthy';
  if (aliveCount === 0) overallHealth = 'critical';
  else if (aliveCount < agents.length || issues.length > 0) overallHealth = 'degraded';
  
  return {
    timestamp: Date.now(),
    agents: statuses,
    overallHealth,
    issues,
    recommendations
  };
}

/**
 * 保存报告到 Redis
 */
export async function saveReportToRedis(report: HealthReport): Promise<void> {
  const { exec } = require('child_process');
  const reportJson = JSON.stringify(report).replace(/"/g, '\\"');
  await execAsync(`redis-cli SET "openclaw:health:latest" "${reportJson}"`);
  await execAsync(`redis-cli LPUSH "openclaw:health:history" "${reportJson}"`);
  await execAsync(`redis-cli LTRIM "openclaw:health:history" 0 99`); // 保留最近100条
}

/**
 * 发送告警（如果需要）
 */
export async function sendAlertIfNeeded(report: HealthReport): Promise<boolean> {
  if (report.overallHealth === 'critical') {
    // TODO: 通过 OpenClaw 发送消息
    console.log('🚨 CRITICAL: 所有 Agent 不可用！');
    return true;
  }
  if (report.issues.length > 0) {
    console.log(`⚠️ 发现 ${report.issues.length} 个问题:`, report.issues);
    return true;
  }
  return false;
}

/**
 * 自动修复常见问题
 */
export async function autoFix(issue: string): Promise<boolean> {
  if (issue.includes('等待确认')) {
    const agentMatch = issue.match(/(\w+-agent)/);
    if (agentMatch) {
      await execAsync(
        `tmux -S /tmp/openclaw-agents.sock send-keys -t ${agentMatch[1]} Enter`
      );
      console.log(`✅ 已发送 Enter 给 ${agentMatch[1]}`);
      return true;
    }
  }
  return false;
}
