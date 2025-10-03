import React from "react";
import { UiButton } from "./UiButton";
import { PRESETS, SCHEMES, SCHEME_DESC } from "../styles/presets";
import { applyTokens } from "../styles/tokens";
import type { SchemeKey } from "../styles/types";

const STORAGE_KEY = "appScheme";

function getInitialScheme(): SchemeKey {
  try {
    const stored = localStorage.getItem(STORAGE_KEY) as SchemeKey | null;
    if (stored && (SCHEMES as string[]).includes(stored)) return stored as SchemeKey;
  } catch {}
  return "A";
}

export function SchemeToggle() {
  const [scheme, setScheme] = React.useState<SchemeKey>(() => getInitialScheme());

  React.useEffect(() => {
    // 应用选定方案的 tokens 到 :root
    applyTokens(PRESETS[scheme]);
    try {
      localStorage.setItem(STORAGE_KEY, scheme);
    } catch {}
  }, [scheme]);

  const handleSet = (key: SchemeKey) => setScheme(key);

  return (
    <div className="ui-row ui-row--gap-sm" aria-label="切换风格方案" title={`当前方案：${scheme}（${SCHEME_DESC[scheme]}）`}>
      {SCHEMES.map((key) => (
        <UiButton
          key={key}
          type="button"
          variant={scheme === key ? "primary" : "ghost"}
          onClick={() => handleSet(key)}
          aria-pressed={scheme === key}
        >
          {key}
        </UiButton>
      ))}
    </div>
  );
}