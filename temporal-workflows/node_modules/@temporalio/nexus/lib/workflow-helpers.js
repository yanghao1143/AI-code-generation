"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (k !== "default" && Object.prototype.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.WorkflowRunOperationHandler = void 0;
exports.startWorkflow = startWorkflow;
const nexus = __importStar(require("nexus-rpc"));
const internal_1 = require("@temporalio/client/lib/internal");
const token_1 = require("./token");
const link_converter_1 = require("./link-converter");
const context_1 = require("./context");
/**
 * Starts a workflow run for a {@link WorkflowRunOperationStartHandler}, linking the execution chain
 * to a Nexus Operation (subsequent runs started from continue-as-new and retries). Automatically
 * propagates the callback, request ID, and back and forward links from the Nexus options to the
 * Workflow.
 *
 * @experimental Nexus support in Temporal SDK is experimental.
 */
async function startWorkflow(ctx, workflowTypeOrFunc, workflowOptions) {
    const { client, taskQueue } = (0, context_1.getHandlerContext)();
    const links = Array();
    if (ctx.inboundLinks?.length > 0) {
        for (const l of ctx.inboundLinks) {
            try {
                links.push({
                    workflowEvent: (0, link_converter_1.convertNexusLinkToWorkflowEventLink)(l),
                });
            }
            catch (error) {
                context_1.log.warn('failed to convert Nexus link to Workflow event link', { error });
            }
        }
    }
    const internalOptions = {
        links,
        requestId: ctx.requestId,
    };
    internalOptions.onConflictOptions = {
        attachLinks: true,
        attachCompletionCallbacks: true,
        attachRequestId: true,
    };
    if (ctx.callbackUrl) {
        internalOptions.completionCallbacks = [
            {
                nexus: { url: ctx.callbackUrl, header: ctx.callbackHeaders },
                links, // pass in links here as well for older servers, newer servers dedupe them.
            },
        ];
    }
    const { taskQueue: userSpecifiedTaskQueue, ...rest } = workflowOptions;
    const startOptions = {
        ...rest,
        taskQueue: userSpecifiedTaskQueue || taskQueue,
        [internal_1.InternalWorkflowStartOptionsSymbol]: internalOptions,
    };
    const handle = await client.workflow.start(workflowTypeOrFunc, startOptions);
    if (internalOptions.backLink?.workflowEvent != null) {
        try {
            ctx.outboundLinks.push((0, link_converter_1.convertWorkflowEventLinkToNexusLink)(internalOptions.backLink.workflowEvent));
        }
        catch (error) {
            context_1.log.warn('failed to convert Workflow event link to Nexus link', { error });
        }
    }
    return {
        workflowId: handle.workflowId,
        runId: handle.firstExecutionRunId,
    };
}
/**
 * A Nexus Operation implementation that is backed by a Workflow run.
 *
 * @experimental Nexus support in Temporal SDK is experimental.
 */
class WorkflowRunOperationHandler {
    handler;
    constructor(handler) {
        this.handler = handler;
    }
    async start(ctx, input) {
        const { namespace } = (0, context_1.getHandlerContext)();
        const handle = await this.handler(ctx, input);
        return nexus.HandlerStartOperationResult.async((0, token_1.generateWorkflowRunOperationToken)(namespace, handle.workflowId));
    }
    getInfo(_ctx, _token) {
        // Not implemented in Temporal yet.
        throw new nexus.HandlerError('NOT_IMPLEMENTED', 'Method not implemented');
    }
    getResult(_ctx, _token) {
        // Not implemented in Temporal yet.
        throw new nexus.HandlerError('NOT_IMPLEMENTED', 'Method not implemented');
    }
    async cancel(_ctx, token) {
        const decoded = (0, token_1.loadWorkflowRunOperationToken)(token);
        await (0, context_1.getClient)().workflow.getHandle(decoded.wid).cancel();
    }
}
exports.WorkflowRunOperationHandler = WorkflowRunOperationHandler;
//# sourceMappingURL=workflow-helpers.js.map