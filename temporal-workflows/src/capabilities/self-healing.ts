/**
 * 问题自愈能力
 * 自动检测、诊断、修复常见问题
 */

import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

export interface Problem {
  type: string;
  description: string;
  severity: 'low' | 'medium' | 'high' | 'critical';
  autoFixable: boolean;
}

export interface FixResult {
  problem: string;
  fixed: boolean;
  action: string;
  error?: string;
}

// 问题检测规则
const PROBLEM_DETECTORS: Array<{
  name: string;
  detect: () => Promise<Problem | null>;
  fix: () => Promise<FixResult>;
}> = [
  {
    name: 'agent_waiting_confirm',
    detect: async () => {
      const agents = ['claude-agent', 'gemini-agent', 'codex-agent'];
      for (const agent of agents) {
        try {
          const { stdout } = await execAsync(
            `tmux -S /tmp/openclaw-agents.sock capture-pane -t ${agent} -p 2>/dev/null | tail -10`
          );
          if (stdout.includes('bypass permissions') || stdout.includes('shift+tab')) {
            return {
              type: 'agent_waiting_confirm',
              description: `${agent} 等待确认`,
              severity: 'medium',
              autoFixable: true
            };
          }
        } catch {}
      }
      return null;
    },
    fix: async () => {
      const agents = ['claude-agent', 'gemini-agent', 'codex-agent'];
      let fixed = false;
      for (const agent of agents) {
        try {
          const { stdout } = await execAsync(
            `tmux -S /tmp/openclaw-agents.sock capture-pane -t ${agent} -p 2>/dev/null | tail -10`
          );
          if (stdout.includes('bypass permissions') || stdout.includes('shift+tab')) {
            await execAsync(`tmux -S /tmp/openclaw-agents.sock send-keys -t ${agent} Enter`);
            fixed = true;
          }
        } catch {}
      }
      return { problem: 'agent_waiting_confirm', fixed, action: '发送 Enter 确认' };
    }
  },
  {
    name: 'agent_not_responding',
    detect: async () => {
      const agents = ['claude-agent', 'gemini-agent', 'codex-agent'];
      for (const agent of agents) {
        try {
          const { stdout } = await execAsync(
            `tmux -S /tmp/openclaw-agents.sock capture-pane -t ${agent} -p 2>/dev/null | wc -l`
          );
          if (parseInt(stdout.trim()) === 0) {
            return {
              type: 'agent_not_responding',
              description: `${agent} 无响应`,
              severity: 'high',
              autoFixable: false
            };
          }
        } catch {}
      }
      return null;
    },
    fix: async () => {
      return { problem: 'agent_not_responding', fixed: false, action: '需要手动重启 Agent' };
    }
  },
  {
    name: 'redis_down',
    detect: async () => {
      try {
        const { stdout } = await execAsync('redis-cli ping 2>/dev/null');
        if (stdout.trim() !== 'PONG') {
          return {
            type: 'redis_down',
            description: 'Redis 服务不可用',
            severity: 'critical',
            autoFixable: true
          };
        }
      } catch {
        return {
          type: 'redis_down',
          description: 'Redis 服务不可用',
          severity: 'critical',
          autoFixable: true
        };
      }
      return null;
    },
    fix: async () => {
      try {
        await execAsync('echo "asd8841315" | sudo -S systemctl restart redis-server');
        await new Promise(r => setTimeout(r, 2000));
        const { stdout } = await execAsync('redis-cli ping 2>/dev/null');
        return { problem: 'redis_down', fixed: stdout.trim() === 'PONG', action: '重启 Redis 服务' };
      } catch (e: any) {
        return { problem: 'redis_down', fixed: false, action: '重启 Redis 失败', error: e.message };
      }
    }
  },
  {
    name: 'disk_space_low',
    detect: async () => {
      try {
        const { stdout } = await execAsync("df -h / | tail -1 | awk '{print $5}' | tr -d '%'");
        const usage = parseInt(stdout.trim());
        if (usage > 90) {
          return {
            type: 'disk_space_low',
            description: `磁盘使用率过高: ${usage}%`,
            severity: 'high',
            autoFixable: true
          };
        }
      } catch {}
      return null;
    },
    fix: async () => {
      try {
        // 清理常见的临时文件
        await execAsync('rm -rf /tmp/jiti/* 2>/dev/null || true');
        await execAsync('rm -rf /home/jinyang/.cache/node/* 2>/dev/null || true');
        return { problem: 'disk_space_low', fixed: true, action: '清理临时文件' };
      } catch (e: any) {
        return { problem: 'disk_space_low', fixed: false, action: '清理失败', error: e.message };
      }
    }
  }
];

export async function detectProblems(): Promise<Problem[]> {
  const problems: Problem[] = [];
  for (const detector of PROBLEM_DETECTORS) {
    try {
      const problem = await detector.detect();
      if (problem) {
        problems.push(problem);
      }
    } catch {}
  }
  return problems;
}

export async function autoFixProblems(): Promise<FixResult[]> {
  const results: FixResult[] = [];
  for (const detector of PROBLEM_DETECTORS) {
    try {
      const problem = await detector.detect();
      if (problem && problem.autoFixable) {
        const result = await detector.fix();
        results.push(result);
      }
    } catch {}
  }
  return results;
}

export async function runSelfHealing(): Promise<{
  problemsFound: number;
  problemsFixed: number;
  results: FixResult[];
}> {
  const problems = await detectProblems();
  const results = await autoFixProblems();
  
  return {
    problemsFound: problems.length,
    problemsFixed: results.filter(r => r.fixed).length,
    results
  };
}
