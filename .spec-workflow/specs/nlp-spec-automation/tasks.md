# nlp-spec-automation 实施任务

以下任务由自动化生成，覆盖文档与数据库落地：

- [-] 生成并审阅需求/设计/任务文档
  - 目标：确保 `.spec-workflow/specs/nlp-spec-automation/{requirements.md,design.md,tasks.md}` 三文档结构完整、一致、可追溯。
  - 检查清单：
    - 文档均存在，且包含核心章节（需求/设计/任务）。
    - 需求到设计、设计到任务存在交叉引用或对应关系说明。
    - 术语与实体在三个文档中一致，避免命名混乱。
    - 风险与限制有明确说明，并在任务中体现缓解措施。
  - 产出物：`review.md`（审阅记录与结论），必要时对三文档进行补充说明或交叉引用。
  - Prompt:
    - Role: Spec Reviewer & Editor
    - Task: 审阅并完善 nlp-spec-automation 的 `requirements.md`、`design.md`、`tasks.md`，补充交叉引用与可追溯性，形成 `review.md` 记录与结论；审批通过后将本任务从 `[-]` 标记为 `[x]`。
    - Restrictions: 不改变业务范围与目标；避免引入未定义术语；如需重大修改，先记录在 `review.md` 并征求确认。
    - _Leverage: `.spec-workflow/specs/nlp-spec-automation/{requirements.md,design.md,tasks.md}` 现有内容。
    - _Requirements: 确保三文档之间的一致性与可追溯性，输出明确的审阅结论与后续动作。
    - Success: 生成 `review.md`，列出一致性检查结果、风险与待办；必要补充项已在三文档中标注或新增注记。
  - 状态：`review.md` 已生成并提交审批，等待通过后标记为完成。

- [ ] 基于实体与关系生成 MySQL DDL 并执行创建
  - 子任务：
    - [x] 生成初版 DDL 文件：`scripts/db/nlp_spec_automation.sql`
    - [x] 添加执行脚本：`scripts/db/apply_ddl.sh`（用于本地/CI 环境应用 DDL 并记录日志）
    - [x] 在开发环境执行 DDL 创建库表（记录 MySQL 版本/字符集/引擎）
    - [x] 验证外键与索引有效性（针对 conversations、fortune_records 等）
    - [x] 输出执行与验证日志到：`scripts/reports/db/nlp-spec-automation/ddl-apply.log`
    - 备注：已在本机 MySQL 8.0.43 (Ubuntu) 环境以 root 无密码执行，结构校验通过；详见 `scripts/reports/db/nlp-spec-automation/ENV.md` 与 `ddl-apply.log`。
- [ ] 为对话与测算记录建立必要索引
  - 子任务（实施进度）：
    - [x] conversation: `idx_conversation_anchor_fan_created(anchor_id, fan_id, created_at)`
    - [x] conversation: `idx_conversation_created(created_at)`
    - [x] fortune_record: `idx_fortune_record_fan_created(fan_id, created_at)`
    - [x] fortune_record: `idx_fortune_record_service(service_id)`
    - [x] fortune_record: `idx_fortune_record_created(created_at)`
    - [x] tag: `uq_tag_name(name)`（唯一约束）
    - [x] anchor: `idx_anchor_level(level)`
    - [x] topic: `idx_topic_popularity(popularity)`
    - [x] fan_tags: `idx_fan_tags_fan(fan_id)`
    - [ ] 根据查询压测结果评估是否需要复合索引或覆盖索引
- [ ] 为工作流定义与脚本内容规划版本化与审计
- [ ] 持续完善 NLP 规则以提升解析准确率
 
 - [ ] 定义并实现 speccheck 报告产出与 CI 集成（scripts/reports/consistency/nlp-spec-automation/report.md）
 - 子任务：
     - [x] 创建报告占位文件：`scripts/reports/consistency/nlp-spec-automation/report.md`
     - [x] 运行 speccheck：对比 DomainModel/DDL/OpenAPI（若有）
       - 最新报告：`scripts/reports/consistency/speccheck-20251003-140644.json`（所有项一致，无缺失与类型不匹配）
     - [x] 在 CI 中增加 speccheck 步骤与报告上传（Artifacts）
       - [x] 添加本地 CI 脚本：`scripts/ci/speccheck.sh`（可用于流水线集成）
       - [x] GitHub Actions 工作流：`.github/workflows/speccheck.yml`（自动运行并上传报告 Artifact）
     - [x] 对不一致项自动生成修复任务（更新 tasks.md）
       - 说明：最新报告 `scripts/reports/consistency/speccheck-20251003-170115.json` 与 `dist/openapi.json` 比对一致，未发现缺失/类型不匹配/资源差异，当前无修复任务可生成，保持持续监控。

- [ ] 生成 OpenAPI 定义并校验一致性
  - 子任务：
    - [x] 创建初版 OpenAPI 文件：`.spec-workflow/specs/nlp-spec-automation/openapi.generated.yaml`
    - [x] 覆盖主要实体的 CRUD 路径与组件 schemas（Anchor/Fan/Conversation/...）
      - 说明：已补齐 Tags/FortuneRecords/FortuneServices/Topics/Scripts/Workflows 的 `/{id}` 路径与 `PUT` 更新，并新增对应 `*Update` Schemas。
    - [x] 与 DDL 对齐字段名/类型/约束，并通过 x-relations 标注外键关系
      - 已对齐：依据 `scripts/db/create.sql`（anchor/fan/tag/fan_tags/conversation/fortune_record/fortune_service/topic/script/workflow）核对 `openapi.generated.yaml` 的 components.schemas 与 paths，必要处补充 `x-relations`（如 conversation.anchor_id/fan_id、fan_tags.fan_id/tag_id、fortune_record.fan_id/service_id、script.topic_id 等）；生成 `dist/openapi.json` 并通过 speccheck 一致性校验。
    - [x] 补充安全方案与权限：在 `components.securitySchemes` 增加 `bearerAuth` 与 `headerPermissions`，并在 Fans 相关操作（GET/POST/GET{id}/PUT{id}/DELETE{id}）声明 operation 级 `security` 与 `x-permissions: [fans]`
    - [x] 在 CI 中验证 OpenAPI 与 DDL/DomainModel 的一致性（结合 speccheck）
      - 最新报告：`scripts/reports/consistency/speccheck-20251003-173617.json`（所有项一致）

- [ ] 合规检查与验收
  - 子任务：
    - [ ] 敏感字段处理策略：`fan.gender`, `fan.birthday`, `fan.zodiac` 的访问与脱敏（需求与设计补充）
    - [ ] 日志审计：记录 speccheck、DDL 应用与修复任务的变更日志（路径：`scripts/reports/**`）
    - [-] 在 `requirements.md` 与 `design.md` 中补充合规章节与验收标准（需审批）
      - 进度：已补充并提交审批（requirements/design）；通过后将标记为 `[x]`。

- [ ] 数据库环境记录
  - 子任务：
    - [x] 创建环境记录：`scripts/reports/db/nlp-spec-automation/ENV.md`（MySQL 版本/字符集/引擎/数据库名）
    - [x] 在执行 DDL 前更新具体环境参数并保存在该文件中
    - [ ] 可选：使用 `docker-compose.mysql.yml` 启动 MySQL 8.0 并填充 ENV.md 参数（HOST/PORT/USER/PASS/DB）