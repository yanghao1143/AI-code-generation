import * as nexus from 'nexus-rpc';
import { StartNexusOperationOptions } from './interceptors';
/**
 * A Nexus client for invoking Nexus Operations for a specific service from a Workflow.
 *
 * @experimental Nexus support in Temporal SDK is experimental.
 */
export interface NexusClient<T extends nexus.ServiceDefinition> {
    /**
     * Start a Nexus Operation and wait for its completion taking a {@link nexus.operation}.
     * Returns the operation's result.
     *
     * @experimental Nexus support in Temporal SDK is experimental.
     */
    executeOperation<O extends T['operations'][keyof T['operations']]>(op: O, input: nexus.OperationInput<O>, options?: Partial<StartNexusOperationOptions>): Promise<nexus.OperationOutput<O>>;
    /**
     * Start a Nexus Operation and wait for its completion, taking an Operation's _property name_.
     * Returns the operation's result.
     *
     * An Operation's _property name_ is the name of the property used to define that Operation in
     * the {@link nexus.ServiceDefinition} object; it may differ from the value of the `name` property
     * if one was explicitly specified on the {@link nexus.OperationDefinition} object.
     *
     * @experimental Nexus support in Temporal SDK is experimental.
     */
    executeOperation<K extends nexus.OperationKey<T['operations']>>(op: K, input: nexus.OperationInput<T['operations'][K]>, options?: Partial<StartNexusOperationOptions>): Promise<nexus.OperationOutput<T['operations'][K]>>;
    /**
     * Start a Nexus Operation taking a {@link nexus.operation}.
     *
     * Returns a handle that can be used to wait for the Operation's result.
     *
     * @experimental Nexus support in Temporal SDK is experimental.
     */
    startOperation<O extends T['operations'][keyof T['operations']]>(op: O, input: nexus.OperationInput<O>, options?: Partial<StartNexusOperationOptions>): Promise<NexusOperationHandle<nexus.OperationOutput<O>>>;
    /**
     * Start a Nexus Operation, taking an Operation's _property name_.
     * Returns a handle that can be used to wait for the Operation's result.
     *
     * An Operation's _property name_ is the name of the property used to define that Operation in
     * the {@link nexus.ServiceDefinition} object; it may differ from the value of the `name` property
     * if one was explicitly specified on the {@link nexus.OperationDefinition} object.
     *
     * @experimental Nexus support in Temporal SDK is experimental.
     */
    startOperation<K extends nexus.OperationKey<T['operations']>>(op: K, input: nexus.OperationInput<T['operations'][K]>, options?: Partial<StartNexusOperationOptions>): Promise<NexusOperationHandle<nexus.OperationOutput<T['operations'][K]>>>;
}
/**
 * A handle to a Nexus Operation.
 *
 * @experimental Nexus support in Temporal SDK is experimental.
 */
export interface NexusOperationHandle<T> {
    /**
     * The Operation's service name.
     */
    readonly service: string;
    /**
     * The name of the Operation.
     */
    readonly operation: string;
    /**
     * Operation token as set by the Operation's handler. May be empty if the Operation completed synchronously.
     */
    readonly token?: string;
    /**
     * Wait for Operation completion and get its result.
     */
    result(): Promise<T>;
}
/**
 * Options for {@link createNexusClient}.
 */
export interface NexusClientOptions<T> {
    endpoint: string;
    service: T;
}
/**
 * Create a Nexus client for invoking Nexus Operations from a Workflow.
 *
 * @experimental Nexus support in Temporal SDK is experimental.
 */
export declare function createNexusClient<T extends nexus.ServiceDefinition>(options: NexusClientOptions<T>): NexusClient<T>;
