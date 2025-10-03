#!/usr/bin/env bash
set -euo pipefail

# Validate a sanitized .env file (no DB connections).
# Usage: scripts/config/env-validate.sh <path-to-env>

if [[ ${1:-} == "" ]]; then
  echo "Usage: $0 <env-file>" >&2
  exit 2
fi
ENV_FILE="$1"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "[ERROR] File not found: $ENV_FILE" >&2
  exit 2
fi

declare -A env
while IFS='=' read -r k v; do
  # Strip comments and blanks
  [[ "$k" =~ ^\s*# ]] && continue
  [[ -z "$k" ]] && continue
  # Preserve value (may contain '=')
  if [[ "$k" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    env[$k]="${v}"
  fi
done < <(grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$ENV_FILE" | sed -E 's/[[:space:]]+$//')

fail=false
warn=false

require() {
  local key="$1"
  if [[ -z "${env[$key]:-}" ]]; then
    echo "[ERROR] Missing required key: $key" >&2
    fail=true
  fi
}

is_int() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

check_port() {
  local p="$1"
  if ! is_int "$p" || (( p < 1 || p > 65535 )); then
    echo "[ERROR] Invalid PORT: $p" >&2
    fail=true
  fi
}

check_positive_int() {
  local name="$1"; local val="$2"
  if [[ -n "$val" ]] && ! is_int "$val"; then
    echo "[ERROR] $name must be positive integer: $val" >&2
    fail=true
  fi
}

check_enum() {
  local name="$1"; shift; local val="$1"; shift; local allowed=($@)
  local ok=false
  for a in "${allowed[@]}"; do [[ "$val" == "$a" ]] && ok=true; done
  if [[ "$ok" != true ]]; then
    echo "[ERROR] $name invalid: $val (allowed: ${allowed[*]})" >&2
    fail=true
  fi
}

looks_like_url_dsn() {
  [[ "$1" =~ ^[A-Za-z]+://[^@]+@[^:/?]+(:[0-9]+)?/[^?]+(\?.*)?$ ]]
}

looks_like_mysql_driver_dsn() {
  [[ "$1" =~ ^[^:@]+:[^@]+@tcp\([^:/?]+:[0-9]+\)/[^?]+(\?.*)?$ ]]
}

check_dsn() {
  local name="$1"; local dsn="$2"
  [[ -z "$dsn" ]] && return 0
  if looks_like_url_dsn "$dsn" || looks_like_mysql_driver_dsn "$dsn"; then
    :
  else
    echo "[ERROR] $name DSN format not recognized: $dsn" >&2
    fail=true
  fi
  # Warn if credentials not masked
  if [[ "$dsn" =~ :[^*@]+@ ]]; then
    echo "[WARN] $name appears to contain unmasked credentials; use *** as placeholder." >&2
    warn=true
  fi
}

# Required
require APP_ENV
require XZ_DB_TYPE

# Enums
[[ -n "${env[APP_ENV]:-}" ]] && check_enum APP_ENV "${env[APP_ENV]}" dev staging prod
[[ -n "${env[XZ_DB_TYPE]:-}" ]] && check_enum XZ_DB_TYPE "${env[XZ_DB_TYPE]}" mysql postgres
[[ -n "${env[XZ_APPLY_DB]:-}" ]] && check_enum XZ_APPLY_DB "${env[XZ_APPLY_DB]}" preview dry-run apply

# Numbers
[[ -n "${env[PORT]:-}" ]] && check_port "${env[PORT]}"
check_positive_int RATE_LIMIT_RPS "${env[RATE_LIMIT_RPS]:-}"
check_positive_int RATE_LIMIT_BURST "${env[RATE_LIMIT_BURST]:-}"
check_positive_int REDIS_DB "${env[REDIS_DB]:-}"
check_positive_int ARTICLES_DEDUP_TTL_MS "${env[ARTICLES_DEDUP_TTL_MS]:-}"

# DSNs
check_dsn XZ_DB_TEST_DSN "${env[XZ_DB_TEST_DSN]:-}"
check_dsn XZ_DB_STAGING_DSN "${env[XZ_DB_STAGING_DSN]:-}"
check_dsn XZ_DB_PROD_DSN "${env[XZ_DB_PROD_DSN]:-}"

# Secret placeholders (不强制 AUTH_TOKENS，因为本地联调常用明文占位 dev-token)
for k in JWT_SECRET REDIS_PASSWORD; do
  if [[ -n "${env[$k]:-}" && "${env[$k]}" != "" && ! "${env[$k]}" =~ \*\*\* ]]; then
    echo "[WARN] $k provided without masked placeholder (***)." >&2
    warn=true
  fi
done

# Apply mode guard
if [[ "${env[XZ_APPLY_DB]:-}" == "apply" ]]; then
  if [[ -z "${env[XZ_APPROVED_TICKET]:-}" ]]; then
    echo "[ERROR] XZ_APPLY_DB=apply requires XZ_APPROVED_TICKET." >&2
    fail=true
  fi
fi

if [[ "$fail" == true ]]; then
  echo "Validation: FAILED" >&2
  exit 1
fi
if [[ "$warn" == true ]]; then
  echo "Validation: OK with WARNINGS" >&2
else
  echo "Validation: OK" >&2
fi