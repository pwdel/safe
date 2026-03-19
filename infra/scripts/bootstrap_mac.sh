#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This bootstrap script is intended for macOS hosts." >&2
  exit 1
fi

VM_NAME="${VM_NAME:-safevm}"
VM_IMAGE="${VM_IMAGE:-24.04}"
VM_CPUS="${VM_CPUS:-2}"
VM_MEMORY="${VM_MEMORY:-4G}"
VM_DISK="${VM_DISK:-30G}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$INFRA_DIR/.." && pwd)"
ANSIBLE_DIR="$INFRA_DIR/ansible"
INVENTORY_SCRIPT="$ANSIBLE_DIR/scripts/gen_inventory_from_multipass.sh"
ARCHIVE_PATH="$(mktemp /tmp/safe-bootstrap.XXXXXX.tar.gz)"
AGENT_ENV_PATH="$(mktemp /tmp/safe-agent-env.XXXXXX)"
SSH_PUBLIC_KEY="${SSH_PUBLIC_KEY:-$HOME/.ssh/id_ed25519.pub}"
HOST_KEYS_DIR="${HOST_KEYS_DIR:-$HOME/.keys/safe}"
RENDER_AGENT_ENV="$INFRA_DIR/scripts/render_host_agent_env.sh"

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

require_cmd multipass
require_cmd ansible-playbook
require_cmd ssh-keygen
require_cmd tar

if [[ ! -f "$SSH_PUBLIC_KEY" ]]; then
  echo "SSH public key not found: $SSH_PUBLIC_KEY" >&2
  exit 1
fi

if [[ -d "$HOST_KEYS_DIR" ]]; then
  OUTPUT="$AGENT_ENV_PATH" HOST_KEYS_DIR="$HOST_KEYS_DIR" bash "$RENDER_AGENT_ENV" >/dev/null
else
  : >"$AGENT_ENV_PATH"
  chmod 0600 "$AGENT_ENV_PATH"
fi

if ! multipass info "$VM_NAME" >/dev/null 2>&1; then
  multipass launch "$VM_IMAGE" --name "$VM_NAME" --cpus "$VM_CPUS" --memory "$VM_MEMORY" --disk "$VM_DISK"
else
  multipass start "$VM_NAME"
fi

multipass exec "$VM_NAME" -- sudo mkdir -p /opt/safe-control
multipass exec "$VM_NAME" -- sudo rm -rf /opt/safe-control/*

tar \
  --exclude='.git' \
  --exclude='.opencode-runtime' \
  --exclude='infra/ansible/.ansible' \
  --exclude='infra/ansible/inventory/hosts.yml' \
  -czf "$ARCHIVE_PATH" \
  -C "$REPO_ROOT" .

multipass exec "$VM_NAME" -- bash -lc 'rm -rf /tmp/safe-control /tmp/safe-control.tgz && mkdir -p /tmp/safe-control'
multipass transfer "$ARCHIVE_PATH" "$VM_NAME":/tmp/safe-control.tgz
multipass exec "$VM_NAME" -- bash -lc 'tar -xzf /tmp/safe-control.tgz -C /tmp/safe-control'
multipass exec "$VM_NAME" -- sudo bash -lc 'cp -a /tmp/safe-control/. /opt/safe-control/'
multipass transfer "$AGENT_ENV_PATH" "$VM_NAME":/tmp/agent.env
multipass exec "$VM_NAME" -- sudo bash -lc 'mkdir -p /srv/safe-secrets && install -m 0600 -o operator -g operator /tmp/agent.env /srv/safe-secrets/agent.env'
PUBKEY_CONTENT="$(cat "$SSH_PUBLIC_KEY")"
multipass exec "$VM_NAME" -- bash -lc "mkdir -p ~/.ssh && chmod 700 ~/.ssh && grep -qxF '$PUBKEY_CONTENT' ~/.ssh/authorized_keys 2>/dev/null || printf '%s\n' '$PUBKEY_CONTENT' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"

bash "$INVENTORY_SCRIPT" "$VM_NAME"

VM_IP="$(awk '/ansible_host:/ {print $2; exit}' "$ANSIBLE_DIR/inventory/hosts.yml")"
if [[ -n "$VM_IP" ]]; then
  ssh-keygen -R "$VM_IP" >/dev/null 2>&1 || true
fi

pushd "$ANSIBLE_DIR" >/dev/null
export ANSIBLE_CONFIG="$ANSIBLE_DIR/ansible.cfg"
ansible-playbook -i inventory/hosts.yml playbooks/site.yml
popd >/dev/null

cat <<EOF

Multipass bootstrap complete.

Open a shell with:
  bash "$INFRA_DIR/scripts/mp-shell.sh"
EOF
