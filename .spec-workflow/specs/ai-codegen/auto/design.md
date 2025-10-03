# auto 技术设计

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
- Anchor <-> Fan 通过联结表 conversation

## 澄清问题
实现前建议确认以下事项：
- 隐私与合规要求（生日、性别等敏感字段）
- 索引策略（fan_id/anchor_id 组合索引）
- 工作流定义是否采用 JSON Schema 与版本管理
- 脚本内容的审计与版本区分
