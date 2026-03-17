#!/usr/bin/env bash
set -euo pipefail

status=0

for path in "$@"; do
  case "$path" in
    .codex/config.toml|.claude/README.md|.envrc|README.md|.gitignore|.pre-commit-config.yaml|scripts/hooks/*)
      ;;
    .codex/*)
      echo "Blocked: do not commit repo-local Codex state outside .codex/config.toml: $path" >&2
      status=1
      ;;
    .claude/*)
      echo "Blocked: do not commit repo-local Claude state outside .claude/README.md: $path" >&2
      status=1
      ;;
  esac
done

exit "$status"
