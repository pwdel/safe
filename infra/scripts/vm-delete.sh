#!/usr/bin/env bash
set -euo pipefail

VM_NAME="${VM_NAME:-safevm}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ANSIBLE_DIR="$INFRA_DIR/ansible"
INVENTORY_FILE="$ANSIBLE_DIR/inventory/hosts.yml"

if ! multipass info "$VM_NAME" >/dev/null 2>&1; then
  echo "Instance not found: $VM_NAME" >&2
  exit 1
fi

VM_IP="$(multipass info "$VM_NAME" | awk '/IPv4/ {print $2; exit}')"
multipass delete --purge "$VM_NAME"

if [[ -n "$VM_IP" ]]; then
  ssh-keygen -R "$VM_IP" >/dev/null 2>&1 || true
fi

rm -f "$INVENTORY_FILE"

echo "Deleted Multipass instance: $VM_NAME"
