"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.convertWorkflowEventLinkToNexusLink = convertWorkflowEventLinkToNexusLink;
exports.convertNexusLinkToWorkflowEventLink = convertNexusLinkToWorkflowEventLink;
const long_1 = __importDefault(require("long"));
const proto_1 = require("@temporalio/proto");
const { EventType } = proto_1.temporal.api.enums.v1;
const LINK_EVENT_ID_PARAM = 'eventID';
const LINK_EVENT_TYPE_PARAM = 'eventType';
const LINK_REQUEST_ID_PARAM = 'requestID';
const LINK_REFERENCE_TYPE_KEY = 'referenceType';
const EVENT_REFERENCE_TYPE = 'EventReference';
const REQUEST_ID_REFERENCE_TYPE = 'RequestIdReference';
// fullName isn't part of the generated typed unfortunately.
const WORKFLOW_EVENT_TYPE = proto_1.temporal.api.common.v1.Link.WorkflowEvent.fullName.slice(1);
function convertWorkflowEventLinkToNexusLink(we) {
    if (!we.namespace || !we.workflowId || !we.runId) {
        throw new TypeError('Missing required fields: namespace, workflowId, or runId');
    }
    const url = new URL(`temporal:///namespaces/${encodeURIComponent(we.namespace)}/workflows/${encodeURIComponent(we.workflowId)}/${encodeURIComponent(we.runId)}/history`);
    if (we.eventRef != null) {
        url.search = convertLinkWorkflowEventEventReferenceToURLQuery(we.eventRef);
    }
    else if (we.requestIdRef != null) {
        url.search = convertLinkWorkflowEventRequestIdReferenceToURLQuery(we.requestIdRef);
    }
    return {
        url,
        type: WORKFLOW_EVENT_TYPE,
    };
}
function convertNexusLinkToWorkflowEventLink(link) {
    if (link.url.protocol !== 'temporal:') {
        throw new TypeError(`Invalid URL scheme: ${link.url}, expected 'temporal:', got '${link.url.protocol}'`);
    }
    // /namespaces/:namespace/workflows/:workflowId/:runId/history
    const parts = link.url.pathname.split('/');
    if (parts.length !== 7 || parts[1] !== 'namespaces' || parts[3] !== 'workflows' || parts[6] !== 'history') {
        throw new TypeError(`Invalid URL path: ${link.url}`);
    }
    const namespace = decodeURIComponent(parts[2]);
    const workflowId = decodeURIComponent(parts[4]);
    const runId = decodeURIComponent(parts[5]);
    const query = link.url.searchParams;
    const refType = query.get(LINK_REFERENCE_TYPE_KEY);
    const workflowEventLink = {
        namespace,
        workflowId,
        runId,
    };
    switch (refType) {
        case EVENT_REFERENCE_TYPE:
            workflowEventLink.eventRef = convertURLQueryToLinkWorkflowEventEventReference(query);
            break;
        case REQUEST_ID_REFERENCE_TYPE:
            workflowEventLink.requestIdRef = convertURLQueryToLinkWorkflowEventRequestIdReference(query);
            break;
        default:
            throw new TypeError(`Unknown reference type: ${refType}`);
    }
    return workflowEventLink;
}
function convertLinkWorkflowEventEventReferenceToURLQuery(eventRef) {
    const params = new URLSearchParams();
    params.set(LINK_REFERENCE_TYPE_KEY, EVENT_REFERENCE_TYPE);
    if (eventRef.eventId != null) {
        const eventId = eventRef.eventId.toNumber();
        if (eventId > 0) {
            params.set(LINK_EVENT_ID_PARAM, `${eventId}`);
        }
    }
    if (eventRef.eventType != null) {
        const eventType = constantCaseToPascalCase(EventType[eventRef.eventType].replace('EVENT_TYPE_', ''));
        params.set(LINK_EVENT_TYPE_PARAM, eventType);
    }
    return params.toString();
}
function convertURLQueryToLinkWorkflowEventEventReference(query) {
    let eventId = 0;
    const eventIdParam = query.get(LINK_EVENT_ID_PARAM);
    if (eventIdParam && /^\d+$/.test(eventIdParam)) {
        eventId = parseInt(eventIdParam, 10);
    }
    const eventTypeParam = query.get(LINK_EVENT_TYPE_PARAM);
    if (!eventTypeParam) {
        throw new TypeError(`Missing eventType parameter`);
    }
    const eventType = EventType[normalizeEnumValue(eventTypeParam, 'EVENT_TYPE')];
    if (eventType == null) {
        throw new TypeError(`Unknown eventType parameter: ${eventTypeParam}`);
    }
    return { eventId: long_1.default.fromNumber(eventId), eventType };
}
function convertLinkWorkflowEventRequestIdReferenceToURLQuery(requestIdRef) {
    const params = new URLSearchParams();
    params.set(LINK_REFERENCE_TYPE_KEY, REQUEST_ID_REFERENCE_TYPE);
    if (requestIdRef.requestId != null) {
        params.set(LINK_REQUEST_ID_PARAM, requestIdRef.requestId);
    }
    if (requestIdRef.eventType != null) {
        const eventType = constantCaseToPascalCase(EventType[requestIdRef.eventType].replace('EVENT_TYPE_', ''));
        params.set(LINK_EVENT_TYPE_PARAM, eventType);
    }
    return params.toString();
}
function convertURLQueryToLinkWorkflowEventRequestIdReference(query) {
    const requestId = query.get(LINK_REQUEST_ID_PARAM);
    const eventTypeParam = query.get(LINK_EVENT_TYPE_PARAM);
    if (!eventTypeParam) {
        throw new TypeError(`Missing eventType parameter`);
    }
    const eventType = EventType[normalizeEnumValue(eventTypeParam, 'EVENT_TYPE')];
    if (eventType == null) {
        throw new TypeError(`Unknown eventType parameter: ${eventTypeParam}`);
    }
    return { requestId, eventType };
}
function normalizeEnumValue(value, prefix) {
    value = pascalCaseToConstantCase(value);
    if (!value.startsWith(prefix)) {
        value = `${prefix}_${value}`;
    }
    return value;
}
function pascalCaseToConstantCase(s) {
    return s.replace(/[^\b][A-Z]/g, (m) => `${m[0]}_${m[1]}`).toUpperCase();
}
function constantCaseToPascalCase(s) {
    return s.replace(/[A-Z]+_?/g, (m) => `${m[0]}${m.slice(1).toLocaleLowerCase()}`.replace(/_/, ''));
}
//# sourceMappingURL=link-converter.js.map