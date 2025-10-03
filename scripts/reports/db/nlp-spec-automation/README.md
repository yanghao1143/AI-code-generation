# nlp-spec-automation DDL 执行与验证

用于记录在开发环境执行 `scripts/db/nlp_spec_automation.sql` 的方法与验证日志路径。

## 环境准备
- MySQL 版本：建议 8.0+
- 字符集：utf8mb4，引擎：InnoDB
- 数据库名示例：`xingzuo_dev`

## 执行示例
```bash
# 请根据环境设置变量
export MYSQL_HOST=127.0.0.1
export MYSQL_PORT=3306
export MYSQL_USER=root
export MYSQL_PASS=your_password
export MYSQL_DB=xingzuo_dev

# 创建数据库（如未存在）
mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DB\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

# 执行 DDL 并记录日志
mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASS" "$MYSQL_DB" \
  < scripts/db/nlp_spec_automation.sql \
  | tee scripts/reports/db/nlp-spec-automation/ddl-apply.log
```

## 验证建议
- 检查外键与索引存在性：
  - conversations(anchor_id, fan_id, created_at)
  - fortune_records(fan_id, created_at)、fortune_records(service_id)
- 约束策略：ON UPDATE CASCADE / ON DELETE RESTRICT/SET NULL 是否符合设计预期。
- 若发现差异，在 `scripts/reports/db/nlp-spec-automation/ddl-apply.log` 标记，并回写 `tasks.md` 生成修复项。