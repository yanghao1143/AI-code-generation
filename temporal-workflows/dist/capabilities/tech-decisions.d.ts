/**
 * 技术决策记录
 * 记录重要决策，形成知识库
 */
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
export declare function recordDecision(decision: TechDecision): Promise<number>;
export declare function searchDecisions(query: string): Promise<TechDecision[]>;
export declare function getRecentDecisions(limit?: number): Promise<string[]>;
