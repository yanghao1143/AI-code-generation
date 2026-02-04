"use strict";
var _a;
Object.defineProperty(exports, "__esModule", { value: true });
exports.decodeVersioningBehavior = exports.encodeVersioningBehavior = exports.VersioningBehavior = void 0;
exports.toCanonicalString = toCanonicalString;
const internal_workflow_1 = require("./internal-workflow");
/**
 * @returns The canonical representation of a deployment version, which is a string in the format
 * `deploymentName.buildId`.
 */
function toCanonicalString(version) {
    return `${version.deploymentName}.${version.buildId}`;
}
/**
 * Specifies when a workflow might move from a worker of one Build Id to another.
 *
 * * 'PINNED' - The workflow will be pinned to the current Build ID unless manually moved.
 * * 'AUTO_UPGRADE' - The workflow will automatically move to the latest version (default Build ID
 *    of the task queue) when the next task is dispatched.
 *
 * @experimental Deployment based versioning is experimental and may change in the future.
 */
exports.VersioningBehavior = {
    PINNED: 'PINNED',
    AUTO_UPGRADE: 'AUTO_UPGRADE',
};
_a = (0, internal_workflow_1.makeProtoEnumConverters)({
    [exports.VersioningBehavior.PINNED]: 1,
    [exports.VersioningBehavior.AUTO_UPGRADE]: 2,
    UNSPECIFIED: 0,
}, 'VERSIONING_BEHAVIOR_'), exports.encodeVersioningBehavior = _a[0], exports.decodeVersioningBehavior = _a[1];
//# sourceMappingURL=worker-deployments.js.map