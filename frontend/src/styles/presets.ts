import { Tokens, SchemeKey } from "./types";

const presetA: Tokens = {
  "--color-primary-start": "#2563eb",
  "--color-primary-end": "#7c3aed",
  "--text-color": "#111827",
  "--bg-color": "#ffffff",
  "--panel-bg": "#ffffff",
  "--panel-border": "rgba(226, 232, 240, 0.9)",
  "--color-accent": "#7c3aed",
  "--btn-border": "#e5e7eb",
  "--btn-ghost-text": "#111827",
  "--border-color": "#e5e7eb",
  "--space-sm": "8px",
  "--space-md": "12px",
  "--space-lg": "16px",
  "--radius-sm": "8px",
  "--radius-md": "10px",
  "--radius-lg": "12px",
  "--shadow-sm": "0 1px 2px rgba(0,0,0,0.08)",
  "--shadow-md": "0 8px 24px rgba(0,0,0,0.12)",
  "--border-width": "1px",
  "--font-size-base": "14px",
  "--line-height-base": "1.6",
  "--container-max-width": "1200px",
  "--grid-gap": "16px",
  "--grid-columns": "12",
};

const presetB: Tokens = {
  "--color-primary-start": "#0ea5e9", // sky-500
  "--color-primary-end": "#22c55e",   // green-500
  "--text-color": "#0f172a",         // slate-900
  "--bg-color": "#f8fafc",           // slate-50
  "--panel-bg": "#ffffff",
  "--panel-border": "rgba(203, 213, 225, 0.9)", // slate-300
  "--color-accent": "#0ea5e9",
  "--btn-border": "#cbd5e1",
  "--btn-ghost-text": "#0f172a",
  "--border-color": "#cbd5e1",
  "--space-sm": "8px",
  "--space-md": "12px",
  "--space-lg": "16px",
  "--radius-sm": "8px",
  "--radius-md": "10px",
  "--radius-lg": "12px",
  "--shadow-sm": "0 1px 2px rgba(0,0,0,0.08)",
  "--shadow-md": "0 8px 24px rgba(0,0,0,0.12)",
  "--border-width": "1px",
  "--font-size-base": "14px",
  "--line-height-base": "1.6",
  "--container-max-width": "1200px",
  "--grid-gap": "16px",
  "--grid-columns": "12",
};

const presetC: Tokens = {
  "--color-primary-start": "#f59e0b", // amber-500
  "--color-primary-end": "#ec4899",   // pink-500
  "--text-color": "#111827",         // neutral text on light bg
  "--bg-color": "#fff7ed",           // orange-50
  "--panel-bg": "#ffffff",
  "--panel-border": "rgba(244, 208, 128, 0.6)",
  "--color-accent": "#f59e0b",
  "--btn-border": "#f1f5f9",
  "--btn-ghost-text": "#111827",
  "--border-color": "#f1f5f9",
  "--space-sm": "8px",
  "--space-md": "12px",
  "--space-lg": "16px",
  "--radius-sm": "8px",
  "--radius-md": "10px",
  "--radius-lg": "12px",
  "--shadow-sm": "0 1px 2px rgba(0,0,0,0.08)",
  "--shadow-md": "0 8px 24px rgba(0,0,0,0.12)",
  "--border-width": "1px",
  "--font-size-base": "14px",
  "--line-height-base": "1.6",
  "--container-max-width": "1100px",
  "--grid-gap": "16px",
  "--grid-columns": "12",
};

const presetD: Tokens = {
  "--color-primary-start": "#3b82f6", // blue-500
  "--color-primary-end": "#a855f7",   // purple-500
  "--text-color": "#e5e7eb",         // light text
  "--bg-color": "#0f172a",           // slate-900
  "--panel-bg": "#111827",           // slate-800
  "--panel-border": "rgba(51, 65, 85, 0.9)", // slate-700
  "--color-accent": "#3b82f6",
  "--btn-border": "#334155",
  "--btn-ghost-text": "#e5e7eb",
  "--border-color": "#334155",
  "--space-sm": "8px",
  "--space-md": "12px",
  "--space-lg": "16px",
  "--radius-sm": "8px",
  "--radius-md": "10px",
  "--radius-lg": "12px",
  "--shadow-sm": "0 1px 2px rgba(0,0,0,0.25)",
  "--shadow-md": "0 8px 24px rgba(0,0,0,0.35)",
  "--border-width": "1px",
  "--font-size-base": "14px",
  "--line-height-base": "1.6",
  "--container-max-width": "1200px",
  "--grid-gap": "16px",
  "--grid-columns": "12",
};

export const PRESETS: Record<SchemeKey, Tokens> = {
  A: presetA,
  B: presetB,
  C: presetC,
  D: presetD,
};

export const SCHEME_DESC: Record<SchemeKey, string> = {
  A: "清爽蓝紫、浅背景，通用业务风格",
  B: "清新蓝绿、浅背景，更轻盈的对比与边框",
  C: "暖色系（琥珀/品红），浅背景，强调视觉情绪",
  D: "暗色系（蓝/紫），深背景，高对比度",
};

export const SCHEMES: SchemeKey[] = ["A", "B", "C", "D"];