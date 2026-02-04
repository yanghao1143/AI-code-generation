"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.RuntimeMetricMeter = void 0;
const core_bridge_1 = require("@temporalio/core-bridge");
class RuntimeMetricMeter {
    runtime;
    constructor(runtime) {
        this.runtime = runtime;
    }
    createCounter(name, unit = '', description = '') {
        const nativeMetric = core_bridge_1.native.newMetricCounter(this.runtime, name, unit, description);
        return new RuntimeMetricCounter(nativeMetric, name, unit, description);
    }
    createHistogram(name, valueType = 'int', unit = '', description = '') {
        switch (valueType) {
            case 'int': {
                const nativeMetric = core_bridge_1.native.newMetricHistogram(this.runtime, name, unit, description);
                return new RuntimeMetricHistogram(nativeMetric, name, unit, description);
            }
            case 'float': {
                const nativeMetric = core_bridge_1.native.newMetricHistogramF64(this.runtime, name, unit, description);
                return new RuntimeMetricHistogramF64(nativeMetric, name, unit, description);
            }
        }
    }
    createGauge(name, valueType = 'int', unit = '', description = '') {
        switch (valueType) {
            case 'int': {
                const nativeMetric = core_bridge_1.native.newMetricGauge(this.runtime, name, unit, description);
                return new RuntimeMetricGauge(nativeMetric, name, unit, description);
            }
            case 'float': {
                const nativeMetric = core_bridge_1.native.newMetricGaugeF64(this.runtime, name, unit, description);
                return new RuntimeMetricGaugeF64(nativeMetric, name, unit, description);
            }
        }
    }
    withTags(_extraTags) {
        // Tags composition is handled by a MetricMeterWithComposedTags wrapper over this one
        throw new Error('withTags is not supported directly on RuntimeMetricMeter');
    }
}
exports.RuntimeMetricMeter = RuntimeMetricMeter;
class RuntimeMetricCounter {
    native;
    name;
    unit;
    description;
    constructor(native, name, unit, description) {
        this.native = native;
        this.name = name;
        this.unit = unit;
        this.description = description;
    }
    add(value, tags = {}) {
        if (value < 0) {
            throw new Error(`MetricCounter value must be non-negative (got ${value})`);
        }
        core_bridge_1.native.addMetricCounterValue(this.native, value, JSON.stringify(tags));
    }
    withTags(_tags) {
        // Tags composition is handled by a MetricMeterWithComposedTags wrapper over this one
        throw new Error('withTags is not supported directly on RuntimeMetricCounter');
    }
}
class RuntimeMetricHistogram {
    native;
    name;
    unit;
    description;
    valueType = 'int';
    constructor(native, name, unit, description) {
        this.native = native;
        this.name = name;
        this.unit = unit;
        this.description = description;
    }
    record(value, tags = {}) {
        if (value < 0) {
            throw new Error(`MetricHistogram value must be non-negative (got ${value})`);
        }
        core_bridge_1.native.recordMetricHistogramValue(this.native, value, JSON.stringify(tags));
    }
    withTags(_tags) {
        // Tags composition is handled by a MetricMeterWithComposedTags wrapper over this one
        throw new Error('withTags is not supported directly on RuntimeMetricHistogram');
    }
}
class RuntimeMetricHistogramF64 {
    native;
    name;
    unit;
    description;
    valueType = 'float';
    constructor(native, name, unit, description) {
        this.native = native;
        this.name = name;
        this.unit = unit;
        this.description = description;
    }
    record(value, tags = {}) {
        if (value < 0) {
            throw new Error(`MetricHistogram value must be non-negative (got ${value})`);
        }
        core_bridge_1.native.recordMetricHistogramF64Value(this.native, value, JSON.stringify(tags));
    }
    withTags(_tags) {
        // Tags composition is handled by a MetricMeterWithComposedTags wrapper over this one
        throw new Error('withTags is not supported directly on RuntimeMetricHistogramF64');
    }
}
class RuntimeMetricGauge {
    native;
    name;
    unit;
    description;
    valueType = 'int';
    constructor(native, name, unit, description) {
        this.native = native;
        this.name = name;
        this.unit = unit;
        this.description = description;
    }
    set(value, tags = {}) {
        if (value < 0) {
            throw new Error(`MetricGauge value must be non-negative (got ${value})`);
        }
        core_bridge_1.native.setMetricGaugeValue(this.native, value, JSON.stringify(tags));
    }
    withTags(_tags) {
        // Tags composition is handled by a MetricMeterWithComposedTags wrapper over this one
        throw new Error('withTags is not supported directly on RuntimeMetricGauge');
    }
}
class RuntimeMetricGaugeF64 {
    native;
    name;
    unit;
    description;
    valueType = 'float';
    constructor(native, name, unit, description) {
        this.native = native;
        this.name = name;
        this.unit = unit;
        this.description = description;
    }
    set(value, tags = {}) {
        if (value < 0) {
            throw new Error(`MetricGauge value must be non-negative (got ${value})`);
        }
        core_bridge_1.native.setMetricGaugeF64Value(this.native, value, JSON.stringify(tags));
    }
    withTags(_tags) {
        // Tags composition is handled by a MetricMeterWithComposedTags wrapper over this one
        throw new Error('withTags is not supported directly on RuntimeMetricGaugeF64');
    }
}
//# sourceMappingURL=runtime-metrics.js.map