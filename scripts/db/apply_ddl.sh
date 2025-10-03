#!/usr/bin/env bash
set -euo pipefail

# Apply DDL for nlp-spec-automation to a MySQL database and log output
# Environment variables:
#   MYSQL_HOST (default 127.0.0.1)
#   MYSQL_PORT (default 3306)
#   MYSQL_USER (default root)
#   MYSQL_PASS (no default; if empty, -p will NOT be passed)
#   MYSQL_DB   (default xingzuo_dev)

# Move to project root (apply_ddl.sh lives in scripts/db)
ROOT_DIR=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT_DIR"

LOG_DIR="scripts/reports/db/nlp-spec-automation"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/ddl-apply.log"

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

echo "[ddl] CWD: $(pwd)"
echo "[ddl] Target DB: $MYSQL_DB on $MYSQL_HOST:$MYSQL_PORT (user=$MYSQL_USER, pass_set=$([[ -n "$MYSQL_PASS" ]] && echo yes || echo no))"

# Write header and server version to log
{
  echo "==== DDL Apply Start: $(date -Is) ===="
  echo "CWD: $(pwd)"
  echo "Target DB: $MYSQL_DB on $MYSQL_HOST:$MYSQL_PORT (user=$MYSQL_USER, pass_set=$([[ -n "$MYSQL_PASS" ]] && echo yes || echo no))"
  echo "Server Version:"
} | tee "$LOG_FILE"

# Log MySQL server version
mysql "${MYSQL_ARGS[@]}" -e "SELECT VERSION() AS server_version;" | tee -a "$LOG_FILE"

# Create database if not exists with utf8mb4
echo ">>> Creating database if not exists with utf8mb4..." | tee -a "$LOG_FILE"
mysql "${MYSQL_ARGS[@]}" \
  -e "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DB\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>&1 | tee -a "$LOG_FILE" || {
  echo "[ddl] ERROR: Failed to create database. Check MySQL credentials and permissions." | tee -a "$LOG_FILE" ; exit 1;
}

# Apply DDL and tee log
echo ">>> Applying DDL from scripts/db/nlp_spec_automation.sql..." | tee -a "$LOG_FILE"
mysql "${MYSQL_ARGS[@]}" "$MYSQL_DB" \
  < scripts/db/nlp_spec_automation.sql \
  2>&1 | tee -a "$LOG_FILE"

# Post-apply summary: list tables and show create definitions
echo ">>> Summary: SHOW TABLES" | tee -a "$LOG_FILE"
mysql "${MYSQL_ARGS[@]}" -D "$MYSQL_DB" -e "SHOW TABLES;" | tee -a "$LOG_FILE"

TABLES=$(mysql "${MYSQL_ARGS[@]}" -D "$MYSQL_DB" -N -e "SHOW TABLES;")
for t in $TABLES; do
  echo ">>> SHOW CREATE TABLE $t" | tee -a "$LOG_FILE"
  # Use \G for vertical format for readability
  mysql "${MYSQL_ARGS[@]}" -D "$MYSQL_DB" -e "SHOW CREATE TABLE \`$t\`\\G" | tee -a "$LOG_FILE"
done

echo "[ddl] Completed. Log: $LOG_FILE"