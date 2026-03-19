#!/usr/bin/env bash
set -euo pipefail

TARGET_HOST="${TARGET_HOST:-}"
TARGET_USER="${TARGET_USER:-ubuntu}"
TARGET_PORT="${TARGET_PORT:-22}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519}"
INVENTORY_FILE="${INVENTORY_FILE:-}"
HOST_ALIAS="${HOST_ALIAS:-safehost}"

if [[ -z "$TARGET_HOST" ]]; then
  echo "TARGET_HOST is required" >&2
  exit 1
fi

if [[ ! -f "$SSH_KEY" ]]; then
  echo "SSH key not found: $SSH_KEY" >&2
  exit 1
fi

if [[ -z "$INVENTORY_FILE" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  ANSIBLE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
  INVENTORY_FILE="$ANSIBLE_DIR/inventory/hosts.yml"
fi

cat >"$INVENTORY_FILE" <<EOF
all:
  hosts:
    $HOST_ALIAS:
      ansible_host: $TARGET_HOST
      ansible_user: $TARGET_USER
      ansible_port: $TARGET_PORT
      ansible_ssh_private_key_file: $SSH_KEY
      ansible_ssh_common_args: "-o StrictHostKeyChecking=no"
EOF

echo "Wrote $INVENTORY_FILE for $HOST_ALIAS ($TARGET_HOST:$TARGET_PORT)"
