"use strict";
/**
 * 项目管理能力
 * 管理多个项目，跟踪进度，分配资源
 */
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.getProjects = getProjects;
exports.addProject = addProject;
exports.checkProjectHealth = checkProjectHealth;
exports.checkAllProjects = checkAllProjects;
exports.getProjectSummary = getProjectSummary;
const child_process_1 = require("child_process");
const util_1 = require("util");
const fs = __importStar(require("fs/promises"));
const execAsync = (0, util_1.promisify)(child_process_1.exec);
// 项目注册表
const PROJECTS_FILE = '/home/jinyang/.openclaw/workspace/projects.json';
async function getProjects() {
    try {
        const content = await fs.readFile(PROJECTS_FILE, 'utf-8');
        return JSON.parse(content);
    }
    catch {
        // 默认项目
        const defaultProjects = [
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
async function addProject(project) {
    const projects = await getProjects();
    const existing = projects.findIndex(p => p.name === project.name);
    if (existing >= 0) {
        projects[existing] = project;
    }
    else {
        projects.push(project);
    }
    await fs.writeFile(PROJECTS_FILE, JSON.stringify(projects, null, 2));
}
async function checkProjectHealth(project) {
    const health = {
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
                const { stdout: tsc } = await execAsync(`cd ${frontendPath} && ./node_modules/.bin/tsc --noEmit 2>&1 | grep -c "error TS" || echo "0"`, { timeout: 60000 });
                health.errorCount = parseInt(tsc.trim()) || 0;
                health.hasErrors = health.errorCount > 0;
            }
            catch { }
        }
    }
    catch (error) {
        console.error(`检查项目 ${project.name} 失败:`, error);
    }
    return health;
}
async function checkAllProjects() {
    const projects = await getProjects();
    const activeProjects = projects.filter(p => p.status === 'active');
    return Promise.all(activeProjects.map(checkProjectHealth));
}
async function getProjectSummary() {
    const healths = await checkAllProjects();
    const lines = ['📊 项目状态总览:'];
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
