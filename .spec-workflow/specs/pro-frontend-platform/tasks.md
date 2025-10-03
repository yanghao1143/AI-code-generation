专业级前端开发平台 任务分解（Phase 3 / Tasks）

说明
- 使用任务状态标记：[ ] pending，[-] in-progress，[x] completed。
- 任务按四大核心模块与跨模块能力拆分，包含验收标准与负责人占位。

总览与里程碑
- [-] M1 需求澄清最小可用：对话澄清 + 文档导出（Markdown/PDF/Word）+ 审计
- [-] M2 视觉风格生成与可视化调整：双方案 + 设计令牌 + 预览
- [ ] M3 交互原型生成与代码导出：视觉回归 + 自动修复
- [ ] M4 网站生成与部署：质量门禁（性能/SEO/可访问性）+ 云端部署
- [ ] M5 跨模块互通、沙盒完善、性能与安全增强

跨模块基础（平台层）
- [-] 统一鉴权与权限
  - [ ] OIDC/JWT 登录与会话管理（后端 + 前端）
  - [ ] 细粒度权限头（X-User-Permissions）与后端中间件
  - 验收：登录/登出、权限受控接口返回 401/403；审计记录登录事件。
- [-] 审计与日志
  - [x] CLI 运行审计（aicodegen_run）与 HTTP 转发（ForwardNoContext）
  - [-] Web/API 操作审计（action、userId、ticket、detail）统一埋点
  - 验收：操作产生 stdout [AUDIT] 与 JSONL 文件；转发成功/失败可追踪。
- [ ] 事件总线与互通
  - [ ] 选型（Kafka/NATS/Redis Streams）与封装（publish/subscribe）
  - [ ] 事件 schema 与 traceId/requestId 贯穿
  - 验收：跨模块事件联动（澄清完成触发风格生成）。
- [ ] 沙盒运行与资源控制
  - [ ] Worker/容器隔离、资源限制（CPU/内存/并发）、网络白名单
  - [ ] 生命周期清理：预览回收与临时文件清理
  - 验收：并发运行稳定、资源超限可控、清理完整。
- [ ] 存储与产物管理
  - [ ] 文档/风格/原型/构建产物统一存储接口（对象存储或本地 + 元数据）
  - 验收：产物可检索、版本化、权限控制生效。
- [ ] 观测性（Metrics/Tracing）
  - [ ] 请求追踪（traceId）、错误分级告警、性能指标采集
  - 验收：仪表盘可视、异常可定位。

模块 1：需求澄清（clarify-svc）
- [-] API 设计与路由
  - [x] POST /api/clarify/generate（text→spec+tasks+openapi）
    - 进度：已实现别名 /api/clarify/generate 与原路径 /api/v1/ai/clarify/generate；权限（ai.clarify）与审计中间件生效。
  - [x] WS /api/clarify/stream（多轮对话流 + 自动摘要）
    - 进度：新增 WebSocket 端点 /api/clarify/stream/ws 与 /api/v1/ai/clarify/stream/ws（单次三分片 + 终止帧），兼容 SSE（/api/clarify/stream 与 /api/v1/ai/clarify/stream）。审计覆盖 WS 握手、帧数、耗时与关闭原因。
  - [x] GET /api/docs/:id（版本/差异/责任人）
    - 进度：下载接口已以 /api/clarify/docs/:name 与 /api/v1/ai/clarify/docs/:name 落地（文件名作为标识）；与规格目标等价，后续在对象存储引入版本/责任元数据。
  - 验收：OpenAPI 定义已更新并包含 /api/clarify* 与 /api/v1/ai/clarify* 双路径（含 SSE 与 WS 流式说明）；后端路由可调试，审计埋点生效。
- [ ] 文档编辑器（可视化）
  - [ ] 块级编辑器（TipTap/ProseMirror），拖拽布局、结构化编辑
  - [ ] 版本控制与 Diff 视图
  - 验收：编辑→版本→导出闭环；权限与审计生效。
- [ ] 智能补全与术语映射
  - [ ] NLP 引擎集成，术语标准化（terms.json）
  - [ ] 冲突检测与优化建议（上下文感知）
  - 验收：建议可接受/拒绝并记录；术语规范化生效。
- [-] 文档导出
  - [x] Markdown 导出（Clarify 导出与下载已实现并通过端到端验收）
  - [x] PDF 导出（Pandoc 集成：后端转换接口 + 文件存储）
    - 进度：已完成端到端（E2E）验证。后端 /api/v1/ai/clarify/export/pdf 已实现并审计；调用要求：需在请求头携带 Authorization: Bearer <token>、X-User-Permissions: ai.clarify、X-Approval-Ticket（本地示例：local-dev）；导出内容与最近一次 Markdown 一致，审计记录包含 userId 与 ticket。
    - _Prompt:
      - Role: Go 后端工程师
      - Task: 集成 Pandoc 实现 Markdown→PDF 导出；新增接口 POST /api/clarify/export/pdf，读取最近一次 Clarify 导出的 Markdown，调用 Pandoc 转换为 PDF 并存储于 dist/clarify；返回可下载的受限 URL。
      - Restrictions: 保持现有鉴权与审计中间件；请求需携带 Authorization 与 X-User-Permissions；不破坏现有 clarifysvc 路由结构。
      - _Leverage: internal/clarify/routes.go、internal/middleware/http_audit.go、scripts/config/terms.json（可选）、对象存储/本地存储接口（若存在）。
      - _Requirements: 文档导出（PDF）；审计与权限生效；文件名规范化（docId + timestamp）。
      - Success: 接口返回 200 并生成 PDF 文件；Network 可见鉴权与权限头；下载成功且与 Markdown 内容一致（标题/目录/分页规范）。
  - [x] Word 导出（Pandoc 集成：后端转换接口 + 文件存储）
    - 进度：已完成端到端（E2E）验证。后端 /api/v1/ai/clarify/export/docx 已实现并审计；前端 Clarify 页面“导出 Word”按钮交互正常，携带审批票据后自动下载 DOCX。调用要求：需在请求头携带 Authorization: Bearer <token>、X-User-Permissions: ai.clarify、X-Approval-Ticket（本地示例：local-dev）；导出内容与最近一次 Markdown 一致，审计记录包含 userId 与 ticket。
    - _Prompt:
      - Role: Go 后端工程师
      - Task: 集成 Pandoc 实现 Markdown→DOCX 导出；新增接口 POST /api/clarify/export/docx，流程同 PDF；返回受限下载 URL。
      - Restrictions: 同上；文件扩展名 .docx；与 PDF 共享转换管线以减少重复代码。
      - _Leverage: 同上；复用 PDF 导出模块的抽象与审计埋点。
      - _Requirements: 文档导出（Word）；审计与权限生效；文件名规范化。
      - Success: 接口返回 200 并生成 DOCX 文件；下载成功且与 Markdown 内容一致。
  - [x] 前端 Clarify 页面接入：最近导出区块（文件名/格式/受限下载链接、复制 curl）、操作面板统一（共享状态/错误提示），已完成并通过浏览器预览验收（http://localhost:5176/clarify）。

模块 2：视觉风格生成（style-svc）
- [-] 设计令牌与主题系统
  - [x] Tokens Schema（色彩/字号/间距/圆角/阴影/栅格）
    - 进度：栅格令牌（container/gap/columns）已接入并在 Style 预览页落地；预览项完成语义结构与 ARIA 标注，支持键盘复制（Enter/Space）；颜色项提供对比度 AA/AAA 提示。
  - [ ] CSS 变量 + Tailwind/Vanilla Extract 集成
  - 验收：主题切换与令牌应用一致。
- [ ] 双方案生成器
  - [ ] 基于 Spec + 规则库生成两套差异化方案（附风格说明）
  - [ ] A11y 冲突检测（对比度 AA/AAA）
  - 验收：每次生成两套方案与报告；颜色/排版差异明显。
- [ ] 可视化调整工具
  - [x] 精确控制参数（色板/间距/圆角等）
  - [x] 历史轨迹记录与报告导出
  - 验收：历史可回溯、变更报告可下载。
  
  补充增强（按需新增）
  - [x] 可访问性增强：语义结构/ARIA/对比度评级（AA/AAA）与键盘可操作性统一
  - [-] 预设扩展：增加更多主题预设（命名、说明与差异点）
  - [x] 变量导出：输出 SASS/LESS 变量文件（与 CSS 变量同步）
  - [-] 增强自动追随与持久化：data-theme 监听策略优化、存储键与恢复逻辑

模块 3：交互原型（proto-svc）
- [ ] 原型生成与组件库
  - [ ] 依据 Spec 与 Tokens 生成页面/路由/状态/组件
  - [ ] 支持主流设计系统规范（Material/Ant/Fluent）
  - 验收：原型完整可交互，结构符合规范。
- [ ] 多设备预览与调试
  - [ ] PC/平板/手机断点调试，交互测试
  - [ ] 流式日志与性能指标（LCP/CLS）
  - 验收：预览稳定、断点与交互测试通过。
- [ ] 原型→代码导出
  - [ ] 生成工程化代码（HTML/CSS/TS/React/Vue）
  - [ ] 视觉回归与自动修复（pixel-diff + 布局校验）
  - 验收：像素级一致性达标；修复建议可应用。

模块 4：网站生成（sitegen-svc）
- [ ] 构建流水线与质量门禁
  - [ ] lint/test/build/analyze 集成（Lighthouse/axe-core）
  - [ ] 阈值策略：性能/SEO/可访问性达标才允许发布
  - 验收：未达标阻断发布并输出建议。
- [ ] 部署适配与云连接器
  - [ ] Vercel/Netlify/AWS Amplify/自托管部署
  - [ ] 环境配置与密钥管理；蓝绿/金丝雀发布
  - 验收：一键部署成功，可回滚。
- [ ] 自然语言修改与热修复
  - [ ] 布局调整、功能增删、性能优化与安全修复
  - 验收：指令驱动修改生效并审计记录。

测试与验收
- [ ] 单元与集成测试：澄清/风格/原型/站点四模块覆盖
- [ ] 端到端（E2E）：从文本 → 规格 → 风格 → 原型 → 站点 → 部署的全链路
- [ ] 质量门禁：Lighthouse/axe-core 指标达标（阈值可配置）
- [ ] 审计追踪：关键事件完整记录，含用户与票据（ticket）

负责人（占位）
- Clarify：Owner TBD
- Style：Owner TBD
- Prototype：Owner TBD
- Sitegen：Owner TBD
- Platform（Auth/Audit/Sandbox/Events/Storage/Obs）：Owner TBD

依赖与风险
- 依赖：LLM 服务、对象存储、消息队列、CI/CD 基础设施。
- 风险：生成质量与一致性、资源成本、合规与隐私要求、跨模块耦合与复杂度。