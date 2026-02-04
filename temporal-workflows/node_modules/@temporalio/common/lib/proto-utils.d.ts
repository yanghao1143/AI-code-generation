import * as proto from '@temporalio/proto';
export type History = proto.temporal.api.history.v1.IHistory;
export type Payload = proto.temporal.api.common.v1.IPayload;
/**
 * JSON representation of Temporal's {@link Payload} protobuf object
 */
export interface JSONPayload {
    /**
     * Mapping of key to base64 encoded value
     */
    metadata?: Record<string, string> | null;
    /**
     * base64 encoded value
     */
    data?: string | null;
}
/**
 * Convert a proto JSON representation of History to a valid History object
 */
export declare function historyFromJSON(history: unknown): History;
/**
 * Convert an History object, e.g. as returned by `WorkflowClient.list().withHistory()`, to a JSON
 * string that adheres to the same norm as JSON history files produced by other Temporal tools.
 */
export declare function historyToJSON(history: History): string;
/**
 * toProto3JSON doesn't correctly handle some of our "bytes" fields, passing them untouched to the
 * output, after which JSON.stringify() would convert them to an array of numbers. As a workaround,
 * recursively walk the object and convert all Buffer instances to base64 strings. Note this only
 * works on proto3-json-serializer v2.0.0. v2.0.2 throws an error before we even get the chance
 * to fix the buffers. See https://github.com/googleapis/proto3-json-serializer-nodejs/issues/103.
 */
export declare function fixBuffers<T>(e: T): T;
/**
 * Convert from protobuf payload to JSON
 */
export declare function payloadToJSON(payload: Payload): JSONPayload;
/**
 * Convert from JSON to protobuf payload
 */
export declare function JSONToPayload(json: JSONPayload): Payload;
