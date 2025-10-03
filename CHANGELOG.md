Unreleased

- 新增 aicodegen CLI：解析 .spec-workflow/sources/策划.md，生成 requirements/design/tasks 文档、MySQL DDL（create/migrate/rollback）与 OpenAPI 文件；支持 --apply-db、--dsn-env、--openapi-out、--ticket 等参数。
- 审计转发：
  - internal/audit.ForwardNoContext：在无 gin.Context（CLI/后台）时发送审计事件到 /api/v1/observe/events，带重试与头部（X-User-Permissions、Authorization）。
  - internal/audit.LogAICodegenRun：记录 aicodegen 运行的关键元数据（源、输出路径、数量统计、澄清问题 ID、DB 应用标志、票据），stdout 打印并可选转发。
  - cmd/aicodegen/main.go 集成审计调用：生成完成后打印并转发 audit 事件。
- 文档与环境：
  - README 新增 aicodegen 使用与审计环境变量说明。
  - 新增 .env.example，包含 AUDIT_FORWARD_ENABLE、OBSERVE_ENDPOINT、OBSERVE_TOKEN、AUDIT_USER_ID 等审计配置示例。
  - scripts/config/env-gen.sh 输出审计相关变量，便于生成 .env。
- 单元测试：
  - internal/audit/aicodegen_test.go：验证 ForwardNoContext 的重试与请求头；验证 LogAICodegenRun 的转发负载与 userId 注入。
- CI 与开发体验：
  - 新增 scripts/ci/aicodegen-dryrun.sh：干跑 aicodegen，校验产物存在并检查 stdout 审计日志行。
  - Makefile 增加 aicodegen-dryrun 目标，并在 make ci 中执行。
- 其他：
  - 支持 openapi-out 独立导出（例如 dist/openapi.aicodegen.json）。

注意事项与常见问题

- Makefile 缺失分隔符错误：确保配方行使用制表符（tab）而非空格。
- speccheck 门禁依赖 jq：缺少 jq 时仅生成报告，不进行阈值判断（门禁跳过）。
- 审计转发：当 AUDIT_FORWARD_ENABLE=true 但未配置 OBSERVE_ENDPOINT 时，默认使用本地 PORT 拼接（http://127.0.0.1:PORT/api/v1/observe/events）。网络错误会自动重试。
- 数据库自动执行：检测到 DSN 时会自动启用 apply-db；如不期望执行，使用 --apply-db=false 或清理 DSN 环境变量。

迁移与升级建议

- 拉取更新后，建议先执行：make ci（包含 tidy/lint/test/security/env-check/aicodegen-dryrun 等）。
- 按需更新 .env 或使用 scripts/config/env-gen.sh 生成；若启用审计转发，请配置 OBSERVE_ENDPOINT 与 OBSERVE_TOKEN。
- 如需审批门禁，执行数据库变更时传入 --ticket 或设置 XZ_APPROVED_TICKET。