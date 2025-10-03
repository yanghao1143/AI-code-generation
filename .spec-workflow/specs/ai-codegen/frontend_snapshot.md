# 前端快照（最小版 React/TS）

- 预览地址：http://localhost:5173/
- 功能点：
  - 鉴权与权限栏（Authorization: Bearer 与 `X-User-Permissions` 可编辑）
  - 文章列表与创建（`/api/v1/articles`）
  - 使用代理转发至后端 `http://localhost:8080`
- 客户端：
  - 从 `dist/openapi.json` 生成 `src/api/types.ts`
  - 最小 API 客户端位于 `src/api/client.ts`
- 依赖与运行：
  - 后端：`AUTH_TOKENS=dev-token PORT=8080 go run ./cmd/app/main.go`
  - 前端：`cd frontend && npm install && npm run dev`