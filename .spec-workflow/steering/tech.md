# 技术架构（星座项目）

## 总体架构
- 后端：Golang + Gin，统一中间件（请求ID、错误处理、鉴权、RBAC、限流）、统一响应结构与API Registry。
- 前端：基于 UI DSL（JSON Schema风格）与组件映射（Web/移动），路由与权限自动注册，预览环境隔离。
- AI能力：
  - 前端生成：Prompt→DSL→组件映射→校验→快照→审批→合并。
  - 后端生成：需求→OpenAPI→Gin Handler/Service/Repo→测试→Swagger/Registry→灰度。
  - 智能联调：契约比对、错误分类（网络/鉴权/限流/模式不匹配/后端异常）、补丁建议与回归测试。
- DevOps：CI/CD门禁（lint/test/安全扫描/契约测试/性能对比），灰度发布与自动回滚；统一追踪与质量看板。

## 安全与合规
- 字段级加密与KMS管理（静态加密、对象存储/备份加密、密钥轮换与演练）。
- 日志脱敏与保留策略；最小化数据采集与去标识化测试数据。
- 向量库安全：集合分级、payload白名单、删除权事件链路、备份与恢复演练。详见《策划.md》附录10.3。

## 业务闭环技术设计
- 支付与结算：订单/支付/回调/配额变更/账单/对账/退款/发票，接口与数据模型在《策划.md》4.6；配合风控与SOP。
- 成本与配额：LLM路由的成本限制与预算曲线，高成本模型需额外审批；生成/联调任务限流与配额管理。

## 非功能（NFR）
- 性能：关键接口P99≤300ms；错误预算月度≤20%；契约通过率≥95%。
- 可靠性：统一错误码与自动修复策略（重试/退避/熔断/隔离）；MTTR优化。
- 兼容性：OpenAPI与前端DSL契约一致；API Registry对齐校验与破坏性变更报告。

## 代码结构（当前仓库）
- `cmd/app/main.go` 主程序，注册 `/api/v1` 路由组与中间件。
- `internal/middleware/*` 请求ID、错误处理、RBAC、鉴权、限流。
- `internal/ai/*` 前端/后端/联调占位接口与请求绑定。
- `internal/api/response.go` 统一响应结构。
- `internal/registry/routes.go` 统一API注册端点。
- `internal/validation/bind.go` 统一JSON绑定与错误响应。

## 与《策划.md》的对应关系
- 4.7–4.9：AI生成前端/后端与智能联调框架 → 已有占位路由与统一响应。
- 4.10–4.16：CI/审批、质量指标、风险与限流、Prompt治理、人机协作与错误码策略 → 中间件与流程可逐步落地到CI。
- 4.6：支付与结算闭环 → 后续模块化实现与路由接入。
## AI 自动化研发规范总纲（技术）

为支持 AI 自动化生成前后端代码及联调，需建立统一、可执行的技术规范，确保生成结果可维护、可测试、可发布。

### 技术架构规范
- 前后端分离：后端提供稳定 `REST/JSON` API；前端以组件化框架（如 React/Vue）消费 API。
- 接口设计标准：统一路径命名、动词/资源模型、分页与过滤、幂等性要求；遵循 OpenAPI 描述。
- 数据交互格式：统一 `application/json`；字段命名 `camelCase`；时间一律使用 `RFC3339` UTC。
- 跨域与鉴权：后端开启 CORS 白名单；鉴权通过 `Authorization: Bearer <token>`；权限在 `X-User-Permissions`。

### 开发规范
- 命名与风格：Go 代码遵循 `Effective Go`；前端遵循社区最佳实践与项目 ESLint/Prettier 配置。
- 文档与注释：公共 API、核心模块、复杂算法必须含简要注释与模块级 README；接口自动生成 OpenAPI 文档。
- 代码质量：必须通过 `lint`、`fmt`、`vet`；引入静态检查作为 CI 必选步骤。

### 接口规范
- 设计规则：资源优先，动作二级；避免动词型路径；使用查询参数表达筛选与排序。
- 请求/响应：统一包裹结构：
  - 成功：`{ "data": <object>, "requestId": <string> }`
  - 失败：`{ "code": <string>, "message": <string>, "requestId": <string>, "severity": <string>, "details": <object> }`
- 错误处理：统一错误码集合（如 `E1000 ValidationError`, `E1100 AuthFailed`, `E1300 RateLimited`, `E2100 ModelNotFound`, `E2200 ClientNotRegistered`, `E3000 InternalError`）；HTTP 状态与错误码一一对应。

### 测试规范
- 单元测试：核心逻辑与接口路由需覆盖，后端目标覆盖率 ≥ 70%；使用标准断言工具（`internal/testassert`）。
- 集成测试：前后端联调用 Mock/Dev 环境；API 合同测试必须与 OpenAPI 对齐；中间件（鉴权、限流、RBAC）必须有覆盖。
- 性能测试：关键路径设定基准（P95 延迟与吞吐）；压测报告入库并随版本发布。

### 版本控制与发布规范
- 代码管理：采用 Git Flow 或 trunk-based；主分支必须通过 CI；合并需评审通过。
- 版本号：遵循 SemVer（`MAJOR.MINOR.PATCH`）；接口变更需更新 OpenAPI 并提升相应版本号。
- 发布流程：
  - CI/CD：`tidy → lint → test → contract → build → deploy`
  - 变更日志：每次发布记录特性、修复、Breaking Changes。
  - 回滚策略：发布失败支持一键回滚至上一稳定版本；数据迁移需具备降级脚本。

### 生成与联调流程（端到端）
1) 需求与约束输入：以结构化 Prompt（角色/目标/边界/输出格式）驱动生成。
2) 契约优先：先产出 OpenAPI/JSON Schema 与前端组件接口，再生成代码骨架。
3) 后端脚手架：根据契约生成路由/请求绑定/统一响应与错误码；自动填充鉴权/限流/RBAC 中间件。
4) 前端脚手架：按组件库与页面 DSL 生成页面/状态管理/API 客户端；统一 Loading/Error/空态处理。
5) 联调验证：运行契约测试与集成测试（含 SSE/流式）；校验请求/响应与错误码一致性。
6) 质量门禁：lint/vet/单元与集成覆盖、性能基线、依赖检查、秘密扫描、RBAC 场景用例。
7) 预览与审批：生成隔离预览环境与变更报告（契约差异/性能/安全），通过审批后进入灰度发布。
8) 灰度与回滚：分批发布与监控指标；触发熔断或异常时自动回滚；记录复盘与补丁建议。

### 防幻觉与不可控代码治理
- Schema-first：所有生成必须以 OpenAPI/JSON Schema 为唯一真实来源；生成代码不得超出契约字段。
- 模板与黑白名单：使用受控脚手架模板；限制依赖包来源与版本范围；禁止引入未经批准的库。
- 提示治理：采用标准 Prompt 模板（角色分离、上下文限定、输出格式明确）；避免自由文本指令。
- 静态与安全检查：强制 `lint/vet/staticcheck/gosec`；前端 `eslint/tsc`；Secrets 与敏感信息扫描必过。
- 代码组织边界：清晰分层（路由/服务/仓储/模型/中间件）；禁止跨层直接依赖；前后端均遵循模块边界。
- 合同测试强制：生成后的所有接口必须通过契约测试；任何破坏性变更需自动生成差异报告与审批。
- 变更最小化策略：对生成的增量变更进行 diff 评审；拒绝大范围重写与格式化噪音。
- 可观测与审计：每次生成记录 `requestId`、模型/版本、模板、差异与测试报告；可追溯可回放。

## 环境变量抽象与脱敏管理
- 目标：统一管理 `.env` 的键与格式，支持按环境生成、无触库校验与脱敏输出，避免泄露敏感信息。
- Schema：`scripts/config/env.schema.yaml`
  - 分类：runtime/auth/build/dedupe/db_runner/articles。
  - 每项包含 `type/required/default/example/description`，用于生成与校验参考。
- 模板与示例：
  - 模板（脱敏占位）：`scripts/config/.env.template`
  - 示例（可直接运行本地）：`.env.example`
- 生成（默认为 dev）：
  - `scripts/config/env-gen.sh dev > .env`
  - 支持覆盖：`PORT/RATE_LIMIT_*`、`DEDUPER_BACKEND/REDIS_*`、`XZ_DB_*`、`APP_ENV` 等。
- 校验（不触库）：
  - `scripts/config/env-validate.sh .env`
  - 检查内容：必填键（如 `APP_ENV`、`XZ_DB_TYPE`）、枚举合法性、端口与整数格式、DSN 两类格式（URL 与 go-sql-driver/mysql）、`apply` 模式的审批票据。
- 脱敏输出：
  - `scripts/config/env-redact.sh .env | head -n 50`
  - 掩码规则：`JWT_SECRET/REDIS_PASSWORD` 强制掩码提示；DSN 中账号/密码统一替换为 `***`；`AUTH_TOKENS` 在预览中会被掩码显示。
- CI 集成：
  - Makefile 目标：`make env-check`
  - 执行 `scripts/ci/envcheck.sh`：校验 `.env` 或回退 `.env.example`，并打印前 50 行的脱敏预览。
  - 失败条件：必填键缺失、格式不合法、DSN 无法识别、`apply` 未提供审批票据。

### 会话唯一约束与持久化配置
- 目标：保证粉丝在同一时刻仅绑定一个活跃会话（如 IM 会话/任务会话），支持并发竞争的原子化占用与释放，具备 TTL 过期与故障恢复能力。
- 配置项（与 `.env.example` 对齐）：
  - `SESSION_BACKEND`：后端实现选择，`memory`（默认）或 `redis`。生产环境建议 `redis`。
  - `SESSION_ACTIVE_TTL_MS`：活跃会话占用的 TTL（毫秒），超时自动释放占用，示例：600000（10 分钟）。
  - `SESSION_KEY_PREFIX`：会话键前缀，用于 Redis 命名空间隔离，示例：`sessions:active:`。
  - 复用 Redis 连接参数：`REDIS_ADDR`、`REDIS_PASSWORD`、`REDIS_DB`（与去重模块一致）。
- 实现建议：
  - Redis 原子占用：`SET key value NX PX <ttl>`；释放使用 `DEL`；并发下客户端以返回值判断是否占用成功；必要时用 Lua 校验释放者一致性。
  - 冲突语义：当占用失败（已有活跃会话），返回 HTTP 409 + 业务错误码（如 `E1400`），前端指引用户先释放再重试。
  - 审计：`POST/DELETE /api/v1/fans/{fanId}/active_conversation` 写入审计事件，结构包含 `fanId/conversationId/action/requestId`；失败也记录原因。
  - 可靠性：
    - TTL 作为兜底，避免永久占用；
    - 释放接口应幂等；
    - 配置降级：Redis 不可用时自动回退 `memory`，并在 `/registry/runtime` 暴露 `sessions.backend` 当前状态与健康指示。
  - 监控：
    - 冲突率、占用成功率、释放成功率、TTL 过期释放率；
    - 审计事件对齐 Observe（`/api/v1/observe/events`）并带重试与退避策略。

## 审计事件转发（Observe）

目标
- 将关键业务审计事件（如粉丝会话设置/清除、批量导出）统一转发到 Observe 服务，便于集中监控、留痕与后续分析。

开启与配置
- AUDIT_FORWARD_ENABLE：true/false，默认 false。开启后触发审计事件会向 Observe 转发。
- OBSERVE_ENDPOINT：HTTP 接收端点，默认推导为 `http://127.0.0.1:{PORT}/api/v1/observe/events`（PORT 来自环境变量或 8080）。
- OBSERVE_TOKEN：当请求上下文没有 auth_token 时使用此 Bearer Token 作为后备鉴权。

请求规范
- 方法与路径：POST `/api/v1/observe/events`
- 必要头部：
  - Authorization: Bearer <token>（优先使用请求上下文携带的 auth_token，其次使用 OBSERVE_TOKEN）
  - X-User-Permissions: observe（确保 RBAC 通过）
  - Content-Type: application/json

负载格式（与 Observe EventRequest 兼容，容忍多余字段）：
- type: "audit"
- severity: "info"（可扩展：warning/error）
- message: 审计事件名（如 fan_session_set / fan_session_clear / fans_export）
- detail: 事件细节对象（包含 requestId、path、method 及业务字段，如 fanId、conversationId、filters、itemCount）
- timestamp: RFC3339 字符串（UTC）
- userId: 触发操作的用户 ID

可靠性与重试策略
- 简单退避重试：最多 3 次，间隔为 100ms、200ms、300ms；收到 2xx 视为成功并中止后续重试。
- 非阻塞：转发在日志记录后异步执行，不影响主业务路径；失败不抛出至调用方。
- 可演进：生产环境可替换为消息队列/死信队列（如 Kafka、RabbitMQ），并叠加重试与指标观测。

安全与合规
- RBAC：必须携带 `X-User-Permissions=observe`，保证仅有 Observe 权限的通道可接收。
- 鉴权：优先使用上下文 Authorization（JWT/Bearer），缺省时回退至 OBSERVE_TOKEN；建议生产环境独立最小权限的服务令牌。
- 敏感信息：detail 中谨慎包含敏感字段（如完整个人信息），建议脱敏或仅保留必要标识。
- 传输安全：远端端点应使用 HTTPS；本地开发可使用 HTTP。

运维与监控建议
- 计数与告警：为转发成功/失败计数打点（未来接入 metrics），失败率超阈值告警。
- 采样与限流：高并发场景可开启采样或限流，避免过载 Observe 服务。
- 回放能力：引入队列后可实现失败回放与追踪链路（traceId/requestId）。