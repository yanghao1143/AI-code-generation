#!/usr/bin/env bash
set -euo pipefail

ENV_FILE=${ENV_FILE:-.env}
if [[ ! -f "$ENV_FILE" ]]; then
  echo "[INFO] $ENV_FILE not found, falling back to .env.example"
  ENV_FILE=.env.example
fi

echo "== Validate: $ENV_FILE =="
"$(dirname "$0")"/../config/env-validate.sh "$ENV_FILE" || exit 1

echo
echo "== Redacted preview =="
"$(dirname "$0")"/../config/env-redact.sh "$ENV_FILE" | head -n 50 || true
echo "(truncated)"