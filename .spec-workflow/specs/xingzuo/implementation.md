# 实施阶段（xingzuo）

## 当前进展
- 统一响应、RBAC 与错误处理测试已通过（`internal/middleware/*_test.go`）。
- 鉴权（Bearer Token，`AUTH_TOKENS`）与限流（`RATE_LIMIT_RPS/BURST`）已挂载到 `/api/v1`。
- AI 前端/后端占位路由与类型就绪，统一 JSON 绑定助手已启用。
- API Registry `/api/v1/registry` 已提供统一发现。

## 代码索引
- 主程序：`cmd/app/main.go`
- 中间件：`internal/middleware/*`
- 统一响应：`internal/api/response.go`
- JSON绑定：`internal/validation/bind.go`
- AI接口：`internal/ai/frontend|backend/*`
- 注册表：`internal/registry/routes.go`

## 下一步
- 完成 CI 门禁与审批流打通；引入契约与性能基线。
- 启动 `billing/` 与 `observe/` 模块的最小可用版本。