import React from "react";

export function ErrorBox({ message }: { message: string }) {
  return (
    <div className="ui-status ui-hint ui-hint--error" role="alert" aria-live="assertive">
      错误：{message}
    </div>
  );
}
