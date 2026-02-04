import * as nexus from 'nexus-rpc';
import { temporal } from '@temporalio/proto';
import { LoadedDataConverter } from '@temporalio/common';
export declare function decodePayloadIntoLazyValue(dataConverter: LoadedDataConverter, payload: temporal.api.common.v1.IPayload | undefined): Promise<nexus.LazyValue>;
export declare function operationErrorToProto(dataConverter: LoadedDataConverter, err: nexus.OperationError): Promise<temporal.api.nexus.v1.IUnsuccessfulOperationError>;
export declare function handlerErrorToProto(dataConverter: LoadedDataConverter, err: nexus.HandlerError): Promise<temporal.api.nexus.v1.IHandlerError>;
export declare function coerceToHandlerError(err: unknown): nexus.HandlerError;
