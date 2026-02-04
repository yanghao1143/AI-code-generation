/**
 * 项目管理能力
 * 管理多个项目，跟踪进度，分配资源
 */
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
export declare function getProjects(): Promise<Project[]>;
export declare function addProject(project: Project): Promise<void>;
export declare function checkProjectHealth(project: Project): Promise<ProjectHealth>;
export declare function checkAllProjects(): Promise<ProjectHealth[]>;
export declare function getProjectSummary(): Promise<string>;
