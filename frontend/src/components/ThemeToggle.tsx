import React from "react";
import { UiButton } from "./UiButton";

type Theme = "light" | "dark";

function getInitialTheme(): Theme {
  try {
    const stored = localStorage.getItem("appTheme");
    if (stored === "dark" || stored === "light") return stored as Theme;
    const prefersDark = window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches;
    return prefersDark ? "dark" : "light";
  } catch {
    return "light";
  }
}

export function ThemeToggle() {
  const [theme, setTheme] = React.useState<Theme>(() => (document.documentElement.getAttribute("data-theme") as Theme) || getInitialTheme());

  React.useEffect(() => {
    document.documentElement.setAttribute("data-theme", theme);
    try {
      localStorage.setItem("appTheme", theme);
    } catch {}
  }, [theme]);

  const toggle = () => setTheme((t) => (t === "dark" ? "light" : "dark"));

  return (
    <UiButton type="button" variant="ghost" aria-label="切换主题" onClick={toggle} title={theme === "dark" ? "切换为亮色" : "切换为暗色"}>
      {theme === "dark" ? "🌙 暗" : "☀️ 亮"}
    </UiButton>
  );
}