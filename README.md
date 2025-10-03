# 星座项目（AI生成与联调骨架）

## 快速开始
- 依赖：Go 1.21+
- 安装依赖：`make tidy`
- 启动服务：`make run`
- 默认端口：`8080`
- 端口覆盖：如 `8080` 被占用，可通过环境变量指定端口，例如：`PORT=8081 make run`
- 示例端口变量：你可以在终端设置 `export PORT=8080` 或 `export PORT=8081`，将文档中的 `http://localhost:` 替换为 `http://localhost:$PORT`。
- 健康检查：`GET /healthz`

## 主要接口（占位）
- 前端生成
  - `POST /api/v1/ai/frontend/generate`
  - `POST /api/v1/ai/frontend/validate`
  - `GET  /api/v1/ai/frontend/templates`
  - `POST /api/v1/ai/frontend/commit`
- 后端生成
  - `POST /api/v1/ai/backend/generate`
  - `POST /api/v1/ai/backend/scaffold`
  - `POST /api/v1/ai/backend/fix`
  - `GET  /api/v1/ai/backend/templates`
- 智能联调
  - `POST /api/v1/ai/integration/test`
  - `POST /api/v1/ai/integration/diagnose`
  - `POST /api/v1/ai/integration/patch`
  - `GET  /api/v1/ai/integration/reports`
- 支付与结算（billing）
  - `POST /api/v1/billing/orders`
  - `POST /api/v1/billing/payments`
  - `GET  /api/v1/billing/plans`
  - `GET  /api/v1/billing/invoices`
- 可观测（observe）
  - `GET  /api/v1/observe/metrics`
  - `GET  /api/v1/observe/traces`
  - `POST /api/v1/observe/events`

## AI 规格生成（/api/v1/ai/specs/generate）
- 作用：读取《.spec-workflow/sources/策划.md》，解析出业务实体与关系，生成规范文档（requirements/design/tasks/OpenAPI），可选生成数据库 DDL，并支持工作流目录产物与 SQL 预览。
- 权限与鉴权：
  - 头：`Authorization: Bearer <token>`（见下文“鉴权与权限”）
  - 头：`X-User-Permissions: ai.specs`
- 请求体（均为可选，带默认值）：
  - `specName`：输出规格名（默认 `ai-codegen`），路径 `.spec-workflow/specs/<specName>/`
  - `sourceSpec`：结构化合并的来源规格（默认同 `specName`），读取 `.spec-workflow/specs/<sourceSpec>/openapi.json`
  - `useStructured`：启用结构化合并（OpenAPI/JSONSchema 提升实体识别）
  - `generateDocs`：生成规范文档（requirements/design/tasks/openapi.generated.json）
  - `generateDDL`：生成 DDL（`scripts/db/{create.sql,migrate.sql,rollback.sql}`）
  - `writeWorkflowDDL`：同时输出 DDL 到 `.spec-workflow/db/mysql/`
  - `execChannel`：`READ | CHANGE | ROLLBACK`，返回 SQL 预览（不连库）
  - `execEnv`：`test | staging | prod`，用于将来执行时的 DSN 选择（当前仅用于文档）
  - `dryRun`：是否干跑（默认 true；当前端点不执行变更，仅生成）
  - `ticketId`：审批票据（用于将来执行 CHANGE/ROLLBACK 时校验）
- 成功响应：统一包裹 `data` 字段，包含：`operationId/specName/sourceSpec/entities/relations/issues/files/sqlPreview/sqlHash`
- 失败响应：统一错误结构，常见代码：
  - `E1000` 请求体解析失败（JSON 不合法）
  - `E1200` 权限不足（缺少 `X-User-Permissions: ai.specs`）
  - `E2001` 无法读取策划文档（文件不存在/不可读）
  - `E2002` 写入规范文档失败
  - `E2003` 写入 DDL 文件失败

### curl 示例
- 仅生成规范文档（默认读取 `.spec-workflow/sources/策划.md`）：
```
curl -X POST http://localhost:/api/v1/ai/specs/generate \
  -H 'Authorization: Bearer dev-token' \
  -H 'X-User-Permissions: ai.specs' \
  -H 'Content-Type: application/json' \
  -d '{"specName":"ai-codegen","generateDocs":true,"generateDDL":false}'
```

- 生成 DDL 并同时输出到工作流目录：
```
curl -X POST http://localhost:/api/v1/ai/specs/generate \
  -H 'Authorization: Bearer dev-token' \
  -H 'X-User-Permissions: ai.specs' \
  -H 'Content-Type: application/json' \
  -d '{"generateDocs":false,"generateDDL":true,"writeWorkflowDDL":true,"execChannel":"READ"}'
```

- 结构化合并（提供 OpenAPI 以提升识别）：
```
curl -X POST http://localhost:/api/v1/ai/specs/generate \
  -H 'Authorization: Bearer dev-token' \
  -H 'X-User-Permissions: ai.specs' \
  -H 'Content-Type: application/json' \
  -d '{"specName":"ai-codegen","sourceSpec":"ai-codegen","useStructured":true,"generateDocs":false,"generateDDL":false}'
```

- 输出文件路径说明：
  - 文档：`.spec-workflow/specs/<specName>/{requirements.md,design.md,tasks.md,openapi.generated.json}`
  - DDL：`scripts/db/{create.sql,migrate.sql,rollback.sql}`
  - 工作流 DDL（可选）：`.spec-workflow/db/mysql/{create.sql,migrate.sql,rollback.sql}`

提示：端点在相同输入下为幂等，重复生成的文件内容哈希一致；当 `useStructured=true` 且提供了 `.spec-workflow/specs/<sourceSpec>/openapi.json` 时，可在极简 PRD 下稳定识别实体。

## 统一响应结构
- 成功：`{"code":"OK","message":"success","requestId":"...","data":...}`
- 错误：`{"code":"E1000","message":"...","requestId":"...","hint":"...","severity":"...","detail":...}`

## 开发说明
- 请求会自动附加并返回 `X-Request-Id` 用于追踪。
- 当前为占位实现，后续将按《策划.md》逐步补齐生成、联调与错误治理逻辑。

## 运行时注册表（/api/v1/registry）
- 访问：`GET /api/v1/registry`（需 Bearer 鉴权）
- 用途：统一暴露运行态与配置快照，便于联调与可观测。
- 返回关键字段：
  - `version`：当前 API 版本（`v1`）。
  - `env`：运行环境（读取 `APP_ENV`）。
  - `build`：构建与版本信息（用于发布追踪）：
    - `version`（`BUILD_VERSION`），`gitSha`（`GIT_SHA`），`buildTime`（`BUILD_TIME`）。
    - `goVersion`、`moduleMain`、`deps`（Go 模块信息统计）。
    - `vcs.revision`、`vcs.time`、`vcs.modified`（来自 `runtime/debug`）。
  - `config.articles`：文章模块配置快照：
    - 心跳：`heartbeatDefaultMs`、`heartbeatMinMs`、`heartbeatMaxMs`（支持 env 调整）。
    - 列表分页：`listPageSizeDefault`、`listPageSizeMin`、`listPageSizeMax`。
    - 跟随模式：`followMaxMsDefault`、`followMaxMsMin`、`followMaxMsMax`、`followBufferMsDefault`、`followBatchMaxDefault`。
    - 去重：`dedupe.backend`（`memory`/`redis`，可由 `DEDUPER_BACKEND`/`REDIS_ADDR` 推断）、`ttlMs`、`keyPrefix`；`redis.addr`、`redis.db`、`redis.passwordSet`（不泄露密文，仅标示是否设置）。
  - `config.runtime`：运行态快照：
    - `port`（读取 `PORT`，默认 `8080`）。
    - `rateLimit.rps`、`rateLimit.burst`（读取 `RATE_LIMIT_RPS`/`RATE_LIMIT_BURST`）。
    - `sse.heartbeat.defaultMs/minMs/maxMs`（SSE 心跳有效配置）。
  - `runtime.metrics`：进程级指标：
    - `startTime`（UTC）、`uptimeMs`、`goroutines`、`memory.allocBytes/sysBytes/numGC`。
  - `services`：各模块暴露的端点清单。

- 快速验证：
  - 启动：`PORT=9092 AUTH_TOKENS=dev-token make run`
  - 访问：`curl -H 'Authorization: Bearer dev-token' http://localhost:9092/api/v1/registry`

## 鉴权与权限（RBAC）
- Bearer Token：在 `AUTH_TOKENS` 环境变量配置有效列表（逗号分隔）；默认包含 `dev-token`。
- 每个受保护接口需携带：`Authorization: Bearer <token>`。
- 权限头：`X-User-Permissions`（CSV）。示例：
  - 访问前端生成：`X-User-Permissions: ai.frontend`
  - 访问后端生成：`X-User-Permissions: ai.backend`
  - 访问联调：`X-User-Permissions: ai.integration`
  - 访问计费：`X-User-Permissions: billing`
  - 访问观测：`X-User-Permissions: observe`
 - 开发环境回退：未使用 JWT 时，本地可直接使用 `Authorization: Bearer dev-token` 搭配 `X-User-Permissions: <perm>`。

## 端口占用与联调说明
- 服务端口：通过环境变量 `PORT` 指定（默认 `8080`）。若 `8080` 被占用，可使用 `PORT=8081 make run` 启动到 8081。
- 排查占用（Linux）：
  - `ss -ltnp | grep :8080`
  - 或：`lsof -i :8080`
- 释放/切换：
  - 释放：根据占用进程 PID 执行 `kill -9 <PID>`（谨慎操作）。
  - 切换：不释放端口时，统一使用备用端口并在示例中以环境变量引用，例如：
    - `export PORT=8081`
    - `curl http://localhost:$PORT/healthz`

## Fans CRUD（/api/v1/fans）
- 说明：提供粉丝实体的标准 CRUD 接口，返回统一响应结构；分页支持 pageSize/afterId（推荐）与 legacy 的 limit/offset。
- 鉴权与权限：需要 `Authorization: Bearer <token>`，并具备权限 `fans`。可通过登录获取带有权限的 JWT，或在本地使用 `dev-token` 搭配 `X-User-Permissions: fans`。

### 1）登录获取 JWT（含 fans 权限）
```
# 通过公开登录端点获取 HS256 JWT（默认 secret=dev-secret）
TOKEN=$(curl -sS -X POST http://localhost:8081/api/public/auth/login \
  -H 'Content-Type: application/json' \
  --data-binary '{"userId":"u1","permissions":["fans"],"expiresInSec":3600}' \
  | sed -n 's/.*"token":"\([^" ]*\)".*/\1/p')
echo "$TOKEN"
```

提示：若不使用 JWT，本地也可直接使用静态令牌：`-H 'Authorization: Bearer dev-token' -H 'X-User-Permissions: fans'`。

### 2）创建粉丝（Create）
```
FID=$(curl -sS -X POST http://localhost:8081/api/v1/fans \
  -H "Authorization: Bearer $TOKEN" \
  -H 'X-User-Permissions: fans' \
  -H 'Content-Type: application/json' \
  --data-binary '{"name":"小明","gender":"male","birthday":"1990-01-01","zodiac":"aries"}' \
  | tee /tmp/fans-create.json \
  | sed -n 's/.*"id":[ ]*\([0-9]\+\).*/\1/p')
echo "Created fan id=$FID"
```

成功示例（data 为创建后的实体）：
```
{"code":"OK","message":"success","requestId":"...","data":{"id":1,"name":"小明","gender":"male","birthday":"1990-01-01","zodiac":"aries","createdAt":"2025-10-03T17:00:00Z"}}
```

### 3）列表查询（List）
```
curl -sS -X GET 'http://localhost:8081/api/v1/fans?pageSize=5' \
  -H "Authorization: Bearer $TOKEN" \
  -H 'X-User-Permissions: fans'
```
分页字段：`data.items[]` 与 `data.page.pageSize/nextAfterId/hasMore/total`。也支持 `limit/offset`：
```
curl -sS -X GET 'http://localhost:8081/api/v1/fans?limit=10&offset=0' \
  -H "Authorization: Bearer $TOKEN" \
  -H 'X-User-Permissions: fans'
```

### 4）按 ID 查询（Get）
```
curl -sS -X GET http://localhost:8081/api/v1/fans/id/$FID \
  -H "Authorization: Bearer $TOKEN" \
  -H 'X-User-Permissions: fans'
```

### 5）更新粉丝（Update）
```
curl -sS -X PUT http://localhost:8081/api/v1/fans/id/$FID \
  -H "Authorization: Bearer $TOKEN" \
  -H 'X-User-Permissions: fans' \
  -H 'Content-Type: application/json' \
  --data-binary '{"name":"小明-更新","zodiac":"taurus"}'
```

### 6）删除粉丝（Delete）
```
curl -sS -X DELETE http://localhost:8081/api/v1/fans/id/$FID \
  -H "Authorization: Bearer $TOKEN" \
  -H 'X-User-Permissions: fans'
```
成功示例：`{"code":"OK","message":"success","requestId":"...","data":{"deleted":true,"id":<FID>}}`

### 7）404 示例（NotFound）
```
curl -sS -X GET http://localhost:8081/api/v1/fans/id/999999 \
  -H "Authorization: Bearer $TOKEN" \
  -H 'X-User-Permissions: fans'
```
失败示例：
```
{"code":"E404","message":"NotFound","requestId":"...","hint":"粉丝不存在","severity":"warning","detail":{"id":999999}}
```

说明：
- Fans JSON 字段：`id/name/gender/birthday/zodiac/createdAt`。
- 请求体（Create/Update）支持字段：`name`（Create 必填）、`gender`、`birthday`、`zodiac`。
- 所有 Fans 端点均要求权限 `fans`，RBAC 通过 `X-User-Permissions` 或 JWT 中的 `permissions` 满足。

## 限流配置
- 环境变量：
  - `RATE_LIMIT_RPS` 每秒令牌速率（默认 `5`）
  - `RATE_LIMIT_BURST` 突发容量（默认 `10`）
- 当超限时，返回统一错误：`E2000`（TooManyRequests）。

## CI 与质量
- 代码格式化：`make fmt`
- 静态检查：`make vet`
- 基础 lint 汇总：`make lint`（包含 fmt 与 vet）
- 一键门禁：`make ci`（tidy + lint + test）

### speccheck 一致性检查（支持可选 DB 预检）
- 入口：GitHub Actions 工作流 `.github/workflows/speccheck.yml`，执行 `bash scripts/ci/speccheck.sh`。
- 可选数据库预检（DDL + seed）：
  - 当配置下列环境变量（建议通过仓库 Secrets 设置）时，speccheck 会在一致性检查前尝试连接 MySQL，自动执行 DDL 与 seed，并进行基础验证（表行数、外键采样）。
  - 若未提供或无法连接数据库，speccheck 将自动跳过 DB 预检，仅执行一致性检查，不影响 CI 通过。
  - 支持的变量：
    - `DB_DSN`：完整 DSN（优先级最高），示例：`user:pass@tcp(127.0.0.1:3306)/xingzuo_dev?parseTime=true&multiStatements=true`
    - 或分解参数：`DB_HOST`、`DB_PORT`、`DB_USER`、`DB_PASS`、`DB_NAME`、`DB_UNIX_SOCKET`
  - 预检执行内容：
    - DDL：`scripts/db/apply_ddl.sh`（读取 `scripts/db/nlp_spec_automation.sql`）
    - Seed：`scripts/db/apply_seed.sh`（读取 `scripts/db/seed.sql`）
    - 日志：`scripts/reports/db/nlp-spec-automation/ddl-apply.log`、`scripts/reports/db/nlp-spec-automation/seed-apply.log`
  - GitHub Secrets 示例：
    - `DB_HOST=127.0.0.1`、`DB_PORT=3306`、`DB_USER=xingzuo`、`DB_PASS=devpass`、`DB_NAME=xingzuo_dev`
    - 或直接设置 `DB_DSN=user:pass@tcp(127.0.0.1:3306)/xingzuo_dev?parseTime=true&multiStatements=true`
  - 本地复核：
    - `bash scripts/ci/speccheck.sh`（支持从当前环境读取 `DB_*` 变量）
    - 或通过 `make speccheck-ci`

## 规格自动化与数据库管线
- 端到端生成（读取《策划.md》→ 规格文档 → MySQL DDL）：
  - `go run ./cmd/specpipe gen`
  - 输出：`.spec-workflow/specs/xingzuo/{requirements.md,design.md,tasks.md}` 与 `scripts/db/{create.sql,migrate.sql,rollback.sql}`。
  - 也可使用已编译 CLI：`./dist/specpipe gen`
- 从 ai-codegen 规格自动生成 xingzuo 规格与数据库（自然语言 → 标准技术文档 → DDL；支持同义词与自动建库）：
  - 基本用法（仅生成文档与 DDL，不执行数据库变更）：
    - `go run ./cmd/specpipe gen --source-spec=ai-codegen --out-spec=xingzuo --terms=scripts/config/terms.json`
  - 完整用法（含自动建库，需提供 DSN 或环境）：
    - `export XZ_APPROVED_TICKET='TICKET-123'`
    - `export XZ_DB_TEST_DSN='user:pass@tcp(127.0.0.1:3306)/xingzuo?parseTime=true&multiStatements=true'`
    - `go run ./cmd/specpipe gen --source-spec=ai-codegen --out-spec=xingzuo --terms=scripts/config/terms.json --apply-db=true --dsn-env=test --ticket=TICKET-123`
  - 自然语言输入（无需文件）：
    - 直接在命令行提供文本：
      - `./dist/specpipe gen --source-text "请为占卜业务设计用户(fan)、话题(topic)、占卜师(anchor)与对话(conversation)等实体及关系..." --openapi-out=dist/openapi.json`
    - 从标准输入读取：
      - `echo "中文PRD内容..." | ./dist/specpipe gen --stdin --openapi-out=dist/openapi.json`
  - 可选参数：
    - `--source-spec=<name>`：从 `.spec-workflow/specs/<name>/requirements.md` 读取自然语言需求（如 `ai-codegen`）。
    - `--source-file=<path>`：直接指定源 Markdown 文件（优先级高于 `--source-spec`）。
    - `--source-text="<中文PRD文本...>"`：直接从命令行提供自然语言需求文本（优先级最高）。
    - `--stdin=true`：从标准输入读取自然语言需求文本（与 `--source-text` 互斥）。
    - `--out-spec=<name>`：输出规格目录名（默认 `xingzuo`）。
    - `--terms=<path>`：同义词 JSON（键：复数/别名；值：规范术语）。将合并到 DomainModel.Terms，用于实体/资源规范化。
    - `--openapi-out=<path>`：将生成的 OpenAPI 3 文档写入指定路径（例如 `dist/openapi.json`）。生成的 paths 按 snake_case 复数规范，包含标准 CRUD 端点与组件 Schemas，便于前端/网关直接消费及 speccheck 对比。
    - `--apply-db=true|false`：是否在生成 DDL 后自动执行数据库变更（默认 `false`）。
    - `--dsn=<mysql_dsn>` 或 `--dsn-env=test|staging|prod`：数据库连接（当 `--apply-db=true` 必需）。
    - `--ticket=<id>`：执行审批票据（当 `--apply-db=true`，且未干跑时必须与 `XZ_APPROVED_TICKET` 匹配）。
  - 生成内容：
    - 文档：`.spec-workflow/specs/<out-spec>/{requirements.md,design.md,tasks.md}`（标题随 `<out-spec>` 动态生成）。
    - DDL：`scripts/db/{create.sql,migrate.sql,rollback.sql}`。
    - OpenAPI：`.spec-workflow/specs/<out-spec>/openapi.generated.json`（规范生成物）与可选导出文件（如 `dist/openapi.json`）。
  - 说明：
    - NLP 解析通过 `internal/nlp/pipeline.go` 将自然语言需求转换为 DomainModel，并附带澄清问题列表。
    - `--terms` 将在解析后合并到 `DomainModel.Terms`，用于资源与实体名的规范化（降低命名差异导致的后续一致性误报）。
    - OpenAPI 资源路径采用 snake_case 复数形式（如 `/fans`, `/fortune_records`），与 speccheck 的命名规范一致；复数与别名通过 `Terms` 自动规范化。
    - 自动建库使用 `ddl.Run` 的 CHANGE 通道与审批门禁，执行过程会产生日志到 `scripts/db/audit/`。
  - Makefile 一键生成（spec-gen-prd）：
    - 干跑（仅生成文档与 DDL，不执行数据库）：
      - `make spec-gen-prd`（默认读取 `.spec-workflow/sources/策划.md`，输出到 `.spec-workflow/specs/xingzuo`）
    - 指定输出规格名：
      - `make spec-gen-prd OUT_SPEC=xingzuo`（源仍为《策划.md》）
    - 自动建库（测试环境，需票据）：
      - `source .env.example && export XZ_DB_TEST_DSN='user:pass@tcp(127.0.0.1:3306)/xingzuo?parseTime=true&multiStatements=true'`
      - `export XZ_APPROVED_TICKET='TICKET-123'`
      - `make spec-gen-prd APPLY_DB=true DSN_ENV=test TICKET=TICKET-123`
    - 可选：直接传入 DSN 而非环境：
      - `make spec-gen-prd APPLY_DB=true DSN='user:pass@tcp(127.0.0.1:3306)/xingzuo?parseTime=true&multiStatements=true' TICKET=TICKET-123`
    - 说明：`spec-gen-prd` 等同于执行 `go run ./cmd/specpipe gen --out-spec=<OUT_SPEC> --terms=scripts/config/terms.json [--apply-db] [--dsn-env|--dsn] [--ticket]`，优先级为 `source-text > stdin > source-file > source-spec > sources/策划.md`（Makefile 目标使用默认源《策划.md》）。
  - nlpgen 子命令（按模块输出）：
    - `go run ./cmd/specpipe nlpgen --module-name=user-order --source-file=.spec-workflow/sources/策划.md --speccheck=true --openapi-out=dist/openapi.json`
    - 说明：输出文档到 `.spec-workflow/specs/xingzuo/user-order`，并可选 speccheck 一致性比对。
- DDL 预览（不连接数据库）：
  - `go run ./cmd/specpipe db-preview --channel=CHANGE`（支持 READ/CHANGE/ROLLBACK）
- DDL 执行器（db-runner）：
  - 环境变量（示例在 `.env.example`）：
    - `XZ_DB_TEST_DSN` / `XZ_DB_STAGING_DSN` / `XZ_DB_PROD_DSN`（go-sql-driver/mysql DSN 格式：`user:pass@tcp(127.0.0.1:3306)/xingzuo?parseTime=true&multiStatements=true`）
    - `XZ_DB_OP_TIMEOUT`（单次操作超时，默认 `30s`）
    - `XZ_APPROVED_TICKET`（审批票据；与 CLI `--ticket` 一致时才允许 CHANGE/ROLLBACK 非干跑执行）
  - 变更执行（测试环境，干跑）：
    - `go run ./cmd/specpipe db-runner --channel=CHANGE --dry-run=true`
  - 变更执行（测试环境，真实执行）：
    - `source .env.example && export XZ_DB_TEST_DSN='user:pass@tcp(127.0.0.1:3306)/xingzuo?parseTime=true&multiStatements=true'`
    - `export XZ_APPROVED_TICKET='TICKET-123'`
    - `go run ./cmd/specpipe db-runner --channel=CHANGE --dsn-env=test --ticket=TICKET-123`
  - 回滚执行（测试环境，真实执行）：
    - `go run ./cmd/specpipe db-runner --channel=ROLLBACK --dsn-env=test --ticket=TICKET-123`
  - 审计日志：每次运行都会落盘到 `scripts/db/audit/YYYYMMDD-HHMM.jsonl`，包含 `ticketId/channel/dsn/sqlHash/dryRun/startedAt/endedAt/status/error/statements`。
  - 安全提示：READ 通道始终干跑；CHANGE/ROLLBACK 在未设置或票据不匹配时将被拒绝（状态 `skipped`）。

## ai-codegen 数据库 DDL 预览与执行

为确保从规范到数据库的安全落地，建议按以下流程操作：

- 预览变更（必做）
  - 运行：`./dist/specpipe db-preview`
  - 会输出变更通道与唯一 sqlHash，示例：
    - `Preview channel=CHANGE sqlHash=8cdc7b10e435f450bc4060e40bdbc8421c6422717ba5d273fb20e5c7d1dcca53`
  - 本次预览已归档到：`scripts/reports/req-ai-codegen-010/ddl_preview.txt`
  - 预览包含即将创建的表、外键与约束（当前包含：`anchor`、`fan`、`tag`、`fan_tags`）

- 执行前检查（必做）
  - 确认数据库连接配置：`config/db.yaml`（host、port、user、database、权限）
  - 备份目标库或先在开发/测试库演练，避免直接影响生产
  - 通过审批：在 Dashboard/VS Code 扩展中对“db-runner 应用 DDL”审批通过后再执行

- 应用到开发库（需审批通过）
  - 运行：`./dist/specpipe db-runner`
  - 在执行前准备回滚脚本与验证步骤，记录成功与失败日志以便追踪

- 回滚（出现问题时）
  - 回滚脚本位置：`scripts/db/rollback.sql`
  - 示例：`mysql -h <host> -P <port> -u <user> -p <database> < scripts/db/rollback.sql`

- 常见问题与提示
  - 与 `scripts/db/create.sql` 的一致性：当前预览与 create.sql 一致，涵盖 `anchor`、`fan`、`tag`、`fan_tags` 及外键；如规范更新，请先跑预览并走审批再执行
  - 幂等性：部分 DDL 使用 `IF NOT EXISTS` 可避免重复创建，但外键与索引的更新仍需谨慎评估
  - 权限不足：确保执行用户拥有建表、建索引、创建外键等权限；否则 db-runner 可能失败
  - 索引与优化：后续任务将补充必要索引与优化建议，请在审批与预览环节一并评估

## 规格一致性检查（speccheck）
- 用途：校验《策划.md》生成的 DomainModel 与 DDL、OpenAPI 的一致性（表/列、资源路径、组件 Schemas）。
- 运行：
  - 推荐使用导出的 OpenAPI：
    - `./dist/specpipe speccheck --ddl=scripts/db/create.sql --openapi=dist/openapi.json --terms=scripts/config/terms.json`
  - 若已有历史报告中的 OpenAPI，也可指定：
    - `go run ./cmd/specpipe speccheck --ddl=scripts/db/create.sql --openapi=scripts/reports/req-ai-codegen-009/openapi.json --terms=scripts/config/terms.json`
  - 报告输出：`scripts/reports/consistency/speccheck-YYYYMMDD-HHMMSS.json`
- 可选配置：
  - 同义词文件（`--terms`）：JSON 映射（键为资源名或其复数/别名，值为规范术语，大小写不敏感）。示例 `scripts/config/terms.json`：
    - `{ "anchors": "Anchor", "fans": "Fan", "tags": "Tag", "conversations": "Conversation", "fortune_services": "FortuneService", "fortune_records": "FortuneRecord", "topics": "Topic", "scripts": "Script", "workflows": "Workflow" }`
    - speccheck 会按同义词规范化并自动复数化与 snake_case，降低命名差异误报。
  - 忽略资源（环境变量）：`XZ_SPECCHECK_IGNORE_RESOURCES="billing,observe,ai,registry,api,auth,article"`
    - speccheck 默认忽略上述平台/系统资源的路径（含复数形式），可按需扩展。
- Makefile：
  - `make speccheck`（本地生成一致性报告）
  - `make speccheck-ci`（CI 门禁，生成稳定工件 `scripts/reports/consistency/speccheck-report.json` 并按阈值判定）
- CI 阈值（环境变量）：
  - `SPECCHECK_FAIL_THRESHOLD`（默认 `0`）：允许的总问题数（DDL: 缺表/多表/缺列/类型不匹配；OpenAPI: 缺资源/多资源/缺组件实体/缺字段/类型不匹配）。超过则失败。
- 误报治理：
  - 已自动忽略多对多联结表（如 `fan_tags`），避免 DDL 多表误报。
  - OpenAPI 资源命名通过 `Terms` 同义词规范化；生成的 paths 已按 snake_case 复数对齐 speccheck；若 paths 尚未补齐但存在组件 Schemas，会视为资源已覆盖以减少误报。

## 可选配置
- DB Runner 模板：`config/db.yaml`（ENV 优先生效）。包含 DSN、审批策略、操作窗口、审计保留期与命名约定示例。

## aicodegen CLI 使用与审计

- 用途：解析 `.spec-workflow/sources/策划.md`（或指定源），生成标准化文档（requirements/design/tasks）、MySQL DDL（create/migrate/rollback）与 OpenAPI。
- 基本用法：
  - `./aicodegen`（默认读取 `.spec-workflow/sources/策划.md`，输出到 `.spec-workflow/specs/ai-codegen/` 与 `scripts/db/`）
  - `./aicodegen --apply-db=false`（仅生成文档与DDL，不执行数据库）
  - `./aicodegen --dsn-env=staging`（指定环境变量 DSN，支持 `test|staging|prod`）
  - `./aicodegen --source-file=path/to.md`（指定 PRD 源文件）
  - `./aicodegen --out-spec=ai-codegen/auto`（指定输出目录名或子目录）
  - `./aicodegen --openapi-out=dist/openapi.aicodegen.json`（额外导出 OpenAPI 文件）
  - `./aicodegen --ticket=REQ-123`（在启用审批门禁时传入票据以执行变更）
- 自动建库：当检测到 DSN（`--dsn` 或 `--dsn-env` 对应环境变量存在）且未显式禁用时，会自动执行数据库创建/迁移（使用 `ddl.Run` 的 CHANGE 通道）。
- 审计记录：
  - 文档与DDL生成会在控制台打印审计日志行（action=`aicodegen_run`），包含源信息、输出路径、实体/关系数量与澄清问题 ID 等元数据。
  - 可选转发到服务端 `POST /api/v1/observe/events`（需开启环境变量）：
    - `AUDIT_FORWARD_ENABLE=true`：启用转发。
    - `OBSERVE_ENDPOINT=http://127.0.0.1:8080/api/v1/observe/events`：转发端点（为空时默认使用本地 `PORT` 拼接）。
    - `OBSERVE_TOKEN=***`：转发使用的 Bearer Token（当无请求上下文时使用）。
    - `AUDIT_USER_ID=<user>`：CLI/后台审计默认的 userId（可选）。
  - 数据库执行的审计会额外落盘 JSONL 到 `scripts/db/audit/YYYYMMDD-HHMM.jsonl`（由 `internal/ddl/runner.go` 实现）。
- 相关环境示例：参见根目录 `.env.example` 或使用 `scripts/config/env-gen.sh` 生成，并通过 `scripts/ci/envcheck.sh` 校验。

## CI 使用说明

- 一键执行：`make ci`
  - 执行序列：tidy → lint → test → contract → security → env-check → aicodegen-dryrun → build-app → deploy → openapi → speccheck-ci。
  - 说明：
    - env-check 会优先读取 `.env`，不存在时回退到 `.env.example`，并输出脱敏预览。
    - aicodegen-dryrun 目标会运行 `scripts/ci/aicodegen-dryrun.sh`，生成规格与 DDL、OpenAPI，并检查 stdout 中的审计日志行。
    - speccheck-ci 依赖 jq（若缺失则仅生成报告并跳过阈值判断）。

- aicodegen 干跑目标：`make aicodegen-dryrun`
  - 使用的脚本：`scripts/ci/aicodegen-dryrun.sh`
  - 可选环境：
    - `OUT_SPEC`（默认 `ai-codegen/ci`）生成到 `.spec-workflow/specs/<OUT_SPEC>/`
    - `OPENAPI_OUT`（默认 `dist/openapi.aicodegen.json`）
    - `APPLY_DB`（默认 `false`）
  - 校验内容：
    - 规格文件（requirements/design/tasks/openapi.generated.json）
    - DDL 文件（scripts/db/create.sql|migrate.sql|rollback.sql）
    - OpenAPI 输出文件存在
    - stdout 包含 `[AUDIT] action=aicodegen_run` 日志行

- 常见问题
  - Makefile 报错“缺失分隔符”：确保配方行使用制表符（tab）而非空格。
  - 本地无 jq：speccheck-ci 会跳过阈值门禁，但仍生成报告。
  - 审计转发未生效：检查 `AUDIT_FORWARD_ENABLE=true`、`OBSERVE_ENDPOINT` 与 `OBSERVE_TOKEN` 是否配置；CLI/后台可选设置 `AUDIT_USER_ID`。
  - 生成 `.env`：用 `scripts/config/env-gen.sh`（可传 `dev|staging|prod`）生成，再执行 `make env-check` 验证。

## 审批门禁（Approval Gate）与示例
- 说明：对关键操作（如批量导出、DDL 变更）启用统一审批门禁。客户端需在请求头携带 `X-Approval-Ticket`，服务端将校验是否在白名单（环境变量 `APPROVAL_TICKETS`）内。
- 配置：在环境中设置白名单（逗号分隔）：`APPROVAL_TICKETS="TICKET-123,TICKET-456"`
- 权限：仍需 `Authorization: Bearer <token>` 与 `X-User-Permissions` 对应资源权限。

### 使用示例
- 回复模板预览（无需审批票据，仅 RBAC）：
  - 请求：
    - `POST /api/v1/reply_templates/preview`
    - 头：`Authorization: Bearer dev-token`、`X-User-Permissions: reply_templates`
    - 体：`{"content":"Hello {{name}}","vars":{"name":"Alice"},"strict":true}`
  - 响应：`{"code":"OK","data":{"preview":"Hello Alice","issues":[]},"requestId":"..."}`

- 粉丝批量导出（需审批票据 + RBAC）：
  - 请求：
    - `POST /api/v1/fans/export`
    - 头：`Authorization: Bearer dev-token`、`X-User-Permissions: fans`、`X-Approval-Ticket: TICKET-123`
    - 体：`{"format":"csv","anchorId":"a_001","tagIds":["t1","t2"],"active":true}`
  - 响应：统一响应包裹，`data.csvContent` 为 CSV 文本占位（后续接数据库查询与真实数据）。

- 粉丝会话唯一约束（仅 RBAC）：
  - 说明：确保每个粉丝（fanId）同一时间仅有一个活跃会话（conversationId）。
  - GET 当前活跃会话：
    - `GET /api/v1/fans/{fanId}/active_conversation`
    - 头：`Authorization: Bearer dev-token`、`X-User-Permissions: fans`
    - 响应示例（无活跃会话时 conversationId 为空字符串）：
      - `{"code":"OK","data":{"fanId":"f_001","conversationId":""},"requestId":"..."}`
  - 设置活跃会话：
    - `POST /api/v1/fans/{fanId}/active_conversation`
    - 头：`Authorization: Bearer dev-token`、`X-User-Permissions: fans`
    - 体：`{"conversationId":"c_123"}`
    - 成功响应：`{"code":"OK","data":{"fanId":"f_001","conversationId":"c_123"},"requestId":"..."}`
    - 冲突示例（已有其他活跃会话时返回 409）：
      - 状态：`409`
      - 体：`{"code":"E1400","message":"Conflict","hint":"已有活跃会话，请先终止","severity":"warning","detail":{"fanId":"f_001"},"requestId":"..."}`
  - 清除活跃会话：
    - `DELETE /api/v1/fans/{fanId}/active_conversation`
    - 头：`Authorization: Bearer dev-token`、`X-User-Permissions: fans`
    - 响应：`{"code":"OK","data":{"fanId":"f_001","cleared":true},"requestId":"..."}`

## 澄清服务（Clarify）

- 作用：根据自然语言输入（prompt），快速生成结构化澄清产物，包括 Requirements、Design、Tasks 以及最小 OpenAPI 片段，支持同步与 SSE 流式输出。
- 端点：
  - `POST /api/v1/ai/clarify/generate`（同步生成）
  - `GET  /api/v1/ai/clarify/stream`（SSE 流式）
- 鉴权与权限：
  - 头：`Authorization: Bearer <token>`（见上文“鉴权与权限”）
  - 头：`X-User-Permissions: ai.clarify`
- 请求字段：
  - `prompt`（string）：自然语言需求或业务描述
  - `language`（string，可选）：输出语言（默认 `zh-CN`，支持 `en-US`）
  - `useStructured`（boolean，可选）：启用结构化解析（更严格）
  - `stream`（boolean，可选）：是否要求流式（同步端点通常忽略此字段）
- 成功响应（统一包裹）：`{"code":"OK","message":"success","requestId":"...","data":{requirements:[],design:[],tasks:[],openapi:{...},issues:[]}}`

### curl 示例（同步生成）

```
curl -X POST http://localhost:/api/v1/ai/clarify/generate \
  -H 'Authorization: Bearer dev-token' \
  -H 'X-User-Permissions: ai.clarify' \
  -H 'Content-Type: application/json' \
  -d '{"prompt":"一个简易文章发布系统","language":"zh-CN","useStructured":false}'
```

成功响应示例（截断）：
```
{
  "code": "OK",
  "data": {
    "requirements": ["输入: 一个简易文章发布系统", "明确目标与范围", "识别关键角色与流程", "列出约束与依赖"],
    "design": ["模块划分与接口草案", "数据模型初稿", "安全与审计要求"],
    "tasks": ["编写需求文档", "整理设计方案", "拆解开发任务"],
    "openapi": {"openapi":"3.0.0","paths":{"/api/v1/ai/clarify/generate":{"post":{}},"/api/v1/ai/clarify/stream":{"get":{}}}}
  },
  "requestId": "..."
}
```

### SSE 示例（流式输出）

```
curl -N "http://localhost:/api/v1/ai/clarify/stream?prompt=%E4%B8%80%E4%B8%AA%E7%AE%80%E6%98%93%E6%96%87%E7%AB%A0%E5%8F%91%E5%B8%83%E7%B3%BB%E7%BB%9F&language=zh-CN" \
  -H 'Authorization: Bearer dev-token' \
  -H 'X-User-Permissions: ai.clarify' \
  -H 'Accept: text/event-stream'
```

示例帧（截断）：
```
data: {"type":"requirements","data":["输入: 一个简易文章发布系统","明确目标与范围",...]}

data: {"type":"design","data":["模块划分与接口草案",...]}

data: {"type":"tasks","data":["编写需求文档",...]}

event: done
data: {"ok":true}
```

### Quick examples (en-US)

- Sync generate:
```
curl -X POST http://localhost:/api/v1/ai/clarify/generate \
  -H 'Authorization: Bearer dev-token' \
  -H 'X-User-Permissions: ai.clarify' \
  -H 'Content-Type: application/json' \
  -d '{"prompt":"A simple article publishing system","language":"en-US"}'
```

- SSE stream:
```
curl -N "http://localhost:/api/v1/ai/clarify/stream?prompt=A%20simple%20article%20publishing%20system&language=en-US" \
  -H 'Authorization: Bearer dev-token' \
  -H 'X-User-Permissions: ai.clarify' \
  -H 'Accept: text/event-stream'
```

提示：示例使用默认端口 `8080`。若你在不同端口运行（如 `PORT=8081`），请替换为对应地址。