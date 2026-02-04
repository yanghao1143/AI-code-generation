/**
 * 技术决策记录
 * 记录重要决策，形成知识库
 */

import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

export interface TechDecision {
  id?: number;
  title: string;
  context: string;
  decision: string;
  consequences: string;
  status: 'proposed' | 'accepted' | 'deprecated' | 'superseded';
  date: string;
  tags: string[];
}

export async function recordDecision(decision: TechDecision): Promise<number> {
  const content = `技术决策: ${decision.title} | 背景: ${decision.context} | 决定: ${decision.decision} | 后果: ${decision.consequences} | 状态: ${decision.status}`;
  
  try {
    const { stdout } = await execAsync(
      `cd /home/jinyang/.openclaw/workspace && ./scripts/pg-memory.sh add-memory "${content.replace(/"/g, '\\"')}" "tech-decision" 9`
    );
    const match = stdout.match(/^(\d+)/);
    return match ? parseInt(match[1]) : 0;
  } catch {
    return 0;
  }
}

export async function searchDecisions(query: string): Promise<TechDecision[]> {
  try {
    const { stdout } = await execAsync(
      `cd /home/jinyang/.openclaw/workspace && ./scripts/pg-memory.sh sql "SELECT id, content FROM memories WHERE category = 'tech-decision' AND content ILIKE '%${query}%' ORDER BY created_at DESC LIMIT 10;"`
    );
    
    // 简单解析
    const decisions: TechDecision[] = [];
    const lines = stdout.trim().split('\n').filter(l => l && !l.startsWith('-'));
    
    for (const line of lines) {
      const parts = line.split('|');
      if (parts.length >= 2) {
        decisions.push({
          id: parseInt(parts[0]) || 0,
          title: parts[1]?.trim() || '',
          context: '',
          decision: '',
          consequences: '',
          status: 'accepted',
          date: '',
          tags: []
        });
      }
    }
    
    return decisions;
  } catch {
    return [];
  }
}

export async function getRecentDecisions(limit: number = 10): Promise<string[]> {
  try {
    const { stdout } = await execAsync(
      `cd /home/jinyang/.openclaw/workspace && ./scripts/pg-memory.sh sql "SELECT LEFT(content, 150) FROM memories WHERE category = 'tech-decision' ORDER BY created_at DESC LIMIT ${limit};"`
    );
    return stdout.trim().split('\n').filter(l => l && !l.startsWith('-'));
  } catch {
    return [];
  }
}
