import React from "react";
import "./ui-button.css";

type Variant = "primary" | "ghost" | "danger";

export interface UiButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: Variant;
}

export function UiButton({ variant = "primary", className = "", ...props }: UiButtonProps) {
  const classes = [
    "ui-btn",
    variant === "ghost" ? "ui-btn--ghost" : "",
    variant === "danger" ? "ui-btn--danger" : "",
    className,
  ]
    .filter(Boolean)
    .join(" ");

  return <button className={classes} {...props} />;
}