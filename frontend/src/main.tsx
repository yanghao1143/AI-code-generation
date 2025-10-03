import React from "react";
import { createRoot } from "react-dom/client";
import App from "./App";
import "./components/ui-tokens.css";
import "./index.css";
import "./components/ui-button.css";
import "./components/ui-input.css";
import "./components/ui-base.css";
import "./components/ui-link.css";
import "./components/ui-helpers.css";
import "./components/ui-typography.css";
import "./components/ui-panel.selected.css";
import { applyTokens } from "./styles/tokens";
import { PRESETS } from "./styles/presets";

// 在应用启动前应用已保存的主题与风格方案，确保页面初渲染即为用户偏好
(() => {
  try {
    const theme = localStorage.getItem("appTheme");
    if (theme === "dark" || theme === "light") {
      document.documentElement.setAttribute("data-theme", theme);
    } else {
      // 未存储时根据系统偏好设置初始主题
      const prefersDark = window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches;
      document.documentElement.setAttribute("data-theme", prefersDark ? "dark" : "light");
    }
  } catch {}

  try {
    const scheme = (localStorage.getItem("appScheme") as keyof typeof PRESETS) || "A";
    if (scheme && PRESETS[scheme]) {
      applyTokens(PRESETS[scheme]);
    }
  } catch {}
})();

const el = document.getElementById("root")!;
createRoot(el).render(<App />);
