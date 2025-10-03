import { Tokens } from "./types";

// Unified token keys used across light/dark and A/B/C/D presets
export const TOKEN_KEYS: string[] = [
  "--text-color",
  "--bg-color",
  "--color-primary-start",
  "--color-primary-end",
  "--border-color",
  "--btn-border",
  "--btn-ghost-text",
  "--space-sm",
  "--space-md",
  "--space-lg",
  "--radius-sm",
  "--radius-md",
  "--radius-lg",
  "--shadow-sm",
  "--shadow-md",
  "--border-width",
  "--font-size-base",
  "--line-height-base",
  // grid tokens
  "--container-max-width",
  "--grid-gap",
  "--grid-columns",
];

// Apply tokens to :root as CSS variables
export function applyTokens(tokens: Tokens) {
  const root = document.documentElement;
  Object.entries(tokens).forEach(([k, v]) => {
    root.style.setProperty(k, v);
  });
}

// Snapshot current CSS variables (limited to TOKEN_KEYS)
export function snapshotCurrentTokens(): Tokens {
  const styles = getComputedStyle(document.documentElement);
  const out: Tokens = {};
  TOKEN_KEYS.forEach((k) => {
    const v = styles.getPropertyValue(k).trim();
    if (v) out[k] = v;
  });
  return out;
}