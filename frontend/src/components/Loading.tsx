import React from "react";

export function Loading({ text = "加载中..." }: { text?: string }) {
  return <div className="ui-status ui-status--loading" role="status" aria-live="polite">{text}</div>;
}
