// 前端设计令牌 Schema：用于在 Style 预览页渲染分组示例（色彩/字号/间距/圆角/阴影/边框）
// 注意：这里的 key 必须与 tokens.ts 中的 CSS 变量保持一致

export type TokenType = "color" | "size" | "space" | "radius" | "shadow" | "border" | "grid";

export interface TokenItem {
  key: string;
  label: string;
  type: TokenType;
  note?: string;
}

export interface TokenGroup {
  name: string;
  description?: string;
  items: TokenItem[];
}

export const TOKENS_SCHEMA: TokenGroup[] = [
  {
    name: "颜色",
    description: "文本/背景/主色/边框等色彩变量",
    items: [
      { key: "--text-color", label: "文本颜色", type: "color" },
      { key: "--bg-color", label: "背景颜色", type: "color" },
      { key: "--color-primary-start", label: "主色（起始）", type: "color" },
      { key: "--color-primary-end", label: "主色（结束）", type: "color" },
      { key: "--border-color", label: "边框颜色", type: "color" },
      { key: "--btn-ghost-text", label: "次按钮文本", type: "color" },
    ],
  },
  {
    name: "字号",
    description: "基础字号与行高",
    items: [
      { key: "--font-size-base", label: "基础字号", type: "size" },
      { key: "--line-height-base", label: "基础行高", type: "size" },
    ],
  },
  {
    name: "间距",
    description: "组件与布局的内外边距尺度",
    items: [
      { key: "--space-sm", label: "间距（小）", type: "space" },
      { key: "--space-md", label: "间距（中）", type: "space" },
      { key: "--space-lg", label: "间距（大）", type: "space" },
    ],
  },
  {
    name: "圆角",
    description: "卡片/按钮等的圆角半径",
    items: [
      { key: "--radius-sm", label: "圆角（小）", type: "radius" },
      { key: "--radius-md", label: "圆角（中）", type: "radius" },
      { key: "--radius-lg", label: "圆角（大）", type: "radius" },
    ],
  },
  {
    name: "阴影",
    description: "卡片/浮层等的阴影层级",
    items: [
      { key: "--shadow-sm", label: "阴影（小）", type: "shadow" },
      { key: "--shadow-md", label: "阴影（中）", type: "shadow" },
    ],
  },
  {
    name: "边框",
    description: "统一的边框宽度",
    items: [
      { key: "--border-width", label: "边框宽度", type: "border" },
    ],
  },
  {
    name: "栅格",
    description: "布局容器与网格配置（预留令牌）",
    items: [
      { key: "--container-max-width", label: "容器最大宽度", type: "grid", note: "示例：1200px" },
      { key: "--grid-gap", label: "栅格间距", type: "grid", note: "示例：16px" },
      { key: "--grid-columns", label: "栅格列数", type: "grid", note: "示例：12" },
    ],
  },
];