#!/usr/bin/env bash
set -euo pipefail

TARGET="all"
HOST_KEYS_DIR="${HOST_KEYS_DIR:-$HOME/.keys/safe}"
SSH_PRIVATE_KEY="${SSH_PRIVATE_KEY:-$HOME/.ssh/id_ed25519}"
SSH_PUBLIC_KEY="${SSH_PUBLIC_KEY:-$HOME/.ssh/id_ed25519.pub}"
REQUIRE_CREDENTIALS=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RENDER_AGENT_ENV="$SCRIPT_DIR/render_host_agent_env.sh"

usage() {
  cat <<'EOF'
Usage:
  bash infra/scripts/check_host_prereqs.sh [options]

Options:
  --target <all|mac|remote>      Check profile (default: all)
  --host-keys-dir <path>         Host key/env directory (default: ~/.keys/safe)
  --ssh-private-key <path>       SSH private key path (default: ~/.ssh/id_ed25519)
  --ssh-public-key <path>        SSH public key path (default: ~/.ssh/id_ed25519.pub)
  --require-credentials          Fail if GitHub token and model key are both missing
  -h, --help                     Show help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      [[ $# -ge 2 ]] || { echo "--target requires a value" >&2; exit 2; }
      TARGET="$2"
      shift 2
      ;;
    --host-keys-dir)
      [[ $# -ge 2 ]] || { echo "--host-keys-dir requires a value" >&2; exit 2; }
      HOST_KEYS_DIR="$2"
      shift 2
      ;;
    --ssh-private-key)
      [[ $# -ge 2 ]] || { echo "--ssh-private-key requires a value" >&2; exit 2; }
      SSH_PRIVATE_KEY="$2"
      shift 2
      ;;
    --ssh-public-key)
      [[ $# -ge 2 ]] || { echo "--ssh-public-key requires a value" >&2; exit 2; }
      SSH_PUBLIC_KEY="$2"
      shift 2
      ;;
    --require-credentials)
      REQUIRE_CREDENTIALS=1
      shift
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

case "$TARGET" in
  all|mac|remote) ;;
  *)
    echo "Invalid --target value: $TARGET (expected all|mac|remote)" >&2
    exit 2
    ;;
esac

missing=0
warned=0

status_ok() {
  printf '[OK]   %s\n' "$1"
}

status_warn() {
  warned=1
  printf '[WARN] %s\n' "$1"
}

status_err() {
  missing=1
  printf '[ERR]  %s\n' "$1"
}

check_cmd() {
  local cmd="$1"
  if command -v "$cmd" >/dev/null 2>&1; then
    status_ok "command '$cmd' found"
  else
    status_err "command '$cmd' missing"
  fi
}

check_file() {
  local path="$1"
  local label="$2"
  if [[ -f "$path" ]]; then
    status_ok "$label: $path"
  else
    status_err "$label missing: $path"
  fi
}

has_rendered_key() {
  local needle="$1"
  local key
  for key in "${rendered_keys[@]:-}"; do
    if [[ "$key" == "$needle" ]]; then
      return 0
    fi
  done
  return 1
}

report_key_status() {
  local key="$1"
  if has_rendered_key "$key"; then
    status_ok "key present: $key"
  else
    status_warn "key missing: $key"
  fi
}

echo "Checking host prerequisites (target=$TARGET)..."

check_cmd bash
check_cmd tar
check_cmd awk

if [[ "$TARGET" == "all" || "$TARGET" == "mac" ]]; then
  check_cmd multipass
  check_cmd ansible-playbook
  check_cmd ssh-keygen
fi

if [[ "$TARGET" == "all" || "$TARGET" == "remote" ]]; then
  check_cmd ansible-playbook
  check_cmd ssh
  check_cmd scp
fi

if [[ "$TARGET" == "all" || "$TARGET" == "remote" ]]; then
  check_file "$SSH_PRIVATE_KEY" "SSH private key"
fi
if [[ "$TARGET" == "all" || "$TARGET" == "mac" ]]; then
  check_file "$SSH_PUBLIC_KEY" "SSH public key"
fi

tmp_env="$(mktemp /tmp/safe-check-agent-env.XXXXXX)"
cleanup() {
  rm -f "$tmp_env"
}
trap cleanup EXIT

if [[ -d "$HOST_KEYS_DIR" ]]; then
  status_ok "host keys dir: $HOST_KEYS_DIR"

  found_parts=0
  for f in agent.env github.env codex.env claude.env openai.env; do
    if [[ -f "$HOST_KEYS_DIR/$f" ]]; then
      status_ok "credential file present: $HOST_KEYS_DIR/$f"
      found_parts=1
    else
      status_warn "credential file missing: $HOST_KEYS_DIR/$f"
    fi
  done
  if (( found_parts == 0 )); then
    status_warn "no credential files found under $HOST_KEYS_DIR"
  fi

  if OUTPUT="$tmp_env" HOST_KEYS_DIR="$HOST_KEYS_DIR" bash "$RENDER_AGENT_ENV" >/dev/null; then
    rendered_keys=()
    if [[ -s "$tmp_env" ]]; then
      mapfile -t rendered_keys < <(awk -F= '
        /^[[:space:]]*#/ { next }
        /^[[:space:]]*$/ { next }
        { print $1 }
      ' "$tmp_env")

      if [[ ${#rendered_keys[@]} -gt 0 ]]; then
        status_ok "rendered env keys: ${rendered_keys[*]}"
      else
        status_warn "rendered env file is empty"
      fi

      report_key_status GH_TOKEN
      report_key_status GITHUB_TOKEN
      report_key_status OPENAI_API_KEY
      report_key_status ANTHROPIC_API_KEY

      has_github=0
      has_model=0
      if has_rendered_key GH_TOKEN || has_rendered_key GITHUB_TOKEN; then
        has_github=1
      fi
      if has_rendered_key OPENAI_API_KEY || has_rendered_key ANTHROPIC_API_KEY; then
        has_model=1
      fi

      if (( REQUIRE_CREDENTIALS == 1 )) && (( has_github == 0 || has_model == 0 )); then
        status_err "required credentials check failed"
      fi
    else
      status_warn "rendered env file is empty"
      rendered_keys=()
      report_key_status GH_TOKEN
      report_key_status GITHUB_TOKEN
      report_key_status OPENAI_API_KEY
      report_key_status ANTHROPIC_API_KEY
      if (( REQUIRE_CREDENTIALS == 1 )); then
        status_err "required credentials check failed"
      fi
    fi
  else
    status_err "failed to render credentials from $HOST_KEYS_DIR"
    status_warn "key missing: GH_TOKEN"
    status_warn "key missing: GITHUB_TOKEN"
    status_warn "key missing: OPENAI_API_KEY"
    status_warn "key missing: ANTHROPIC_API_KEY"
  fi
else
  status_warn "host keys dir missing: $HOST_KEYS_DIR"
  status_warn "credential file missing: $HOST_KEYS_DIR/agent.env"
  status_warn "credential file missing: $HOST_KEYS_DIR/github.env"
  status_warn "credential file missing: $HOST_KEYS_DIR/codex.env"
  status_warn "credential file missing: $HOST_KEYS_DIR/claude.env"
  status_warn "credential file missing: $HOST_KEYS_DIR/openai.env"
  status_warn "key missing: GH_TOKEN"
  status_warn "key missing: GITHUB_TOKEN"
  status_warn "key missing: OPENAI_API_KEY"
  status_warn "key missing: ANTHROPIC_API_KEY"
  if (( REQUIRE_CREDENTIALS == 1 )); then
    status_err "required credentials check failed"
  fi
fi

if (( missing == 1 )); then
  echo "Preflight check failed."
  exit 1
fi

if (( warned == 1 )); then
  echo "Preflight check passed with warnings."
else
  echo "Preflight check passed."
fi
