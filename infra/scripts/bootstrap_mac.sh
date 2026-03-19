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

if ! multipass info "$VM_NAME" >/dev/null 2>&1; then
  multipass launch "$VM_IMAGE" --name "$VM_NAME" --cpus "$VM_CPUS" --memory "$VM_MEMORY" --disk "$VM_DISK"
else
  multipass start "$VM_NAME"
fi

multipass exec "$VM_NAME" -- sudo mkdir -p /opt/safe-control
multipass exec "$VM_NAME" -- sudo rm -rf /opt/safe-control/*
multipass transfer -r "$REPO_ROOT"/ "$VM_NAME":/tmp/safe-control
multipass exec "$VM_NAME" -- sudo bash -lc 'cp -a /tmp/safe-control/. /opt/safe-control/'

bash "$INVENTORY_SCRIPT" "$VM_NAME"

VM_IP="$(awk '/ansible_host:/ {print $2; exit}' "$ANSIBLE_DIR/inventory/hosts.yml")"
if [[ -n "$VM_IP" ]]; then
  ssh-keygen -R "$VM_IP" >/dev/null 2>&1 || true
fi

ansible-playbook -i "$ANSIBLE_DIR/inventory/hosts.yml" "$ANSIBLE_DIR/playbooks/site.yml"

cat <<EOF

Multipass bootstrap complete.

Open a shell with:
  bash "$INFRA_DIR/scripts/mp-shell.sh"
EOF
