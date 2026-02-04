import type { VersioningIntent as VersioningIntentString } from './versioning-intent';
/**
 * Protobuf enum representation of {@link VersioningIntentString}.
 *
 * @deprecated In favor of the new Worker Deployment API.
 * @experimental The Worker Versioning API is still being designed. Major changes are expected.
 */
export declare enum VersioningIntent {
    UNSPECIFIED = 0,
    COMPATIBLE = 1,
    DEFAULT = 2
}
export declare function versioningIntentToProto(intent: VersioningIntentString | undefined): VersioningIntent;
