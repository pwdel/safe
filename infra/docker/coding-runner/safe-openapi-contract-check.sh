#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: safe-openapi-contract-check [options] [-- <extra schemathesis args>]

Validate an OpenAPI spec with kin-openapi, start the backend, run Schemathesis,
and write one combined report log.

Options:
  --target-repo PATH     Target repo root (default: /workspace/socialpredict)
  --backend-dir PATH     Backend working directory (default: <target-repo>/backend)
  --spec PATH            OpenAPI spec path, absolute or relative to backend dir (default: docs/openapi.yaml)
  --base-url URL         Base URL for live API checks (default: http://127.0.0.1:8080)
  --start-cmd CMD        Backend start command (default: go run .)
  --wait-seconds N       Seconds to wait for API reachability (default: 45)
  --report-dir PATH      Output directory for run reports (default: <target-repo>/.codex-reports/contracts)
  -h, --help             Show this help

Environment overrides:
  SAFE_CONTRACT_TARGET_REPO
  SAFE_CONTRACT_BACKEND_DIR
  SAFE_CONTRACT_SPEC_PATH
  SAFE_CONTRACT_BASE_URL
  SAFE_CONTRACT_START_CMD
  SAFE_CONTRACT_WAIT_SECONDS
  SAFE_CONTRACT_REPORT_DIR
EOF
}

target_repo="${SAFE_CONTRACT_TARGET_REPO:-/workspace/socialpredict}"
backend_dir="${SAFE_CONTRACT_BACKEND_DIR:-$target_repo/backend}"
spec_input="${SAFE_CONTRACT_SPEC_PATH:-docs/openapi.yaml}"
base_url="${SAFE_CONTRACT_BASE_URL:-http://127.0.0.1:8080}"
start_cmd="${SAFE_CONTRACT_START_CMD:-go run .}"
wait_seconds="${SAFE_CONTRACT_WAIT_SECONDS:-45}"
report_dir="${SAFE_CONTRACT_REPORT_DIR:-$target_repo/.codex-reports/contracts}"

schemathesis_args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target-repo)
      [[ $# -ge 2 ]] || { echo "--target-repo requires a value" >&2; exit 2; }
      target_repo="$2"
      shift 2
      ;;
    --backend-dir)
      [[ $# -ge 2 ]] || { echo "--backend-dir requires a value" >&2; exit 2; }
      backend_dir="$2"
      shift 2
      ;;
    --spec)
      [[ $# -ge 2 ]] || { echo "--spec requires a value" >&2; exit 2; }
      spec_input="$2"
      shift 2
      ;;
    --base-url)
      [[ $# -ge 2 ]] || { echo "--base-url requires a value" >&2; exit 2; }
      base_url="$2"
      shift 2
      ;;
    --start-cmd)
      [[ $# -ge 2 ]] || { echo "--start-cmd requires a value" >&2; exit 2; }
      start_cmd="$2"
      shift 2
      ;;
    --wait-seconds)
      [[ $# -ge 2 ]] || { echo "--wait-seconds requires a value" >&2; exit 2; }
      wait_seconds="$2"
      shift 2
      ;;
    --report-dir)
      [[ $# -ge 2 ]] || { echo "--report-dir requires a value" >&2; exit 2; }
      report_dir="$2"
      shift 2
      ;;
    --)
      shift
      schemathesis_args=("$@")
      break
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

[[ "$wait_seconds" =~ ^[0-9]+$ ]] || { echo "Invalid --wait-seconds value: $wait_seconds" >&2; exit 2; }

kin_validate_bin="${KIN_OPENAPI_VALIDATE_BIN:-/usr/local/bin/kin-openapi-validate}"
schemathesis_bin="${SCHEMATHESIS_BIN:-/usr/local/bin/schemathesis}"

if [[ ! -x "$kin_validate_bin" ]]; then
  echo "kin-openapi validator not found at $kin_validate_bin" >&2
  exit 1
fi
if [[ ! -x "$schemathesis_bin" ]]; then
  echo "schemathesis binary not found at $schemathesis_bin" >&2
  exit 1
fi
if [[ ! -d "$backend_dir" ]]; then
  echo "Backend directory not found: $backend_dir" >&2
  exit 1
fi

if [[ "$spec_input" = /* ]]; then
  spec_path="$spec_input"
else
  spec_path="$backend_dir/$spec_input"
fi
if [[ ! -f "$spec_path" ]]; then
  echo "OpenAPI spec not found: $spec_path" >&2
  exit 1
fi

mkdir -p "$report_dir"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
report_file="$report_dir/openapi-contract-check_${timestamp}.log"
backend_log="$report_dir/openapi-contract-check_${timestamp}.backend.log"

gopath_dir="${SAFE_CONTRACT_GOPATH:-/home/agent/.tmp/go}"
gomodcache_dir="${SAFE_CONTRACT_GOMODCACHE:-$gopath_dir/pkg/mod}"
mkdir -p "$gopath_dir" "$gomodcache_dir"
export GOPATH="$gopath_dir"
export GOMODCACHE="$gomodcache_dir"

backend_pid=""
cleanup() {
  if [[ -n "$backend_pid" ]] && kill -0 "$backend_pid" 2>/dev/null; then
    kill "$backend_pid" 2>/dev/null || true
    wait "$backend_pid" 2>/dev/null || true
  fi
}
trap cleanup EXIT

{
  echo "timestamp=$timestamp"
  echo "target_repo=$target_repo"
  echo "backend_dir=$backend_dir"
  echo "spec_path=$spec_path"
  echo "base_url=$base_url"
  echo "start_cmd=$start_cmd"
  echo "wait_seconds=$wait_seconds"
  if [[ "${#schemathesis_args[@]}" -gt 0 ]]; then
    echo "schemathesis_args=${schemathesis_args[*]}"
  else
    echo "schemathesis_args=<none>"
  fi
  echo
  echo "[1/3] Validate OpenAPI with kin-openapi"
} | tee "$report_file"

"$kin_validate_bin" "$spec_path" 2>&1 | tee -a "$report_file"

{
  echo
  echo "[2/3] Start backend"
} | tee -a "$report_file"

(
  cd "$backend_dir"
  exec bash -lc "$start_cmd"
) >"$backend_log" 2>&1 &
backend_pid="$!"
echo "backend_pid=$backend_pid" | tee -a "$report_file"
echo "backend_log=$backend_log" | tee -a "$report_file"

ready=0
for (( i=1; i<=wait_seconds; i++ )); do
  if ! kill -0 "$backend_pid" 2>/dev/null; then
    echo "backend exited before becoming reachable" | tee -a "$report_file"
    tail -n 120 "$backend_log" | sed 's/^/[backend] /' | tee -a "$report_file" || true
    exit 1
  fi
  if curl -sS -o /dev/null --connect-timeout 1 "$base_url"; then
    ready=1
    break
  fi
  sleep 1
done

if (( ready == 0 )); then
  echo "backend did not become reachable at $base_url within ${wait_seconds}s" | tee -a "$report_file"
  tail -n 120 "$backend_log" | sed 's/^/[backend] /' | tee -a "$report_file" || true
  exit 1
fi

{
  echo
  echo "[3/3] Run Schemathesis"
} | tee -a "$report_file"

schemathesis_exit=0
if ! "$schemathesis_bin" run "$spec_path" --url "$base_url" "${schemathesis_args[@]}" 2>&1 | tee -a "$report_file"; then
  schemathesis_exit=$?
fi

if (( schemathesis_exit != 0 )); then
  echo "schemathesis_exit=$schemathesis_exit" | tee -a "$report_file"
  exit "$schemathesis_exit"
fi

echo "report_file=$report_file"
