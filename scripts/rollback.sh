#!/usr/bin/env bash
set -euo pipefail

# Simple rollback script: restore previous deployed binary if available.
ROOT_DIR=$(cd "$(dirname "$0")"/.. && pwd)
DIST_DIR="${ROOT_DIR}/dist"

if [[ ! -d "${DIST_DIR}" ]]; then
  echo "dist directory not found: ${DIST_DIR}" >&2
  exit 1
fi

if [[ -f "${DIST_DIR}/app.prev" ]]; then
  cp "${DIST_DIR}/app.prev" "${DIST_DIR}/app"
  echo "Rollback completed: restored dist/app from dist/app.prev"
else
  echo "No previous build to rollback (dist/app.prev not found)." >&2
  exit 2
fi