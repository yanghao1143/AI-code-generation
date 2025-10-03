# 专业级前端开发平台 设计文档（Phase 2 / Design）

目标
- 构建一个面向专业团队的前端开发平台，覆盖需求澄清、视觉风格生成、交互原型、网站生成四大核心模块，支持自然语言交互（中英双语）、沙盒运行、模块间数据互通与全程审计追踪。

总体架构
- 前后端分层：
  - 前端 Web：TypeScript + React（或可替换为 Vue），SSR/SSG（Next.js/Nuxt）以支持原型预览与站点生成。
  - 后端服务：Go（现有仓库），提供 NLP、Spec/Contract 生成、审计、风格生成、原型编译、站点构建与部署等能力。
  - 共享服务：鉴权（JWT/OIDC）、审计中心（统一事件+JSONL）、对象存储（文档/构建产物）、队列与任务编排（异步生成与部署）。
- 模块化服务：
  - clarify-svc（需求澄清）
  - style-svc（视觉风格）
  - proto-svc（交互原型）
  - sitegen-svc（网站生成）
  - shared：audit-svc、auth-svc、nlp-svc、storage-svc、deployment-svc
- 数据互通：统一数据模型与事件总线（Kafka/NATS/Redis Streams）。各模块通过事件（domain events）和 API 同步状态。
- 沙盒运行：每个模块在隔离容器/worker 中执行，限制资源、超时与权限；提供临时预览与清理策略。

跨模块能力设计
- 自然语言交互：
  - 输入：中文/英文，支持连续多轮上下文，系统维持会话状态（Conversation + Context）。
  - 解析：nlp-svc 调用 LLM，对意图（intent）与结构数据（entities）进行抽取，生成标准化模型（DomainModel/Spec）。
  - 指令化修改：支持“更商务化”“更活泼”等风格语义；支持“增加结算页面”“调整栅格间距”等布局与功能调整。
- 沙盒环境：
  - 每次生成流程在独立沙盒执行；
  - 资源管控：CPU/内存/并发/网络白名单；
  - 产物持久化：仅将必要产物与审计写入持久层，沙盒退出后清理临时文件与预览实例。
- 数据互通与状态同步：
  - 采用统一 ID（requestId/traceId）贯穿多个模块；
  - 各模块产物（规格、风格、原型、代码、站点）以引用关系串联，支持回溯。
- 审计追踪：
  - 统一事件结构：{action, userId, ticket, timestamp, detail}；
  - 事件流：stdout + HTTP 转发（ForwardNoContext），写入 JSONL（如 scripts/db/audit/*），用于追责与合规；
  - 重要操作（变更写入、部署）需审批门禁（ticket 与 XZ_APPROVED_TICKET 匹配）。

模块 1：需求澄清（clarify-svc）
- 功能设计：
  - 智能需求文档生成：基于自然语言输入，输出 Requirements/Design/Tasks（Markdown/Word/PDF）。
  - 可视化编辑：块级编辑器（ProseMirror/TipTap），支持拖拽布局、段落级结构化；版本/差异与责任人记录。
  - 智能补全：上下文感知建议（写作建议、术语标准化、冲突检测）。
  - 流式对话：多轮澄清、自动摘要；支持引用上下文片段与外部链接。
- 技术方案：
  - 文档导出：Markdown 为主；PDF/Word 通过转换（如 Pandoc）在后端生成。
  - 模型映射：术语表（terms.json）驱动字段规范化；生成 DomainModel 与 OpenAPI 草案。
  - 版本控制：存储 JSON AST + 快照；提供 diff/merge；审计记录改动人和说明。
- 关键接口：
  - POST /api/clarify/generate（text→spec+tasks+openapi）
  - WS /api/clarify/stream/ws（对话流，WebSocket）
  - SSE /api/clarify/stream（对话流，Server-Sent Events）
  - 说明：上述接口需提供 Authorization: Bearer <token>（支持 dev-token 或 JWT），以及权限头 X-User-Permissions: ai.clarify（或在 JWT 中包含该权限）
  - GET /api/docs/:id（版本+diff）

模块 2：视觉风格生成（style-svc）
- 功能设计：
  - 每次自动生成 2 套差异化视觉方案（色彩/排版/组件样式），附专业风格说明。
  - 可视化调整：色板、间距、圆角等参数的精确控制；支持设计令牌（Design Tokens）。
  - 自然语言指令：语义化调整（更商务/更活泼/提高对比度/弱化阴影）。
  - 轨迹与报告：完整记录所有调整，支持版本对比与回溯，生成风格变更报告。
- 技术方案：
  - 样式内核：CSS 变量 + Tailwind/Vanilla Extract；主题切换与令牌化。
  - 方案生成：LLM + 规则库（行业基线）；冲突检测（对比度、可访问性 AA/AAA）。
  - 预览：多设备即时预览；暗/亮模式切换；可视化标尺与密度控制。
- 关键接口：
  - POST /api/style/generate（domain→tokens+guidelines）
  - POST /api/style/apply（tokens→预览主题）
  - GET /api/style/report/:id（变更报告）

模块 3：交互原型（proto-svc）
- 功能设计：
  - 一键高保真原型：完整页面结构与组件库，遵循主流规范（Material/Ant Design/Fluent）。
  - 多设备实时预览：PC/平板/手机，断点调试，交互测试；流式日志与性能指标。
  - 原型→代码转换：生成工程化组件代码（HTML/CSS/TS/React/Vue）。
  - 像素级一致性：设计稿与代码产出差异检测与自动修复（视觉回归+布局校验）。
- 技术方案：
  - 组件生成：基于 Spec 与 Style Tokens，组合生成页面、路由、状态管理与测试样例。
  - 视觉回归：Playwright + pixel-diff；差异阈值与忽略规则。
  - 自动修复：启发式规则（栅格/间距/对比度），可选 AI 辅助修正。
- 关键接口：
  - POST /api/proto/generate（spec+style→prototype）
  - GET /api/proto/preview/:id（多设备预览）
  - POST /api/proto/export（prototype→code）

模块 4：网站生成（sitegen-svc）
- 功能设计：
  - 设计到部署全自动化：主流云一键部署（Vercel/Netlify/AWS Amplify/自托管）。
  - 响应式布局与跨终端适配：自动生成断点与优化代码。
  - 代码质量检测：性能/SEO/可访问性实时报告与建议（Lighthouse、axe-core）。
  - 合规与修复：确保 W3C 标准与性能指标；自动修复常见兼容性问题。
  - 自然语言修改：布局调整、功能增删、热修复与回滚。
- 技术方案：
  - 构建流水线：CI 任务编排（lint/test/build/analyze/deploy）。
  - 质量门禁：阈值策略（LCP/CLS/TTI、可访问性分数、错误率），不达标阻断发布。
  - 部署适配：静态托管与边缘函数；环境配置与密钥管理；蓝绿/金丝雀发布。
- 关键接口：
  - POST /api/site/build（code→artifacts）
  - POST /api/site/deploy（artifacts→cloud）
  - GET /api/site/report/:id（性能/SEO/可访问性报告）

数据模型（核心实体与关系）
- RequirementDoc：需求文档（id, title, version, astRef, author, createdAt, updatedAt, status）。
- StyleProposal：风格方案（id, docId, tokens, guideline, createdBy, variants[2]）。
- StyleRevision：风格调整（id, proposalId, diff, reason, createdAt, createdBy）。
- Prototype：原型（id, docId, styleId, pages, components, previewUrl, status）。
- BuildArtifact：构建产物（id, protoId, commitHash, bundleUrl, metrics）。
- Deployment：部署（id, artifactId, env, url, status, startedAt, finishedAt）。
- AuditEvent：审计事件（id, action, userId, ticket, ts, detail）。
- Conversation：对话（id, userId, context, messages[], summary）。
关系示例：RequirementDoc 1..n StyleProposal；StyleProposal 1..n StyleRevision；RequirementDoc + StyleRevision → Prototype；Prototype → BuildArtifact → Deployment；全程 AuditEvent 关联。

接口与集成
- API 风格：REST + WebSocket（流式预览与日志）。
- 鉴权与权限：JWT/OIDC；细粒度权限头（X-User-Permissions）。
- 审计集成：调用 audit.LogXxx 与 HTTP 转发；关键产物路径与统计写入 detail。
- OpenAPI：由 contract/specgen 生成；前端与第三方可据此对接。

沙盒与资源管理
- 隔离：容器/VM/Firecracker；最小权限与网络白名单。
- 资源：CPU/内存/磁盘/并发限流；超时控制（如 XZ_DB_OP_TIMEOUT 类似策略）。
- 清理：生命周期钩子（创建/完成/失败）→ 清理预览与临时文件。

质量与安全
- 代码质量：ESLint/Prettier/TypeCheck；单测/端到端测试；可访问性（axe-core）。
- 安全：依赖审计、CSP/HTTPS、输入校验、防注入与越权；Secrets 管理（KMS/环境隔离）。
- 合规：隐私与日志留存策略；审批门禁（ticket 匹配）。

性能与可维护性
- 缓存与增量：复用中间产物（spec→style→proto→site）
- 并行与排队：按模块独立队列；热点任务合并。
- 观测性：日志、指标、追踪（requestId/traceId），错误分级与告警。

里程碑（建议）
- M1：澄清最小可用（对话 + 文档导出 + 审计）
- M2：风格生成与可视化调整（双方案 + 令牌 + 预览）
- M3：原型生成与导出代码（视觉回归）
- M4：网站构建与部署（质量门指标与回滚）
- M5：跨模块互通、沙盒完善、性能与安全增强

验收要点
- 全链路审计可追溯；
- 中英文自然语言指令贯穿；
- 预览与构建产物可复现；
- 质量门禁可配置且生效；
- 文档、风格、原型、站点四类核心产物完整且互相关联。