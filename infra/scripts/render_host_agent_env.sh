#!/usr/bin/env bash
set -euo pipefail

HOST_KEYS_DIR="${HOST_KEYS_DIR:-$HOME/.keys/safe}"
OUTPUT="${OUTPUT:-}"

allowed_key() {
  case "$1" in
    GITHUB_TOKEN|GH_TOKEN|OPENAI_API_KEY|OPENAI_ORG_ID|OPENAI_BASE_URL)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

emit_valid_lines() {
  local file="$1"
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
      printf '%s\n' "$line"
      continue
    fi

    if [[ "$line" =~ ^([A-Z0-9_]+)=(.*)$ ]]; then
      key="${BASH_REMATCH[1]}"
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

if [[ -z "$OUTPUT" ]]; then
  OUTPUT="$(mktemp /tmp/safe-agent-env.XXXXXX)"
fi

: >"$OUTPUT"

if [[ -f "$HOST_KEYS_DIR/agent.env" ]]; then
  emit_valid_lines "$HOST_KEYS_DIR/agent.env" >>"$OUTPUT"
else
  if [[ -f "$HOST_KEYS_DIR/github.env" ]]; then
    emit_valid_lines "$HOST_KEYS_DIR/github.env" >>"$OUTPUT"
  fi
  if [[ -f "$HOST_KEYS_DIR/openai.env" ]]; then
    if [[ -s "$OUTPUT" ]]; then
      printf '\n' >>"$OUTPUT"
    fi
    emit_valid_lines "$HOST_KEYS_DIR/openai.env" >>"$OUTPUT"
  fi
fi

chmod 0600 "$OUTPUT"
printf '%s\n' "$OUTPUT"
