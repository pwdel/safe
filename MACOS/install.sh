#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This installer is for macOS only." >&2
  exit 1
fi

PROJECTS_DIR="${PROJECTS_DIR:-$HOME/Projects}"
PYTHON_VERSION="${PYTHON_VERSION:-3.12}"
INSTALL_DOCKER="${INSTALL_DOCKER:-1}"
INSTALL_CODEX="${INSTALL_CODEX:-1}"

append_if_missing() {
  local file="$1"
  local line="$2"
  touch "$file"
  if ! grep -Fqx "$line" "$file"; then
    printf '%s\n' "$line" >>"$file"
  fi
}

append_block_if_missing() {
  local file="$1"
  local marker="$2"
  local block="$3"
  touch "$file"
  if ! grep -Fq "$marker" "$file"; then
    printf '\n%s\n' "$block" >>"$file"
  fi
}

if ! xcode-select -p >/dev/null 2>&1; then
  echo "Xcode Command Line Tools are not installed. Run: xcode-select --install" >&2
  exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

eval "$(/opt/homebrew/bin/brew shellenv)"
append_if_missing "$HOME/.zprofile" 'eval "$(/opt/homebrew/bin/brew shellenv)"'
append_if_missing "$HOME/.bash_profile" 'eval "$(/opt/homebrew/bin/brew shellenv)"'
append_if_missing "$HOME/.bashrc" 'eval "$(/opt/homebrew/bin/brew shellenv)"'

brew update

brew install ansible multipass direnv uv pyenv pyenv-virtualenv pre-commit gettext tree gh opencode

if [[ "$INSTALL_CODEX" == "1" ]]; then
  brew install --cask codex
fi

if [[ "$INSTALL_DOCKER" == "1" ]]; then
  brew install --cask docker-desktop
fi

append_if_missing "$HOME/.zshrc" 'eval "$(direnv hook zsh)"'
append_if_missing "$HOME/.zshrc" 'export PATH="/opt/homebrew/opt/gettext/bin:$PATH"'
append_if_missing "$HOME/.bashrc" 'export PATH="/opt/homebrew/opt/gettext/bin:$PATH"'

append_block_if_missing "$HOME/.zshrc" '# safe-pyenv-init' "$(cat <<'EOF'
# safe-pyenv-init
export PYENV_ROOT="$HOME/.pyenv"
if command -v pyenv >/dev/null 2>&1; then
  eval "$(pyenv init - zsh)"
  eval "$(pyenv virtualenv-init -)"
fi
EOF
)"

append_block_if_missing "$HOME/.zshrc" '# safe-vm-tools' "$(cat <<'EOF'
# safe-vm-tools
alias mp='multipass'
alias ap='ansible-playbook'
alias safe-bootstrap='bash "$HOME/Projects/safe/infra/scripts/bootstrap_mac.sh"'
alias safe-vm='bash "$HOME/Projects/safe/infra/scripts/mp-shell.sh"'
EOF
)"

append_block_if_missing "$HOME/.bashrc" '# safe-vm-tools' "$(cat <<'EOF'
# safe-vm-tools
alias mp='multipass'
alias ap='ansible-playbook'
alias safe-bootstrap='bash "$HOME/Projects/safe/infra/scripts/bootstrap_mac.sh"'
alias safe-vm='bash "$HOME/Projects/safe/infra/scripts/mp-shell.sh"'
EOF
)"

uv python install "$PYTHON_VERSION"

if [[ -d "$PROJECTS_DIR/socialpredict" ]]; then
  mkdir -p "$PROJECTS_DIR/socialpredict/data/postgres" "$PROJECTS_DIR/socialpredict/data/certbot"
  chown -R "$(whoami)":staff "$PROJECTS_DIR/socialpredict/data"
fi

cat <<EOF

Install complete.

Next recommended steps:
  1. Restart your shell or run: source ~/.zprofile && source ~/.zshrc
  2. cd $PROJECTS_DIR/safe && direnv allow && pre-commit install
  3. cd $PROJECTS_DIR/mlx-test && direnv allow && uv sync
  4. cd $PROJECTS_DIR/safe && bash scripts/opencode-local.sh auth login
  5. If Docker Desktop was installed, open it once before using socialpredict
  6. Verify Ansible and Multipass with: ansible --version && multipass version
  7. Try the shell helpers: safe-bootstrap && safe-vm

Reference:
  $PROJECTS_DIR/safe/MACOS/MACOS.md
EOF
