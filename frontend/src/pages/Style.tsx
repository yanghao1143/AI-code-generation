import React from "react";
import { UiButton } from "../components/UiButton";
import "../components/ui-helpers.css";
import "../components/ui-input.css";
import { ComponentShowcase } from "../components/ComponentShowcase";
import { Tokens, SchemeKey } from "../styles/types";
import { PRESETS, SCHEME_DESC, SCHEMES } from "../styles/presets";
import { applyTokens } from "../styles/tokens";
import { TOKENS_SCHEMA } from "../styles/tokens.schema";

// 方案预设与描述从 ../styles/presets 引入

// 使用从 ../styles/tokens 引入的 applyTokens

function hexToRgb(hex: string) {
  const h = hex.replace("#", "");
  const bigint = parseInt(h.length === 3 ? h.split("").map((c) => c + c).join("") : h, 16);
  return { r: (bigint >> 16) & 255, g: (bigint >> 8) & 255, b: bigint & 255 };
}
function luminance(hex: string) {
  const { r, g, b } = hexToRgb(hex);
  const srgb = [r, g, b].map((v) => {
    const c = v / 255;
    return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
  });
  return 0.2126 * srgb[0] + 0.7152 * srgb[1] + 0.0722 * srgb[2];
}
function contrastRatio(fg: string, bg: string) {
  const L1 = luminance(fg);
  const L2 = luminance(bg);
  const lighter = Math.max(L1, L2);
  const darker = Math.min(L1, L2);
  return (lighter + 0.05) / (darker + 0.05);
}

// 基于 WCAG 2.1 对比度标准返回评级说明
function wcagRating(ratio: number, opts?: { largeText?: boolean }) {
  const isLarge = !!opts?.largeText;
  if (isLarge) {
    if (ratio >= 7) return "AAA（大字）";
    if (ratio >= 4.5) return "AA（大字）";
    if (ratio >= 3) return "AA（大字临界）";
    return "未通过（大字）";
  }
  if (ratio >= 7) return "AAA";
  if (ratio >= 4.5) return "AA";
  if (ratio >= 3) return "AA（大字）";
  return "未通过";
}

function downloadJson(name: string, data: object) {
  const blob = new Blob([JSON.stringify(data, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = `${name}.json`;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
}

export default function Style() {
  const [active, setActive] = React.useState<SchemeKey>("A");
  const [tokens, setTokens] = React.useState<Tokens>(PRESETS["A"]);
  const [history, setHistory] = React.useState<Tokens[]>([]);
  const [initializedFromStorage, setInitializedFromStorage] = React.useState(false);
  const [layoutPreset, setLayoutPreset] = React.useState<"card" | "form" | "list">("card");
  const [importText, setImportText] = React.useState("");
  const [importMode, setImportMode] = React.useState<"merge" | "replace">("merge");
  const [autoFollowTheme, setAutoFollowTheme] = React.useState(false);
  const [density, setDensity] = React.useState<"comfortable" | "compact">("comfortable");
  const [copyStatus, setCopyStatus] = React.useState<"idle" | "ok" | "error">("idle");
  const themeDebounceRef = React.useRef<number | null>(null);
  const [currentThemeAttr, setCurrentThemeAttr] = React.useState<string>("");

  const STORAGE_KEYS = {
    tokens: "style.tokens",
    scheme: "style.scheme",
    autoFollow: "style.autoFollow",
  } as const;

  const handleSetActive = (scheme: SchemeKey) => {
    // 用户主动切换方案，后续应以预设为基准
    setInitializedFromStorage(false);
    setActive(scheme);
  };

  React.useEffect(() => {
    if (initializedFromStorage) return; // 存储初始化时不覆盖
    const init = PRESETS[active];
    setTokens(init);
    applyTokens(init);
  }, [active, initializedFromStorage]);

  // 初始化：从 localStorage 恢复
  React.useEffect(() => {
    try {
      const savedScheme = localStorage.getItem(STORAGE_KEYS.scheme);
      const savedTokens = localStorage.getItem(STORAGE_KEYS.tokens);
      const savedAutoFollow = localStorage.getItem(STORAGE_KEYS.autoFollow);
      if (savedAutoFollow === "1" || savedAutoFollow === "0") {
        setAutoFollowTheme(savedAutoFollow === "1");
      }
      if (savedScheme && SCHEMES.includes(savedScheme as SchemeKey)) {
        setActive(savedScheme as SchemeKey);
      }
      if (savedTokens) {
        const parsed: Tokens = JSON.parse(savedTokens);
        setTokens(parsed);
        applyTokens(parsed);
        setInitializedFromStorage(true);
      }
    } catch (e) {
      // ignore parsing/storage errors
    }
  }, []);

  // 初始化当前 data-theme 展示（用于验收观察）
  React.useEffect(() => {
    try {
      const t = document.documentElement.getAttribute("data-theme") || "";
      setCurrentThemeAttr(t);
    } catch {}
  }, []);

  // 持久化：方案与令牌
  React.useEffect(() => {
    try {
      localStorage.setItem(STORAGE_KEYS.scheme, active);
      localStorage.setItem(STORAGE_KEYS.tokens, JSON.stringify(tokens));
    } catch (e) {
      // ignore storage errors
    }
  }, [tokens, active]);

  // 持久化：自动追随主题开关
  React.useEffect(() => {
    try {
      localStorage.setItem(STORAGE_KEYS.autoFollow, autoFollowTheme ? "1" : "0");
    } catch (e) {
      // ignore storage errors
    }
  }, [autoFollowTheme]);

  const setToken = (key: string, value: string) => {
    setTokens((prev) => {
      const next = { ...prev, [key]: value };
      applyTokens(next);
      return next;
    });
  };

  const saveSnapshot = () => {
    setHistory((h) => [...h, { ...tokens }]);
  };
  const rollback = () => {
    setHistory((h) => {
      if (h.length === 0) return h;
      const prev = h[h.length - 1];
      applyTokens(prev);
      setTokens(prev);
      return h.slice(0, -1);
    });
  };
  const resetToPreset = () => {
    const base = PRESETS[active];
    setTokens(base);
    applyTokens(base);
  };

  const textColor = tokens["--text-color"] || PRESETS[active]["--text-color"];
  const bgColor = tokens["--bg-color"] || PRESETS[active]["--bg-color"];
  const ratio = contrastRatio(textColor, bgColor);
  const a11y = ratio >= 4.5 ? "AA 通过" : ratio >= 3 ? "AA 大字通过/建议调整" : "未通过，建议提升对比度";

  const exportReport = () => {
    const report = {
      scheme: active,
      tokens,
      a11y: { ratio: Number(ratio.toFixed(2)), status: a11y },
      timestamp: new Date().toISOString(),
    };
    downloadJson(`style-report-${active}`, report);
  };

  const buildCssVariables = (obj: Tokens) => {
    const lines = Object.entries(obj)
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([k, v]) => `  ${k}: ${v};`)
      .join("\n");
    return `:root {\n${lines}\n}`;
  };

  // SASS/LESS 变量构建
  const buildScssVariables = (obj: Tokens) => {
    const lines = Object.entries(obj)
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([k, v]) => `$${k.replace(/^--/, "")}: ${v};`)
      .join("\n");
    return lines;
  };

  const buildLessVariables = (obj: Tokens) => {
    const lines = Object.entries(obj)
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([k, v]) => `@${k.replace(/^--/, "")}: ${v};`)
      .join("\n");
    return lines;
  };

  const exportCss = () => {
    const css = buildCssVariables(tokens);
    const blob = new Blob([css], { type: "text/css" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `style-css-${active}.css`;
    document.body.appendChild(a);
    a.click();
    a.remove();
    URL.revokeObjectURL(url);
  };

  const exportScss = () => {
    const scss = buildScssVariables(tokens);
    const blob = new Blob([scss], { type: "text/x-scss" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `style-vars-${active}.scss`;
    document.body.appendChild(a);
    a.click();
    a.remove();
    URL.revokeObjectURL(url);
  };

  const exportLess = () => {
    const less = buildLessVariables(tokens);
    const blob = new Blob([less], { type: "text/x-less" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `style-vars-${active}.less`;
    document.body.appendChild(a);
    a.click();
    a.remove();
    URL.revokeObjectURL(url);
  };

  const copyCss = async () => {
    const css = buildCssVariables(tokens);
    try {
      if (navigator.clipboard && navigator.clipboard.writeText) {
        await navigator.clipboard.writeText(css);
      } else {
        const ta = document.createElement("textarea");
        ta.value = css;
        document.body.appendChild(ta);
        ta.select();
        document.execCommand("copy");
        ta.remove();
      }
      setCopyStatus("ok");
    } catch {
      setCopyStatus("error");
    } finally {
      setTimeout(() => setCopyStatus("idle"), 2000);
    }
  };

  const copyScss = async () => {
    const scss = buildScssVariables(tokens);
    try {
      if (navigator.clipboard && navigator.clipboard.writeText) {
        await navigator.clipboard.writeText(scss);
      } else {
        const ta = document.createElement("textarea");
        ta.value = scss;
        document.body.appendChild(ta);
        ta.select();
        document.execCommand("copy");
        ta.remove();
      }
      setCopyStatus("ok");
    } catch {
      setCopyStatus("error");
    } finally {
      setTimeout(() => setCopyStatus("idle"), 2000);
    }
  };

  const copyLess = async () => {
    const less = buildLessVariables(tokens);
    try {
      if (navigator.clipboard && navigator.clipboard.writeText) {
        await navigator.clipboard.writeText(less);
      } else {
        const ta = document.createElement("textarea");
        ta.value = less;
        document.body.appendChild(ta);
        ta.select();
        document.execCommand("copy");
        ta.remove();
      }
      setCopyStatus("ok");
    } catch {
      setCopyStatus("error");
    } finally {
      setTimeout(() => setCopyStatus("idle"), 2000);
    }
  };

  const syncFromCurrentTheme = () => {
    const rootStyles = getComputedStyle(document.documentElement);
    const keys = [
      "--text-color","--bg-color","--color-primary-start","--color-primary-end","--border-color","--btn-border","--btn-ghost-text",
      "--space-sm","--space-md","--space-lg","--radius-sm","--radius-md","--radius-lg",
      "--shadow-sm","--shadow-md","--border-width","--font-size-base","--line-height-base"
    ];
    const next: Tokens = { ...tokens };
    keys.forEach((k) => {
      const v = rootStyles.getPropertyValue(k).trim();
      if (v) next[k] = v;
    });
    setTokens(next);
    applyTokens(next);
    saveSnapshot();
  };

  // 验收辅助：手动设置/取消 data-theme
  const setDataTheme = (val: string | null) => {
    const target = document.documentElement;
    if (val) target.setAttribute("data-theme", val);
    else target.removeAttribute("data-theme");
  };

  React.useEffect(() => {
    if (!autoFollowTheme) return;
    const target = document.documentElement;
    const obs = new MutationObserver((mutations) => {
      for (const m of mutations) {
        if (m.type === "attributes" && m.attributeName === "data-theme") {
          if (themeDebounceRef.current) window.clearTimeout(themeDebounceRef.current);
          themeDebounceRef.current = window.setTimeout(() => {
            const theme = target.getAttribute("data-theme") || "";
            setCurrentThemeAttr(theme);
            const mapped = inferSchemeFromTheme(theme);
            setActive(mapped);
            syncFromCurrentTheme();
          }, 200);
        }
      }
    });
    obs.observe(target, { attributes: true });
    return () => obs.disconnect();
  }, [autoFollowTheme]);

  const inferSchemeFromTheme = (theme: string): SchemeKey => {
    const t = theme.toLowerCase();
    if (t.includes("dark")) return "D";
    if (t.includes("light")) return "A";
    return active; // 未知主题时保持当前方案
  };

  const applyImported = (incoming: Tokens, mode: "merge" | "replace") => {
    const next = mode === "replace" ? incoming : { ...tokens, ...incoming };
    setTokens(next);
    applyTokens(next);
    saveSnapshot();
  };

  const handleImportFile: React.ChangeEventHandler<HTMLInputElement> = async (e) => {
    try {
      const file = e.target.files?.[0];
      if (!file) return;
      const text = await file.text();
      const parsed = JSON.parse(text);
      applyImported(parsed, importMode);
    } catch (err) {
      // ignore parse errors
    } finally {
      e.target.value = ""; // reset file input
    }
  };

  const handleApplyImportText = () => {
    try {
      const parsed = JSON.parse(importText);
      applyImported(parsed, importMode);
      setImportText("");
    } catch (err) {
      // ignore parse errors
    }
  };

  const pxNum = (v: string | undefined, fallback: number) => {
    if (!v) return fallback;
    const n = parseFloat(String(v).replace("px", ""));
    return Number.isFinite(n) ? n : fallback;
  };

  const numVal = (v: string | undefined, fallback: number) => {
    if (!v) return fallback;
    const n = parseFloat(String(v));
    return Number.isFinite(n) ? n : fallback;
  };

  // 为避免 JSX 属性中复杂转义导致的解析问题，这里单独定义导入占位文本
  const importPlaceholder = '粘贴令牌 JSON，例如：{ "--text-color": "#111827", "--bg-color": "#ffffff" }';

  const getTokenValue = (key: string) => {
    return tokens[key] || PRESETS[active][key] || "";
  };

  const PreviewItem: React.FC<{ item: { key: string; label: string; type: string } }> = ({ item }) => {
    const val = getTokenValue(item.key);
    const commonBox = {
      display: "inline-flex",
      alignItems: "center",
      justifyContent: "center",
      border: "1px solid var(--border-color)",
      padding: "var(--space-sm)",
      marginRight: "var(--space-md)",
      marginBottom: "var(--space-md)",
      minWidth: 120,
    } as React.CSSProperties;

    const copyTokenValue = async () => {
      try {
        const text = `${item.key}: ${val}`;
        if (navigator.clipboard && navigator.clipboard.writeText) {
          await navigator.clipboard.writeText(text);
        } else {
          const ta = document.createElement("textarea");
          ta.value = text;
          document.body.appendChild(ta);
          ta.select();
          document.execCommand("copy");
          ta.remove();
        }
        setCopyStatus("ok");
      } catch {
        setCopyStatus("error");
      } finally {
        setTimeout(() => setCopyStatus("idle"), 2000);
      }
    };

    const onKeyDown: React.KeyboardEventHandler<HTMLDivElement> = (e) => {
      if (e.key === "Enter" || e.key === " ") {
        e.preventDefault();
        copyTokenValue();
      }
    };

    if (item.type === "color") {
      // 针对不同颜色令牌计算与 bg/text 的对比度
      let fg = val;
      let bg = bgColor;
      let desc = "前景到背景";
      if (item.key === "--bg-color") {
        fg = textColor;
        bg = val;
        desc = "文本到背景";
      } else if (item.key === "--text-color" || item.key === "--btn-ghost-text") {
        fg = val;
        bg = bgColor;
        desc = "文本到背景";
      }
      const r = contrastRatio(fg, bg);
      const rating = wcagRating(r);
      const statusId = `token-status-${item.key.replace(/[^a-z0-9-]/gi, "_")}`;
      return (
        <div
          style={commonBox}
          role="listitem"
          tabIndex={0}
          aria-label={`${item.label}（${item.key}，值 ${val}）。${desc}对比度 ${r.toFixed(2)}，评级 ${rating}。按 Enter/Space 复制变量值。`}
          aria-describedby={statusId}
          onKeyDown={onKeyDown}
        >
          <div style={{ width: 48, height: 28, background: val, borderRadius: "var(--radius-sm)", marginRight: "var(--space-sm)" }} />
          <div>
            <div style={{ fontWeight: 600 }}>{item.label}</div>
            <div className="ui-status">{item.key}</div>
            <div className="ui-status">{val}</div>
            <div id={statusId} className="ui-status">{desc}对比度：{r.toFixed(2)}（{rating}）</div>
          </div>
        </div>
      );
    }

    if (item.type === "size") {
      const isFont = item.key === "--font-size-base";
      const isLineHeight = item.key === "--line-height-base";
      const descId = `token-desc-${item.key.replace(/[^a-z0-9-]/gi, "_")}`;
      return (
        <div
          className="ui-token-item"
          style={commonBox}
          role="listitem"
          tabIndex={0}
          aria-keyshortcuts="Enter Space"
          aria-label={`${item.label}（${item.key}，值 ${val}）。按 Enter/Space 复制变量值。`}
          aria-describedby={descId}
          onKeyDown={onKeyDown}
        >
          <div style={{ fontSize: isFont ? `var(--font-size-base)` : undefined, lineHeight: isLineHeight ? `var(--line-height-base)` : undefined }}>
            Aa 字样示例
          </div>
          <div style={{ marginLeft: "var(--space-md)" }}>
            <div style={{ fontWeight: 600 }}>{item.label}</div>
            <div className="ui-status">{item.key}</div>
            <div className="ui-status">{val}</div>
            <div id={descId} className="ui-status ui-status--small">按 Enter/Space 复制变量值</div>
          </div>
        </div>
      );
    }

    if (item.type === "space") {
      const descId = `token-desc-${item.key.replace(/[^a-z0-9-]/gi, "_")}`;
      return (
        <div
          className="ui-token-item"
          style={commonBox}
          role="listitem"
          tabIndex={0}
          aria-keyshortcuts="Enter Space"
          aria-label={`${item.label}（${item.key}，值 ${val}）。按 Enter/Space 复制变量值。`}
          aria-describedby={descId}
          onKeyDown={onKeyDown}
        >
          <div style={{ width: 80, height: `var(${item.key})`, background: "var(--color-primary-start)", borderRadius: "var(--radius-sm)" }} />
          <div style={{ marginLeft: "var(--space-md)" }}>
            <div style={{ fontWeight: 600 }}>{item.label}</div>
            <div className="ui-status">{item.key}</div>
            <div className="ui-status">{val}</div>
            <div id={descId} className="ui-status ui-status--small">按 Enter/Space 复制变量值</div>
          </div>
        </div>
      );
    }

    if (item.type === "radius") {
      const descId = `token-desc-${item.key.replace(/[^a-z0-9-]/gi, "_")}`;
      return (
        <div
          className="ui-token-item"
          style={commonBox}
          role="listitem"
          tabIndex={0}
          aria-keyshortcuts="Enter Space"
          aria-label={`${item.label}（${item.key}，值 ${val}）。按 Enter/Space 复制变量值。`}
          aria-describedby={descId}
          onKeyDown={onKeyDown}
        >
          <div style={{ width: 56, height: 36, background: "var(--bg-color)", border: "1px solid var(--border-color)", borderRadius: `var(${item.key})` }} />
          <div style={{ marginLeft: "var(--space-md)" }}>
            <div style={{ fontWeight: 600 }}>{item.label}</div>
            <div className="ui-status">{item.key}</div>
            <div className="ui-status">{val}</div>
            <div id={descId} className="ui-status ui-status--small">按 Enter/Space 复制变量值</div>
          </div>
        </div>
      );
    }

    if (item.type === "shadow") {
      const descId = `token-desc-${item.key.replace(/[^a-z0-9-]/gi, "_")}`;
      return (
        <div
          className="ui-token-item"
          style={commonBox}
          role="listitem"
          tabIndex={0}
          aria-keyshortcuts="Enter Space"
          aria-label={`${item.label}（${item.key}，值 ${val}）。按 Enter/Space 复制变量值。`}
          aria-describedby={descId}
          onKeyDown={onKeyDown}
        >
          <div style={{ width: 120, height: 60, background: "var(--bg-color)", boxShadow: `var(${item.key})`, borderRadius: "var(--radius-sm)" }} />
          <div style={{ marginLeft: "var(--space-md)" }}>
            <div style={{ fontWeight: 600 }}>{item.label}</div>
            <div className="ui-status">{item.key}</div>
            <div className="ui-status">{val}</div>
            <div id={descId} className="ui-status ui-status--small">按 Enter/Space 复制变量值</div>
          </div>
        </div>
      );
    }

    if (item.type === "border") {
      const descId = `token-desc-${item.key.replace(/[^a-z0-9-]/gi, "_")}`;
      return (
        <div
          className="ui-token-item"
          style={{ ...commonBox, flexDirection: "column", alignItems: "stretch" }}
          role="listitem"
          tabIndex={0}
          aria-keyshortcuts="Enter Space"
          aria-label={`${item.label}（${item.key}，值 ${val}）。按 Enter/Space 复制变量值。`}
          aria-describedby={descId}
          onKeyDown={onKeyDown}
        >
          <div style={{ height: 0, borderTop: `var(${item.key}) solid var(--border-color)` }} />
          <div style={{ marginTop: "var(--space-sm)" }}>
            <div style={{ fontWeight: 600 }}>{item.label}</div>
            <div className="ui-status">{item.key}</div>
            <div className="ui-status">{val}</div>
            <div id={descId} className="ui-status ui-status--small">按 Enter/Space 复制变量值</div>
          </div>
        </div>
      );
    }

    if (item.type === "grid") {
      // 针对不同 grid 令牌展示不同示例
      if (item.key === "--container-max-width") {
        const descId = `token-desc-${item.key.replace(/[^a-z0-9-]/gi, "_")}`;
        return (
          <div
            className="ui-token-item"
            style={{ ...commonBox, flexDirection: "column", alignItems: "stretch", width: 360 }}
            role="listitem"
            tabIndex={0}
            aria-keyshortcuts="Enter Space"
            aria-label={`${item.label}（${item.key}，值 ${val}）。按 Enter/Space 复制变量值。`}
            aria-describedby={descId}
            onKeyDown={onKeyDown}
          >
            <div
              style={{
                height: 20,
                background: "linear-gradient(to right, var(--color-primary-start), var(--color-primary-end))",
                borderRadius: "var(--radius-sm)",
                maxWidth: val || "1200px",
              }}
              title={`max-width: ${val}`}
            />
            <div style={{ marginTop: "var(--space-sm)" }}>
              <div style={{ fontWeight: 600 }}>{item.label}</div>
              <div className="ui-status">{item.key}</div>
              <div className="ui-status">{val}</div>
              <div id={descId} className="ui-status ui-status--small">按 Enter/Space 复制变量值</div>
            </div>
          </div>
        );
      }

      if (item.key === "--grid-gap") {
        const gap = val || "16px";
        const descId = `token-desc-${item.key.replace(/[^a-z0-9-]/gi, "_")}`;
        return (
          <div
            className="ui-token-item"
            style={{ ...commonBox, flexDirection: "column", alignItems: "stretch" }}
            role="listitem"
            tabIndex={0}
            aria-keyshortcuts="Enter Space"
            aria-label={`${item.label}（${item.key}，值 ${gap}）。按 Enter/Space 复制变量值。`}
            aria-describedby={descId}
            onKeyDown={onKeyDown}
          >
            <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap }}>
              {new Array(8).fill(0).map((_, i) => (
                <div key={i} style={{ height: 18, background: "var(--panel-border)", borderRadius: "var(--radius-sm)" }} />
              ))}
            </div>
            <div style={{ marginTop: "var(--space-sm)" }}>
              <div style={{ fontWeight: 600 }}>{item.label}</div>
              <div className="ui-status">{item.key}</div>
              <div className="ui-status">{gap}</div>
              <div id={descId} className="ui-status ui-status--small">按 Enter/Space 复制变量值</div>
            </div>
          </div>
        );
      }

      if (item.key === "--grid-columns") {
        const colsRaw = val || "12";
        const cols = Math.max(1, Math.min(6, parseInt(colsRaw, 10) || 12));
        const descId = `token-desc-${item.key.replace(/[^a-z0-9-]/gi, "_")}`;
        return (
          <div
            className="ui-token-item"
            style={{ ...commonBox, flexDirection: "column", alignItems: "stretch", width: 360 }}
            role="listitem"
            tabIndex={0}
            aria-keyshortcuts="Enter Space"
            aria-label={`${item.label}（${item.key}，值 ${colsRaw}）。按 Enter/Space 复制变量值。`}
            aria-describedby={descId}
            onKeyDown={onKeyDown}
          >
            <div style={{ display: "grid", gridTemplateColumns: `repeat(${cols}, 1fr)`, gap: "var(--space-sm)" }}>
              {new Array(cols).fill(0).map((_, i) => (
                <div key={i} style={{ height: 18, background: "var(--color-primary-start)", borderRadius: "var(--radius-sm)" }} />
              ))}
            </div>
            <div style={{ marginTop: "var(--space-sm)" }}>
              <div style={{ fontWeight: 600 }}>{item.label}</div>
              <div className="ui-status">{item.key}</div>
              <div className="ui-status">{colsRaw}</div>
              <div id={descId} className="ui-status ui-status--small">按 Enter/Space 复制变量值</div>
            </div>
          </div>
        );
      }

      const descId = `token-desc-${item.key.replace(/[^a-z0-9-]/gi, "_")}`;
      return (
        <div
          className="ui-token-item"
          style={commonBox}
          role="listitem"
          tabIndex={0}
          aria-keyshortcuts="Enter Space"
          aria-label={`${item.label}（${item.key}，值 ${val}）。按 Enter/Space 复制变量值。`}
          aria-describedby={descId}
          onKeyDown={onKeyDown}
        >
          <div>
            <div style={{ fontWeight: 600 }}>{item.label}</div>
            <div className="ui-status">{item.key}</div>
            <div className="ui-status">{val}</div>
            <div id={descId} className="ui-status ui-status--small">按 Enter/Space 复制变量值</div>
          </div>
        </div>
      );
    }

    return null;
  };

  return (
    <div className={density === "compact" ? "ui-density--compact" : undefined}>
      <div className="ui-panel">
      <h2 className="ui-title" id="style-page-title">Style 设计令牌（方案切换、预览、调整）</h2>
      <div className="ui-row ui-row--gap-md ui-mb-md">
        {SCHEMES.map((k) => (
          <UiButton key={k} variant={active === k ? "primary" : "ghost"} onClick={() => handleSetActive(k)}>
            方案 {k}
          </UiButton>
        ))}
        <UiButton variant="ghost" onClick={() => downloadJson(`style-tokens-${active}`, tokens)}>导出 JSON</UiButton>
        <UiButton variant="ghost" onClick={exportReport}>导出报告</UiButton>
        <UiButton variant="ghost" onClick={() => { try { localStorage.removeItem(STORAGE_KEYS.scheme); localStorage.removeItem(STORAGE_KEYS.tokens);} catch(e){}; setInitializedFromStorage(false); resetToPreset(); }}>清空持久化</UiButton>
        <UiButton variant="ghost" onClick={syncFromCurrentTheme}>从当前主题同步</UiButton>
        <label className="ui-inline-gap">
          <input type="checkbox" checked={autoFollowTheme} onChange={(e) => setAutoFollowTheme(e.target.checked)} /> 自动追随主题
        </label>
        <UiButton variant="ghost" onClick={() => setAutoFollowTheme(true)}>跟随系统</UiButton>
        <UiButton variant="ghost" onClick={() => { setAutoFollowTheme(false); handleSetActive("A"); resetToPreset(); }}>恢复默认</UiButton>
        <UiButton variant="ghost" onClick={exportCss}>导出 CSS</UiButton>
        <UiButton variant="ghost" onClick={copyCss}>复制 CSS</UiButton>
        <UiButton variant="ghost" onClick={exportScss}>导出 SASS</UiButton>
        <UiButton variant="ghost" onClick={copyScss}>复制 SASS</UiButton>
        <UiButton variant="ghost" onClick={exportLess}>导出 LESS</UiButton>
        <UiButton variant="ghost" onClick={copyLess}>复制 LESS</UiButton>
        <span className="ui-status ui-inline-gap-right" role="status" aria-live="polite">{copyStatus === "ok" ? "已复制" : copyStatus === "error" ? "复制失败" : ""}</span>
      </div>
      <div className="ui-row ui-row--gap-md ui-mb-md">
        <span className="ui-status">当前方案：{active}（{SCHEME_DESC[active]}）</span>
        <span className="ui-status">对比度：{ratio.toFixed(2)}（{a11y}）</span>
      </div>

      <div className="ui-row ui-row--gap-md ui-mb-md">
        <h3 className="ui-title" style={{ marginRight: 'var(--space-md)' }}>界面密度</h3>
        <UiButton variant={density === 'comfortable' ? 'primary' : 'ghost'} onClick={() => setDensity('comfortable')}>舒适</UiButton>
        <UiButton variant={density === 'compact' ? 'primary' : 'ghost'} onClick={() => setDensity('compact')}>紧凑</UiButton>
      </div>

      <div className="ui-row ui-row--gap-md ui-mb-md">
        <h3 className="ui-title" style={{ marginRight: 'var(--space-md)' }}>布局预设</h3>
        <UiButton variant={layoutPreset === 'card' ? 'primary' : 'ghost'} onClick={() => setLayoutPreset('card')}>卡片</UiButton>
        <UiButton variant={layoutPreset === 'form' ? 'primary' : 'ghost'} onClick={() => setLayoutPreset('form')}>表单</UiButton>
        <UiButton variant={layoutPreset === 'list' ? 'primary' : 'ghost'} onClick={() => setLayoutPreset('list')}>列表</UiButton>
      </div>

      <div className="ui-row ui-row--gap-md ui-mb-md">
        <h3 className="ui-title" style={{ marginRight: 'var(--space-md)' }}>系统主题模拟</h3>
        <UiButton variant="ghost" onClick={() => { setDataTheme('light'); setCurrentThemeAttr('light'); }}>Light</UiButton>
        <UiButton variant="ghost" onClick={() => { setDataTheme('dark'); setCurrentThemeAttr('dark'); }}>Dark</UiButton>
        <UiButton variant="ghost" onClick={() => { setDataTheme(null); setCurrentThemeAttr(''); }}>Unset</UiButton>
        <span className="ui-status">当前 data-theme：{currentThemeAttr || '（未设置）'}</span>
      </div>

      <div className="ui-row ui-row--gap-md ui-mb-md">
        <div className="ui-panel" style={{ width: 380 }}>
          <h3 className="ui-title">可视化调整工具</h3>
          <div className="ui-row ui-row--gap-md ui-mb-md">
            <label>
              Text Color
              <input type="color" className="ui-input ui-inline-gap" value={tokens["--text-color"] || "#111827"} onChange={(e) => setToken("--text-color", e.target.value)} />
            </label>
            <label>
              Background
              <input type="color" className="ui-input ui-inline-gap" value={tokens["--bg-color"] || "#ffffff"} onChange={(e) => setToken("--bg-color", e.target.value)} />
            </label>
          </div>
          <div className="ui-row ui-row--gap-md ui-mb-md">
            <label>
              Primary Start
              <input type="color" className="ui-input ui-inline-gap" value={tokens["--color-primary-start"] || "#2563eb"} onChange={(e) => setToken("--color-primary-start", e.target.value)} />
            </label>
            <label>
              Primary End
              <input type="color" className="ui-input ui-inline-gap" value={tokens["--color-primary-end"] || "#7c3aed"} onChange={(e) => setToken("--color-primary-end", e.target.value)} />
            </label>
          </div>
          <div className="ui-row ui-row--gap-md ui-mb-md">
            <label>
              Space SM
              <input type="number" className="ui-input ui-inline-gap ui-input--w-sm" min={0} max={48} value={pxNum(tokens["--space-sm"], 8)} onChange={(e) => setToken("--space-sm", `${e.target.value}px`)} />
            </label>
            <label>
              Space MD
              <input type="number" className="ui-input ui-inline-gap ui-input--w-sm" min={0} max={64} value={pxNum(tokens["--space-md"], 12)} onChange={(e) => setToken("--space-md", `${e.target.value}px`)} />
            </label>
            <label>
              Space LG
              <input type="number" className="ui-input ui-inline-gap ui-input--w-sm" min={0} max={80} value={pxNum(tokens["--space-lg"], 16)} onChange={(e) => setToken("--space-lg", `${e.target.value}px`)} />
            </label>
          </div>
          <div className="ui-row ui-row--gap-md ui-mb-md">
            <label>
              Radius SM
              <input type="number" className="ui-input ui-inline-gap ui-input--w-sm" min={0} max={24} value={pxNum(tokens["--radius-sm"], 8)} onChange={(e) => setToken("--radius-sm", `${e.target.value}px`)} />
            </label>
            <label>
              Radius MD
              <input type="number" className="ui-input ui-inline-gap ui-input--w-sm" min={0} max={32} value={pxNum(tokens["--radius-md"], 10)} onChange={(e) => setToken("--radius-md", `${e.target.value}px`)} />
            </label>
            <label>
              Radius LG
              <input type="number" className="ui-input ui-inline-gap ui-input--w-sm" min={0} max={40} value={pxNum(tokens["--radius-lg"], 12)} onChange={(e) => setToken("--radius-lg", `${e.target.value}px`)} />
            </label>
          </div>
          <div className="ui-row ui-row--gap-md ui-mb-md">
            <label>
              Border Width
              <input type="number" className="ui-input ui-inline-gap ui-input--w-sm" min={0} max={8} value={pxNum(tokens["--border-width"], 1)} onChange={(e) => setToken("--border-width", `${e.target.value}px`)} />
            </label>
            <label>
              Font Size (base)
              <input type="number" className="ui-input ui-inline-gap ui-input--w-sm" min={10} max={20} value={pxNum(tokens["--font-size-base"], 14)} onChange={(e) => setToken("--font-size-base", `${e.target.value}px`)} />
            </label>
            <label>
              Line Height
              <input type="number" step={0.1} className="ui-input ui-inline-gap ui-input--w-sm" min={1} max={2.4} value={numVal(tokens["--line-height-base"], 1.6)} onChange={(e) => setToken("--line-height-base", `${e.target.value}`)} />
            </label>
          </div>
          <div className="ui-row ui-row--gap-md ui-mb-md">
            <label className="ui-flex-1">
              Shadow (sm)
              <input type="text" className="ui-input ui-inline-gap" value={tokens["--shadow-sm"] || "0 1px 2px rgba(0,0,0,0.08)"} onChange={(e) => setToken("--shadow-sm", e.target.value)} />
            </label>
            <label className="ui-flex-1">
              Shadow (md)
              <input type="text" className="ui-input ui-inline-gap" value={tokens["--shadow-md"] || "0 8px 24px rgba(0,0,0,0.12)"} onChange={(e) => setToken("--shadow-md", e.target.value)} />
            </label>
          </div>
          <div className="ui-actions">
            <UiButton variant="ghost" onClick={saveSnapshot}>保存快照</UiButton>
            <UiButton variant="ghost" onClick={rollback} disabled={history.length === 0}>回滚上一个</UiButton>
            <UiButton variant="ghost" onClick={resetToPreset}>重置为当前方案</UiButton>
          </div>
          <hr style={{ borderColor: 'var(--border-color)', margin: 'var(--space-md) 0' }} />
          <h3 className="ui-title">导入令牌</h3>
          <div className="ui-row ui-row--gap-md ui-mb-md">
            <label>
              从文件导入（JSON）
              <input type="file" accept="application/json" className="ui-input ui-inline-gap" onChange={handleImportFile} />
            </label>
          </div>
          <div className="ui-mb-md">
            <textarea
              className="ui-input"
              rows={4}
              placeholder={importPlaceholder}
              value={importText}
              onChange={(e) => setImportText(e.target.value)}
            />
          </div>
          <div className="ui-row ui-row--gap-md ui-mb-md">
            <label>
              <input
                type="radio"
                name="import-mode"
                checked={importMode === 'merge'}
                onChange={() => setImportMode('merge')}
              /> 合并
            </label>
            <label>
              <input
                type="radio"
                name="import-mode"
                checked={importMode === 'replace'}
                onChange={() => setImportMode('replace')}
              /> 覆盖
            </label>
            <UiButton variant="ghost" onClick={handleApplyImportText}>应用粘贴</UiButton>
          </div>
        </div>
        <div className="ui-panel" style={{ flex: 1, minWidth: 360, boxShadow: 'var(--shadow-md)', borderWidth: 'var(--border-width)', fontSize: 'var(--font-size-base)', lineHeight: 'var(--line-height-base)' }}>
          {layoutPreset === 'card' && (
            <div>
              <h3 className="ui-title">示例卡片</h3>
              <p className="ui-status">这是预览文本，用于观察颜色与层次。</p>
              <div className="ui-actions">
                <UiButton>主按钮</UiButton>
                <UiButton variant="ghost">次按钮</UiButton>
              </div>
              <div className="ui-mt-md">
                <a href="#" className="ui-link">示例链接</a>
              </div>
            </div>
          )}

          {layoutPreset === 'form' && (
            <div>
              <h3 className="ui-title">示例表单</h3>
              <div className="ui-mb-md">
                <label>用户名</label>
                <input className="ui-input" placeholder="输入用户名" />
              </div>
              <div className="ui-mb-md">
                <label>邮箱</label>
                <input className="ui-input" type="email" placeholder="name@example.com" />
              </div>
              <div className="ui-mb-md">
                <label>密码</label>
                <input className="ui-input" type="password" placeholder="至少 8 位" />
              </div>
              <div className="ui-actions">
                <UiButton>提交</UiButton>
                <UiButton variant="ghost">取消</UiButton>
              </div>
            </div>
          )}

          {layoutPreset === 'list' && (
            <div>
              <h3 className="ui-title">示例列表</h3>
              {["第一项：系统消息摘要","第二项：任务进度更新","第三项：通知与活动"].map((text, i) => (
                <div key={i} style={{
                  padding: 'var(--space-md)',
                  borderBottom: '1px solid var(--border-color)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between'
                }}>
                  <span>{text}</span>
                  <div className="ui-actions">
                    <UiButton variant="ghost">查看</UiButton>
                    <UiButton variant="ghost">更多</UiButton>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
      <div className="ui-panel" role="region" aria-labelledby="tokens-schema-title">
        <h3 className="ui-title" id="tokens-schema-title">令牌 Schema 预览</h3>
        {TOKENS_SCHEMA.map((group) => {
          const gid = `group-${group.name.replace(/\s+/g, "-")}`;
          const did = `${gid}-desc`;
          return (
            <section key={group.name} className="ui-mb-md" role="group" aria-labelledby={gid} aria-describedby={group.description ? did : undefined}>
              <h4 className="ui-title" id={gid}>{group.name}</h4>
              {group.description ? <p id={did} className="ui-status">{group.description}</p> : null}
              <div style={{ display: "flex", flexWrap: "wrap" }} role="list" aria-label={`${group.name} 列表`}>
                {group.items.map((it) => (
                  <PreviewItem key={it.key} item={it} />
                ))}
              </div>
            </section>
          );
        })}
      </div>
      </div>
      <ComponentShowcase />
    </div>
  );
}