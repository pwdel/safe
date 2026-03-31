#!/usr/bin/env bash
set -euo pipefail

TARGET="all"
HOST_KEYS_DIR="${HOST_KEYS_DIR:-$HOME/.keys/safe}"
SSH_PRIVATE_KEY="${SSH_PRIVATE_KEY:-$HOME/.ssh/id_ed25519}"
SSH_PUBLIC_KEY="${SSH_PUBLIC_KEY:-$HOME/.ssh/id_ed25519.pub}"
REQUIRE_CREDENTIALS=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RENDER_AGENT_ENV="$SCRIPT_DIR/render_host_agent_env.sh"
ENV_MANIFEST_FILE="$SCRIPT_DIR/env_key_manifest.sh"
ENV_MANIFEST_LABEL="infra/scripts/env_key_manifest.sh"

if [[ ! -f "$ENV_MANIFEST_FILE" ]]; then
  echo "Missing env manifest: $ENV_MANIFEST_FILE" >&2
  exit 1
fi
# shellcheck source=infra/scripts/env_key_manifest.sh
source "$ENV_MANIFEST_FILE"

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

print_env_format_guide() {
  local runtime_keys
  local split_files
  local tf_required
  local tf_optional
  local task_required
  local task_optional

  runtime_keys="$(env_manifest_join ", " "${RUNTIME_ALLOWED_KEYS[@]}")"
  split_files="$(env_manifest_join ", " "${RUNTIME_SPLIT_ENV_FILES[@]}")"
  tf_required="$(env_manifest_join ", " "${TERRAFORM_REQUIRED_KEYS[@]}")"
  tf_optional="$(env_manifest_join ", " "${TERRAFORM_OPTIONAL_KEYS[@]}")"
  task_required="$(env_manifest_join ", " "${TASK_SPEC_REQUIRED_KEYS[@]}")"
  task_optional="$(env_manifest_join ", " "${TASK_SPEC_OPTIONAL_KEYS[@]}")"

  print_box_hr
  print_box_line "Env file contract"
  print_box_line "Source: $ENV_MANIFEST_LABEL"
  print_box_hr
  print_box_line "Directory: $(display_path "$HOST_KEYS_DIR")"
  print_box_line "Format: one KEY=VALUE per line (no leading 'export')."
  print_box_line "Comments/blanks: '#' comments and blank lines are allowed."
  print_box_line "Runtime keys accepted: $runtime_keys"
  print_box_line "Preferred runtime file: $(display_path "$HOST_KEYS_DIR/$RUNTIME_PRIMARY_ENV_FILE")"
  print_box_line "Split runtime files (if primary is absent): $split_files"
  print_box_line "Terraform file: $(display_path "$HOST_KEYS_DIR/$TERRAFORM_ENV_FILE")"
  print_box_line "Required Terraform keys: $tf_required"
  print_box_line "Optional Terraform keys: $tf_optional"
  print_box_line "Task spec file: $(display_path "$HOST_KEYS_DIR/$TASK_SPEC_ENV_FILE")"
  print_box_line "Required task spec keys: $task_required"
  print_box_line "Optional task spec keys: $task_optional"
  print_box_hr
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
    status_ok "$label: $(display_path "$path")"
  else
    status_err "$label missing: $(display_path "$path")"
  fi
}

display_path() {
  local path="$1"
  if [[ "$path" == "$HOME" ]]; then
    printf '~'
    return
  fi
  if [[ "$path" == "$HOME/"* ]]; then
    printf '~/%s' "${path#"$HOME/"}"
    return
  fi
  printf '%s' "$path"
}

print_box_hr() {
  printf '%s\n' "--------------------------------------------------------------------"
}

print_box_line() {
  printf '| %s\n' "$1"
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

check_terraform_env_file() {
  local tf_file="$HOST_KEYS_DIR/$TERRAFORM_ENV_FILE"
  local tf_file_display
  tf_file_display="$(display_path "$tf_file")"
  local missing_required=0
  local line=""
  local key=""
  local line_no=0

  if [[ ! -f "$tf_file" ]]; then
    status_warn "terraform env file missing: $tf_file_display"
    return
  fi

  status_ok "terraform env file present: $tf_file_display"

  while IFS= read -r line || [[ -n "$line" ]]; do
    line_no=$((line_no + 1))
    if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
      continue
    fi
    if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
      key="${BASH_REMATCH[1]}"
      if [[ "$key" != TF_VAR_* ]]; then
        status_warn "non-TF_VAR key in $tf_file_display:$line_no ($key)"
      fi
      continue
    fi
    status_err "invalid line in $tf_file_display:$line_no (expected KEY=VALUE)"
  done <"$tf_file"

  local required_key
  for required_key in "${TERRAFORM_REQUIRED_KEYS[@]}"; do
    if grep -Eq "^${required_key}=" "$tf_file"; then
      status_ok "terraform key present: $required_key"
    else
      status_warn "terraform key missing: $required_key"
      missing_required=1
    fi
  done

  if (( REQUIRE_CREDENTIALS == 1 )) && (( missing_required == 1 )); then
    status_err "required Terraform credentials check failed"
  fi
}

check_task_spec_env_file() {
  local task_file="$HOST_KEYS_DIR/$TASK_SPEC_ENV_FILE"
  local task_file_display
  task_file_display="$(display_path "$task_file")"
  local line=""
  local key=""
  local line_no=0
  local missing_required=0

  if [[ ! -f "$task_file" ]]; then
    status_warn "task spec env file missing: $task_file_display"
    return
  fi

  status_ok "task spec env file present: $task_file_display"

  while IFS= read -r line || [[ -n "$line" ]]; do
    line_no=$((line_no + 1))
    if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
      continue
    fi
    if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
      key="${BASH_REMATCH[1]}"
      if ! env_manifest_contains "$key" "${TASK_SPEC_ALLOWED_KEYS[@]}"; then
        status_warn "unsupported task spec key in $task_file_display:$line_no ($key)"
      fi
      continue
    fi
    status_err "invalid line in $task_file_display:$line_no (expected KEY=VALUE)"
  done <"$task_file"

  local required_key
  for required_key in "${TASK_SPEC_REQUIRED_KEYS[@]}"; do
    if grep -Eq "^${required_key}=" "$task_file"; then
      status_ok "task spec key present: $required_key"
    else
      status_warn "task spec key missing: $required_key"
      missing_required=1
    fi
  done

  if (( REQUIRE_CREDENTIALS == 1 )) && (( missing_required == 1 )); then
    status_err "required task spec credentials check failed"
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
  status_ok "host keys dir: $(display_path "$HOST_KEYS_DIR")"

  found_parts=0
  if [[ -f "$HOST_KEYS_DIR/$RUNTIME_PRIMARY_ENV_FILE" ]]; then
    status_ok "credential file present: $(display_path "$HOST_KEYS_DIR/$RUNTIME_PRIMARY_ENV_FILE") (preferred)"
    found_parts=1
    for f in "${RUNTIME_SPLIT_ENV_FILES[@]}"; do
      if [[ -f "$HOST_KEYS_DIR/$f" ]]; then
        status_ok "additional credential file present: $(display_path "$HOST_KEYS_DIR/$f")"
      fi
    done
  else
    for f in "${RUNTIME_SPLIT_ENV_FILES[@]}"; do
      if [[ -f "$HOST_KEYS_DIR/$f" ]]; then
        status_ok "credential file present: $(display_path "$HOST_KEYS_DIR/$f")"
        found_parts=1
      else
        status_warn "credential file missing: $(display_path "$HOST_KEYS_DIR/$f")"
      fi
    done
  fi
  if (( found_parts == 0 )); then
    status_warn "no runtime credential files found under $(display_path "$HOST_KEYS_DIR")"
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

      for key in "${RUNTIME_GITHUB_AUTH_KEYS[@]}"; do
        report_key_status "$key"
      done
      for key in "${RUNTIME_MODEL_AUTH_KEYS[@]}"; do
        report_key_status "$key"
      done

      has_github=0
      has_model=0
      for key in "${RUNTIME_GITHUB_AUTH_KEYS[@]}"; do
        if has_rendered_key "$key"; then
          has_github=1
        fi
      done
      for key in "${RUNTIME_MODEL_AUTH_KEYS[@]}"; do
        if has_rendered_key "$key"; then
          has_model=1
        fi
      done

      if (( REQUIRE_CREDENTIALS == 1 )) && (( has_github == 0 || has_model == 0 )); then
        status_err "required credentials check failed"
      fi
    else
      status_warn "rendered env file is empty"
      rendered_keys=()
      for key in "${RUNTIME_GITHUB_AUTH_KEYS[@]}"; do
        report_key_status "$key"
      done
      for key in "${RUNTIME_MODEL_AUTH_KEYS[@]}"; do
        report_key_status "$key"
      done
      if (( REQUIRE_CREDENTIALS == 1 )); then
        status_err "required credentials check failed"
      fi
    fi
  else
    status_err "failed to render credentials from $(display_path "$HOST_KEYS_DIR")"
    for key in "${RUNTIME_GITHUB_AUTH_KEYS[@]}"; do
      status_warn "key missing: $key"
    done
    for key in "${RUNTIME_MODEL_AUTH_KEYS[@]}"; do
      status_warn "key missing: $key"
    done
  fi

  check_terraform_env_file
  check_task_spec_env_file
else
  status_warn "host keys dir missing: $(display_path "$HOST_KEYS_DIR")"
  status_warn "credential file missing: $(display_path "$HOST_KEYS_DIR/$RUNTIME_PRIMARY_ENV_FILE")"
  for f in "${RUNTIME_SPLIT_ENV_FILES[@]}"; do
    status_warn "credential file missing: $(display_path "$HOST_KEYS_DIR/$f")"
  done
  for key in "${RUNTIME_GITHUB_AUTH_KEYS[@]}"; do
    status_warn "key missing: $key"
  done
  for key in "${RUNTIME_MODEL_AUTH_KEYS[@]}"; do
    status_warn "key missing: $key"
  done
  status_warn "terraform env file missing: $(display_path "$HOST_KEYS_DIR/$TERRAFORM_ENV_FILE")"
  status_warn "task spec env file missing: $(display_path "$HOST_KEYS_DIR/$TASK_SPEC_ENV_FILE")"
  if (( REQUIRE_CREDENTIALS == 1 )); then
    status_err "required credentials check failed"
  fi
fi

echo
print_env_format_guide

if (( missing == 1 )); then
  echo "Preflight check failed."
  exit 1
fi

if (( warned == 1 )); then
  echo "Preflight check passed with warnings."
else
  echo "Preflight check passed."
fi
