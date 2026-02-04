/**
 * 深度学习能力
 * 从历史中提取模式，形成知识
 */
export interface Pattern {
    type: string;
    description: string;
    frequency: number;
    lastSeen: string;
    actionTaken?: string;
    successful?: boolean;
}
export interface Knowledge {
    topic: string;
    insight: string;
    confidence: number;
    source: string;
    createdAt: string;
}
/**
 * 分析问题模式
 */
export declare function analyzeIssuePatterns(): Promise<Pattern[]>;
/**
 * 分析成功模式
 */
export declare function analyzeSuccessPatterns(): Promise<Pattern[]>;
/**
 * 生成知识洞察
 */
export declare function generateInsights(): Promise<Knowledge[]>;
/**
 * 保存知识到知识库
 */
export declare function saveKnowledge(knowledge: Knowledge): Promise<void>;
/**
 * 运行深度学习
 */
export declare function runDeepLearning(): Promise<{
    patternsFound: number;
    insightsGenerated: number;
    knowledgeSaved: number;
}>;
