"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.generateWorkflowRunOperationToken = generateWorkflowRunOperationToken;
exports.loadWorkflowRunOperationToken = loadWorkflowRunOperationToken;
exports.base64URLEncodeNoPadding = base64URLEncodeNoPadding;
/**
 * @internal
 * @hidden
 */
const OperationTokenType = {
    WORKFLOW_RUN: 1,
};
/**
 * Generate a workflow run Operation token.
 */
function generateWorkflowRunOperationToken(namespace, workflowId) {
    const token = {
        t: OperationTokenType.WORKFLOW_RUN,
        ns: namespace,
        wid: workflowId,
    };
    return base64URLEncodeNoPadding(JSON.stringify(token));
}
/**
 * Load and validate a workflow run Operation token.
 */
function loadWorkflowRunOperationToken(data) {
    if (!data) {
        throw new TypeError('invalid workflow run token: token is empty');
    }
    let decoded;
    try {
        decoded = base64URLDecodeNoPadding(data);
    }
    catch (err) {
        throw new TypeError('failed to decode token', { cause: err });
    }
    let token;
    try {
        token = JSON.parse(decoded);
    }
    catch (err) {
        throw new TypeError('failed to unmarshal workflow run Operation token', { cause: err });
    }
    if (token.t !== OperationTokenType.WORKFLOW_RUN) {
        throw new TypeError(`invalid workflow token type: ${token.t}, expected: ${OperationTokenType.WORKFLOW_RUN}`);
    }
    if (token.v !== undefined && token.v !== 0) {
        throw new TypeError('invalid workflow run token: "v" field should not be present');
    }
    if (!token.wid) {
        throw new TypeError('invalid workflow run token: missing workflow ID (wid)');
    }
    return token;
}
// Exported for use in tests.
function base64URLEncodeNoPadding(str) {
    const base64 = Buffer.from(str).toString('base64url');
    return base64.replace(/[=]+$/, '');
}
function base64URLDecodeNoPadding(str) {
    // Validate the string contains only valid base64URL characters
    if (!/^[A-Za-z0-9_-]*$/.test(str)) {
        throw new TypeError('invalid base64URL encoded string: contains invalid characters');
    }
    const paddingLength = str.length % 4;
    if (paddingLength > 0) {
        str += '='.repeat(4 - paddingLength);
    }
    return Buffer.from(str, 'base64url').toString('utf-8');
}
//# sourceMappingURL=token.js.map