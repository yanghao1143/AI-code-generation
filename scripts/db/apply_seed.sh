#!/usr/bin/env bash
set -euo pipefail

# Apply DDL and seed data for nlp-spec-automation to a MySQL database and log output
# Environment variables:
#   MYSQL_HOST (default 127.0.0.1)
#   MYSQL_PORT (default 3306)
#   MYSQL_USER (default root)
#   MYSQL_PASS (no default; if empty, -p will NOT be passed)
#   MYSQL_DB   (default xingzuo_dev)

# Move to project root (this script lives in scripts/db)
ROOT_DIR=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT_DIR"

LOG_DIR="scripts/reports/db/nlp-spec-automation"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/seed-apply.log"

MYSQL_HOST=${MYSQL_HOST:-127.0.0.1}
MYSQL_PORT=${MYSQL_PORT:-3306}
MYSQL_USER=${MYSQL_USER:-root}
MYSQL_PASS=${MYSQL_PASS:-}
MYSQL_DB=${MYSQL_DB:-xingzuo_dev}

# Build mysql args and avoid interactive prompt when password is empty
MYSQL_ARGS=( -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" )
if [ -n "$MYSQL_PASS" ]; then
  MYSQL_ARGS+=( -p"$MYSQL_PASS" )
fi

echo "[seed] CWD: $(pwd)"
echo "[seed] Target DB: $MYSQL_DB on $MYSQL_HOST:$MYSQL_PORT (user=$MYSQL_USER, pass_set=$([[ -n "$MYSQL_PASS" ]] && echo yes || echo no))"

{
  echo "==== Seed Apply Start: $(date -Is) ===="
  echo "CWD: $(pwd)"
  echo "Target DB: $MYSQL_DB on $MYSQL_HOST:$MYSQL_PORT (user=$MYSQL_USER, pass_set=$([[ -n \"$MYSQL_PASS\" ]] && echo yes || echo no))"
  echo "Server Version:"
} | tee "$LOG_FILE"

# Log MySQL server version
mysql "${MYSQL_ARGS[@]}" -e "SELECT VERSION() AS server_version;" | tee -a "$LOG_FILE"

echo ">>> Ensuring database and DDL are applied (calling scripts/db/apply_ddl.sh)" | tee -a "$LOG_FILE"
scripts/db/apply_ddl.sh 2>&1 | tee -a "$LOG_FILE"

echo ">>> Applying seed data from scripts/db/seed.sql..." | tee -a "$LOG_FILE"
mysql "${MYSQL_ARGS[@]}" "$MYSQL_DB" \
  < scripts/db/seed.sql \
  2>&1 | tee -a "$LOG_FILE" || {
  echo "[seed] ERROR: Failed to apply seed data. Check MySQL credentials, schema, and foreign keys." | tee -a "$LOG_FILE" ; exit 1;
}

# Post-apply verification: counts and simple integrity checks
echo ">>> Verification: table row counts" | tee -a "$LOG_FILE"
mysql "${MYSQL_ARGS[@]}" -D "$MYSQL_DB" -e "\
SELECT 'anchor' AS table_name, COUNT(*) AS cnt FROM anchor UNION ALL \
SELECT 'fan', COUNT(*) FROM fan UNION ALL \
SELECT 'tag', COUNT(*) FROM tag UNION ALL \
SELECT 'topic', COUNT(*) FROM topic UNION ALL \
SELECT 'script', COUNT(*) FROM script UNION ALL \
SELECT 'workflow', COUNT(*) FROM workflow UNION ALL \
SELECT 'fortune_service', COUNT(*) FROM fortune_service UNION ALL \
SELECT 'conversation', COUNT(*) FROM conversation UNION ALL \
SELECT 'fortune_record', COUNT(*) FROM fortune_record UNION ALL \
SELECT 'fan_tags', COUNT(*) FROM fan_tags;" | tee -a "$LOG_FILE"

echo ">>> Verification: foreign key sample joins" | tee -a "$LOG_FILE"
mysql "${MYSQL_ARGS[@]}" -D "$MYSQL_DB" -e "\
SELECT c.id, a.name AS anchor_name, f.name AS fan_name \
FROM conversation c \
JOIN anchor a ON a.id = c.anchor_id \
JOIN fan f ON f.id = c.fan_id \
ORDER BY c.id LIMIT 5;" | tee -a "$LOG_FILE"

echo ">>> Seed apply completed. Log: $LOG_FILE" | tee -a "$LOG_FILE"