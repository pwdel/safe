#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if multipass info "${VM_NAME:-safevm}" >/dev/null 2>&1; then
  bash "$SCRIPT_DIR/vm-delete.sh"
fi

exec bash "$SCRIPT_DIR/bootstrap_mac.sh"
