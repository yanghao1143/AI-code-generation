#!/usr/bin/env bash
set -euo pipefail

# Fans CRUD CI smoke test: start server, run Python test, stop server

PORT=${PORT:-8081}
AUTH_TOKENS=${AUTH_TOKENS:-dev-token}
JWT_SECRET=${JWT_SECRET:-dev-secret}

BASE_URL="http://127.0.0.1:${PORT}"

if [ ! -x dist/app ]; then
  echo "dist/app not found or not executable. Run 'make build-app deploy' first." >&2
  exit 1
fi

echo "Starting server on ${BASE_URL}..."
(
  AUTH_TOKENS="${AUTH_TOKENS}" JWT_SECRET="${JWT_SECRET}" PORT="${PORT}" ./dist/app &
) || true

# Wait for health endpoint
for i in $(seq 1 40); do
  if curl -sS "${BASE_URL}/healthz" >/dev/null 2>&1; then
    break
  fi
  sleep 0.25
done

if ! curl -sS "${BASE_URL}/healthz" >/dev/null 2>&1; then
  echo "Server failed to become healthy at ${BASE_URL}/healthz" >&2
  exit 1
fi

echo "Running Fans CRUD smoke test..."
BASE_URL="${BASE_URL}" AUTH_TOKEN="${AUTH_TOKENS}" USER_PERMISSIONS="fans" \
  python3 scripts/smoke/fans_crud.py || {
    echo "Fans CRUD smoke test FAILED" >&2
    exit 1
  }

echo "Fans CRUD smoke test PASSED"