import { Payload } from '../interfaces';
import { TypedSearchAttributes, SearchAttributes, SearchAttributeUpdatePair } from '../search-attributes';
import { PayloadConverter, JsonPayloadConverter } from './payload-converter';
/**
 * Converts Search Attribute values using JsonPayloadConverter
 */
export declare class SearchAttributePayloadConverter implements PayloadConverter {
    jsonConverter: JsonPayloadConverter;
    validNonDateTypes: string[];
    toPayload(values: unknown): Payload;
    /**
     * Datetime Search Attribute values are converted to `Date`s
     */
    fromPayload<T>(payload: Payload): T;
}
export declare const searchAttributePayloadConverter: SearchAttributePayloadConverter;
export declare class TypedSearchAttributePayloadConverter implements PayloadConverter {
    jsonConverter: JsonPayloadConverter;
    toPayload<T>(attr: T): Payload;
    fromPayload<T>(payload: Payload): T;
}
export declare const typedSearchAttributePayloadConverter: TypedSearchAttributePayloadConverter;
export declare function encodeUnifiedSearchAttributes(searchAttributes?: SearchAttributes, // eslint-disable-line deprecation/deprecation
typedSearchAttributes?: TypedSearchAttributes | SearchAttributeUpdatePair[]): Record<string, Payload>;
export declare function decodeSearchAttributes(indexedFields: Record<string, Payload> | undefined | null): SearchAttributes;
export declare function decodeTypedSearchAttributes(indexedFields: Record<string, Payload> | undefined | null): TypedSearchAttributes;
