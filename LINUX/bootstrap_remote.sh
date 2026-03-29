#!/usr/bin/env bash
set -euo pipefail

TARGET_HOST="${TARGET_HOST:-}"
TARGET_USER="${TARGET_USER:-ubuntu}"
TARGET_PORT="${TARGET_PORT:-22}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519}"
TARGET_APP_ROOT="${TARGET_APP_ROOT:-/opt/safe-control}"
SECRETS_ROOT="${SECRETS_ROOT:-/srv/safe-secrets}"
HOST_KEYS_DIR="${HOST_KEYS_DIR:-$HOME/.keys/safe}"
HOST_ALIAS="${HOST_ALIAS:-safehost}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INFRA_DIR="$REPO_ROOT/infra"
ANSIBLE_DIR="$INFRA_DIR/ansible"
ARCHIVE_PATH="$(mktemp /tmp/safe-linux-bootstrap.XXXXXX.tar.gz)"
AGENT_ENV_PATH="$(mktemp /tmp/safe-linux-agent-env.XXXXXX)"
RENDER_AGENT_ENV="$INFRA_DIR/scripts/render_host_agent_env.sh"
CHECK_HOST_PREREQS="$INFRA_DIR/scripts/check_host_prereqs.sh"
RENDER_INVENTORY="$ANSIBLE_DIR/scripts/render_inventory_for_ssh_host.sh"

cleanup() {
  rm -f "$ARCHIVE_PATH"
  rm -f "$AGENT_ENV_PATH"
}

trap cleanup EXIT

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
}

require_cmd ansible-playbook
require_cmd scp
require_cmd ssh
require_cmd tar

CHECK_ARGS=(--target remote --host-keys-dir "$HOST_KEYS_DIR" --ssh-private-key "$SSH_KEY")
if [[ -f "${SSH_KEY}.pub" ]]; then
  CHECK_ARGS+=(--ssh-public-key "${SSH_KEY}.pub")
fi
if [[ "${REQUIRE_RUNTIME_CREDENTIALS:-0}" == "1" ]]; then
  CHECK_ARGS+=(--require-credentials)
fi
bash "$CHECK_HOST_PREREQS" "${CHECK_ARGS[@]}"

if [[ -z "$TARGET_HOST" ]]; then
  echo "TARGET_HOST is required" >&2
  exit 1
fi

if [[ ! -f "$SSH_KEY" ]]; then
  echo "SSH key not found: $SSH_KEY" >&2
  exit 1
fi

if [[ "$TARGET_APP_ROOT" != /opt/* ]]; then
  echo "Refusing to deploy to non-/opt target path: $TARGET_APP_ROOT" >&2
  exit 1
fi

if [[ -d "$HOST_KEYS_DIR" ]]; then
  OUTPUT="$AGENT_ENV_PATH" HOST_KEYS_DIR="$HOST_KEYS_DIR" bash "$RENDER_AGENT_ENV" >/dev/null
else
  : >"$AGENT_ENV_PATH"
  chmod 0600 "$AGENT_ENV_PATH"
fi

tar \
  --exclude='.git' \
  --exclude='.opencode-runtime' \
  --exclude='infra/ansible/.ansible' \
  --exclude='infra/ansible/inventory/hosts.yml' \
  -czf "$ARCHIVE_PATH" \
  -C "$REPO_ROOT" .

SSH_TARGET="$TARGET_USER@$TARGET_HOST"
SSH_OPTS=(-i "$SSH_KEY" -p "$TARGET_PORT" -o StrictHostKeyChecking=no)
SCP_OPTS=(-i "$SSH_KEY" -P "$TARGET_PORT" -o StrictHostKeyChecking=no)

ssh "${SSH_OPTS[@]}" "$SSH_TARGET" \
  "sudo mkdir -p '$TARGET_APP_ROOT' '$SECRETS_ROOT' && rm -rf '$TARGET_APP_ROOT'/* /tmp/safe-control /tmp/safe-control.tgz"

scp "${SCP_OPTS[@]}" "$ARCHIVE_PATH" "$SSH_TARGET:/tmp/safe-control.tgz"
scp "${SCP_OPTS[@]}" "$AGENT_ENV_PATH" "$SSH_TARGET:/tmp/agent.env"

ssh "${SSH_OPTS[@]}" "$SSH_TARGET" "\
  set -euo pipefail && \
  mkdir -p /tmp/safe-control && \
  tar -xzf /tmp/safe-control.tgz -C /tmp/safe-control && \
  sudo cp -a /tmp/safe-control/. '$TARGET_APP_ROOT/' && \
  sudo install -m 0600 -o root -g root /tmp/agent.env '$SECRETS_ROOT/agent.env' && \
  rm -rf /tmp/safe-control /tmp/safe-control.tgz /tmp/agent.env"

TARGET_HOST="$TARGET_HOST" \
TARGET_USER="$TARGET_USER" \
TARGET_PORT="$TARGET_PORT" \
SSH_KEY="$SSH_KEY" \
HOST_ALIAS="$HOST_ALIAS" \
bash "$RENDER_INVENTORY"

ssh-keygen -R "$TARGET_HOST" >/dev/null 2>&1 || true

pushd "$ANSIBLE_DIR" >/dev/null
export ANSIBLE_CONFIG="$ANSIBLE_DIR/ansible.cfg"
ansible-playbook -i inventory/hosts.yml playbooks/site.yml
popd >/dev/null

cat <<EOF

Remote Linux bootstrap complete.

Target host: $TARGET_HOST
Control repo: $TARGET_APP_ROOT
Secrets path: $SECRETS_ROOT/agent.env
EOF
