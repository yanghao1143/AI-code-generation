"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (k !== "default" && Object.prototype.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.decodePayloadIntoLazyValue = decodePayloadIntoLazyValue;
exports.operationErrorToProto = operationErrorToProto;
exports.handlerErrorToProto = handlerErrorToProto;
exports.coerceToHandlerError = coerceToHandlerError;
const grpc_js_1 = require("@grpc/grpc-js");
const protoJsonSerializer = __importStar(require("proto3-json-serializer"));
const nexus = __importStar(require("nexus-rpc"));
const proto_1 = require("@temporalio/proto");
const client_1 = require("@temporalio/client");
const common_1 = require("@temporalio/common");
const internal_non_workflow_1 = require("@temporalio/common/lib/internal-non-workflow");
const proto_utils_1 = require("@temporalio/common/lib/proto-utils");
////////////////////////////////////////////////////////////////////////////////////////////////////
// Payloads
////////////////////////////////////////////////////////////////////////////////////////////////////
async function decodePayloadIntoLazyValue(dataConverter, payload) {
    let decoded;
    try {
        decoded = await (0, internal_non_workflow_1.decodeOptionalSingle)(dataConverter.payloadCodecs, payload);
    }
    catch (err) {
        throw new nexus.HandlerError('BAD_REQUEST', `Failed to decode payload: ${err}`);
    }
    // Nexus headers have string values and Temporal Payloads have binary values. Instead of
    // converting Payload instances into Content instances, we embed the Payload in the serializer
    // and pretend we are deserializing an empty Content.
    const input = new nexus.LazyValue(new PayloadSerializer(dataConverter.payloadConverter, decoded ?? undefined), {});
    return input;
}
/**
 * An adapter from a Temporal PayloadConverer and a Nexus Serializer.
 */
class PayloadSerializer {
    payloadConverter;
    payload;
    constructor(payloadConverter, payload) {
        this.payloadConverter = payloadConverter;
        this.payload = payload;
    }
    deserialize() {
        if (this.payload == null) {
            return undefined;
        }
        try {
            return this.payloadConverter.fromPayload(this.payload);
        }
        catch (err) {
            throw new nexus.HandlerError('BAD_REQUEST', `Failed to deserialize input: ${err}`);
        }
    }
    /** Not used in this path */
    serialize() {
        throw new Error('not implemented');
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////////
// Failures
////////////////////////////////////////////////////////////////////////////////////////////////////
// fullName isn't part of the generated typed unfortunately.
const TEMPORAL_FAILURE_METADATA = { type: proto_1.temporal.api.failure.v1.Failure.fullName.slice(1) };
async function operationErrorToProto(dataConverter, err) {
    let { cause } = err;
    if (cause == null) {
        // Create an error without capturing a stack trace.
        const wrapped = Object.create(common_1.ApplicationFailure.prototype);
        wrapped.message = err.message;
        wrapped.stack = err.stack;
        wrapped.nonRetryable = true;
        cause = wrapped;
    }
    return {
        operationState: err.state,
        failure: await errorToNexusFailure(dataConverter, cause),
    };
}
async function errorToNexusFailure(dataConverter, err) {
    const failure = await (0, internal_non_workflow_1.encodeErrorToFailure)(dataConverter, err);
    const { message } = failure;
    delete failure.message;
    // TODO: there must be a more graceful way of passing this object to this function.
    const pbj = protoJsonSerializer.toProto3JSON(proto_1.temporal.api.failure.v1.Failure.fromObject(failure));
    return {
        message,
        metadata: TEMPORAL_FAILURE_METADATA,
        details: Buffer.from(JSON.stringify((0, proto_utils_1.fixBuffers)(pbj))),
    };
}
async function handlerErrorToProto(dataConverter, err) {
    let retryBehavior = proto_1.temporal.api.enums.v1.NexusHandlerErrorRetryBehavior.NEXUS_HANDLER_ERROR_RETRY_BEHAVIOR_UNSPECIFIED;
    if (err.retryable === true) {
        retryBehavior = proto_1.temporal.api.enums.v1.NexusHandlerErrorRetryBehavior.NEXUS_HANDLER_ERROR_RETRY_BEHAVIOR_RETRYABLE;
    }
    else if (err.retryable === false) {
        retryBehavior =
            proto_1.temporal.api.enums.v1.NexusHandlerErrorRetryBehavior.NEXUS_HANDLER_ERROR_RETRY_BEHAVIOR_NON_RETRYABLE;
    }
    let { cause } = err;
    if (cause == null) {
        // TODO(nexus/error): I believe this is wrong, but leaving as-is until we have a decision on
        //                    on how we want to encode Nexus errors going forward.
        //
        // Create an error without capturing a stack trace.
        const wrapped = Object.create(common_1.ApplicationFailure.prototype);
        wrapped.message = err.message;
        wrapped.stack = err.stack;
        cause = wrapped;
    }
    return {
        errorType: err.type,
        failure: await errorToNexusFailure(dataConverter, cause),
        retryBehavior,
    };
}
function coerceToHandlerError(err) {
    if (err instanceof nexus.HandlerError) {
        return err;
    }
    // REVIEW: This check could be moved down and fold into the next one but will keep for now to help readability.
    if (err instanceof common_1.ApplicationFailure && err.nonRetryable) {
        return new nexus.HandlerError('INTERNAL', undefined, { cause: err, retryableOverride: false });
    }
    if (err instanceof client_1.ServiceError) {
        if ((0, client_1.isGrpcServiceError)(err.cause)) {
            switch (err.cause.code) {
                case grpc_js_1.status.INVALID_ARGUMENT:
                    return new nexus.HandlerError('BAD_REQUEST', undefined, { cause: err });
                case (grpc_js_1.status.ALREADY_EXISTS, grpc_js_1.status.FAILED_PRECONDITION, grpc_js_1.status.OUT_OF_RANGE):
                    return new nexus.HandlerError('INTERNAL', undefined, { cause: err, retryableOverride: false });
                case (grpc_js_1.status.ABORTED, grpc_js_1.status.UNAVAILABLE):
                    return new nexus.HandlerError('UNAVAILABLE', undefined, { cause: err });
                case (grpc_js_1.status.CANCELLED,
                    grpc_js_1.status.DATA_LOSS,
                    grpc_js_1.status.INTERNAL,
                    grpc_js_1.status.UNKNOWN,
                    grpc_js_1.status.UNAUTHENTICATED,
                    grpc_js_1.status.PERMISSION_DENIED):
                    // Note that UNAUTHENTICATED and PERMISSION_DENIED have Nexus error types but we convert to internal because
                    // this is not a client auth error and happens when the handler fails to auth with Temporal and should be
                    // considered retryable.
                    return new nexus.HandlerError('INTERNAL', undefined, { cause: err });
                case grpc_js_1.status.NOT_FOUND:
                    return new nexus.HandlerError('NOT_FOUND', undefined, { cause: err });
                case grpc_js_1.status.RESOURCE_EXHAUSTED:
                    return new nexus.HandlerError('RESOURCE_EXHAUSTED', undefined, { cause: err });
                case grpc_js_1.status.UNIMPLEMENTED:
                    return new nexus.HandlerError('NOT_IMPLEMENTED', undefined, { cause: err });
                case grpc_js_1.status.DEADLINE_EXCEEDED:
                    return new nexus.HandlerError('UPSTREAM_TIMEOUT', undefined, { cause: err });
            }
        }
    }
    return new nexus.HandlerError('INTERNAL', undefined, { cause: err });
}
//# sourceMappingURL=conversions.js.map