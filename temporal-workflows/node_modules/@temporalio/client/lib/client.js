"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.Client = void 0;
const internal_workflow_1 = require("@temporalio/common/lib/internal-workflow");
const async_completion_client_1 = require("./async-completion-client");
const base_client_1 = require("./base-client");
const schedule_client_1 = require("./schedule-client");
const workflow_client_1 = require("./workflow-client");
const task_queue_client_1 = require("./task-queue-client");
/**
 * High level SDK client.
 */
class Client extends base_client_1.BaseClient {
    options;
    /**
     * Workflow sub-client - use to start and interact with Workflows
     */
    workflow;
    /**
     * (Async) Activity completion sub-client - use to manually manage Activities
     */
    activity;
    /**
     * Schedule sub-client - use to start and interact with Schedules
     */
    schedule;
    /**
     * Task Queue sub-client - use to perform operations on Task Queues
     *
     * @experimental The Worker Versioning API is still being designed. Major changes are expected.
     */
    taskQueue;
    constructor(options) {
        options = options ?? {};
        // Add client plugins from the connection
        options.plugins = (options.plugins ?? []).concat(options.connection?.plugins ?? []);
        // Process plugins first to allow them to modify connect configuration
        for (const plugin of options.plugins) {
            if (plugin.configureClient !== undefined) {
                options = plugin.configureClient(options);
            }
        }
        super(options);
        const { interceptors, workflow, plugins, ...commonOptions } = options;
        this.workflow = new workflow_client_1.WorkflowClient({
            ...commonOptions,
            ...(workflow ?? {}),
            connection: this.connection,
            dataConverter: this.dataConverter,
            interceptors: interceptors?.workflow,
            queryRejectCondition: workflow?.queryRejectCondition,
        });
        this.activity = new async_completion_client_1.AsyncCompletionClient({
            ...commonOptions,
            connection: this.connection,
            dataConverter: this.dataConverter,
        });
        this.schedule = new schedule_client_1.ScheduleClient({
            ...commonOptions,
            connection: this.connection,
            dataConverter: this.dataConverter,
            interceptors: interceptors?.schedule,
        });
        this.taskQueue = new task_queue_client_1.TaskQueueClient({
            ...commonOptions,
            connection: this.connection,
            dataConverter: this.dataConverter,
        });
        this.options = {
            ...(0, base_client_1.defaultBaseClientOptions)(),
            ...(0, internal_workflow_1.filterNullAndUndefined)(commonOptions),
            loadedDataConverter: this.dataConverter,
            interceptors: {
                workflow: this.workflow.options.interceptors,
                schedule: this.schedule.options.interceptors,
            },
            workflow: {
                queryRejectCondition: this.workflow.options.queryRejectCondition,
            },
            plugins: plugins ?? [],
        };
    }
    /**
     * Raw gRPC access to the Temporal service.
     *
     * **NOTE**: The namespace provided in {@link options} is **not** automatically set on requests made via this service
     * object.
     */
    get workflowService() {
        return this.connection.workflowService;
    }
}
exports.Client = Client;
//# sourceMappingURL=client.js.map