#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_MANIFEST_FILE="$SCRIPT_DIR/env_key_manifest.sh"

HOST_KEYS_DIR="${HOST_KEYS_DIR:-$HOME/.keys/safe}"
OUTPUT="${OUTPUT:-}"

allowed_key() {
  env_manifest_contains "$1" "${TASK_SPEC_ALLOWED_KEYS[@]}"
}

emit_valid_lines() {
  local file="$1"
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
      printf '%s\n' "$line"
      continue
    fi

    if [[ "$line" =~ ^([A-Z0-9_]+)=(.*)$ ]]; then
      local key="${BASH_REMATCH[1]}"
      if ! allowed_key "$key"; then
        echo "Unsupported key in $file: $key" >&2
        exit 1
      fi
      printf '%s\n' "$line"
      continue
    fi

    echo "Invalid line in $file: $line" >&2
    exit 1
  done <"$file"
}

if [[ ! -f "$ENV_MANIFEST_FILE" ]]; then
  echo "Missing env manifest: $ENV_MANIFEST_FILE" >&2
  exit 1
fi
# shellcheck source=infra/scripts/env_key_manifest.sh
source "$ENV_MANIFEST_FILE"

if [[ -z "$OUTPUT" ]]; then
  OUTPUT="$(mktemp /tmp/safe-task-spec-env.XXXXXX)"
fi

: >"$OUTPUT"

if [[ -f "$HOST_KEYS_DIR/$TASK_SPEC_ENV_FILE" ]]; then
  emit_valid_lines "$HOST_KEYS_DIR/$TASK_SPEC_ENV_FILE" >>"$OUTPUT"
fi

chmod 0600 "$OUTPUT"
printf '%s\n' "$OUTPUT"
