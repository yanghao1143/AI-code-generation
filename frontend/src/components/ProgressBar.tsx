import React from "react";

type ProgressBarProps = {
  loaded: number;
  total: number;
  height?: number;
  showText?: boolean;
};

export function ProgressBar({ loaded, total, height = 10, showText = true }: ProgressBarProps) {
  const safeTotal = Math.max(0, total || 0);
  const safeLoaded = Math.max(0, Math.min(loaded || 0, safeTotal || loaded || 0));
  const pct = safeTotal > 0 ? Math.round((safeLoaded / safeTotal) * 100) : 0;

  return (
    <div>
      {showText && (
        <div className="ui-row ui-row--justify-between ui-status ui-status--small ui-mb-sm">
          <span>总数：{safeTotal}</span>
          <span>
            已加载：{safeLoaded}（{pct}%）
          </span>
        </div>
      )}
      <div
        role="progressbar"
        aria-valuemin={0}
        aria-valuemax={safeTotal || undefined}
        aria-valuenow={safeLoaded}
        aria-label="进度"
        className="ui-progress"
        style={{ ["--progress-height" as any]: `${height}px` }}
      >
        <div
          className="ui-progress__bar"
          style={{ ["--progress-pct" as any]: `${Math.min(100, Math.max(0, pct))}%` }}
        />
      </div>
    </div>
  );
}