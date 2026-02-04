/**
 * @internal
 * @hidden
 */
export interface WorkflowRunOperationToken {
    /**
     * Version of the token, by default we assume we're on version 1, this field is not emitted as part of the output,
     * it's only used to reject newer token versions on load.
     */
    v?: number;
    /**
     * Type of the Operation. Must be OPERATION_TOKEN_TYPE_WORKFLOW_RUN.
     */
    t: OperationTokenType;
    /**
     * Namespace of the workflow.
     */
    ns: string;
    /**
     * ID of the workflow.
     */
    wid: string;
}
/**
 * OperationTokenType is used to identify the type of Operation token.
 * Currently, we only have one type of Operation token: WorkflowRun.
 */
type OperationTokenType = (typeof OperationTokenType)[keyof typeof OperationTokenType];
/**
 * @internal
 * @hidden
 */
declare const OperationTokenType: {
    readonly WORKFLOW_RUN: 1;
};
/**
 * Generate a workflow run Operation token.
 */
export declare function generateWorkflowRunOperationToken(namespace: string, workflowId: string): string;
/**
 * Load and validate a workflow run Operation token.
 */
export declare function loadWorkflowRunOperationToken(data: string): WorkflowRunOperationToken;
export declare function base64URLEncodeNoPadding(str: string): string;
export {};
