#!/usr/bin/env bash
set -euo pipefail

VM_NAME="${1:-safevm}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
INVENTORY_FILE="$ANSIBLE_DIR/inventory/hosts.yml"

if ! command -v multipass >/dev/null 2>&1; then
  echo "multipass is required" >&2
  exit 1
fi

IP="$(multipass info "$VM_NAME" | awk '/IPv4/ {print $2; exit}')"

if [[ -z "$IP" ]]; then
  echo "Could not determine IP for Multipass instance: $VM_NAME" >&2
  exit 1
fi

cat >"$INVENTORY_FILE" <<EOF
all:
  hosts:
    $VM_NAME:
      ansible_host: $IP
      ansible_user: ubuntu
      ansible_ssh_common_args: "-o StrictHostKeyChecking=no"
EOF

echo "Wrote $INVENTORY_FILE for $VM_NAME ($IP)"
