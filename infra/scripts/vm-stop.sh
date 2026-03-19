#!/usr/bin/env bash
set -euo pipefail

VM_NAME="${VM_NAME:-safevm}"

if ! multipass info "$VM_NAME" >/dev/null 2>&1; then
  echo "Instance not found: $VM_NAME" >&2
  exit 1
fi

exec multipass stop "$VM_NAME"
