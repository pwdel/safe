#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$INFRA_DIR/.." && pwd)"
LINUX_DIR="$REPO_ROOT/LINUX"
TERRAFORM_DIR="$INFRA_DIR/terraform"
HELP_DIR="$SCRIPT_DIR/help"

VM_NAME="${VM_NAME:-safevm}"
TARGET_HOST="${TARGET_HOST:-}"
REMOTE_SSH_USER="${REMOTE_SSH_USER:-operator}"
REMOTE_BOOTSTRAP_USER="${REMOTE_BOOTSTRAP_USER:-root}"
REMOTE_PORT="${REMOTE_PORT:-22}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519}"
SSH_PUBLIC_KEY="${SSH_PUBLIC_KEY:-$HOME/.ssh/id_ed25519.pub}"
HOST_KEYS_DIR="${HOST_KEYS_DIR:-$HOME/.keys/safe}"
TF_AUTO_APPROVE="${TF_AUTO_APPROVE:-0}"

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

show_help_topic() {
  local topic="${1:-overview}"
  local help_file="$HELP_DIR/safectl-${topic}.txt"
  if [[ ! -f "$help_file" ]]; then
    die "Unknown help topic: $topic (expected one of: overview, local, remote, terraform, access, check)"
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
  [[ -f "$SSH_KEY" ]] || die "SSH key not found: $SSH_KEY"
  [[ -n "$TARGET_HOST" ]] || die "Missing --host (or TARGET_HOST env var)."
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
  [[ -f "$SSH_KEY" ]] || die "SSH key not found: $SSH_KEY"
  [[ -n "$TARGET_HOST" ]] || die "Missing --host (or TARGET_HOST env var)."
  ssh \
    -i "$SSH_KEY" \
    -p "$REMOTE_PORT" \
    -o StrictHostKeyChecking=accept-new \
    -t "${REMOTE_SSH_USER}@${TARGET_HOST}" \
    "$command"
}

remote_ssh_shell() {
  require_cmd ssh
  [[ -f "$SSH_KEY" ]] || die "SSH key not found: $SSH_KEY"
  [[ -n "$TARGET_HOST" ]] || die "Missing --host (or TARGET_HOST env var)."
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
  [[ -n "$TARGET_HOST" ]] || die "Missing --host (or TARGET_HOST env var) for remote bootstrap."
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
      ;;
    output-bootstrap)
      (cd "$TERRAFORM_DIR" && terraform output bootstrap_command)
      ;;
    deploy)
      (cd "$TERRAFORM_DIR" && terraform init)
      if [[ "$TF_AUTO_APPROVE" == "1" ]]; then
        (cd "$TERRAFORM_DIR" && terraform apply -auto-approve "$@")
      else
        (cd "$TERRAFORM_DIR" && terraform apply "$@")
      fi
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
