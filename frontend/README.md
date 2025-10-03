# React + TypeScript + Vite

This template provides a minimal setup to get React working in Vite with HMR and some ESLint rules.

Currently, two official plugins are available:

- [@vitejs/plugin-react](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react) uses [Babel](https://babeljs.io/) for Fast Refresh
- [@vitejs/plugin-react-swc](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react-swc) uses [SWC](https://swc.rs/) for Fast Refresh

## React Compiler

The React Compiler is not enabled on this template because of its impact on dev & build performances. To add it, see [this documentation](https://react.dev/learn/react-compiler/installation).

## Expanding the ESLint configuration

If you are developing a production application, we recommend updating the configuration to enable type-aware lint rules:

```js
export default defineConfig([
  globalIgnores(['dist']),
  {
    files: ['**/*.{ts,tsx}'],
    extends: [
      // Other configs...

      // Remove tseslint.configs.recommended and replace with this
      tseslint.configs.recommendedTypeChecked,
      // Alternatively, use this for stricter rules
      tseslint.configs.strictTypeChecked,
      // Optionally, add this for stylistic rules
      tseslint.configs.stylisticTypeChecked,

      // Other configs...
    ],
    languageOptions: {
      parserOptions: {
        project: ['./tsconfig.node.json', './tsconfig.app.json'],
        tsconfigRootDir: import.meta.dirname,
      },
      // other options...
    },
  },
])
```

You can also install [eslint-plugin-react-x](https://github.com/Rel1cx/eslint-react/tree/main/packages/plugins/eslint-plugin-react-x) and [eslint-plugin-react-dom](https://github.com/Rel1cx/eslint-react/tree/main/packages/plugins/eslint-plugin-react-dom) for React-specific lint rules:

```js
// eslint.config.js
import reactX from 'eslint-plugin-react-x'
import reactDom from 'eslint-plugin-react-dom'

export default defineConfig([
  globalIgnores(['dist']),
  {
    files: ['**/*.{ts,tsx}'],
    extends: [
      // Other configs...
      // Enable lint rules for React
      reactX.configs['recommended-typescript'],
      // Enable lint rules for React DOM
      reactDom.configs.recommended,
    ],
    languageOptions: {
      parserOptions: {
        project: ['./tsconfig.node.json', './tsconfig.app.json'],
        tsconfigRootDir: import.meta.dirname,
      },
      // other options...
    },
  },
])
```

## Clarify 流式接口（SSE / WebSocket）

- 调试页：访问 `/clarify/stream`，输入 prompt 与 language，分别测试 SSE 与 WS，查看帧输出。
- 代理：`vite.config.ts` 已将 `/api` 代理到 `http://localhost:8081`，请确保后端运行（`PORT=8081 go run ./cmd/app`）。
- 快速连通性脚本：`npm run smoke:clarify`（需要后端已启动）。
- 详细前端使用说明请参见 `frontend/docs/clarify-stream.md`。

## Clarify Viewer 简易预览页

- 路径：`/clarify/viewer`
- 功能：
  - 同步生成 Clarify（需求/设计/任务），或使用 SSE 流式预览并支持取消。
  - 本地将结果转为 Markdown，支持复制与下载，不依赖后端导出。
  - 后端导出：Markdown / PDF / DOCX；PDF/DOCX 需填写 Approval Ticket（审批票据）。
  - 交叉链接：Clarify 主页、Clarify Stream Debug、OpenAPI 预览。
- 使用步骤：
  1. 启动后端（`PORT=8081 go run ./cmd/app`）与前端（在 `frontend` 内 `npm run dev`）。
  2. 在登录页（`/login`）登录，或在浏览器本地存储设置 `authToken` 与 `userPerms`（例如包含 `clarify` 权限）。
  3. 在 Clarify Viewer 填写 prompt 与 language，点击“同步生成”或“SSE 流式生成”。
  4. 生成后可“复制 Markdown”或“下载 Markdown”。
  5. 需要后端导出时，填写 Approval Ticket，点击“导出 PDF/Word”。
- 说明：
  - cURL/请求会自动携带本地的 `Authorization: Bearer <authToken>`、`X-User-Permissions`、`X-Request-Id` 等头部（由前端 API 客户端生成）。
  - 如无权限或审批票据不合法，后端会返回错误，请检查账号与票据。

## Clarify 冒烟测试与导出验证

- 前置条件：后端运行（`PORT=8081 go run ./cmd/app`），并准备好鉴权信息。
- 环境变量（示例）：
  - `API_BASE_ALIAS=http://localhost:8081`
  - `AUTH_TOKEN=xxxx`（具有 Clarify 权限的用户 Token）
  - `USER_PERMS=ai.clarify`（或包含 clarify 权限的更完整列表）
  - `APPROVAL_TICKET=TKT-123`（用于受控的 PDF/DOCX 导出）
- 运行：
  - 仅流式/平台连通性：`npm run smoke:clarify`
  - 仅 Clarify 导出：`npm run smoke:clarify-export`
  - 综合（SSE/WS + 导出）：`npm run smoke:clarify-all`
- 期望结果：
  - SSE/WS：收到若干帧并以 `done` 结束；无错误。
  - 导出：Markdown/PDF/DOCX 接口返回 `ok=true` 且状态码 200；下载的 PDF/DOCX 响应 `Content-Type` 分别为 `application/pdf` 与 `application/vnd.openxmlformats-officedocument.wordprocessingml.document`，并且响应体大小大于 0。

## 单元测试（Vitest）

- 安装依赖：`npm install`
- 运行测试：`npm test` 或 `npm run test`
- 覆盖内容：`clarifyStreamLive` 的增量事件（requirements/design/tasks/done）、错误分支（非 200/ok）、中途 `AbortSignal` 取消处理。
- 测试环境说明：测试中已对 `localStorage` 与 `crypto.randomUUID` 进行最小化模拟，以便在 Node 环境下运行。

## 开发提示

- 前端开发服务器端口：`vite.config.ts` 指定为 5178。
- `/api` 代理到 `http://localhost:8081`，请确保后端与鉴权信息有效。
- 浏览器端会自动附带 `Authorization`、`X-User-Permissions` 与 `X-Request-Id` 等头部；在本地开发环境可通过登录页或手动设置 `localStorage` 的 `authToken` 与 `userPerms`。

## OpenAPI 预览

- 路径：`/openapi`
- 功能：
  - 查看与刷新 OpenAPI 规格，下载 `openapi.json`。
  - 支持按路径关键字过滤（如：`clarify`/`articles`/`llm`），与按 tag 过滤（如：`Clarify`/`Articles`）。
  - 每个路径列出匹配的方法（GET/POST/PUT/DELETE/PATCH）、标签与摘要。
  - 一键复制该路径方法的 cURL（自动带上本地存储的 token 与权限）。
  - 复制筛选后的 `paths` JSON 片段，便于粘贴到文档或调试。
- 使用提示：
  - 若需快速试用 Clarify 接口，可通过路径过滤找到相关接口，点击“复制 cURL”，在终端执行验证。
  - 未来计划：增加 Try-Out 面板（选择方法/路径/请求体直接发起请求）。

## 导航与路由

- 顶部导航包含：Articles、Clarify、Clarify Viewer、Clarify Stream Debug、OpenAPI、Style、Login。
- 相关页面：
  - Clarify 主页：同步/流式生成、后端导出、历史记录。
  - Clarify Viewer：轻量预览与导出，适合快速生成与本地 Markdown 整理。
  - OpenAPI：接口文档快速过滤、复制与 cURL 辅助。
