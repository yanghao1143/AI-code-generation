run:
	go run ./cmd/app

build:
	go build ./...

build-app:
	mkdir -p bin
	go build -o bin/app ./cmd/app

build-aicodegen:
	mkdir -p bin
	go build -o bin/aicodegen ./cmd/aicodegen

tidy:
	go mod tidy

test:
	go test ./...

contract:
	go test ./internal/registry -run 'TestOpenAPI_' -v

fmt:
	go fmt ./...

vet:
	go vet ./...

lint:
	make fmt vet

security:
	@echo "Running security scans..."
	go vet ./...
	go mod verify
	@echo "Security scan completed."

deploy: build-app
	mkdir -p dist
	@if [ -f dist/app ]; then cp dist/app dist/app.prev; fi
	cp bin/app dist/app
	@echo "deployed at $(shell date -u +%Y-%m-%dT%H:%M:%SZ)" >> dist/deploy.log

ci:
    make tidy lint test contract security env-check aicodegen-dryrun build-app deploy openapi speccheck-ci smoke-fans

openapi:
	go run ./cmd/openapi -o .spec-workflow/specs/xingzuo/openapi.json

speccheck:
	go run ./cmd/specpipe speccheck --ddl=scripts/db/create.sql --openapi=scripts/reports/req-ai-codegen-009/openapi.json --terms=scripts/config/terms.json

speccheck-ci:
    bash scripts/ci/speccheck.sh

env-check:
	@bash scripts/ci/envcheck.sh

aicodegen-dryrun:
    bash scripts/ci/aicodegen-dryrun.sh

# Run Fans CRUD smoke test (starts dist/app, performs CRUD, expects 404 after delete)
smoke-fans:
    bash scripts/ci/smoke-fans.sh

# One-click PRD → Specs & DDL generation
# Usage examples:
#   make spec-gen-prd                      # 从 .spec-workflow/sources/策划.md 生成规格与 DDL（不执行 DB）
#   make spec-gen-prd OUT_SPEC=xingzuo     # 指定输出规格名
#   make spec-gen-prd APPLY_DB=true DSN_ENV=test TICKET=TICKET-123  # 自动建库（需 env/票据）
spec-gen-prd:
	@echo "Generating specs and DDL from .spec-workflow/sources/策划.md..."
	@out_spec=$${OUT_SPEC:-xingzuo}; apply_db=$${APPLY_DB:-false}; dsn_env=$${DSN_ENV:-}; dsn=$${DSN:-}; ticket=$${TICKET:-}; \
	cmd="go run ./cmd/specpipe gen --out-spec=$$out_spec --terms=scripts/config/terms.json"; \
	if [ "$$apply_db" = "true" ]; then cmd="$$cmd --apply-db=true"; fi; \
	if [ -n "$$dsn_env" ]; then cmd="$$cmd --dsn-env=$$dsn_env"; fi; \
	if [ -n "$$dsn" ]; then cmd="$$cmd --dsn=$$dsn"; fi; \
	if [ -n "$$ticket" ]; then cmd="$$cmd --ticket=$$ticket"; fi; \
	echo $$cmd; eval $$cmd