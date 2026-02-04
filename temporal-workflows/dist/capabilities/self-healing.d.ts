/**
 * 问题自愈能力
 * 自动检测、诊断、修复常见问题
 */
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
export declare function detectProblems(): Promise<Problem[]>;
export declare function autoFixProblems(): Promise<FixResult[]>;
export declare function runSelfHealing(): Promise<{
    problemsFound: number;
    problemsFixed: number;
    results: FixResult[];
}>;
