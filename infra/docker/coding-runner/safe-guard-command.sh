#!/usr/bin/env bash
set -euo pipefail

cmd_name="$(basename "$0")"
real_cmd="/bin/$cmd_name"
if [[ ! -x "$real_cmd" ]]; then
  real_cmd="$(command -v "$cmd_name" || true)"
fi

if [[ -z "$real_cmd" || ! -x "$real_cmd" ]]; then
  echo "Unable to resolve wrapped command: $cmd_name" >&2
  exit 127
fi

if [[ "${SAFE_ALLOW_RISKY:-0}" == "1" ]]; then
  exec "$real_cmd" "$@"
fi

block() {
  echo "Blocked risky command in safe runner: $cmd_name $*" >&2
  echo "Set SAFE_ALLOW_RISKY=1 if you intentionally need to bypass this guard." >&2
  exit 64
}

case "$cmd_name" in
  rm)
    for arg in "$@"; do
      case "$arg" in
        /|/*/..|../*|../../*|~|$HOME|/workspace)
          block "$@"
          ;;
      esac
    done
    joined=" $* "
    if [[ "$joined" == *" -rf / "* || "$joined" == *" -fr / "* || "$joined" == *" --no-preserve-root "* ]]; then
      block "$@"
    fi
    ;;
  chmod)
    joined=" $* "
    if [[ "$joined" == *" -R 777 "* || "$joined" == *" -R 666 "* || "$joined" == *" -R a+w "* || "$joined" == *" -R a+rwx "* ]]; then
      block "$@"
    fi
    ;;
  chown)
    joined=" $* "
    if [[ "$joined" == *" -R "* ]]; then
      block "$@"
    fi
    ;;
  dd|mkfs|fdisk|sfdisk|parted|mount|umount)
    block "$@"
    ;;
esac

exec "$real_cmd" "$@"
