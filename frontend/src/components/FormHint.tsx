import React from "react";

type Variant = "info" | "success" | "warning" | "error";

export interface FormHintProps {
  variant?: Variant;
  children: React.ReactNode;
  icon?: string; // 可选图标字符，例如 "ℹ️" "✅" "⚠️" "❌"
}

export function FormHint({ variant = "info", children, icon }: FormHintProps) {
  const iconChar = icon ?? (variant === "success" ? "✅" : variant === "warning" ? "⚠️" : variant === "error" ? "❌" : "ℹ️");
  return (
    <p className={`ui-input-hint ui-hint ui-hint--${variant}`}>
      <span aria-hidden className="ui-inline-gap-right">{iconChar}</span>
      {children}
    </p>
  );
}