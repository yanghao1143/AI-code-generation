# Clarify 流式接口（SSE / WebSocket）前端使用说明

本说明介绍如何在前端调试和使用 Clarify 的流式接口，包括 SSE 与 WebSocket 两种方式。

## 接口概览

- SSE: `/api/clarify/stream?prompt=...&language=...`
- WebSocket: `/api/clarify/stream/ws?prompt=...&language=...`

后端已集成鉴权与审计（HTTPAudit），并在 OpenAPI 中登记了 Clarify 模块的文档。

## 鉴权与权限

浏览器请求时需要提供 Token 与权限：

- HTTP（SSE）方式：
  - `Authorization: Bearer <token>`（支持 dev-token 或 JWT）
  - `X-User-Permissions: ai.clarify`（或包含该权限的 JWT）
  - 可选：`X-Request-Id` 用于审计链路关联

- WebSocket 方式：浏览器无法设置自定义头部，使用 `Sec-WebSocket-Protocol` 传递：
  - 子协议列表第一个为 token，第二个为权限字符串，例如：`["dev-token", "ai.clarify"]`
  - 后端已在 `internal/middleware/auth.go` 支持该方式进行鉴权与权限校验

## 前端调试页面

- 路由地址：`/clarify/stream`
- 入口导航：在顶栏可看到 “Clarify Stream” 按钮
- 功能：可输入 `prompt` 与 `language`，分别测试 “开始 SSE” 与 “开始 WS”，并查看逐帧输出

## 快速脚本测试

在前端项目根目录：

```bash
npm run smoke:clarify
```

该脚本会对 SSE 与 WS 连接进行快速连通性检查（每种模式 3 帧）。

## Vite 代理与后端地址

- Vite `vite.config.ts` 将 `/api` 代理至 `http://localhost:8081`
- 请确保后端服务已启动（`PORT=8081 go run ./cmd/app`），并能访问 `/api/clarify/stream` 与 `/api/clarify/stream/ws`

## 代码示例

### WebSocket（浏览器）

```ts
import { connectClarifyWs } from "../src/api/clarifyWs";

const ws = connectClarifyWs("示例 prompt", "zh-CN", {
  onOpen() { console.log("WS connected"); },
  onMessage(frame) { console.log(frame); },
  onClose() { console.log("WS closed"); },
});
```

### SSE（浏览器）

```ts
const qs = new URLSearchParams({ prompt: "示例 prompt", language: "zh-CN" });
const res = await fetch(`/api/clarify/stream?${qs.toString()}`, {
  headers: {
    Authorization: `Bearer ${localStorage.getItem("authToken") || "dev-token"}`,
    "X-User-Permissions": localStorage.getItem("userPerms") || "ai.clarify",
    "X-Request-Id": (crypto as any).randomUUID?.() || String(Date.now()),
  },
});
const reader = res.body!.getReader();
const decoder = new TextDecoder();
let buf = "";
while (true) {
  const { value, done } = await reader.read();
  if (done) break;
  buf += decoder.decode(value, { stream: true });
  while (true) {
    const idx = buf.indexOf("\n\n");
    if (idx === -1) break;
    const chunk = buf.slice(0, idx);
    buf = buf.slice(idx + 2);
    if (chunk.startsWith("data: ")) {
      const txt = chunk.slice("data: ".length);
      try { console.log(JSON.parse(txt)); } catch { console.log(txt); }
    }
  }
}
```

## 审计与可观测性

- 后端审计会记录：WS 握手、帧数量与大小、持续时长、关闭原因等；SSE 会记录帧输出与完成事件
- 建议前端传递 `X-Request-Id` 以便在日志审计中进行链路关联

## 常见问题

- 如果浏览器 WS 连接被拒绝：检查是否正确通过 `Sec-WebSocket-Protocol` 传递了 token 与权限
- 如果 SSE 无数据：检查权限头与后端日志，确认是否有权限不足或参数错误