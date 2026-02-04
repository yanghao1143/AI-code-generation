import { type MetricMeter } from '@temporalio/common';
import { MetricSinks } from '@temporalio/workflow/lib/metrics';
import { InjectedSinks } from '../sinks';
export declare function initMetricSink(metricMeter: MetricMeter): InjectedSinks<MetricSinks>;
