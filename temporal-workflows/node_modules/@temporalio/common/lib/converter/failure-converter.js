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
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.DefaultFailureConverter = void 0;
exports.cutoffStackTrace = cutoffStackTrace;
const nexus = __importStar(require("nexus-rpc"));
const long_1 = __importDefault(require("long"));
const failure_1 = require("../failure");
const internal_workflow_1 = require("../internal-workflow");
const type_helpers_1 = require("../type-helpers");
const time_1 = require("../time");
const payload_converter_1 = require("./payload-converter");
// Can't import proto enums into the workflow sandbox, use this helper type and enum converter instead.
const NexusHandlerErrorRetryBehavior = {
    RETRYABLE: 'RETRYABLE',
    NON_RETRYABLE: 'NON_RETRYABLE',
};
const [encodeNexusHandlerErrorRetryBehavior, decodeNexusHandlerErrorRetryBehavior] = (0, internal_workflow_1.makeProtoEnumConverters)({
    UNSPECIFIED: 0,
    [NexusHandlerErrorRetryBehavior.RETRYABLE]: 1,
    [NexusHandlerErrorRetryBehavior.NON_RETRYABLE]: 2,
}, 'NEXUS_HANDLER_ERROR_RETRY_BEHAVIOR_');
function combineRegExp(...regexps) {
    return new RegExp(regexps.map((x) => `(?:${x.source})`).join('|'));
}
/**
 * Stack traces will be cutoff when on of these patterns is matched
 */
const CUTOFF_STACK_PATTERNS = combineRegExp(
/** Activity execution */
/\s+at Activity\.execute \(.*[\\/]worker[\\/](?:src|lib)[\\/]activity\.[jt]s:\d+:\d+\)/, 
/** Nexus execution */
/\s+at( async)? NexusHandler\.invokeUserCode \(.*[\\/]worker[\\/](?:src|lib)[\\/]nexus[\\/]index\.[jt]s:\d+:\d+\)/, 
/** Workflow activation */
/\s+at Activator\.\S+NextHandler \(.*[\\/]workflow[\\/](?:src|lib)[\\/]internals\.[jt]s:\d+:\d+\)/, 
/** Workflow run anything in context */
/\s+at Script\.runInContext \((?:node:vm|vm\.js):\d+:\d+\)/);
/**
 * Any stack trace frames that match any of those wil be dopped.
 * The "null." prefix on some cases is to avoid https://github.com/nodejs/node/issues/42417
 */
const DROPPED_STACK_FRAMES_PATTERNS = combineRegExp(
/** Internal functions used to recursively chain interceptors */
/\s+at (null\.)?next \(.*[\\/]common[\\/](?:src|lib)[\\/]interceptors\.[jt]s:\d+:\d+\)/, 
/** Internal functions used to recursively chain interceptors */
/\s+at (null\.)?executeNextHandler \(.*[\\/]worker[\\/](?:src|lib)[\\/]activity\.[jt]s:\d+:\d+\)/);
/**
 * Cuts out the framework part of a stack trace, leaving only user code entries
 */
function cutoffStackTrace(stack) {
    const lines = (stack ?? '').split(/\r?\n/);
    const acc = Array();
    for (const line of lines) {
        if (CUTOFF_STACK_PATTERNS.test(line))
            break;
        if (!DROPPED_STACK_FRAMES_PATTERNS.test(line))
            acc.push(line);
    }
    return acc.join('\n');
}
/**
 * Default, cross-language-compatible Failure converter.
 *
 * By default, it will leave error messages and stack traces as plain text. In order to encrypt them, set
 * `encodeCommonAttributes` to `true` in the constructor options and use a {@link PayloadCodec} that can encrypt /
 * decrypt Payloads in your {@link WorkerOptions.dataConverter | Worker} and
 * {@link ClientOptions.dataConverter | Client options}.
 */
class DefaultFailureConverter {
    options;
    constructor(options) {
        const { encodeCommonAttributes } = options ?? {};
        this.options = {
            encodeCommonAttributes: encodeCommonAttributes ?? false,
        };
    }
    /**
     * Converts a Failure proto message to a JS Error object.
     *
     * Does not set common properties, that is done in {@link failureToError}.
     */
    failureToErrorInner(failure, payloadConverter) {
        if (failure.applicationFailureInfo) {
            return new failure_1.ApplicationFailure(failure.message ?? undefined, failure.applicationFailureInfo.type, Boolean(failure.applicationFailureInfo.nonRetryable), (0, payload_converter_1.arrayFromPayloads)(payloadConverter, failure.applicationFailureInfo.details?.payloads), this.optionalFailureToOptionalError(failure.cause, payloadConverter), undefined, (0, failure_1.decodeApplicationFailureCategory)(failure.applicationFailureInfo.category));
        }
        if (failure.serverFailureInfo) {
            return new failure_1.ServerFailure(failure.message ?? undefined, Boolean(failure.serverFailureInfo.nonRetryable), this.optionalFailureToOptionalError(failure.cause, payloadConverter));
        }
        if (failure.timeoutFailureInfo) {
            return new failure_1.TimeoutFailure(failure.message ?? undefined, (0, payload_converter_1.fromPayloadsAtIndex)(payloadConverter, 0, failure.timeoutFailureInfo.lastHeartbeatDetails?.payloads), (0, failure_1.decodeTimeoutType)(failure.timeoutFailureInfo.timeoutType));
        }
        if (failure.terminatedFailureInfo) {
            return new failure_1.TerminatedFailure(failure.message ?? undefined, this.optionalFailureToOptionalError(failure.cause, payloadConverter));
        }
        if (failure.canceledFailureInfo) {
            return new failure_1.CancelledFailure(failure.message ?? undefined, (0, payload_converter_1.arrayFromPayloads)(payloadConverter, failure.canceledFailureInfo.details?.payloads), this.optionalFailureToOptionalError(failure.cause, payloadConverter));
        }
        if (failure.resetWorkflowFailureInfo) {
            return new failure_1.ApplicationFailure(failure.message ?? undefined, 'ResetWorkflow', false, (0, payload_converter_1.arrayFromPayloads)(payloadConverter, failure.resetWorkflowFailureInfo.lastHeartbeatDetails?.payloads), this.optionalFailureToOptionalError(failure.cause, payloadConverter));
        }
        if (failure.childWorkflowExecutionFailureInfo) {
            const { namespace, workflowType, workflowExecution, retryState } = failure.childWorkflowExecutionFailureInfo;
            if (!(workflowType?.name && workflowExecution)) {
                throw new TypeError('Missing attributes on childWorkflowExecutionFailureInfo');
            }
            return new failure_1.ChildWorkflowFailure(namespace ?? undefined, workflowExecution, workflowType.name, (0, failure_1.decodeRetryState)(retryState), this.optionalFailureToOptionalError(failure.cause, payloadConverter));
        }
        if (failure.activityFailureInfo) {
            if (!failure.activityFailureInfo.activityType?.name) {
                throw new TypeError('Missing activityType?.name on activityFailureInfo');
            }
            return new failure_1.ActivityFailure(failure.message ?? undefined, failure.activityFailureInfo.activityType.name, failure.activityFailureInfo.activityId ?? undefined, (0, failure_1.decodeRetryState)(failure.activityFailureInfo.retryState), failure.activityFailureInfo.identity ?? undefined, this.optionalFailureToOptionalError(failure.cause, payloadConverter));
        }
        if (failure.nexusHandlerFailureInfo) {
            let retryableOverride = undefined;
            const retryBehavior = decodeNexusHandlerErrorRetryBehavior(failure.nexusHandlerFailureInfo.retryBehavior);
            switch (retryBehavior) {
                case 'RETRYABLE':
                    retryableOverride = true;
                    break;
                case 'NON_RETRYABLE':
                    retryableOverride = false;
                    break;
            }
            return new nexus.HandlerError(failure.nexusHandlerFailureInfo.type ?? 'INTERNAL', 
            // TODO(nexus/error): Maybe set a default message here, once we've decided on error handling.
            failure.message ?? undefined, {
                cause: this.optionalFailureToOptionalError(failure.cause, payloadConverter),
                retryableOverride,
            });
        }
        if (failure.nexusOperationExecutionFailureInfo) {
            return new failure_1.NexusOperationFailure(
            // TODO(nexus/error): Maybe set a default message here, once we've decided on error handling.
            failure.message ?? undefined, failure.nexusOperationExecutionFailureInfo.scheduledEventId?.toNumber(), 
            // We assume these will always be set or gracefully set to empty strings.
            failure.nexusOperationExecutionFailureInfo.endpoint ?? '', failure.nexusOperationExecutionFailureInfo.service ?? '', failure.nexusOperationExecutionFailureInfo.operation ?? '', failure.nexusOperationExecutionFailureInfo.operationToken ?? undefined, this.optionalFailureToOptionalError(failure.cause, payloadConverter));
        }
        return new failure_1.TemporalFailure(failure.message ?? undefined, this.optionalFailureToOptionalError(failure.cause, payloadConverter));
    }
    failureToError(failure, payloadConverter) {
        if (failure.encodedAttributes) {
            const attrs = payloadConverter.fromPayload(failure.encodedAttributes);
            // Don't apply encodedAttributes unless they conform to an expected schema
            if (typeof attrs === 'object' && attrs !== null) {
                const { message, stack_trace } = attrs;
                // Avoid mutating the argument
                failure = { ...failure };
                if (typeof message === 'string') {
                    failure.message = message;
                }
                if (typeof stack_trace === 'string') {
                    failure.stackTrace = stack_trace;
                }
            }
        }
        const err = this.failureToErrorInner(failure, payloadConverter);
        err.stack = failure.stackTrace ?? '';
        if (err instanceof failure_1.TemporalFailure) {
            err.failure = failure;
        }
        return err;
    }
    errorToFailure(err, payloadConverter) {
        const failure = this.errorToFailureInner(err, payloadConverter);
        if (this.options.encodeCommonAttributes) {
            const { message, stackTrace } = failure;
            failure.message = 'Encoded failure';
            failure.stackTrace = '';
            failure.encodedAttributes = payloadConverter.toPayload({ message, stack_trace: stackTrace });
        }
        return failure;
    }
    errorToFailureInner(err, payloadConverter) {
        // TODO(nexus/error): If we decide not to have a NexusHandlerFailure, we could still attach the
        //                    failure proto to the Nexus HandlerError object, by using a private symbol
        //                    property. To be considered once we have a decision on error handling.
        if (err instanceof failure_1.TemporalFailure || err instanceof nexus.HandlerError) {
            if (err instanceof failure_1.TemporalFailure && err.failure)
                return err.failure;
            const base = {
                message: err.message,
                stackTrace: cutoffStackTrace(err.stack),
                cause: this.optionalErrorToOptionalFailure(err.cause, payloadConverter),
                source: failure_1.FAILURE_SOURCE,
            };
            if (err instanceof failure_1.ActivityFailure) {
                return {
                    ...base,
                    activityFailureInfo: {
                        ...err,
                        retryState: (0, failure_1.encodeRetryState)(err.retryState),
                        activityType: { name: err.activityType },
                    },
                };
            }
            if (err instanceof failure_1.ChildWorkflowFailure) {
                return {
                    ...base,
                    childWorkflowExecutionFailureInfo: {
                        ...err,
                        retryState: (0, failure_1.encodeRetryState)(err.retryState),
                        workflowExecution: err.execution,
                        workflowType: { name: err.workflowType },
                    },
                };
            }
            if (err instanceof failure_1.ApplicationFailure) {
                return {
                    ...base,
                    applicationFailureInfo: {
                        type: err.type,
                        nonRetryable: err.nonRetryable,
                        details: err.details && err.details.length
                            ? { payloads: (0, payload_converter_1.toPayloads)(payloadConverter, ...err.details) }
                            : undefined,
                        nextRetryDelay: (0, time_1.msOptionalToTs)(err.nextRetryDelay),
                        category: (0, failure_1.encodeApplicationFailureCategory)(err.category),
                    },
                };
            }
            if (err instanceof failure_1.CancelledFailure) {
                return {
                    ...base,
                    canceledFailureInfo: {
                        details: err.details && err.details.length
                            ? { payloads: (0, payload_converter_1.toPayloads)(payloadConverter, ...err.details) }
                            : undefined,
                    },
                };
            }
            if (err instanceof failure_1.TimeoutFailure) {
                return {
                    ...base,
                    timeoutFailureInfo: {
                        timeoutType: (0, failure_1.encodeTimeoutType)(err.timeoutType),
                        lastHeartbeatDetails: err.lastHeartbeatDetails
                            ? { payloads: (0, payload_converter_1.toPayloads)(payloadConverter, err.lastHeartbeatDetails) }
                            : undefined,
                    },
                };
            }
            if (err instanceof failure_1.ServerFailure) {
                return {
                    ...base,
                    serverFailureInfo: { nonRetryable: err.nonRetryable },
                };
            }
            if (err instanceof failure_1.TerminatedFailure) {
                return {
                    ...base,
                    terminatedFailureInfo: {},
                };
            }
            if (err instanceof nexus.HandlerError) {
                let retryBehavior = undefined;
                switch (err.retryableOverride) {
                    case true:
                        retryBehavior = encodeNexusHandlerErrorRetryBehavior('RETRYABLE');
                        break;
                    case false:
                        retryBehavior = encodeNexusHandlerErrorRetryBehavior('NON_RETRYABLE');
                        break;
                }
                return {
                    // TODO(nexus/error): Maybe set a default message here, once we've decided on error handling.
                    ...base,
                    nexusHandlerFailureInfo: {
                        type: err.type,
                        retryBehavior,
                    },
                };
            }
            if (err instanceof failure_1.NexusOperationFailure) {
                return {
                    // TODO(nexus/error): Maybe set a default message here, once we've decided on error handling.
                    ...base,
                    nexusOperationExecutionFailureInfo: {
                        scheduledEventId: err.scheduledEventId ? long_1.default.fromNumber(err.scheduledEventId) : undefined,
                        endpoint: err.endpoint,
                        service: err.service,
                        operation: err.operation,
                        operationToken: err.operationToken,
                    },
                };
            }
            // Just a TemporalFailure
            return base;
        }
        const base = {
            source: failure_1.FAILURE_SOURCE,
        };
        if ((0, type_helpers_1.isError)(err)) {
            return {
                ...base,
                message: String(err.message) ?? '',
                stackTrace: cutoffStackTrace(err.stack),
                cause: this.optionalErrorToOptionalFailure(err.cause, payloadConverter),
            };
        }
        const recommendation = ` [A non-Error value was thrown from your code. We recommend throwing Error objects so that we can provide a stack trace]`;
        if (typeof err === 'string') {
            return { ...base, message: err + recommendation };
        }
        if (typeof err === 'object') {
            let message = '';
            try {
                message = JSON.stringify(err);
            }
            catch (_err) {
                message = String(err);
            }
            return { ...base, message: message + recommendation };
        }
        return { ...base, message: String(err) + recommendation };
    }
    /**
     * Converts a Failure proto message to a JS Error object if defined or returns undefined.
     */
    optionalFailureToOptionalError(failure, payloadConverter) {
        return failure ? this.failureToError(failure, payloadConverter) : undefined;
    }
    /**
     * Converts an error to a Failure proto message if defined or returns undefined
     */
    optionalErrorToOptionalFailure(err, payloadConverter) {
        return err ? this.errorToFailure(err, payloadConverter) : undefined;
    }
}
exports.DefaultFailureConverter = DefaultFailureConverter;
//# sourceMappingURL=failure-converter.js.map