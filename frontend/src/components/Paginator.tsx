import React, { useState, useEffect } from "react";
import { UiButton } from "./UiButton";
import "./ui-input.css";

type PaginatorProps = {
  pageIndex: number; // 0-based
  pageCount: number; // total pages
  disabled?: boolean;
  onChange: (index: number) => void;
  variant?: "default" | "compact";
  responsive?: boolean;
  onPrefetch?: (nextIndex: number) => void; // 预取下一页（可选）
};
export function Paginator({ pageIndex, pageCount, disabled = false, onChange, variant = "default", responsive = true, onPrefetch }: PaginatorProps) {
  const [inputVal, setInputVal] = useState<string>(String(pageIndex + 1));

  const clamp = (n: number) => Math.max(0, Math.min(pageCount - 1, n));
  const go = (n: number) => onChange(clamp(n));

  useEffect(() => {
    setInputVal(String(pageIndex + 1));
  }, [pageIndex, pageCount]);

  // 可选的预取下一页策略：页码变化时提示上层预取下一页数据
  useEffect(() => {
    if (typeof onPrefetch === "function" && pageIndex + 1 < pageCount) {
      onPrefetch(pageIndex + 1);
    }
  }, [pageIndex, pageCount, onPrefetch]);

  const submitJump = (e: React.FormEvent) => {
    e.preventDefault();
    const n = parseInt(inputVal, 10);
    if (!Number.isFinite(n)) return;
    if (n < 1 || n > pageCount) return;
    go(n - 1);
  };

  const isCompact = variant === "compact";

  return (
    <div className={`ui-row ${isCompact ? "ui-row--gap-xs" : "ui-row--gap-md"} ${responsive ? "" : "ui-row--nowrap"}`}>
      {!isCompact && (
        <span className="ui-status ui-status--small">
          共 {pageCount} 页，当前第 {pageIndex + 1} 页（范围 1 - {pageCount}）
        </span>
      )}
      <UiButton type="button" variant="ghost" onClick={() => go(0)} disabled={disabled || pageIndex <= 0}>
        « 首页
      </UiButton>
      <UiButton type="button" variant="ghost" onClick={() => go(pageIndex - 1)} disabled={disabled || pageIndex <= 0}>
        ‹ 上一页
      </UiButton>
      <UiButton type="button" variant="ghost" onClick={() => go(pageIndex + 1)} disabled={disabled || pageIndex >= pageCount - 1}>
        下一页 ›
      </UiButton>
      <UiButton type="button" variant="ghost" onClick={() => go(pageCount - 1)} disabled={disabled || pageIndex >= pageCount - 1}>
        末页 »
      </UiButton>
      <form onSubmit={submitJump} className={`ui-row ${isCompact ? "ui-row--gap-xs" : ""}`}>
        {!isCompact && (
          <label className="ui-status ui-status--small ui-row ui-row--gap-xs">
            <span>跳转：</span>
            <input
              type="number"
              min={1}
              max={pageCount}
              value={inputVal}
              onChange={(e) => setInputVal(e.target.value)}
              className="ui-input ui-input--w-sm"
            />
          </label>
        )}
        {isCompact && (
          <input
            aria-label="跳转到页码"
            type="number"
            min={1}
            max={pageCount}
            value={inputVal}
            onChange={(e) => setInputVal(e.target.value)}
            className="ui-input ui-input--w-xs"
          />
        )}
        <UiButton
          type="submit"
          disabled={
            disabled ||
            !Number.isFinite(parseInt(inputVal, 10)) ||
            parseInt(inputVal, 10) < 1 ||
            parseInt(inputVal, 10) > pageCount
          }
        >
          Go
        </UiButton>
      </form>
    </div>
  );
}