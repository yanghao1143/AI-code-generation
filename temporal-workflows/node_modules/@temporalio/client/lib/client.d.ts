import { AsyncCompletionClient } from './async-completion-client';
import { BaseClient, BaseClientOptions, LoadedWithDefaults } from './base-client';
import { ClientInterceptors } from './interceptors';
import { ScheduleClient } from './schedule-client';
import { QueryRejectCondition, WorkflowService } from './types';
import { WorkflowClient } from './workflow-client';
import { TaskQueueClient } from './task-queue-client';
export interface ClientOptions extends BaseClientOptions {
    /**
     * Used to override and extend default Connection functionality
     *
     * Useful for injecting auth headers and tracing Workflow executions
     */
    interceptors?: ClientInterceptors;
    /**
     * List of plugins to register with the client.
     *
     * Plugins allow you to extend and customize the behavior of Temporal clients.
     * They can intercept and modify client creation.
     *
     * @experimental Plugins is an experimental feature; APIs may change without notice.
     */
    plugins?: ClientPlugin[];
    workflow?: {
        /**
         * Should a query be rejected by closed and failed workflows
         *
         * @default `undefined`, which means that closed and failed workflows are still queryable
         */
        queryRejectCondition?: QueryRejectCondition;
    };
}
export type LoadedClientOptions = LoadedWithDefaults<ClientOptions>;
/**
 * High level SDK client.
 */
export declare class Client extends BaseClient {
    readonly options: LoadedClientOptions;
    /**
     * Workflow sub-client - use to start and interact with Workflows
     */
    readonly workflow: WorkflowClient;
    /**
     * (Async) Activity completion sub-client - use to manually manage Activities
     */
    readonly activity: AsyncCompletionClient;
    /**
     * Schedule sub-client - use to start and interact with Schedules
     */
    readonly schedule: ScheduleClient;
    /**
     * Task Queue sub-client - use to perform operations on Task Queues
     *
     * @experimental The Worker Versioning API is still being designed. Major changes are expected.
     */
    readonly taskQueue: TaskQueueClient;
    constructor(options?: ClientOptions);
    /**
     * Raw gRPC access to the Temporal service.
     *
     * **NOTE**: The namespace provided in {@link options} is **not** automatically set on requests made via this service
     * object.
     */
    get workflowService(): WorkflowService;
}
/**
 * Plugin to control the configuration of a native connection.
 *
 * @experimental Plugins is an experimental feature; APIs may change without notice.
 */
export interface ClientPlugin {
    /**
     * Gets the name of this plugin.
     */
    get name(): string;
    /**
     * Hook called when creating a client to allow modification of configuration.
     *
     * This method is called during client creation and allows plugins to modify
     * the client configuration before the client is fully initialized.
     */
    configureClient?(options: Omit<ClientOptions, 'plugins'>): Omit<ClientOptions, 'plugins'>;
}
