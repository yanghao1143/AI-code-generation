目的

- 定义前端设计令牌（Design Tokens）的统一结构与命名，覆盖颜色、字号、间距、圆角、阴影、边框与栅格等常见视觉变量。
- 保障各页面与组件通过 CSS 变量进行主题/方案切换的一致性，便于 Style 预览页、Preset 方案和后续主题系统复用。

命名规范

- 统一使用 CSS 变量形式：以 -- 开头，采用短横线分隔（如：--text-color）。
- 语义优先，避免具体组件名称：示例 --border-color，而非 --card-border-color。
- 与代码实现保持一致：tokens.ts 中的 TOKEN_KEYS 为当前有效键。

令牌分类与键列表（当前实现）

1) 颜色（color）
- --text-color：文本颜色
- --bg-color：背景颜色
- --color-primary-start：主色（渐变起始）
- --color-primary-end：主色（渐变结束）
- --border-color：通用边框颜色
- --btn-ghost-text：次按钮文本颜色

2) 字号（size）
- --font-size-base：基础字号（px）
- --line-height-base：基础行高（纯数值）

3) 间距（space）
- --space-sm：小号间距（px）
- --space-md：中号间距（px）
- --space-lg：大号间距（px）

4) 圆角（radius）
- --radius-sm：小号圆角（px）
- --radius-md：中号圆角（px）
- --radius-lg：大号圆角（px）

5) 阴影（shadow）
- --shadow-sm：小号阴影（CSS box-shadow）
- --shadow-md：中号阴影（CSS box-shadow）

6) 边框（border）
- --border-width：统一边框宽度（px）

7) 栅格（grid）（已接入预览）
- --container-max-width：容器最大宽度（默认 1200px）
- --grid-gap：栅格间距（默认 16px）
- --grid-columns：栅格列数（默认 12）
说明：上述 grid 令牌已加入 TOKEN_KEYS 与 A/B/C/D 预设；Style 预览页已提供示例展示（容器宽度条、gap 网格、列数网格）。后续布局系统可直接读取这些变量应用于容器与网格布局。

示例 JSON（与代码当前键一致）

{
  "--text-color": "#111827",
  "--bg-color": "#ffffff",
  "--color-primary-start": "#2563eb",
  "--color-primary-end": "#7c3aed",
  "--border-color": "#e5e7eb",
  "--btn-ghost-text": "#6b7280",
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
  "--line-height-base": "1.6"
}

前端接入说明

- tokens.ts
  - TOKEN_KEYS：当前支持的 CSS 变量键列表。
  - applyTokens(tokens: Record<string, string>)：将变量写入 document.documentElement。
  - snapshotCurrentTokens()：从 :root 读取当前 CSS 变量快照（受 TOKEN_KEYS 限定）。

- tokens.schema.ts
  - TOKENS_SCHEMA：用于 Style 预览页按“分类-项目”渲染视觉示例，键名需与 TOKEN_KEYS 对齐。

- Style 预览页（Style.tsx）
  - 支持方案切换（A/B/C/D）与本地持久化；
  - 提供可视化调整工具（颜色、间距、圆角、阴影等）；
  - 支持导出 JSON/CSS/SCSS/LESS；
  - “令牌 Schema 预览”区块按 TOKENS_SCHEMA 分组渲染色板、字号、间距、圆角、阴影与边框示例。

验收与约束

- 键名必须与代码保持一致；新增令牌需同时更新：
  - TOKEN_KEYS（tokens.ts）
  - TOKENS_SCHEMA（tokens.schema.ts）
  - Style 预览页对应的展示逻辑（如需要）。
- 建议颜色对比度（文本 vs 背景）达到 WCAG AA：计算公式已在 Style.tsx 内实现用于参考。
- 阴影与渐变等复杂值需使用合法 CSS 字面量以保证渲染一致性。