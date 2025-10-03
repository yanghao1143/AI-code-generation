# fan-management 技术设计

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

## 关系
- Fan <-> Tag 通过联结表 fan_tags

## 澄清问题
实现前建议确认以下事项：
- 隐私与合规要求（生日、性别等敏感字段）
- 索引策略（fan_id/anchor_id 组合索引）
- 工作流定义是否采用 JSON Schema 与版本管理
- 脚本内容的审计与版本区分
