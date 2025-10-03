# nlp-spec-automation 技术设计

本设计由 NLP 解析生成，描述实体、字段、关系与数据库约束的初步方案。

## 实体与字段
### Anchor
- id: bigint (NOT NULL, UNIQUE)
- name: string (NOT NULL)
- level: string (NOT NULL)
- created_at: datetime (NOT NULL)

### Fan
- id: bigint (NOT NULL, UNIQUE)
- name: string (NOT NULL)
- gender: string (NULL)
- birthday: string (NULL)
- zodiac: string (NULL)
- created_at: datetime (NOT NULL)

### Tag
- id: bigint (NOT NULL, UNIQUE)
- name: string (NOT NULL)
- created_at: datetime (NOT NULL)

### Conversation
- id: bigint (NOT NULL, UNIQUE)
- anchor_id: bigint (NOT NULL)
- fan_id: bigint (NOT NULL)
- content: text (NOT NULL)
- created_at: datetime (NOT NULL)

### FortuneService
- id: bigint (NOT NULL, UNIQUE)
- code: string (NOT NULL)
- name: string (NOT NULL)
- input_schema: text (NULL)
- created_at: datetime (NOT NULL)

### FortuneRecord
- id: bigint (NOT NULL, UNIQUE)
- fan_id: bigint (NOT NULL)
- service_id: bigint (NOT NULL)
- result: text (NOT NULL)
- created_at: datetime (NOT NULL)

### Topic
- id: bigint (NOT NULL, UNIQUE)
- name: string (NOT NULL)
- popularity: int (NULL)
- created_at: datetime (NOT NULL)

### Script
- id: bigint (NOT NULL, UNIQUE)
- title: string (NOT NULL)
- content: text (NOT NULL)
- topic_id: bigint (NULL)
- created_at: datetime (NOT NULL)

### Workflow
- id: bigint (NOT NULL, UNIQUE)
- name: string (NOT NULL)
- definition: text (NOT NULL)
- created_at: datetime (NOT NULL)

## 关系
- Anchor -> Conversation (one_to_many)
- Fan -> Conversation (one_to_many)
- Fan <-> Tag 通过联结表 fan_tags
- Fan -> FortuneRecord (one_to_many)
- FortuneService -> FortuneRecord (one_to_many)
- Topic -> Script (one_to_many)

## 澄清问题
实现前建议确认以下事项：
- 隐私与合规要求（生日、性别等敏感字段）
- 索引策略（fan_id/anchor_id 组合索引）
- 工作流定义是否采用 JSON Schema 与版本管理
- 脚本内容的审计与版本区分

## 字段约束细化（建议）
为提升与数据库/OpenAPI 的一致性，建议在各实体中明确字段长度/唯一/空值策略：

- Anchor
  - name: VARCHAR(255) NOT NULL
  - level: VARCHAR(64) NOT NULL
  - created_at: DATETIME NOT NULL

- Fan
  - name: VARCHAR(255) NOT NULL
  - gender: VARCHAR(16) NULL
  - birthday: 建议改为 DATE（当前为 VARCHAR(32) 以兼容解析不确定性）
  - zodiac: VARCHAR(32) NULL
  - created_at: DATETIME NOT NULL

- Tag
  - name: VARCHAR(128) NOT NULL, 建议唯一（UNIQUE）
  - created_at: DATETIME NOT NULL

- Conversation
  - anchor_id: BIGINT NOT NULL（FK anchors.id）
  - fan_id: BIGINT NOT NULL（FK fans.id）
  - content: TEXT NOT NULL
  - created_at: DATETIME NOT NULL
  - 索引建议：idx_conversations_anchor_fan_created(anchor_id, fan_id, created_at)

- FortuneService
  - code: VARCHAR(64) NOT NULL UNIQUE
  - name: VARCHAR(255) NOT NULL
  - input_schema: TEXT NULL
  - created_at: DATETIME NOT NULL

- FortuneRecord
  - fan_id: BIGINT NOT NULL（FK fans.id）
  - service_id: BIGINT NOT NULL（FK fortune_services.id）
  - result: TEXT NOT NULL
  - created_at: DATETIME NOT NULL
  - 索引建议：idx_fortune_records_fan_created(fan_id, created_at)、idx_fortune_records_service(service_id)

- Topic
  - name: VARCHAR(255) NOT NULL
  - popularity: INT NULL
  - created_at: DATETIME NOT NULL

- Script
  - title: VARCHAR(255) NOT NULL
  - content: TEXT NOT NULL
  - topic_id: BIGINT NULL（FK topics.id，ON DELETE SET NULL）
  - created_at: DATETIME NOT NULL

- Workflow
  - name: VARCHAR(255) NOT NULL
  - definition: TEXT NOT NULL
  - created_at: DATETIME NOT NULL

## Glossary（术语表）
- Anchor（主播）：内容生产者或服务提供方。
- Fan（粉丝）：消费内容或服务的用户实体。
- Tag（标签）：用于标注 Fan 的特征或偏好，可用于检索与分群。
- Conversation（对话）：Anchor 与 Fan 的互动记录文本。
- FortuneService（测算服务）：提供占星/算命等服务的定义（含输入模式）。
- FortuneRecord（测算记录）：针对 Fan 的某次服务结果记录。
- Topic（话题）：内容或讨论主题，供脚本关联与分类。
- Script（脚本）：一段可复用的文案或流程脚本，可关联 Topic。
- Workflow（工作流）：以文本/DSL 描述的可执行流程定义。

## 合规与隐私（新增）
为满足隐私与合规需求，结合中间件与 OpenAPI 规范，设计补充如下：

- 敏感字段控制
  - 涉及 PII 的字段：`fan.gender`, `fan.birthday`, `fan.zodiac`。
  - 访问策略：服务端在通过认证（Bearer/HS256 JWT）与授权后，才返回上述字段；默认列表接口可通过字段选择或开关进行脱敏（如不返回 birthday 的具体日）。
  - 脱敏建议：
    - `birthday` 建议以 YYYY-MM 或仅年级段返回；若保留字符串以兼容解析不确定性，可在后续迁移中调整为 `DATE` 类型。
    - `gender`, `zodiac` 在非必要场景下可省略或以聚合统计替代。

- 鉴权与权限
  - 统一支持 Bearer 静态令牌与 HS256 JWT；JWT 包含 `permissions` 声明。
  - Fans 相关接口必须具备 `fans` 权限；兼容从请求头 `X-User-Permissions` 读取权限（与现有中间件一致）。
  - OpenAPI 中对相关路径声明安全要求（bearerAuth/headerPermissions），便于联调与测试。

- 日志与审计
  - speccheck、一致性报告、DDL 应用与种子数据的日志写入 `scripts/reports/**`，包含时间戳与上下文信息。
  - 审计事件覆盖：DDL 变更、OpenAPI 更新与校验报告、索引优化与压测结论。

- 数据保留与删除策略
  - `conversation`、`fortune_record` 建议设定保留周期（例如 180 天），并在清理流程中记录审计日志。
  - 删除 `fan` 时的关联处理策略（软删除或应用层校验），避免级联删除造成审计缺失；设计中优先推荐软删除并保留关联记录。

## 验收标准（合规补充）
- speccheck 报告通过，OpenAPI 与 DDL/DomainModel 一致，敏感字段的暴露受权限控制（联调用例验证）。
- 审计日志存在并包含 speccheck/DDL/种子数据/索引优化等事件；路径与命名规范统一。
- README 或规范提供最小化数据访问示例（仅在拥有 `fans` 权限时返回敏感字段），并给出脱敏开关的用法说明。
