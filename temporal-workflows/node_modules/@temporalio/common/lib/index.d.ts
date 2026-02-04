/**
 * Common library for code that's used across the Client, Worker, and/or Workflow
 *
 * @module
 */
export * from './activity-options';
export { ActivityCancellationDetailsOptions, ActivityCancellationDetails } from './activity-cancellation-details';
export * from './converter/data-converter';
export * from './converter/failure-converter';
export * from './converter/payload-codec';
export * from './converter/payload-converter';
export * from './converter/types';
export * from './deprecated-time';
export * from './errors';
export * from './failure';
export { Headers, Next } from './interceptors';
export * from './interfaces';
export * from './logger';
export * from './priority';
export * from './metrics';
export * from './retry-policy';
export type { Timestamp, Duration, StringValue } from './time';
export * from './worker-deployments';
export * from './workflow-definition-options';
export * from './workflow-handle';
export * from './workflow-options';
export * from './versioning-intent';
export { SearchAttributes, // eslint-disable-line deprecation/deprecation
SearchAttributeValue, // eslint-disable-line deprecation/deprecation
SearchAttributeType, SearchAttributePair, SearchAttributeUpdatePair, TypedSearchAttributes, defineSearchAttributeKey, } from './search-attributes';
/**
 * Encode a UTF-8 string into a Uint8Array
 *
 * @hidden
 * @deprecated - meant for internal use only
 */
export declare function u8(s: string): Uint8Array;
/**
 * Decode a Uint8Array into a UTF-8 string
 *
 * @hidden
 * @deprecated - meant for internal use only
 */
export declare function str(arr: Uint8Array): string;
/**
 * Get `error.message` (or `undefined` if not present)
 *
 * @hidden
 * @deprecated - meant for internal use only
 */
export declare function errorMessage(error: unknown): string | undefined;
/**
 * Get `error.code` (or `undefined` if not present)
 *
 * @hidden
 * @deprecated - meant for internal use only
 */
export declare function errorCode(error: unknown): string | undefined;
