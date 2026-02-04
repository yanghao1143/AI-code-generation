import * as nexus from 'nexus-rpc';
import { LoadedDataConverter, Payload, MetricMeter, MetricTags } from '@temporalio/common';
import { temporal, coresdk } from '@temporalio/proto';
import { Client } from '@temporalio/client';
import { Logger } from '../logger';
import { NexusInterceptorsFactory } from '../interceptors';
export declare class NexusHandler {
    readonly taskToken: Uint8Array;
    readonly namespace: string;
    readonly taskQueue: string;
    readonly context: nexus.OperationContext;
    readonly client: Client;
    readonly abortController: AbortController;
    readonly serviceRegistry: nexus.ServiceRegistry;
    readonly dataConverter: LoadedDataConverter;
    /**
     * Logger bound to `sdkComponent: worker`, with metadata from this Nexus task.
     * This is the logger to use for all log messages emitted by the Nexus
     * worker. Note this is not exactly the same thing as the Nexus context
     * logger, which is bound to `sdkComponent: nexus`.
     */
    private readonly logger;
    /**
     * Metric Meter with tags from this Nexus task, including tags from interceptors.
     */
    private readonly metricMeter;
    /**
     * List of interceptors for this Nexus task.
     */
    private readonly interceptors;
    constructor(taskToken: Uint8Array, namespace: string, taskQueue: string, context: nexus.OperationContext, client: Client, abortController: AbortController, serviceRegistry: nexus.ServiceRegistry, dataConverter: LoadedDataConverter, workerLogger: Logger, workerMetricMeter: MetricMeter, interceptors: NexusInterceptorsFactory[]);
    getLogAttributes(): Record<string, unknown>;
    protected getMetricTags(): MetricTags;
    protected startOperation(ctx: nexus.StartOperationContext, payload: Payload | undefined): Promise<coresdk.nexus.INexusTaskCompletion>;
    protected cancelOperation(ctx: nexus.CancelOperationContext, token: string): Promise<coresdk.nexus.INexusTaskCompletion>;
    protected invokeUserCode<R>(method: string, fn: () => Promise<R>): Promise<R>;
    /**
     * Actually executes the Operation.
     *
     * Any call up to this function and including this one will be trimmed out of stack traces.
     */
    protected execute(task: temporal.api.workflowservice.v1.IPollNexusTaskQueueResponse): Promise<coresdk.nexus.INexusTaskCompletion>;
    run(task: temporal.api.workflowservice.v1.IPollNexusTaskQueueResponse): Promise<coresdk.nexus.INexusTaskCompletion>;
}
export declare function constructNexusOperationContext(request: temporal.api.nexus.v1.IRequest | null | undefined, abortSignal: AbortSignal): nexus.OperationContext;
