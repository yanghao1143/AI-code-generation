"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.MiB = void 0;
exports.toMB = toMB;
exports.byteArrayToBuffer = byteArrayToBuffer;
exports.convertToParentWorkflowType = convertToParentWorkflowType;
exports.convertDeploymentVersion = convertDeploymentVersion;
exports.convertToRootWorkflowType = convertToRootWorkflowType;
const workflow_1 = require("@temporalio/workflow");
exports.MiB = 1024 ** 2;
function toMB(bytes, fractionDigits = 2) {
    return (bytes / 1024 / 1024).toFixed(fractionDigits);
}
function byteArrayToBuffer(array) {
    return Buffer.from(array, array.byteOffset, array.byteLength + array.byteOffset);
}
function convertToParentWorkflowType(parent) {
    if (!parent) {
        return undefined;
    }
    if (!parent.workflowId || !parent.runId || !parent.namespace) {
        throw new workflow_1.IllegalStateError('Parent INamespacedWorkflowExecution is missing a field that should be defined');
    }
    return {
        workflowId: parent.workflowId,
        runId: parent.runId,
        namespace: parent.namespace,
    };
}
function convertDeploymentVersion(v) {
    if (v == null || v.buildId == null) {
        return undefined;
    }
    return {
        buildId: v.buildId,
        deploymentName: v.deploymentName ?? '',
    };
}
function convertToRootWorkflowType(root) {
    if (root == null) {
        return undefined;
    }
    if (!root.workflowId || !root.runId) {
        throw new workflow_1.IllegalStateError('Root workflow execution is missing a field that should be defined');
    }
    return {
        workflowId: root.workflowId,
        runId: root.runId,
    };
}
//# sourceMappingURL=utils.js.map