#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

export XDG_CONFIG_HOME="${repo_root}/.opencode-runtime/config"
export XDG_STATE_HOME="${repo_root}/.opencode-runtime/state"
export XDG_DATA_HOME="${repo_root}/.opencode-runtime/data"
export XDG_CACHE_HOME="${repo_root}/.opencode-runtime/cache"

mkdir -p \
  "${XDG_CONFIG_HOME}" \
  "${XDG_STATE_HOME}" \
  "${XDG_DATA_HOME}" \
  "${XDG_CACHE_HOME}"

exec opencode "${repo_root}" "$@"
