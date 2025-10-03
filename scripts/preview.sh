#!/usr/bin/env bash
set -euo pipefail

# Preview script: generate contract diff, performance and security reports.
# Usage: scripts/preview.sh <requestId>

ROOT_DIR=$(cd "$(dirname "$0")"/.. && pwd)
REQUEST_ID=${1:-preview-$(date +%s)}
REPORT_DIR="${ROOT_DIR}/scripts/reports/${REQUEST_ID}"
BASE_OPENAPI="${ROOT_DIR}/.spec-workflow/specs/xingzuo/openapi.json"

mkdir -p "${REPORT_DIR}"

echo "[Preview] requestId=${REQUEST_ID}" > "${REPORT_DIR}/SUMMARY.txt"

# 1) Contract: generate fresh OpenAPI and diff with baseline
echo "[Contract] Generating OpenAPI..."
go run "${ROOT_DIR}/cmd/openapi" -o "${REPORT_DIR}/openapi.json" >/dev/null 2>&1 || true
if [[ -f "${BASE_OPENAPI}" ]]; then
  echo "[Contract] Diff against baseline..."
  diff -u "${BASE_OPENAPI}" "${REPORT_DIR}/openapi.json" > "${REPORT_DIR}/openapi.diff" || true
else
  echo "[Contract] Baseline not found, skipping diff." >> "${REPORT_DIR}/SUMMARY.txt"
fi

# 2) Security: static checks & module verification
echo "[Security] Running checks..."
{
  echo "== go vet =="
  go vet "${ROOT_DIR}/..." || true
  echo
  echo "== go mod verify =="
  (cd "${ROOT_DIR}" && go mod verify) || true
} > "${REPORT_DIR}/security.txt" 2>&1

# 3) Performance: launch isolated app, probe healthz with latency percentiles & throughput
echo "[Performance] Probing /healthz on isolated server..."
PORT=9091 AUTH_TOKENS=dev-token RATE_LIMIT_RPS=100 RATE_LIMIT_BURST=100 \
  nohup go run "${ROOT_DIR}/cmd/app" >/dev/null 2>&1 &
APP_PID=$!

# Wait for server readiness up to ~4s
for i in $(seq 1 20); do
  CODE=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:9091/healthz" || true)
  if [[ "${CODE}" == "200" ]]; then break; fi
  sleep 0.2
done

SAMPLES=30
WARMUP=5
declare -a latencies

# Warmup requests (not recorded)
for i in $(seq 1 ${WARMUP}); do
  curl -s -w '%{time_total}\n' -o /dev/null "http://localhost:9091/healthz" >/dev/null 2>&1 || true
done

START_NS=$(date +%s%N)
for i in $(seq 1 ${SAMPLES}); do
  t=$(curl -s -w '%{time_total}\n' -o /dev/null "http://localhost:9091/healthz" || echo "0")
  latencies+=("${t}")
done
END_NS=$(date +%s%N)

# Compute percentiles and throughput
mapfile -t sorted_arr < <(printf "%s\n" "${latencies[@]}" | sort -n)
MIN_LAT="${sorted_arr[0]}"
MAX_LAT="${sorted_arr[$(( ${#sorted_arr[@]} - 1 ))]}"
AVG_LAT=$(printf "%s\n" "${latencies[@]}" | awk '{s+=$1} END {if (NR>0) printf "%.6f", s/NR; else print "0"}')

calc_pct() {
  local p=$1
  local n=${#sorted_arr[@]}
  local idx
  idx=$(awk -v p="${p}" -v n="${n}" 'BEGIN{v=int(p*n/100); if (v>=n) v=n-1; if (v<0) v=0; print v}')
  echo "${sorted_arr[$idx]}"
}

P50_LAT=$(calc_pct 50)
P90_LAT=$(calc_pct 90)
P99_LAT=$(calc_pct 99)

DUR_S=$(awk -v s="${START_NS}" -v e="${END_NS}" 'BEGIN{printf "%.3f", (e-s)/1000000000.0}')
THROUGHPUT=$(awk -v n="${SAMPLES}" -v d="${DUR_S}" 'BEGIN{if (d>0) printf "%.2f", n/d; else print "0.00"}')

{
  echo "== curl metrics (single check) =="
  curl -s -w 'time_total:%{time_total} size_download:%{size_download} http_code:%{http_code}\n' -o /dev/null "http://localhost:9091/healthz" || true
  echo
  echo "== latency samples (s) =="
  printf "%s\n" "${latencies[@]}"
  echo
  echo "== summary =="
  echo "samples: ${SAMPLES} warmup: ${WARMUP} duration_s: ${DUR_S}"
  echo "min_s: ${MIN_LAT} avg_s: ${AVG_LAT} p50_s: ${P50_LAT} p90_s: ${P90_LAT} p99_s: ${P99_LAT} max_s: ${MAX_LAT}"
  echo "throughput_rps: ${THROUGHPUT}"
} > "${REPORT_DIR}/performance.txt" 2>&1

kill "${APP_PID}" >/dev/null 2>&1 || true

# 3b) SSE handshake and heartbeat interval metrics
echo "[Performance] Measuring SSE handshake and heartbeat..."
PORT=9091 AUTH_TOKENS=dev-token RATE_LIMIT_RPS=100 RATE_LIMIT_BURST=100 \
  nohup go run "${ROOT_DIR}/cmd/app" >/dev/null 2>&1 &
SSE_PID=$!

# Wait briefly for app
sleep 0.5

# Allow mode and heartbeat override via env, and extra query params
SSE_MODE=${SSE_MODE:-example}
HEARTBEAT_MS=${HEARTBEAT_MS:-5}
SSE_QPARAMS=${SSE_QPARAMS:-}
BASE_URL="http://localhost:9091/api/v1/articles/stream?mode=${SSE_MODE}&heartbeatMs=${HEARTBEAT_MS}"
if [[ -n "${SSE_QPARAMS}" ]]; then
  SSE_URL="${BASE_URL}&${SSE_QPARAMS}"
else
  SSE_URL="${BASE_URL}"
fi
HANDSHAKE=$(curl -s -o /dev/null -N -w 'time_connect:%{time_connect} time_starttransfer:%{time_starttransfer} http_code:%{http_code}\n' \
  -H 'Authorization: Bearer dev-token' -H 'X-User-Permissions: articles' "${SSE_URL}" || true)

# Capture heartbeat interval by parsing SSE frames timestamps
HB_FILE="${REPORT_DIR}/.sse_hb.tmp"
: > "${HB_FILE}"
{
  curl -s -N -H 'Authorization: Bearer dev-token' -H 'X-User-Permissions: articles' "${SSE_URL}" || true
} | while IFS= read -r line; do
  now_ns=$(date +%s%N)
  if [[ "$line" == data:* ]]; then
    last_data_ns="$now_ns"
  elif [[ "$line" == :heartbeat* ]]; then
    if [[ -n "${last_data_ns:-}" ]] && [[ ! -s "${HB_FILE}" ]]; then
      awk -v s="${last_data_ns}" -v e="$now_ns" 'BEGIN{printf "%.6f", (e-s)/1000000000.0}' > "${HB_FILE}"
    fi
  fi
done
HB_INTERVAL=$(cat "${HB_FILE}" 2>/dev/null || echo "")
rm -f "${HB_FILE}" || true

{
  echo
  echo "== sse handshake =="
  echo "${HANDSHAKE}"
  echo
  echo "== sse heartbeat interval (s) =="
  echo "${HB_INTERVAL:-N/A}"
} >> "${REPORT_DIR}/performance.txt" 2>&1

kill "${SSE_PID}" >/dev/null 2>&1 || true

echo "[Artifacts] Stored under ${REPORT_DIR}" >> "${REPORT_DIR}/SUMMARY.txt"
echo "Preview completed."