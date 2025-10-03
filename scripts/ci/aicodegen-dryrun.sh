#!/usr/bin/env bash
set -euo pipefail

# Run aicodegen in dry-run mode and verify outputs + audit log line
# Env (optional):
#   OUT_SPEC: output spec directory under .spec-workflow/specs (default ai-codegen/ci)
#   OPENAPI_OUT: output OpenAPI file path (default dist/openapi.aicodegen.json)
#   APPLY_DB: apply-db flag (default false)

echo "Running aicodegen dry-run..."

OUT_SPEC=${OUT_SPEC:-ai-codegen/ci}
OPENAPI_OUT=${OPENAPI_OUT:-dist/openapi.aicodegen.json}
APPLY_DB=${APPLY_DB:-false}

# Clean previous artifacts for a fresh run
SPEC_DIR=".spec-workflow/specs/${OUT_SPEC}"
rm -rf "${SPEC_DIR}" || true
rm -f scripts/db/create.sql scripts/db/migrate.sql scripts/db/rollback.sql || true
rm -f "${OPENAPI_OUT}" || true
mkdir -p "$(dirname "${OPENAPI_OUT}")"

LOG_FILE=$(mktemp)
echo "Invoking: go run ./cmd/aicodegen --apply-db=${APPLY_DB} --out-spec=${OUT_SPEC} --openapi-out=${OPENAPI_OUT}"
set -o pipefail
go run ./cmd/aicodegen --apply-db="${APPLY_DB}" --out-spec="${OUT_SPEC}" --openapi-out="${OPENAPI_OUT}" | tee "${LOG_FILE}"

# Verify generated files exist
missing=0
for f in requirements.md design.md tasks.md openapi.generated.json; do
  p="${SPEC_DIR}/${f}"
  if [[ ! -f "$p" ]]; then echo "[ERROR] Missing spec file: $p"; missing=$((missing+1)); fi
done
for f in scripts/db/create.sql scripts/db/migrate.sql scripts/db/rollback.sql; do
  if [[ ! -f "$f" ]]; then echo "[ERROR] Missing DDL file: $f"; missing=$((missing+1)); fi
done
if [[ ! -f "${OPENAPI_OUT}" ]]; then echo "[ERROR] Missing OpenAPI file: ${OPENAPI_OUT}"; missing=$((missing+1)); fi

if [[ "$missing" -gt 0 ]]; then
  echo "aicodegen dry-run failed: $missing missing artifacts"
  exit 1
fi

# Verify audit log line exists in stdout
if ! grep -q "\[AUDIT\] action=aicodegen_run" "${LOG_FILE}"; then
  echo "[ERROR] Audit log line not found in aicodegen output"
  echo "-- output preview --"; tail -n 50 "${LOG_FILE}" || true
  exit 2
fi

echo "aicodegen dry-run passed (artifacts present and audit log emitted)"