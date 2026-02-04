import { MetricCounter, MetricGauge, MetricHistogram, MetricMeter, MetricTags, NumericMetricValueType } from '@temporalio/common';
import { native } from '@temporalio/core-bridge';
export declare class RuntimeMetricMeter implements MetricMeter {
    protected runtime: native.Runtime;
    constructor(runtime: native.Runtime);
    createCounter(name: string, unit?: string, description?: string): MetricCounter;
    createHistogram(name: string, valueType?: NumericMetricValueType, unit?: string, description?: string): MetricHistogram;
    createGauge(name: string, valueType?: NumericMetricValueType, unit?: string, description?: string): MetricGauge;
    withTags(_extraTags: MetricTags): MetricMeter;
}
