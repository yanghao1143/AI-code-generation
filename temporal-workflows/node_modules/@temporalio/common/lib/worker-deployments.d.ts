import type { temporal } from '@temporalio/proto';
/**
 * Represents the version of a specific worker deployment.
 *
 * @experimental Deployment based versioning is experimental and may change in the future.
 */
export interface WorkerDeploymentVersion {
    readonly buildId: string;
    readonly deploymentName: string;
}
/**
 * @returns The canonical representation of a deployment version, which is a string in the format
 * `deploymentName.buildId`.
 */
export declare function toCanonicalString(version: WorkerDeploymentVersion): string;
/**
 * Specifies when a workflow might move from a worker of one Build Id to another.
 *
 * * 'PINNED' - The workflow will be pinned to the current Build ID unless manually moved.
 * * 'AUTO_UPGRADE' - The workflow will automatically move to the latest version (default Build ID
 *    of the task queue) when the next task is dispatched.
 *
 * @experimental Deployment based versioning is experimental and may change in the future.
 */
export declare const VersioningBehavior: {
    readonly PINNED: "PINNED";
    readonly AUTO_UPGRADE: "AUTO_UPGRADE";
};
export type VersioningBehavior = (typeof VersioningBehavior)[keyof typeof VersioningBehavior];
export declare const encodeVersioningBehavior: (input: "PINNED" | "AUTO_UPGRADE" | temporal.api.enums.v1.VersioningBehavior | "VERSIONING_BEHAVIOR_PINNED" | "VERSIONING_BEHAVIOR_AUTO_UPGRADE" | null | undefined) => temporal.api.enums.v1.VersioningBehavior | undefined, decodeVersioningBehavior: (input: temporal.api.enums.v1.VersioningBehavior | null | undefined) => "PINNED" | "AUTO_UPGRADE" | undefined;
/**
 * Represents versioning overrides. For example, when starting workflows.
 */
export type VersioningOverride = PinnedVersioningOverride | 'AUTO_UPGRADE';
/**
 * Workflow will be pinned to a specific deployment version.
 */
export interface PinnedVersioningOverride {
    /**
     * The worker deployment version to pin the workflow to.
     */
    pinnedTo: WorkerDeploymentVersion;
}
/**
 * The workflow will auto-upgrade to the current deployment version on the next workflow task.
 */
export type AutoUpgradeVersioningOverride = 'AUTO_UPGRADE';
