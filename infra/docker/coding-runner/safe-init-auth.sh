#!/usr/bin/env bash
set -euo pipefail

if [[ -n "${GITHUB_TOKEN:-}" || -n "${GH_TOKEN:-}" ]]; then
  export GH_TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
  if command -v gh >/dev/null 2>&1; then
    if ! gh auth status >/dev/null 2>&1; then
      printf '%s' "$GH_TOKEN" | gh auth login --hostname github.com --with-token >/dev/null
    fi
    gh auth setup-git >/dev/null 2>&1 || true
    echo "GitHub auth is configured inside the runner."
  else
    echo "gh is not installed in the runner." >&2
  fi
else
  echo "GitHub token not present in runner environment."
fi

if [[ -n "${OPENAI_API_KEY:-}" ]]; then
  echo "OpenAI API key is present in the runner environment."
else
  echo "OpenAI API key not present in runner environment."
fi
