import { OperationInfo } from "../common";
import { LazyValue } from "../serialization";
import { HandlerStartOperationResult } from "./start-operation-result";
import { StartOperationContext, GetOperationResultContext, GetOperationInfoContext, CancelOperationContext } from "./operation-context";
import { ServiceHandler } from "./service-handler";
/**
 * The root Nexus handler, which dispatches Nexus requests to a collection of registered service
 * implementations.
 *
 * @experimental
 */
export declare class ServiceRegistry {
    /**
     * Registered service handlers to which this registry dispatches requests.
     */
    private readonly services;
    /**
     * Constructs a new {@link ServiceRegistry}.
     *
     * @experimental
     */
    static create(services: ServiceHandler<any>[]): ServiceRegistry;
    private constructor();
    private getOperationHandler;
    start(ctx: StartOperationContext, lv: LazyValue): Promise<HandlerStartOperationResult<any>>;
    getInfo(ctx: GetOperationInfoContext, token: string): Promise<OperationInfo>;
    getResult(ctx: GetOperationResultContext, token: string): Promise<any>;
    cancel(ctx: CancelOperationContext, token: string): Promise<void>;
}
