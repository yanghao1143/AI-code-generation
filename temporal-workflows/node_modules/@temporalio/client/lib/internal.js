"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.InternalWorkflowStartOptionsSymbol = void 0;
/**
 * A symbol used to attach extra, SDK-internal options to the `WorkflowClient.start()` call.
 *
 * These are notably used by the Temporal Nexus helpers.
 *
 * @internal
 * @hidden
 */
exports.InternalWorkflowStartOptionsSymbol = Symbol.for('__temporal_internal_client_workflow_start_options');
//# sourceMappingURL=internal.js.map