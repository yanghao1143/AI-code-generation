import { Link as NexusLink } from 'nexus-rpc';
import { temporal } from '@temporalio/proto';
type WorkflowEventLink = temporal.api.common.v1.Link.IWorkflowEvent;
export declare function convertWorkflowEventLinkToNexusLink(we: WorkflowEventLink): NexusLink;
export declare function convertNexusLinkToWorkflowEventLink(link: NexusLink): WorkflowEventLink;
export {};
