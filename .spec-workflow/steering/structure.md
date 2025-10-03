# 项目结构与模块规划（星座项目）

## 仓库结构（当前）
- `cmd/app/` 主程序与路由注册。
- `internal/middleware/` 请求ID、错误处理、RBAC、鉴权、限流。
- `internal/api/` 统一响应结构。
- `internal/ai/frontend|backend|integration/` AI生成与联调接口占位与类型。
- `internal/registry/` API Registry统一发现。
- `internal/validation/` 请求绑定与错误返回助手。
- `策划.md` 完整策划案与附录。

## 规划模块
- `billing/` 支付与结算闭环（订单/支付/账单/对账/退款/发票）与风控。
- `llm/` LLM路由与成本/配额守护，Prompt治理与模板版本管理。
- `contract/` 契约测试与OpenAPI/DSL一致性校验，破坏性变更报告。
- `observe/` 追踪与指标采集、质量看板与事件复盘。
- `portal/` 管理后台（审批/门禁/预览与灰度/成本与配额/合规报告）。

## 路线图与依赖
- 与《策划.md》5.3路线图一致：逐期落地生成→联调→门禁→灰度→SLO看板。
- 依赖：Gin、OpenAPI/Swagger、KMS、对象存储、向量库（安全策略与删除传播）。

## 规范
- 统一响应与错误码；RBAC与鉴权；限流与配额；审计与日志脱敏。
- CI门禁：lint/test/安全扫描/契约测试/性能基线；灰度与自动回滚；审批分层。

## 规范映射与执行
- 技术架构与接口规范：详见 `steering/tech.md` 的架构、接口、错误码与数据格式章节。
- 开发规范：命名、编码风格、注释与文档、质量门禁统一遵循 `steering/tech.md`。
- 测试规范：单元/集成/性能测试与契约测试流程见 `steering/tech.md`。
- 版本控制与发布：分支策略、SemVer、CI/CD与回滚策略见 `steering/tech.md`。

## 前后端分离实践细则
- 后端：路由层（Gin）→ 服务层 → 仓储层 → 中间件（鉴权/限流/RBAC）。
- 前端：页面/组件层 → 状态管理 → API 客户端；统一 Loading/Error/空态处理。
- 合同优先：以 OpenAPI/JSON Schema 为唯一真实来源，前后端均以此生成与联调。

## 联调契约与环境
- 契约测试：根据 OpenAPI 校验请求/响应与错误码一致性（含 SSE/流式）。
- 预览环境：生成隔离预览与变更报告（契约差异/性能/安全），审批通过后灰度发布。
- 观测与审计：统一 requestId、追踪、指标与事件复盘，生成记录可追溯。