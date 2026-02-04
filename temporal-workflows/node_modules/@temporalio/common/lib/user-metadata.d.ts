import type { temporal } from '@temporalio/proto';
import { PayloadConverter } from './converter/payload-converter';
/**
 * User metadata that can be attached to workflow commands.
 */
export interface UserMetadata {
    /** @experimental A fixed, single line summary of the command's purpose */
    staticSummary?: string;
    /** @experimental Fixed additional details about the command for longer-text description, can span multiple lines */
    staticDetails?: string;
}
export declare function userMetadataToPayload(payloadConverter: PayloadConverter, staticSummary: string | undefined, staticDetails: string | undefined): temporal.api.sdk.v1.IUserMetadata | undefined;
