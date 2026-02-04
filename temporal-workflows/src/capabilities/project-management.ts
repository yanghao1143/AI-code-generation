/**
 * 项目管理能力
 * 管理多个项目，跟踪进度，分配资源
 */

import { exec } from 'child_process';
import { promisify } from 'util';
import * as fs from 'fs/promises';

const execAsync = promisify(exec);

export interface Project {
  name: string;
  path: string;
  type: 'frontend' | 'backend' | 'fullstack' | 'other';
  status: 'active' | 'paused' | 'completed';
  priority: number;
  lastActivity?: string;
}

export interface ProjectHealth {
  project: string;
  hasErrors: boolean;
  errorCount: number;
  warningCount: number;
  lastCommit: string;
  lastCommitTime: string;
  uncommittedChanges: number;
  branch: string;
}

// 项目注册表
const PROJECTS_FILE = '/home/jinyang/.openclaw/workspace/projects.json';

export async function getProjects(): Promise<Project[]> {
  try {
    const content = await fs.readFile(PROJECTS_FILE, 'utf-8');
    return JSON.parse(content);
  } catch {
    // 默认项目
    const defaultProjects: Project[] = [
      {
        name: 'Koma',
        path: '/home/jinyang/Koma',
        type: 'fullstack',
        status: 'active',
        priority: 1
      }
    ];
    await fs.writeFile(PROJECTS_FILE, JSON.stringify(defaultProjects, null, 2));
    return defaultProjects;
  }
}

export async function addProject(project: Project): Promise<void> {
  const projects = await getProjects();
  const existing = projects.findIndex(p => p.name === project.name);
  if (existing >= 0) {
    projects[existing] = project;
  } else {
    projects.push(project);
  }
  await fs.writeFile(PROJECTS_FILE, JSON.stringify(projects, null, 2));
}

export async function checkProjectHealth(project: Project): Promise<ProjectHealth> {
  const health: ProjectHealth = {
    project: project.name,
    hasErrors: false,
    errorCount: 0,
    warningCount: 0,
    lastCommit: '',
    lastCommitTime: '',
    uncommittedChanges: 0,
    branch: ''
  };

  try {
    // Git 状态
    const { stdout: branch } = await execAsync(`cd ${project.path} && git branch --show-current 2>/dev/null`);
    health.branch = branch.trim();

    const { stdout: status } = await execAsync(`cd ${project.path} && git status --porcelain 2>/dev/null`);
    health.uncommittedChanges = status.trim().split('\n').filter(l => l).length;

    const { stdout: log } = await execAsync(`cd ${project.path} && git log -1 --format="%s|%cr" 2>/dev/null`);
    const [commit, time] = log.trim().split('|');
    health.lastCommit = commit;
    health.lastCommitTime = time;

    // TypeScript 检查 (如果是前端项目)
    if (project.type === 'frontend' || project.type === 'fullstack') {
      const frontendPath = project.type === 'fullstack' ? `${project.path}/frontend` : project.path;
      try {
        const { stdout: tsc } = await execAsync(
          `cd ${frontendPath} && ./node_modules/.bin/tsc --noEmit 2>&1 | grep -c "error TS" || echo "0"`,
          { timeout: 60000 }
        );
        health.errorCount = parseInt(tsc.trim()) || 0;
        health.hasErrors = health.errorCount > 0;
      } catch {}
    }
  } catch (error) {
    console.error(`检查项目 ${project.name} 失败:`, error);
  }

  return health;
}

export async function checkAllProjects(): Promise<ProjectHealth[]> {
  const projects = await getProjects();
  const activeProjects = projects.filter(p => p.status === 'active');
  return Promise.all(activeProjects.map(checkProjectHealth));
}

export async function getProjectSummary(): Promise<string> {
  const healths = await checkAllProjects();
  const lines: string[] = ['📊 项目状态总览:'];
  
  for (const h of healths) {
    const icon = h.hasErrors ? '❌' : '✅';
    lines.push(`${icon} ${h.project} (${h.branch})`);
    if (h.uncommittedChanges > 0) {
      lines.push(`   └─ ${h.uncommittedChanges} 个未提交修改`);
    }
    if (h.hasErrors) {
      lines.push(`   └─ ${h.errorCount} 个 TypeScript 错误`);
    }
  }
  
  return lines.join('\n');
}
