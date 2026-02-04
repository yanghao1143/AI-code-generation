"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.asNativeTuner = asNativeTuner;
const time_1 = require("@temporalio/common/lib/time");
////////////////////////////////////////////////////////////////////////////////////////////////////
function asNativeTuner(tuner, logger) {
    if (isTunerHolder(tuner)) {
        let tunerOptions = undefined;
        const retme = {
            workflowTaskSlotSupplier: nativeifySupplier(tuner.workflowTaskSlotSupplier, 'workflow', logger),
            activityTaskSlotSupplier: nativeifySupplier(tuner.activityTaskSlotSupplier, 'activity', logger),
            localActivityTaskSlotSupplier: nativeifySupplier(tuner.localActivityTaskSlotSupplier, 'activity', logger),
            nexusTaskSlotSupplier: nativeifySupplier(tuner.nexusTaskSlotSupplier, 'nexus', logger),
        };
        for (const supplier of [
            retme.workflowTaskSlotSupplier,
            retme.activityTaskSlotSupplier,
            retme.localActivityTaskSlotSupplier,
        ]) {
            if (isResourceBased(supplier)) {
                if (tunerOptions !== undefined) {
                    if (tunerOptions.targetCpuUsage !== supplier.tunerOptions.targetCpuUsage ||
                        tunerOptions.targetMemoryUsage !== supplier.tunerOptions.targetMemoryUsage) {
                        throw new TypeError('Cannot construct worker tuner with multiple different tuner options');
                    }
                }
                else {
                    tunerOptions = supplier.tunerOptions;
                }
            }
        }
        return retme;
    }
    else if (isResourceBasedTuner(tuner)) {
        const wftSO = addResourceBasedSlotDefaults(tuner.workflowTaskSlotOptions ?? {}, 'workflow');
        const atSO = addResourceBasedSlotDefaults(tuner.activityTaskSlotOptions ?? {}, 'activity');
        const latSO = addResourceBasedSlotDefaults(tuner.localActivityTaskSlotOptions ?? {}, 'activity');
        const nexusSO = addResourceBasedSlotDefaults(tuner.nexusTaskSlotOptions ?? {}, 'nexus');
        return {
            workflowTaskSlotSupplier: {
                type: 'resource-based',
                tunerOptions: tuner.tunerOptions,
                ...wftSO,
                rampThrottle: (0, time_1.msToNumber)(wftSO.rampThrottle),
            },
            activityTaskSlotSupplier: {
                type: 'resource-based',
                tunerOptions: tuner.tunerOptions,
                ...atSO,
                rampThrottle: (0, time_1.msToNumber)(atSO.rampThrottle),
            },
            localActivityTaskSlotSupplier: {
                type: 'resource-based',
                tunerOptions: tuner.tunerOptions,
                ...latSO,
                rampThrottle: (0, time_1.msToNumber)(latSO.rampThrottle),
            },
            nexusTaskSlotSupplier: {
                type: 'resource-based',
                tunerOptions: tuner.tunerOptions,
                ...nexusSO,
                rampThrottle: (0, time_1.msToNumber)(nexusSO.rampThrottle),
            },
        };
    }
    else {
        throw new TypeError('Invalid worker tuner configuration');
    }
}
const isResourceBasedTuner = (tuner) => Object.hasOwnProperty.call(tuner, 'tunerOptions');
const isTunerHolder = (tuner) => Object.hasOwnProperty.call(tuner, 'workflowTaskSlotSupplier');
const isResourceBased = (sup) => sup.type === 'resource-based';
const isCustom = (sup) => sup.type === 'custom';
////////////////////////////////////////////////////////////////////////////////////////////////////
function nativeifySupplier(supplier, kind, logger) {
    if (isResourceBased(supplier)) {
        const tunerOptions = supplier.tunerOptions;
        const defaulted = addResourceBasedSlotDefaults(supplier, kind);
        return {
            type: 'resource-based',
            minimumSlots: defaulted.minimumSlots,
            maximumSlots: defaulted.maximumSlots,
            rampThrottle: (0, time_1.msToNumber)(defaulted.rampThrottle),
            tunerOptions: {
                targetMemoryUsage: tunerOptions.targetMemoryUsage,
                targetCpuUsage: tunerOptions.targetCpuUsage,
            },
        };
    }
    if (isCustom(supplier)) {
        return new NativeifiedCustomSlotSupplier(supplier, logger);
    }
    return {
        type: 'fixed-size',
        numSlots: supplier.numSlots,
    };
}
function addResourceBasedSlotDefaults(slotOptions, kind) {
    if (kind === 'workflow') {
        return {
            minimumSlots: slotOptions.minimumSlots ?? 2,
            maximumSlots: slotOptions.maximumSlots ?? 1000,
            rampThrottle: slotOptions.rampThrottle ?? 10,
        };
    }
    else {
        return {
            minimumSlots: slotOptions.minimumSlots ?? 1,
            maximumSlots: slotOptions.maximumSlots ?? 2000,
            rampThrottle: slotOptions.rampThrottle ?? 50,
        };
    }
}
class NativeifiedCustomSlotSupplier {
    supplier;
    logger;
    type = 'custom';
    constructor(supplier, logger) {
        this.supplier = supplier;
        this.logger = logger;
        this.reserveSlot = this.reserveSlot.bind(this);
        this.tryReserveSlot = this.tryReserveSlot.bind(this);
        this.markSlotUsed = this.markSlotUsed.bind(this);
        this.releaseSlot = this.releaseSlot.bind(this);
    }
    async reserveSlot(ctx, abortSignal) {
        if (ctx.slotType === 'nexus') {
            throw new Error('nexus not yet supported in slot suppliers');
        }
        try {
            const result = await this.supplier.reserveSlot({
                slotType: ctx.slotType,
                taskQueue: ctx.taskQueue,
                workerIdentity: ctx.workerIdentity,
                workerBuildId: ctx.workerDeploymentVersion?.buildId ?? '',
                workerDeploymentVersion: ctx.workerDeploymentVersion ?? undefined,
                isSticky: ctx.isSticky,
            }, abortSignal);
            return result;
        }
        catch (error) {
            if (abortSignal.aborted && error !== abortSignal.reason) {
                this.logger.error('Error in custom slot supplier `reserveSlot`', { error });
            }
            throw error;
        }
    }
    tryReserveSlot(ctx) {
        if (ctx.slotType === 'nexus') {
            throw new Error('nexus not yet supported in slot suppliers');
        }
        try {
            const result = this.supplier.tryReserveSlot({
                slotType: ctx.slotType,
                taskQueue: ctx.taskQueue,
                workerIdentity: ctx.workerIdentity,
                workerBuildId: ctx.workerDeploymentVersion?.buildId ?? '',
                workerDeploymentVersion: ctx.workerDeploymentVersion ?? undefined,
                isSticky: ctx.isSticky,
            });
            return result ?? null;
        }
        catch (error) {
            this.logger.error(`Error in custom slot supplier tryReserveSlot`, { error });
            return null;
        }
    }
    markSlotUsed(ctx) {
        try {
            this.supplier.markSlotUsed({
                slotInfo: ctx.slotInfo,
                permit: ctx.permit,
            });
        }
        catch (error) {
            this.logger.error(`Error in custom slot supplier markSlotUsed`, { error });
        }
    }
    releaseSlot(ctx) {
        try {
            this.supplier.releaseSlot({
                slotInfo: ctx.slotInfo ?? undefined,
                permit: ctx.permit,
            });
        }
        catch (error) {
            this.logger.error(`Error in custom slot supplier releaseSlot`, { error });
        }
    }
}
//# sourceMappingURL=worker-tuner.js.map