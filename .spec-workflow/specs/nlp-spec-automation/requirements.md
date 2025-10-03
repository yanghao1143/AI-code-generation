# NLP 规范自动化（nlp-spec-automation）需求说明

## 概述
通过自然语言处理（NLP）自动解析用户输入的需求文本，生成规范化的技术文档，并驱动模块级开发落地到 `.spec-workflow/specs/xingzuo`。同时，自动从解析出的领域模型生成数据库 DDL（建表/索引/外键），实现“从自然语言到规范与数据库”的一体化自动化。

## 目标
- 将用户的自然语言需求准确转换为结构化的规格文档（requirements/design/tasks）。
- 自动在 `specs/xingzuo` 下创建或更新对应模块的规格文档与实现任务。
- 从解析出的实体、字段、关系自动生成数据库 DDL，并输出到 `scripts/db/create.sql` 等位置。
- 保证生成的 OpenAPI 与 DDL 与领域模型一致，提供一致性检查与报告（speccheck）。

## 范围（In Scope）
- 自然语言需求解析：实体、字段、类型、约束（长度/精度/主键/外键/唯一）、关系（一对多/多对多）。
- 规格生成：
  - 在 `.spec-workflow/specs/xingzuo/{模块名}/requirements.md` 生成需求文档。
  - 在 `.spec-workflow/specs/xingzuo/{模块名}/design.md` 生成设计文档（包含 API/数据模型/流程）。
  - 在 `.spec-workflow/specs/xingzuo/{模块名}/tasks.md` 生成任务清单（原子任务，含 Prompt 字段）。
- 数据库自动化：从领域模型生成 MySQL DDL（create/migrate/rollback），包含索引与外键约束。
- OpenAPI 自动化：为每个实体生成 schemas 与 CRUD 路径，保留字段长度/精度与外键关系扩展（例如 x-relations、外键描述）。
- 一致性校验：运行 `specpipe speccheck` 输出一致性报告并纳入 CI。

## 非范围（Out of Scope）
- 复杂业务规则的自动验证（需人工补充）。
- 前端页面的自动生成（可后续扩展为单独规格）。

## 用户输入与示例
- 输入形式：中文或英文的自然语言需求，支持要点式与段落式。
- 示例（中文）：
  - “用户可以注册，邮箱唯一；订单属于用户，订单金额两位小数，用户删除时订单跟随删除。”
  - “文章有标题（最长200）、正文、作者；作者和文章是一对多关系；需要创建接口和数据库表。”

## 转换输出
- 规格文档：
  - requirements.md：用户故事（EARS）、验收标准、约束。
  - design.md：架构与模块设计、API 设计、数据模型（ER）、约束与迁移策略。
  - tasks.md：原子化实现任务（含 Prompt、成功标准、文件路径）。
- 代码与工件：
  - `scripts/db/create.sql`、`scripts/db/migrate.sql`、`scripts/db/rollback.sql`。
  - `.spec-workflow/specs/xingzuo/**/openapi.json` 与 `openapi.generated.json`。
  - 一致性报告：`scripts/reports/consistency/{spec-name}/report.md`。

## 解析与建模要求
- 实体命名：支持中文名自动蛇形命名（SnakeCase）映射为表名与字段名。
- 字段类型：支持 VARCHAR(length)、DECIMAL(precision, scale)、INT/BIGINT、DATETIME、TEXT 等。
- 约束：长度（maxLength）、精度与小数位（x-precision/x-scale）、唯一、非空、主键、外键（含 ON DELETE/UPDATE 策略）。
- 关系：一对多/多对多/一对一，生成外键约束与 OpenAPI x-relations 扩展。
- 路径与资源：按实体生成标准 CRUD 路径模板，可扩展列表/分页/筛选。

## 准确性与校验
- 解析准确性目标：
  - 字段类型识别准确率 ≥ 95%
  - 外键关系识别准确率 ≥ 95%
  - 约束（唯一/长度/精度）识别准确率 ≥ 90%
- 校验机制：
  - speccheck 对比 DomainModel、DDL、OpenAPI，发现缺失/多余资源并报告。
  - 生成后进行编译与快照比对，确保 OpenAPI 和 DDL 可用。

## 交互流程（高层）
1. 用户在 IDE/CLI 提交自然语言需求。
2. NLP 解析管线将文本转为领域模型（实体/字段/关系/约束）。
3. 生成 `specs/xingzuo/{模块}` 的 requirements/design/tasks 文档并创建审批。
4. 通过审批后，执行 `specpipe gen` 生成 OpenAPI 与 DDL；写入 `scripts/db/*.sql`。
5. 执行 `specpipe speccheck` 输出一致性报告；若不一致，自动提出修复建议任务。

## 依赖与集成
- 解析：`internal/nlp/pipeline.go`、`internal/nlp/ai_codegen.go`。
- 领域模型：`internal/model/model.go`。
- 规格生成：`internal/specgen/generator.go`、`cmd/specpipe/main.go`。
- 一致性校验：`internal/speccheck/checker.go`。

## 风险与缓解
- NLP 解析歧义：提供澄清问题与交互式提示；生成报告列出假设与不确定项。
- 数据库约束冲突：speccheck 报告并阻止发布，需任务修复。

## 验收标准（示例）
- 给定示例输入，自动生成 `用户/订单` 模块规格与 DDL；OpenAPI 中包含 x-relations 与字段约束（maxLength、x-precision/x-scale）。
- speccheck 报告无缺失表/资源，或自动生成修复任务。

## 合规要求与验收标准（新增）

为满足隐私与合规要求，并确保规范到落地的一致性，补充如下需求与验收标准：

- 敏感字段访问控制
  - 涉及 PII 的字段：`fan.gender`, `fan.birthday`, `fan.zodiac`。
  - 服务端必须进行鉴权与授权后才返回上述字段；默认列表查询可仅返回非敏感字段（如需要，提供开关或字段选择）。
  - 字段脱敏策略：
    - `birthday` 支持按天/月脱敏（例如仅展示 YYYY-MM 或屏蔽具体日）。
    - `gender`, `zodiac` 可在非必要场景下省略或聚合统计返回。

- 鉴权与权限
  - 统一使用 Bearer 或 HS256 JWT 认证；JWT 中包含 `permissions` 声明。
  - Fans 相关接口必须具备 `fans` 权限；兼容从请求头 `X-User-Permissions` 读取权限的方式（与中间件一致）。
  - 接口需在 OpenAPI 中声明安全要求，便于前后端与测试联调。

- 日志与审计
  - speccheck、一致性报告、DDL 应用、种子数据应用的日志必须写入 `scripts/reports/**` 并保留。
  - 审计事件包含：DDL 变更、OpenAPI 更新与校验报告、索引优化与压测结果摘要。

- 数据保留与删除
  - 明确 `conversation`、`fortune_record` 的保留策略与清理条件；在需求中补充（例如保留 180 天）。
  - 删除 `fan` 时的关联处理策略（软删除或应用层校验）需在设计中体现，避免意外删除造成审计缺失。

- 验收标准（合规补充）
  - speccheck 报告通过，且 OpenAPI 对敏感字段的暴露受权限控制（联调用例验证）。
  - 审计日志存在并包含上述事件，路径与文件命名规范统一。
  - README 或规范提供最小化数据访问示例（仅在拥有 `fans` 权限时返回敏感字段）。
