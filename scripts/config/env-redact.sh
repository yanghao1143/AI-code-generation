#!/usr/bin/env bash
set -euo pipefail

# Redact sensitive parts from a .env file to stdout.
# Usage: scripts/config/env-redact.sh <path-to-env>

if [[ ${1:-} == "" ]]; then
  echo "Usage: $0 <env-file>" >&2
  exit 2
fi
ENV_FILE="$1"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "[ERROR] File not found: $ENV_FILE" >&2
  exit 2
fi

# Mask password-like values and DSN credentials
sed -E \
  -e 's/^\s*(AUTH_TOKENS|JWT_SECRET|REDIS_PASSWORD)\s*=\s*.*/\1=***/g' \
  -e 's#([A-Za-z]+://[^:@]+):[^@]*@#\1:***@#g' \
  -e 's#^([A-Za-z_0-9]+_DSN=)([^:@=]+):[^@]*@tcp\(#\1\2:***@tcp(#g' \
  "$ENV_FILE"