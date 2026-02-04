"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ENHANCED_STACK_TRACE_QUERY_NAME = exports.STACK_TRACE_QUERY_NAME = exports.TEMPORAL_RESERVED_PREFIX = void 0;
exports.throwIfReservedName = throwIfReservedName;
exports.TEMPORAL_RESERVED_PREFIX = '__temporal_';
exports.STACK_TRACE_QUERY_NAME = '__stack_trace';
exports.ENHANCED_STACK_TRACE_QUERY_NAME = '__enhanced_stack_trace';
/**
 * Validates if the provided name contains any reserved prefixes or matches any reserved names.
 * Throws a TypeError if validation fails, with a specific message indicating whether the issue
 * is with a reserved prefix or an exact match to a reserved name.
 *
 * @param type The entity type being checked
 * @param name The name to check against reserved prefixes/names
 */
function throwIfReservedName(type, name) {
    if (name.startsWith(exports.TEMPORAL_RESERVED_PREFIX)) {
        throw new TypeError(`Cannot use ${type} name: '${name}', with reserved prefix: '${exports.TEMPORAL_RESERVED_PREFIX}'`);
    }
    if (name === exports.STACK_TRACE_QUERY_NAME || name === exports.ENHANCED_STACK_TRACE_QUERY_NAME) {
        throw new TypeError(`Cannot use ${type} name: '${name}', which is a reserved name`);
    }
}
//# sourceMappingURL=reserved.js.map