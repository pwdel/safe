#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "This installer is for Linux hosts only." >&2
  exit 1
fi

if [[ ! -f /etc/os-release ]]; then
  echo "Unsupported Linux host." >&2
  exit 1
fi

. /etc/os-release
if [[ "${ID:-}" != "ubuntu" ]]; then
  echo "This installer currently targets Ubuntu." >&2
  exit 1
fi

sudo apt-get update
sudo apt-get install -y \
  ansible \
  ca-certificates \
  curl \
  docker-compose-v2 \
  docker.io \
  git \
  golang-go \
  jq \
  nodejs \
  npm \
  python3 \
  python3-pip \
  python3-venv \
  ripgrep

sudo systemctl enable --now docker

cat <<'EOF'

Linux host bootstrap complete.

Next steps:
  1. Copy or clone /opt/safe-control onto the host you want to provision
  2. Keep fork work under /srv/workspaces/forks
  3. Start the coding runner with: sudo /usr/local/bin/safe-start-runner
EOF
