import React from "react";

export function Empty({ text = "暂无数据" }: { text?: string }) {
  return <div className="ui-status ui-status--empty" role="status" aria-live="polite">{text}</div>;
}
