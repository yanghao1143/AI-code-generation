#!/usr/bin/env bash
set -euo pipefail

# speccheck CI script for nlp-spec-automation
# Usage:
#   ./scripts/ci/speccheck.sh
# Optional thresholds (env):
#   FAIL_ON_MISSING_TABLES, FAIL_ON_EXTRA_TABLES, FAIL_ON_MISSING_COLUMNS,
#   FAIL_ON_TYPE_MISMATCHES, FAIL_ON_MISSING_RESOURCES, FAIL_ON_EXTRA_RESOURCES,
#   FAIL_ON_SCHEMA_MISSING, FAIL_ON_FIELD_ISSUES

ROOT_DIR=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT_DIR"

SPEC_DIR=".spec-workflow/specs/nlp-spec-automation"
DDL="scripts/db/nlp_spec_automation.sql"
OPENAPI_JSON="$SPEC_DIR/openapi.generated.json"
TERMS="scripts/config/terms.json"
OUT_DIR="scripts/reports/consistency"
mkdir -p "$OUT_DIR"

# Optional: DB precheck (apply DDL + seed) before consistency check
DB_LOG_DIR="scripts/reports/db/nlp-spec-automation"
mkdir -p "$DB_LOG_DIR"
CI_DB_LOG="$DB_LOG_DIR/ci-precheck.log"

db_precheck() {
  echo "[speccheck][db] Precheck starting..." | tee -a "$CI_DB_LOG"
  # Map backend DB_* envs to MYSQL_* envs expected by scripts/db/*.sh
  export MYSQL_HOST="${MYSQL_HOST:-${DB_HOST:-127.0.0.1}}"
  export MYSQL_PORT="${MYSQL_PORT:-${DB_PORT:-3306}}"
  export MYSQL_USER="${MYSQL_USER:-${DB_USER:-root}}"
  export MYSQL_PASS="${MYSQL_PASS:-${DB_PASS:-}}"
  export MYSQL_DB="${MYSQL_DB:-${DB_NAME:-xingzuo_dev}}"

  # Build mysql args
  local args=( -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" )
  if [ -n "$MYSQL_PASS" ]; then args+=( -p"$MYSQL_PASS" ); fi

  if ! command -v mysql >/dev/null 2>&1; then
    echo "[speccheck][db] mysql client not found, skipping DB precheck" | tee -a "$CI_DB_LOG"
    return 0
  fi

  # Try a lightweight connectivity probe
  if ! mysql "${args[@]}" -e "SELECT 1" >/dev/null 2>&1; then
    echo "[speccheck][db] MySQL not reachable (host=$MYSQL_HOST port=$MYSQL_PORT user=$MYSQL_USER), skipping DB precheck" | tee -a "$CI_DB_LOG"
    return 0
  fi

  echo "[speccheck][db] MySQL reachable, applying DDL..." | tee -a "$CI_DB_LOG"
  MYSQL_HOST="$MYSQL_HOST" MYSQL_PORT="$MYSQL_PORT" MYSQL_USER="$MYSQL_USER" MYSQL_PASS="$MYSQL_PASS" MYSQL_DB="$MYSQL_DB" \
    bash scripts/db/apply_ddl.sh 2>&1 | tee -a "$CI_DB_LOG" || {
      echo "[speccheck][db] DDL apply failed, continuing without seed" | tee -a "$CI_DB_LOG" ; return 0;
    }

  echo "[speccheck][db] Applying seed data..." | tee -a "$CI_DB_LOG"
  MYSQL_HOST="$MYSQL_HOST" MYSQL_PORT="$MYSQL_PORT" MYSQL_USER="$MYSQL_USER" MYSQL_PASS="$MYSQL_PASS" MYSQL_DB="$MYSQL_DB" \
    bash scripts/db/apply_seed.sh 2>&1 | tee -a "$CI_DB_LOG" || {
      echo "[speccheck][db] Seed apply failed, proceeding with consistency check" | tee -a "$CI_DB_LOG" ; return 0;
    }

  echo "[speccheck][db] Precheck completed. Log: $CI_DB_LOG" | tee -a "$CI_DB_LOG"
}

db_precheck || true

timestamp=$(date +%Y%m%d-%H%M%S)
OUT="$OUT_DIR/speccheck-$timestamp.json"

RUN_LOG="$OUT_DIR/speccheck-run-$timestamp.log"
echo "[speccheck] Running consistency check..."
{ go run ./cmd/specpipe speccheck --ddl="$DDL" --openapi="$OPENAPI_JSON" --terms="$TERMS" --out="$OUT"; } 2>&1 | tee "$RUN_LOG"

# Determine actual output path (some versions of specpipe may write with its own timestamp)
OUT_REAL="$OUT"
if [[ ! -f "$OUT_REAL" ]]; then
  alt=$(grep -E 'Consistency report written:' "$RUN_LOG" | tail -n1 | sed -E 's/.*Consistency report written:\s*(.*)/\1/')
  if [[ -n "$alt" && -f "$alt" ]]; then
    OUT_REAL="$alt"
  else
    latest=$(ls -t "$OUT_DIR"/speccheck-*.json 2>/dev/null | head -n1 || true)
    if [[ -n "$latest" ]]; then OUT_REAL="$latest"; fi
  fi
fi

echo "[speccheck] Report written: $OUT_REAL"

# Try parse summary using jq if available, fallback to grep/awk parsing
if command -v jq >/dev/null 2>&1; then
  summary=$(jq -r '.summary' "$OUT_REAL")
  openapi_summary=$(jq -r '.openapi.summary' "$OUT_REAL")
else
  summary=$(grep -m1 '"summary"' "$OUT_REAL" | sed -E 's/.*"summary"\:\s*"(.*)".*/\1/')
  openapi_summary=$(grep -m1 '"summary"' "$OUT_REAL" -n | tail -n1 | sed -E 's/.*"summary"\:\s*"(.*)".*/\1/')
fi

echo "[speccheck] Summary: $summary"
echo "[speccheck] OpenAPI Summary: $openapi_summary"

parse_field() {
  local s="$1" key="$2"
  echo "$s" | awk -v k="$key" '{for(i=1;i<=NF;i++){split($i,a,"="); if(a[1]==k) {print a[2]; exit}}}'
}

mt=$(parse_field "$summary" "missingTables")
et=$(parse_field "$summary" "extraTables")
mc=$(parse_field "$summary" "missingColumnsTables")
tm=$(parse_field "$summary" "typeMismatchTables")

mrs=$(parse_field "$openapi_summary" "missingResources")
ers=$(parse_field "$openapi_summary" "extraResources")
sm=$(parse_field "$openapi_summary" "schemaMissing")
fi=$(parse_field "$openapi_summary" "fieldIssues")

FAIL_ON_MISSING_TABLES=${FAIL_ON_MISSING_TABLES:-0}
FAIL_ON_EXTRA_TABLES=${FAIL_ON_EXTRA_TABLES:-0}
FAIL_ON_MISSING_COLUMNS=${FAIL_ON_MISSING_COLUMNS:-0}
FAIL_ON_TYPE_MISMATCHES=${FAIL_ON_TYPE_MISMATCHES:-0}
FAIL_ON_MISSING_RESOURCES=${FAIL_ON_MISSING_RESOURCES:-0}
FAIL_ON_EXTRA_RESOURCES=${FAIL_ON_EXTRA_RESOURCES:-0}
FAIL_ON_SCHEMA_MISSING=${FAIL_ON_SCHEMA_MISSING:-0}
FAIL_ON_FIELD_ISSUES=${FAIL_ON_FIELD_ISSUES:-0}

fail=0
[[ -n "$mt" && ${mt:-0} -gt $FAIL_ON_MISSING_TABLES ]] && echo "[speccheck] Fail: missingTables=$mt > $FAIL_ON_MISSING_TABLES" && fail=1
[[ -n "$et" && ${et:-0} -gt $FAIL_ON_EXTRA_TABLES ]] && echo "[speccheck] Fail: extraTables=$et > $FAIL_ON_EXTRA_TABLES" && fail=1
[[ -n "$mc" && ${mc:-0} -gt $FAIL_ON_MISSING_COLUMNS ]] && echo "[speccheck] Fail: missingColumnsTables=$mc > $FAIL_ON_MISSING_COLUMNS" && fail=1
[[ -n "$tm" && ${tm:-0} -gt $FAIL_ON_TYPE_MISMATCHES ]] && echo "[speccheck] Fail: typeMismatchTables=$tm > $FAIL_ON_TYPE_MISMATCHES" && fail=1

[[ -n "$mrs" && ${mrs:-0} -gt $FAIL_ON_MISSING_RESOURCES ]] && echo "[speccheck] Fail: missingResources=$mrs > $FAIL_ON_MISSING_RESOURCES" && fail=1
[[ -n "$ers" && ${ers:-0} -gt $FAIL_ON_EXTRA_RESOURCES ]] && echo "[speccheck] Fail: extraResources=$ers > $FAIL_ON_EXTRA_RESOURCES" && fail=1
[[ -n "$sm" && ${sm:-0} -gt $FAIL_ON_SCHEMA_MISSING ]] && echo "[speccheck] Fail: schemaMissing=$sm > $FAIL_ON_SCHEMA_MISSING" && fail=1
[[ -n "$fi" && ${fi:-0} -gt $FAIL_ON_FIELD_ISSUES ]] && echo "[speccheck] Fail: fieldIssues=$fi > $FAIL_ON_FIELD_ISSUES" && fail=1

if [[ $fail -eq 1 ]]; then
  echo "[speccheck] Failed thresholds. See $OUT_REAL"
  exit 1
fi

echo "[speccheck] Passed. Report: $OUT_REAL"
exit 0