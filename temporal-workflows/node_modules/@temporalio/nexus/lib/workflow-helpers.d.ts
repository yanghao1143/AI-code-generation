import * as nexus from 'nexus-rpc';
import { Workflow } from '@temporalio/common';
import { Replace } from '@temporalio/common/lib/type-helpers';
import { WorkflowStartOptions as ClientWorkflowStartOptions } from '@temporalio/client';
declare const isNexusWorkflowHandle: unique symbol;
/**
 * A handle to a running workflow that is returned by the {@link startWorkflow} helper.
 * This handle should be returned by {@link WorkflowRunOperationStartHandler} implementations.
 *
 * @experimental Nexus support in Temporal SDK is experimental.
 */
export interface WorkflowHandle<_T> {
    readonly workflowId: string;
    readonly runId: string;
    /**
     * Virtual type brand to maintain a distinction between {@link WorkflowHandle} provided by the
     * {@link startWorkflow} helper (which will have attached links, request ID, completion URL, etc)
     * and the `WorkflowHandle` type returned by the {@link WorkflowClient.start}.
     *
     * @internal
     * @hidden
     *
     * @experimental Nexus support in Temporal SDK is experimental.
     */
    readonly [isNexusWorkflowHandle]: typeof isNexusWorkflowHandle;
}
/**
 * Options for starting a workflow using {@link startWorkflow}, this type is identical to the
 * client's `WorkflowStartOptions` with the exception that `taskQueue` is optional and defaults
 * to the current worker's task queue.
 *
 * @experimental Nexus support in Temporal SDK is experimental.
 */
export type WorkflowStartOptions<T extends Workflow> = Replace<ClientWorkflowStartOptions<T>, {
    taskQueue?: string;
}>;
/**
 * Starts a workflow run for a {@link WorkflowRunOperationStartHandler}, linking the execution chain
 * to a Nexus Operation (subsequent runs started from continue-as-new and retries). Automatically
 * propagates the callback, request ID, and back and forward links from the Nexus options to the
 * Workflow.
 *
 * @experimental Nexus support in Temporal SDK is experimental.
 */
export declare function startWorkflow<T extends Workflow>(ctx: nexus.StartOperationContext, workflowTypeOrFunc: string | T, workflowOptions: WorkflowStartOptions<T>): Promise<WorkflowHandle<T>>;
/**
 * A handler function for the {@link WorkflowRunOperationHandler} constructor.
 *
 * @experimental Nexus support in Temporal SDK is experimental.
 */
export type WorkflowRunOperationStartHandler<I, O> = (ctx: nexus.StartOperationContext, input: I) => Promise<WorkflowHandle<O>>;
/**
 * A Nexus Operation implementation that is backed by a Workflow run.
 *
 * @experimental Nexus support in Temporal SDK is experimental.
 */
export declare class WorkflowRunOperationHandler<I, O> implements nexus.OperationHandler<I, O> {
    readonly handler: WorkflowRunOperationStartHandler<I, O>;
    constructor(handler: WorkflowRunOperationStartHandler<I, O>);
    start(ctx: nexus.StartOperationContext, input: I): Promise<nexus.HandlerStartOperationResult<O>>;
    getInfo(_ctx: nexus.GetOperationInfoContext, _token: string): Promise<nexus.OperationInfo>;
    getResult(_ctx: nexus.GetOperationResultContext, _token: string): Promise<O>;
    cancel(_ctx: nexus.CancelOperationContext, token: string): Promise<void>;
}
export {};
