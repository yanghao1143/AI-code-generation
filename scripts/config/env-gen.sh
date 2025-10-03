#!/usr/bin/env bash
set -euo pipefail

# Generate a sanitized .env based on defaults and optional overrides.
# Usage: scripts/config/env-gen.sh [dev|staging|prod] > .env

ENV_NAME=${1:-dev}

# Optional overrides via environment
PORT=${PORT:-8080}
RATE_LIMIT_RPS=${RATE_LIMIT_RPS:-100}
RATE_LIMIT_BURST=${RATE_LIMIT_BURST:-100}

DEDUPER_BACKEND=${DEDUPER_BACKEND:-redis}
REDIS_ADDR=${REDIS_ADDR:-127.0.0.1:6379}
REDIS_PASSWORD=${REDIS_PASSWORD:-}
REDIS_DB=${REDIS_DB:-0}
ARTICLES_DEDUP_TTL_MS=${ARTICLES_DEDUP_TTL_MS:-600000}
ARTICLES_DEDUP_KEY_PREFIX=${ARTICLES_DEDUP_KEY_PREFIX:-articles:seen:}

XZ_DB_TYPE=${XZ_DB_TYPE:-mysql}
XZ_DB_VERSION=${XZ_DB_VERSION:-8.0.32}
XZ_APPLY_DB=${XZ_APPLY_DB:-preview}
XZ_DB_TEST_DSN=${XZ_DB_TEST_DSN:-}
XZ_DB_STAGING_DSN=${XZ_DB_STAGING_DSN:-}
XZ_DB_PROD_DSN=${XZ_DB_PROD_DSN:-}
XZ_DB_OP_TIMEOUT=${XZ_DB_OP_TIMEOUT:-30s}

cat <<EOF
## Runtime & Auth
APP_ENV=${ENV_NAME}
AUTH_TOKENS=dev-token
PORT=${PORT}
RATE_LIMIT_RPS=${RATE_LIMIT_RPS}
RATE_LIMIT_BURST=${RATE_LIMIT_BURST}

## Build metadata
BUILD_VERSION=
GIT_SHA=
BUILD_TIME=

## Redis Dedupe (optional)
DEDUPER_BACKEND=${DEDUPER_BACKEND}
REDIS_ADDR=${REDIS_ADDR}
REDIS_PASSWORD=${REDIS_PASSWORD}
REDIS_DB=${REDIS_DB}
ARTICLES_DEDUP_TTL_MS=${ARTICLES_DEDUP_TTL_MS}
ARTICLES_DEDUP_KEY_PREFIX=${ARTICLES_DEDUP_KEY_PREFIX}

## DB Runner
XZ_DB_TYPE=${XZ_DB_TYPE}
XZ_DB_VERSION=${XZ_DB_VERSION}
XZ_APPLY_DB=${XZ_APPLY_DB}
XZ_DB_TEST_DSN=${XZ_DB_TEST_DSN}
XZ_DB_STAGING_DSN=${XZ_DB_STAGING_DSN}
XZ_DB_PROD_DSN=${XZ_DB_PROD_DSN}
XZ_DB_OP_TIMEOUT=${XZ_DB_OP_TIMEOUT}
XZ_APPROVED_TICKET=

# JWT secret (optional, defaults to dev-secret if empty). Use masked value if set.
JWT_SECRET=
 
## Audit & Observe (optional)
# Enable forwarding audit events to /api/v1/observe/events
AUDIT_FORWARD_ENABLE=false
# Observe endpoint (defaults to local PORT when empty)
OBSERVE_ENDPOINT=
# Bearer token for forwarding (masked placeholder recommended)
OBSERVE_TOKEN=
# Default user id for CLI/background audit logs (optional)
AUDIT_USER_ID=
EOF