#!/usr/bin/env bash
set -euo pipefail

VM_NAME="${VM_NAME:-safevm}"

if multipass info "$VM_NAME" >/dev/null 2>&1; then
  exec multipass info "$VM_NAME"
fi

echo "Instance not found: $VM_NAME" >&2
exec multipass list
