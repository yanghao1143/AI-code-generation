import 'abort-controller/polyfill';
import { Context, Info } from '@temporalio/activity';
import { ActivityCancellationDetails, ActivityFunction, LoadedDataConverter, MetricMeter, MetricTags } from '@temporalio/common';
import { Logger } from '@temporalio/common/lib/logger';
import { Client } from '@temporalio/client';
import { coresdk } from '@temporalio/proto';
import { ActivityCancellationDetailsHolder } from '@temporalio/common/lib/activity-cancellation-details';
import { ActivityExecuteInput, ActivityInboundCallsInterceptor, ActivityInterceptorsFactory, ActivityOutboundCallsInterceptor } from './interceptors';
export type CancelReason = keyof typeof coresdk.activity_task.ActivityCancelReason | 'WORKER_SHUTDOWN' | 'HEARTBEAT_DETAILS_CONVERSION_FAILED';
export declare class Activity {
    readonly info: Info;
    readonly fn: ActivityFunction<any[], any> | undefined;
    readonly dataConverter: LoadedDataConverter;
    readonly heartbeatCallback: Context['heartbeat'];
    private readonly _client;
    protected cancelReason?: CancelReason;
    protected cancellationDetails: ActivityCancellationDetailsHolder;
    readonly context: Context;
    cancel: (reason: CancelReason, details: ActivityCancellationDetails) => void;
    readonly abortController: AbortController;
    /**
     * Logger bound to `sdkComponent: worker`, with metadata from this activity.
     * This is the logger to use for all log messages emitted by the activity
     * worker. Note this is not exactly the same thing as the activity context
     * logger, which is bound to `sdkComponent: activity`.
     */
    private readonly workerLogger;
    /**
     * Metric Meter with tags from this activity, including tags from interceptors.
     */
    private readonly metricMeter;
    readonly interceptors: {
        inbound: ActivityInboundCallsInterceptor[];
        outbound: ActivityOutboundCallsInterceptor[];
    };
    constructor(info: Info, fn: ActivityFunction<any[], any> | undefined, dataConverter: LoadedDataConverter, heartbeatCallback: Context['heartbeat'], _client: Client | undefined, // May be undefined in the case of MockActivityEnvironment
    workerLogger: Logger, workerMetricMeter: MetricMeter, interceptors: ActivityInterceptorsFactory[]);
    protected getLogAttributes(): Record<string, unknown>;
    protected getMetricTags(): MetricTags;
    /**
     * Actually executes the function.
     *
     * Any call up to this function and including this one will be trimmed out of stack traces.
     */
    protected execute(fn: ActivityFunction<any[], any>, input: ActivityExecuteInput): Promise<unknown>;
    private executeWithClient;
    run(input: ActivityExecuteInput): Promise<coresdk.activity_result.IActivityExecutionResult>;
    runNoEncoding(fn: ActivityFunction<any[], any>, input: ActivityExecuteInput): Promise<unknown>;
}
/**
 * Returns a map of attributes to be set on log messages for a given Activity
 */
export declare function activityLogAttributes(info: Info): Record<string, unknown>;
