import { Payload } from '../interfaces';
/**
 * Used by the framework to serialize/deserialize data like parameters and return values.
 *
 * This is called inside the {@link https://docs.temporal.io/typescript/determinism | Workflow isolate}.
 * To write async code or use Node APIs (or use packages that use Node APIs), use a {@link PayloadCodec}.
 */
export interface PayloadConverter {
    /**
     * Converts a value to a {@link Payload}.
     *
     * @param value The value to convert. Example values include the Workflow args sent from the Client and the values returned by a Workflow or Activity.
     *
     * @returns The {@link Payload}.
     *
     * Should throw {@link ValueError} if unable to convert.
     */
    toPayload<T>(value: T): Payload;
    /**
     * Converts a {@link Payload} back to a value.
     */
    fromPayload<T>(payload: Payload): T;
}
/**
 * Implements conversion of a list of values.
 *
 * @param converter
 * @param values JS values to convert to Payloads
 * @return list of {@link Payload}s
 * @throws {@link ValueError} if conversion of the value passed as parameter failed for any
 *     reason.
 */
export declare function toPayloads(converter: PayloadConverter, ...values: unknown[]): Payload[] | undefined;
/**
 * Run {@link PayloadConverter.toPayload} on an optional value, and then encode it.
 */
export declare function convertOptionalToPayload(payloadConverter: PayloadConverter, value: unknown): Payload | null | undefined;
/**
 * Run {@link PayloadConverter.toPayload} on each value in the map.
 *
 * @throws {@link ValueError} if conversion of any value in the map fails
 */
export declare function mapToPayloads<K extends string, T = any>(converter: PayloadConverter, map: Record<K, T>): Record<K, Payload>;
/**
 * Implements conversion of an array of values of different types. Useful for deserializing
 * arguments of function invocations.
 *
 * @param converter
 * @param index index of the value in the payloads
 * @param payloads serialized value to convert to JS values.
 * @return converted JS value
 * @throws {@link PayloadConverterError} if conversion of the data passed as parameter failed for any
 *     reason.
 */
export declare function fromPayloadsAtIndex<T>(converter: PayloadConverter, index: number, payloads?: Payload[] | null): T;
/**
 * Run {@link PayloadConverter.fromPayload} on each value in the array.
 */
export declare function arrayFromPayloads(converter: PayloadConverter, payloads?: Payload[] | null): unknown[];
export declare function mapFromPayloads<K extends string, T = unknown>(converter: PayloadConverter, map?: Record<K, Payload> | null | undefined): Record<K, T> | undefined;
export declare const rawPayloadTypeBrand: unique symbol;
/**
 * RawValue is a wrapper over a payload.
 * A payload that belongs to a RawValue is special in that it bypasses user-defined payload converters,
 * instead using the default payload converter. The payload still undergoes codec conversion.
 */
export declare class RawValue<T = unknown> {
    private readonly _payload;
    private readonly [rawPayloadTypeBrand];
    constructor(value: T, payloadConverter?: PayloadConverter);
    static fromPayload(p: Payload): RawValue;
    get payload(): Payload;
}
export interface PayloadConverterWithEncoding {
    /**
     * Converts a value to a {@link Payload}.
     *
     * @param value The value to convert. Example values include the Workflow args sent from the Client and the values returned by a Workflow or Activity.
     * @returns The {@link Payload}, or `undefined` if unable to convert.
     */
    toPayload<T>(value: T): Payload | undefined;
    /**
     * Converts a {@link Payload} back to a value.
     */
    fromPayload<T>(payload: Payload): T;
    readonly encodingType: string;
}
/**
 * Tries to convert values to {@link Payload}s using the {@link PayloadConverterWithEncoding}s provided to the constructor, in the order provided.
 *
 * Converts Payloads to values based on the `Payload.metadata.encoding` field, which matches the {@link PayloadConverterWithEncoding.encodingType}
 * of the converter that created the Payload.
 */
export declare class CompositePayloadConverter implements PayloadConverter {
    readonly converters: PayloadConverterWithEncoding[];
    readonly converterByEncoding: Map<string, PayloadConverterWithEncoding>;
    constructor(...converters: PayloadConverterWithEncoding[]);
    /**
     * Tries to run `.toPayload(value)` on each converter in the order provided at construction.
     * Returns the first successful result, throws {@link ValueError} if there is no converter that can handle the value.
     */
    toPayload<T>(value: T): Payload;
    /**
     * Run {@link PayloadConverterWithEncoding.fromPayload} based on the `encoding` metadata of the {@link Payload}.
     */
    fromPayload<T>(payload: Payload): T;
}
/**
 * Converts between JS undefined and NULL Payload
 */
export declare class UndefinedPayloadConverter implements PayloadConverterWithEncoding {
    encodingType: "binary/null";
    toPayload(value: unknown): Payload | undefined;
    fromPayload<T>(_content: Payload): T;
}
/**
 * Converts between binary data types and RAW Payload
 */
export declare class BinaryPayloadConverter implements PayloadConverterWithEncoding {
    encodingType: "binary/plain";
    toPayload(value: unknown): Payload | undefined;
    fromPayload<T>(content: Payload): T;
}
/**
 * Converts between non-undefined values and serialized JSON Payload
 */
export declare class JsonPayloadConverter implements PayloadConverterWithEncoding {
    encodingType: "json/plain";
    toPayload(value: unknown): Payload | undefined;
    fromPayload<T>(content: Payload): T;
}
export declare class DefaultPayloadConverter extends CompositePayloadConverter {
    constructor();
}
/**
 * The default {@link PayloadConverter} used by the SDK. Supports `Uint8Array` and JSON serializables (so if
 * {@link https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/JSON/stringify#description | `JSON.stringify(yourArgOrRetval)`}
 * works, the default payload converter will work).
 *
 * To also support Protobufs, create a custom payload converter with {@link DefaultPayloadConverter}:
 *
 * `const myConverter = new DefaultPayloadConverter({ protobufRoot })`
 */
export declare const defaultPayloadConverter: DefaultPayloadConverter;
