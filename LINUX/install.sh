#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "This installer is for Linux control-plane hosts only." >&2
  exit 1
fi

if [[ ! -f /etc/os-release ]]; then
  echo "Unsupported Linux host." >&2
  exit 1
fi

sudo apt-get update
sudo apt-get install -y \
  ansible \
  ca-certificates \
  curl \
  git \
  jq \
  openssh-client \
  python3 \
  python3-pip \
  python3-venv \
  ripgrep

cat <<'EOF'

Linux control-plane bootstrap complete.

Next steps:
  1. Create or identify the Ubuntu host you want to provision
  2. Ensure SSH access to that host works
  3. From the safe repo, run: bash LINUX/bootstrap_remote.sh
EOF
