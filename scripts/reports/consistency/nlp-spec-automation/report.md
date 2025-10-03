# speccheck 一致性报告占位（nlp-spec-automation）

本报告用于记录 DomainModel、DDL 与 OpenAPI 的一致性检查结果。

- 规格位置：`.spec-workflow/specs/nlp-spec-automation/{requirements.md,design.md,tasks.md}`
- DDL 文件：`scripts/db/nlp_spec_automation.sql`
- 生成工具：`specpipe speccheck`

## 生成说明（待集成到 CI）
1. 确保 DDL 与 OpenAPI（若已生成）就绪。
2. 运行 speccheck（示例）：
   - `specpipe speccheck --spec nlp-spec-automation --ddl scripts/db/nlp_spec_automation.sql --out scripts/reports/consistency/nlp-spec-automation/report.md`
3. 在 CI 作业中上传本报告为 Artifact，若发现不一致项则生成修复任务并关联到 `tasks.md`。

## 汇总（Summary）
- 生成时间：2025-10-03T14:06:44+08:00
- 总体状态：一致（missingTables=0, extraTables=0, missingColumnsTables=0, typeMismatchTables=0）
- OpenAPI 状态：一致（missingResources=0, extraResources=0, schemaMissing=0, fieldIssues=0）
- 报告 JSON：`scripts/reports/consistency/speccheck-20251003-140644.json`

## 对比：DomainModel ↔ DDL
- 实体缺失/多余：无
- 字段类型/约束差异：无（已将部分长度统一为 VARCHAR(255) 并补齐 fan.zodiac）
- 外键/索引差异：初版符合设计；已新增建议索引，待实际查询压测验证

## 对比：DDL ↔ OpenAPI
- 资源/路径缺失或多余：无（通过术语映射扩充消除额外资源提示）
- Schema 字段与约束差异：无
- x-relations（外键扩展）一致性：后续在 OpenAPI 中补充 x-relations 注记

## 违规项列表（Violations）
- 无

## 后续动作（Next Actions）
- 在 `tasks.md` 标记 speccheck 已运行并通过；将 CI 集成子任务保持待办
- 继续推进 DDL 应用与验证并记录日志