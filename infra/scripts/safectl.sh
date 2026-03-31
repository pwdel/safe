#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$INFRA_DIR/.." && pwd)"
LINUX_DIR="$REPO_ROOT/LINUX"
TERRAFORM_DIR="$INFRA_DIR/terraform"
HELP_DIR="$SCRIPT_DIR/help"
ENV_MANIFEST_FILE="$SCRIPT_DIR/env_key_manifest.sh"

VM_NAME="${VM_NAME:-safevm}"
TARGET_HOST="${TARGET_HOST:-}"
REMOTE_SSH_USER="${REMOTE_SSH_USER:-operator}"
REMOTE_BOOTSTRAP_USER="${REMOTE_BOOTSTRAP_USER:-root}"
REMOTE_PORT="${REMOTE_PORT:-22}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519}"
SSH_PUBLIC_KEY="${SSH_PUBLIC_KEY:-$HOME/.ssh/id_ed25519.pub}"
HOST_KEYS_DIR="${HOST_KEYS_DIR:-$HOME/.keys/safe}"
TF_AUTO_APPROVE="${TF_AUTO_APPROVE:-0}"
TERRAFORM_ENV_FILE="${TERRAFORM_ENV_FILE:-terraform.env}"
TERRAFORM_ENV_LOADED=0

if [[ -f "$ENV_MANIFEST_FILE" ]]; then
  # shellcheck source=infra/scripts/env_key_manifest.sh
  source "$ENV_MANIFEST_FILE"
fi

die() {
  echo "$*" >&2
  exit 1
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    die "Missing required command: $cmd"
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

terraform_env_path() {
  printf '%s/%s' "$HOST_KEYS_DIR" "$TERRAFORM_ENV_FILE"
}

sync_do_token_env() {
  if [[ -n "${TF_VAR_do_token:-}" ]]; then
    export DIGITALOCEAN_ACCESS_TOKEN="${DIGITALOCEAN_ACCESS_TOKEN:-$TF_VAR_do_token}"
    export DIGITALOCEAN_TOKEN="${DIGITALOCEAN_TOKEN:-$TF_VAR_do_token}"
  fi
  if [[ -n "${DIGITALOCEAN_ACCESS_TOKEN:-}" && -z "${TF_VAR_do_token:-}" ]]; then
    export TF_VAR_do_token="$DIGITALOCEAN_ACCESS_TOKEN"
  fi
  if [[ -n "${DIGITALOCEAN_TOKEN:-}" && -z "${DIGITALOCEAN_ACCESS_TOKEN:-}" ]]; then
    export DIGITALOCEAN_ACCESS_TOKEN="$DIGITALOCEAN_TOKEN"
  fi
  if [[ -n "${DIGITALOCEAN_ACCESS_TOKEN:-}" && -z "${DIGITALOCEAN_TOKEN:-}" ]]; then
    export DIGITALOCEAN_TOKEN="$DIGITALOCEAN_ACCESS_TOKEN"
  fi
}

load_terraform_env() {
  local tf_env_file
  tf_env_file="$(terraform_env_path)"
  local line=""
  local key=""
  local value=""
  local line_no=0

  if [[ "$TERRAFORM_ENV_LOADED" == "1" ]]; then
    sync_do_token_env
    return 0
  fi

  if [[ -f "$tf_env_file" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      line_no=$((line_no + 1))
      if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
        continue
      fi
      if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
        key="${BASH_REMATCH[1]}"
        value="${BASH_REMATCH[2]}"
        export "$key=$value"
        continue
      fi
      die "Invalid line in $(display_path "$tf_env_file"):$line_no (expected KEY=VALUE)"
    done <"$tf_env_file"
  fi

  sync_do_token_env
  TERRAFORM_ENV_LOADED=1
}

upsert_terraform_env_key() {
  local key="$1"
  local value="$2"
  local tf_env_file
  local tmp_file
  tf_env_file="$(terraform_env_path)"

  mkdir -p "$HOST_KEYS_DIR"
  touch "$tf_env_file"
  chmod 600 "$tf_env_file"

  tmp_file="$(mktemp /tmp/safectl-env-upsert.XXXXXX)"
  awk -v key="$key" -v value="$value" '
    BEGIN { updated = 0 }
    $0 ~ ("^" key "=") {
      if (updated == 0) {
        print key "=" value
        updated = 1
      }
      next
    }
    { print }
    END {
      if (updated == 0) {
        print key "=" value
      }
    }
  ' "$tf_env_file" >"$tmp_file"
  mv "$tmp_file" "$tf_env_file"
  chmod 600 "$tf_env_file"

  if [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    export "$key=$value"
  fi
}

remove_terraform_env_key() {
  local key="$1"
  local tf_env_file
  local tmp_file
  tf_env_file="$(terraform_env_path)"

  if [[ ! -f "$tf_env_file" ]]; then
    return 0
  fi

  tmp_file="$(mktemp /tmp/safectl-env-remove.XXXXXX)"
  awk -v key="$key" '
    $0 ~ ("^" key "=") { next }
    { print }
  ' "$tf_env_file" >"$tmp_file"
  mv "$tmp_file" "$tf_env_file"
  chmod 600 "$tf_env_file"
  unset "$key" || true
}

capture_terraform_target_host() {
  local host_ip
  host_ip="$(cd "$TERRAFORM_DIR" && terraform output -raw droplet_ipv4_address 2>/dev/null || true)"
  if [[ -z "$host_ip" ]]; then
    return 0
  fi
  upsert_terraform_env_key SAFE_TARGET_HOST "$host_ip"
  export SAFE_TARGET_HOST="$host_ip"
  echo "Saved SAFE_TARGET_HOST=$host_ip to $(display_path "$(terraform_env_path)")"
}

ensure_target_host() {
  if [[ -z "$TARGET_HOST" ]]; then
    load_terraform_env
    if [[ -n "${SAFE_TARGET_HOST:-}" ]]; then
      TARGET_HOST="$SAFE_TARGET_HOST"
    fi
  fi
  [[ -n "$TARGET_HOST" ]] || die "Missing --host (or TARGET_HOST env var). Set SAFE_TARGET_HOST in $(display_path "$(terraform_env_path)") to reuse the last Terraform host."
}

show_help_topic() {
  local topic="${1:-overview}"
  local help_file="$HELP_DIR/safectl-${topic}.txt"
  if [[ ! -f "$help_file" ]]; then
    die "Unknown help topic: $topic (expected one of: overview, local, remote, terraform, doctl, access, check)"
  fi
  cat "$help_file"
}

usage() {
  show_help_topic overview
}

build_shell_cmd() {
  local out=()
  local arg
  for arg in "$@"; do
    out+=("$(printf '%q' "$arg")")
  done
  (IFS=' '; printf '%s' "${out[*]}")
}

remote_ssh_exec() {
  local command="$1"
  require_cmd ssh
  [[ -f "$SSH_KEY" ]] || die "SSH key not found: $(display_path "$SSH_KEY")"
  ensure_target_host
  ssh \
    -i "$SSH_KEY" \
    -p "$REMOTE_PORT" \
    -o StrictHostKeyChecking=accept-new \
    "${REMOTE_SSH_USER}@${TARGET_HOST}" \
    "$command"
}

remote_ssh_exec_tty() {
  local command="$1"
  require_cmd ssh
  [[ -f "$SSH_KEY" ]] || die "SSH key not found: $(display_path "$SSH_KEY")"
  ensure_target_host
  ssh \
    -i "$SSH_KEY" \
    -p "$REMOTE_PORT" \
    -o StrictHostKeyChecking=accept-new \
    -t "${REMOTE_SSH_USER}@${TARGET_HOST}" \
    "$command"
}

remote_ssh_shell() {
  require_cmd ssh
  [[ -f "$SSH_KEY" ]] || die "SSH key not found: $(display_path "$SSH_KEY")"
  ensure_target_host
  exec ssh \
    -i "$SSH_KEY" \
    -p "$REMOTE_PORT" \
    -o StrictHostKeyChecking=accept-new \
    -t "${REMOTE_SSH_USER}@${TARGET_HOST}"
}

local_vm_ip() {
  require_cmd multipass
  multipass info "$VM_NAME" | awk '/IPv4/ {print $2; exit}'
}

run_local_bootstrap() {
  bash "$SCRIPT_DIR/bootstrap_mac.sh"
}

run_local_shell() {
  bash "$SCRIPT_DIR/mp-shell.sh"
}

run_local_operator_shell() {
  local vm_ip
  vm_ip="$(local_vm_ip)"
  [[ -n "$vm_ip" ]] || die "Could not determine VM IP for $VM_NAME."
  TARGET_HOST="$vm_ip" remote_ssh_shell
}

run_local_status() {
  local vm_ip
  vm_ip="$(local_vm_ip)"
  [[ -n "$vm_ip" ]] || die "Could not determine VM IP for $VM_NAME."
  bash "$SCRIPT_DIR/vm-status.sh"
  TARGET_HOST="$vm_ip" remote_ssh_exec "sudo -n /usr/local/bin/safe-runner-status"
}

run_local_runner_shell() {
  local vm_ip
  vm_ip="$(local_vm_ip)"
  [[ -n "$vm_ip" ]] || die "Could not determine VM IP for $VM_NAME."
  TARGET_HOST="$vm_ip" remote_ssh_exec_tty "sudo -n /usr/local/bin/safe-enter-runner"
}

run_local_codex_login() {
  local vm_ip
  vm_ip="$(local_vm_ip)"
  [[ -n "$vm_ip" ]] || die "Could not determine VM IP for $VM_NAME."
  TARGET_HOST="$vm_ip" remote_ssh_exec_tty "sudo -n /usr/local/bin/safe-codex-login"
}

run_local_fork_shell() {
  local fork_name="${1:-}"
  [[ -n "$fork_name" ]] || die "Usage: local fork-shell <fork-name>"
  local vm_ip
  vm_ip="$(local_vm_ip)"
  [[ -n "$vm_ip" ]] || die "Could not determine VM IP for $VM_NAME."
  TARGET_HOST="$vm_ip" remote_ssh_exec_tty "sudo -n /usr/local/bin/safe-enter-fork $fork_name"
}

run_local_helper() {
  local helper="${1:-}"
  shift || true
  [[ -n "$helper" ]] || die "Usage: local helper <safe-*> [args...]"
  [[ "$helper" == safe-* ]] || die "Helper command must start with safe- (got: $helper)"
  local vm_ip
  vm_ip="$(local_vm_ip)"
  [[ -n "$vm_ip" ]] || die "Could not determine VM IP for $VM_NAME."
  local cmd
  cmd="$(build_shell_cmd sudo -n "/usr/local/bin/$helper" "$@")"
  TARGET_HOST="$vm_ip" remote_ssh_exec "$cmd"
}

run_local_test() {
  local vm_ip
  vm_ip="$(local_vm_ip)"
  [[ -n "$vm_ip" ]] || die "Could not determine VM IP for $VM_NAME."
  echo "Testing operator SSH access on $vm_ip..."
  TARGET_HOST="$vm_ip" remote_ssh_exec "whoami"
  echo "Starting runner via safe helper..."
  TARGET_HOST="$vm_ip" remote_ssh_exec "sudo -n /usr/local/bin/safe-start-runner"
  echo "Checking runner status..."
  TARGET_HOST="$vm_ip" remote_ssh_exec "sudo -n /usr/local/bin/safe-runner-status"
}

run_remote_bootstrap() {
  ensure_target_host
  TARGET_HOST="$TARGET_HOST" \
  TARGET_USER="$REMOTE_BOOTSTRAP_USER" \
  TARGET_PORT="$REMOTE_PORT" \
  SSH_KEY="$SSH_KEY" \
  bash "$LINUX_DIR/bootstrap_remote.sh"
}

run_remote_helper() {
  local helper="${1:-}"
  shift || true
  [[ -n "$helper" ]] || die "Usage: remote helper <safe-*> [args...]"
  [[ "$helper" == safe-* ]] || die "Helper command must start with safe- (got: $helper)"
  local cmd
  cmd="$(build_shell_cmd sudo -n "/usr/local/bin/$helper" "$@")"
  remote_ssh_exec "$cmd"
}

run_remote_runner_shell() {
  remote_ssh_exec_tty "sudo -n /usr/local/bin/safe-enter-runner"
}

run_remote_codex_login() {
  remote_ssh_exec_tty "sudo -n /usr/local/bin/safe-codex-login"
}

run_remote_fork_shell() {
  local fork_name="${1:-}"
  [[ -n "$fork_name" ]] || die "Usage: remote fork-shell <fork-name>"
  remote_ssh_exec_tty "sudo -n /usr/local/bin/safe-enter-fork $fork_name"
}

run_remote_exec() {
  [[ $# -gt 0 ]] || die "Usage: remote exec -- <command...>"
  local cmd
  cmd="$(build_shell_cmd "$@")"
  remote_ssh_exec "$cmd"
}

run_terraform() {
  local action="$1"
  shift || true
  load_terraform_env
  require_cmd terraform
  case "$action" in
    init)
      (cd "$TERRAFORM_DIR" && terraform init "$@")
      ;;
    plan)
      (cd "$TERRAFORM_DIR" && terraform plan "$@")
      ;;
    apply)
      if [[ "$TF_AUTO_APPROVE" == "1" ]]; then
        (cd "$TERRAFORM_DIR" && terraform apply -auto-approve "$@")
      else
        (cd "$TERRAFORM_DIR" && terraform apply "$@")
      fi
      capture_terraform_target_host
      ;;
    destroy)
      if [[ "$TF_AUTO_APPROVE" == "1" ]]; then
        (cd "$TERRAFORM_DIR" && terraform destroy -auto-approve "$@")
      else
        (cd "$TERRAFORM_DIR" && terraform destroy "$@")
      fi
      remove_terraform_env_key SAFE_TARGET_HOST
      echo "Removed SAFE_TARGET_HOST from $(display_path "$(terraform_env_path)")"
      ;;
    output-bootstrap)
      (cd "$TERRAFORM_DIR" && terraform output bootstrap_command)
      ;;
    output-host)
      (cd "$TERRAFORM_DIR" && terraform output -raw droplet_ipv4_address)
      ;;
    deploy)
      (cd "$TERRAFORM_DIR" && terraform init)
      if [[ "$TF_AUTO_APPROVE" == "1" ]]; then
        (cd "$TERRAFORM_DIR" && terraform apply -auto-approve "$@")
      else
        (cd "$TERRAFORM_DIR" && terraform apply "$@")
      fi
      capture_terraform_target_host
      local bootstrap_cmd
      bootstrap_cmd="$(cd "$TERRAFORM_DIR" && terraform output -raw bootstrap_command)"
      [[ -n "$bootstrap_cmd" ]] || die "Terraform output bootstrap_command was empty."
      echo "Running bootstrap command from repo root:"
      echo "$bootstrap_cmd"
      (cd "$REPO_ROOT" && bash -lc "$bootstrap_cmd")
      ;;
    *)
      die "Unknown terraform command: $action"
      ;;
  esac
}

run_doctl() {
  [[ $# -gt 0 ]] || die "Usage: doctl <subcommand...>"
  load_terraform_env
  require_cmd doctl
  doctl "$@"
}

run_host_check() {
  local target="${1:-all}"
  local check_script="$SCRIPT_DIR/check_host_prereqs.sh"
  local args=(--target "$target" --host-keys-dir "$HOST_KEYS_DIR" --ssh-private-key "$SSH_KEY")
  if [[ -f "$SSH_PUBLIC_KEY" ]]; then
    args+=(--ssh-public-key "$SSH_PUBLIC_KEY")
  fi
  if [[ "${REQUIRE_RUNTIME_CREDENTIALS:-0}" == "1" ]]; then
    args+=(--require-credentials)
  fi
  bash "$check_script" "${args[@]}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)
      [[ $# -ge 2 ]] || die "--host requires a value"
      TARGET_HOST="$2"
      shift 2
      ;;
    --ssh-user)
      [[ $# -ge 2 ]] || die "--ssh-user requires a value"
      REMOTE_SSH_USER="$2"
      shift 2
      ;;
    --bootstrap-user)
      [[ $# -ge 2 ]] || die "--bootstrap-user requires a value"
      REMOTE_BOOTSTRAP_USER="$2"
      shift 2
      ;;
    --port)
      [[ $# -ge 2 ]] || die "--port requires a value"
      REMOTE_PORT="$2"
      shift 2
      ;;
    --key)
      [[ $# -ge 2 ]] || die "--key requires a value"
      SSH_KEY="$2"
      shift 2
      ;;
    --auto-approve)
      TF_AUTO_APPROVE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      die "Unknown option: $1"
      ;;
    *)
      break
      ;;
  esac
done

if [[ "${1:-}" == "help" ]]; then
  shift
  show_help_topic "${1:-overview}"
  exit 0
fi

group="${1:-}"
command="${2:-}"
if [[ -z "$group" || -z "$command" ]]; then
  usage
  exit 1
fi
shift 2

case "$group" in
  local)
    case "$command" in
      help) show_help_topic local ;;
      bootstrap) run_local_bootstrap ;;
      shell) run_local_shell ;;
      operator-shell) run_local_operator_shell ;;
      runner-shell) run_local_runner_shell ;;
      codex-login) run_local_codex_login ;;
      fork-shell) run_local_fork_shell "$@" ;;
      helper) run_local_helper "$@" ;;
      status) run_local_status ;;
      test) run_local_test ;;
      *) die "Unknown local command: $command" ;;
    esac
    ;;
  remote)
    case "$command" in
      help) show_help_topic remote ;;
      bootstrap) run_remote_bootstrap ;;
      shell) remote_ssh_shell ;;
      operator-shell) remote_ssh_shell ;;
      runner-shell) run_remote_runner_shell ;;
      codex-login) run_remote_codex_login ;;
      fork-shell) run_remote_fork_shell "$@" ;;
      helper) run_remote_helper "$@" ;;
      exec)
        if [[ "${1:-}" == "--" ]]; then
          shift
        fi
        run_remote_exec "$@"
        ;;
      *) die "Unknown remote command: $command" ;;
    esac
    ;;
  terraform)
    if [[ "$command" == "help" ]]; then
      show_help_topic terraform
      exit 0
    fi
    run_terraform "$command" "$@"
    ;;
  doctl)
    if [[ "$command" == "help" ]]; then
      show_help_topic doctl
      exit 0
    fi
    run_doctl "$command" "$@"
    ;;
  check)
    case "$command" in
      help) show_help_topic check ;;
      host) run_host_check all ;;
      local) run_host_check mac ;;
      remote) run_host_check remote ;;
      *) die "Unknown check command: $command" ;;
    esac
    ;;
  *)
    die "Unknown group: $group"
    ;;
esac
