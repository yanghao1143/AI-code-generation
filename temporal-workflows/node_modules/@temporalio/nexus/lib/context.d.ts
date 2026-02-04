import { AsyncLocalStorage } from 'node:async_hooks';
import { Logger, MetricMeter } from '@temporalio/common';
import { Client } from '@temporalio/client';
export declare const asyncLocalStorage: AsyncLocalStorage<HandlerContext>;
export declare function getHandlerContext(): HandlerContext;
/**
 * Context used internally in the SDK to propagate information from the worker to the Temporal Nexus helpers.
 *
 * @internal
 * @hidden
 */
export interface HandlerContext {
    log: Logger;
    metrics: MetricMeter;
    client: Client;
    namespace: string;
    taskQueue: string;
}
/**
 * A logger for use in Nexus Handler scope.
 *
 * This defaults to the `Runtime`'s Logger (see {@link Runtime.logger}). Attributes from the
 * current Nexus handler context are automatically included as metadata on every log entries. An
 * extra `sdkComponent` metadata attribute is also added, with value `nexus`; this can be used
 * for fine-grained filtering of log entries further downstream.
 *
 * To customize log attributes, register a {@link nexus.NexusOutboundCallsInterceptor} that
 * intercepts the `getLogAttributes()` method.
 *
 * @experimental Nexus support in Temporal SDK is experimental.
 */
export declare const log: Logger;
/**
 * A metric meter for use in Nexus handler scope, with Nexus handler-specific tags.
 *
 * To add custom tags, register a {@link nexus.NexusOutboundCallsInterceptor} that
 * intercepts the `getMetricTags()` method.
 *
 * @experimental Nexus support in Temporal SDK is experimental.
 */
export declare const metricMeter: MetricMeter;
/**
 * Returns a client to be used in a Nexus Operation's context, this Client is powered by the same
 * NativeConnection that the worker was created with.
 *
 * @experimental Nexus support in Temporal SDK is experimental.
 */
export declare function getClient(): Client;
