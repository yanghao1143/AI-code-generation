# 数据库环境记录（nlp-spec-automation）

用于记录并维护 DDL 应用与验证所需的数据库环境信息。

## 基本信息
- MySQL 版本：8.0.43 (Ubuntu)
- 字符集：utf8mb4
- 排序规则：utf8mb4_unicode_ci
- 引擎：InnoDB
- 数据库名：xingzuo_dev（建议按环境区分：_dev/_test/_prod）

## 连接参数（当前开发环境）
- HOST：127.0.0.1
- PORT：3306
- USER：root
- PASS：<空>
- DB：xingzuo_dev

更新说明：已在本机 MySQL（root 无密码）环境中成功执行 DDL 创建库表。

## DDL 应用
- DDL 文件：`scripts/db/nlp_spec_automation.sql`
- 执行脚本：`scripts/db/apply_ddl.sh`
- 执行示例：
  ```bash
  export MYSQL_HOST=127.0.0.1
  export MYSQL_PORT=3306
  export MYSQL_USER=root
  export MYSQL_PASS=your_password
  export MYSQL_DB=xingzuo_dev
  ./scripts/db/apply_ddl.sh
  ```
- 执行日志：`scripts/reports/db/nlp-spec-automation/ddl-apply.log`

校验提示：如需复核，执行如下命令查看结构摘要：
```bash
mysql -h 127.0.0.1 -P 3306 -u root -D xingzuo_dev -e "SHOW TABLES;"
```

## 验证清单
- 外键有效性：conversation(anchor_id, fan_id)、fortune_record(fan_id, service_id)
- 索引存在性：
  - conversation: idx_conversation_anchor_fan_created(anchor_id, fan_id, created_at)
  - conversation: idx_conversation_created(created_at)
  - fortune_record: idx_fortune_record_fan_created(fan_id, created_at)
  - fortune_record: idx_fortune_record_service(service_id)
  - fortune_record: idx_fortune_record_created(created_at)
  - tag: uq_tag_name(name)
  - anchor: idx_anchor_level(level)
  - topic: idx_topic_popularity(popularity)
  - fan_tags: idx_fan_tags_fan(fan_id)

## CI 集成
- speccheck 脚本：`scripts/ci/speccheck.sh`
- 报告目录：`scripts/reports/consistency/`
- 最新一次报告示例：`scripts/reports/consistency/speccheck-20251003-140644.json`

## CI 可选 DB 预检（DDL + seed）
- 概述：在执行 speccheck 一致性检查前，CI 可选进行数据库预检（先应用 DDL，再导入 seed，并进行基础验证）。
- 触发条件：在 CI 环境（GitHub Actions）提供以下 Secrets/环境变量之一即可触发：
  - `DB_DSN`（优先级最高，示例：`user:pass@tcp(127.0.0.1:3306)/xingzuo_dev?parseTime=true&multiStatements=true`）
  - 或分解参数：`DB_HOST`、`DB_PORT`、`DB_USER`、`DB_PASS`、`DB_NAME`、`DB_UNIX_SOCKET`
- 跳过策略：未设置上述变量或 MySQL 不可达时，speccheck 会自动跳过 DB 预检，仅执行一致性检查，不影响 CI 通过。
- 执行内容：
  - DDL：`scripts/db/apply_ddl.sh`（读取 `scripts/db/nlp_spec_automation.sql`）
  - Seed：`scripts/db/apply_seed.sh`（读取 `scripts/db/seed.sql`）
  - 验证：表行数与关键外键采样连接（输出到日志）。
- 日志位置：
  - `scripts/reports/db/nlp-spec-automation/ddl-apply.log`
  - `scripts/reports/db/nlp-spec-automation/seed-apply.log`
- 本地复核：
  - 直接运行：`bash scripts/ci/speccheck.sh`（从当前环境读取 `DB_*` 变量）
  - 或使用 Makefile：`make speccheck-ci`