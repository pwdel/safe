# MacOS Setup

This repo is a portable, versioned simulation of a user-scoped AI coding setup on macOS.

The long-term target is still a real user-scoped machine configuration such as:

- `~/.codex`
- `~/.config/opencode`
- shell startup files like `~/.zprofile` and `~/.zshrc`
- user-installed tools from Homebrew

For now, `safe/` holds the documented version of that setup so it can be reviewed and iterated safely in git.

## What this consolidates

This document rolls together:

- the current `safe/README.md`
- the older `machinesetup/README.md`
- `mlx-test/README.md`
- `mlx-test/USE.md`
- `socialpredict/README/LOCAL_SETUP.md`
- the relevant repo-local Codex patterns from `specify-setup`

`new/` did not add tracked machine prerequisites beyond general Codex local state, so it does not materially change this guide.

## Baseline assumptions

- Host OS: macOS on Apple silicon
- Shell: `zsh`
- Projects root: `~/Projects`
- Homebrew prefix: `/opt/homebrew`

## Machine-level prerequisites

### Xcode Command Line Tools

Install Apple’s command-line developer tools first:

```bash
xcode-select --install
```

### Homebrew

Install Homebrew, then add it to your shell:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
```

### Core CLI tools

These tools cover the repos currently under `~/Projects`:

- `ansible`
- `multipass`
- `direnv`
- `uv`
- `pyenv`
- `pyenv-virtualenv`
- `pre-commit`
- `gettext`
- `tree`
- `gh`
- `opencode`

Install them with:

```bash
brew install ansible multipass direnv uv pyenv pyenv-virtualenv pre-commit gettext tree gh opencode
```

### GUI and larger tooling

These are installed as Homebrew casks:

- `codex`
- `docker-desktop`

Install them with:

```bash
brew install --cask codex docker-desktop
```

## Shell configuration

### Homebrew shellenv

Add Homebrew to `~/.zprofile`:

```bash
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
```

### direnv

Hook `direnv` into `zsh`:

```bash
echo 'eval "$(direnv hook zsh)"' >> ~/.zshrc
```

### pyenv

Hook `pyenv` and `pyenv-virtualenv` into `zsh`:

```bash
cat <<'EOF' >> ~/.zshrc
export PYENV_ROOT="$HOME/.pyenv"
if command -v pyenv >/dev/null 2>&1; then
  eval "$(pyenv init - zsh)"
  eval "$(pyenv virtualenv-init -)"
fi
EOF
```

### gettext / envsubst

If `envsubst` is not visible after `brew install gettext`, add:

```bash
echo 'export PATH="/opt/homebrew/opt/gettext/bin:$PATH"' >> ~/.zshrc
```

## Python strategy

The repos here are better served by `uv` and `pyenv` than by shell aliases like `python=python3` or `pip=pip3`.

Recommended baseline:

```bash
uv python install 3.12
pyenv install 3.12.2
```

Notes:

- `mlx-test` requires Python `>=3.10`
- `uv sync` is the expected dependency workflow for the local MLX repo
- the older `machinesetup` guidance about `pip-tools` and Python aliases is optional, not required for the current repos

## SSH

Generate a user key if needed:

```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
pbcopy < ~/.ssh/id_ed25519.pub
```

## AI coding tools

### Codex

- The portable simulation in this repo uses `~/Projects/safe/.envrc` to point `CODEX_HOME` at `~/Projects/safe/.codex`
- In a real user-scoped setup, the equivalent settings would usually live under `~/.codex`
- This repo currently documents Codex guardrails, pre-commit checks, and hook experiments

Useful commands:

```bash
cd ~/Projects/safe
direnv allow
codex
pre-commit install
pre-commit run --all-files
```

### OpenCode

- OpenCode is included because it currently offers a more Claude Code like hook/plugin surface
- This repo keeps the project config at `opencode.json`
- The active repo-local plugin lives at `.opencode/plugins/guardrails.js`
- `scripts/opencode-local.sh` simulates user-scoped XDG paths inside the repo

Useful commands:

```bash
cd ~/Projects/safe
bash scripts/opencode-local.sh --version
bash scripts/opencode-local.sh auth login
bash scripts/opencode-local.sh
```

## VM and provisioning layer

For this repo, Ansible and Multipass are required parts of the host setup on macOS Apple silicon.

The intended layering is:

- macOS host for interactive control and credentials
- Multipass VM for the first containment boundary
- Docker inside the VM for the actual automated coding runtime
- writable fork clones inside the VM, not directly on the macOS host

This is the model we want for running Codex or Claude Code with bypassed internal permissions while still keeping containment boundaries around the work.

Vagrant still belongs in the broader machine setup toolbox, but it is not the recommended `safe` implementation on Apple silicon.

## Repo-specific bootstrap steps

### `safe`

```bash
cd ~/Projects/safe
direnv allow
pre-commit install
bash infra/scripts/bootstrap_mac.sh
```

### `mlx-test`

This repo depends on Apple MLX and uses `uv`:

```bash
cd ~/Projects/mlx-test
direnv allow
uv sync
python -c "import mlx.core as mx; print(mx.array([1, 2, 3]))"
mlx-smoke-test
mlx-code-smoke-test
```

Notes:

- the first MLX code-model run downloads the model locally
- `mlx-community/Qwen2.5-Coder-7B-Instruct-4bit` is the currently documented test model

### `socialpredict`

This repo currently expects Docker Desktop and Docker Compose.

Install requirements first:

- Docker Desktop
- `gettext` for `envsubst`

Then bootstrap the local data directories if needed:

```bash
cd ~/Projects/socialpredict
mkdir -p data/postgres data/certbot
chown -R "$(whoami)":staff data
```

Then follow the local setup flow:

```bash
cd ~/Projects/socialpredict
./SocialPredict install
./SocialPredict up
```

Notes:

- on newer macOS versions, Docker file provenance / xattr behavior may require the local mounted-data workaround already described in `socialpredict`
- `docker compose` is expected, not `docker-compose`

### `specify-setup`

This repo contributes a pattern more than extra machine prerequisites:

- use `.envrc` to point `CODEX_HOME` at a repo-local `.codex`
- keep machine-specific Codex trust settings out of tracked repo config when possible

## Vagrant

Vagrant is required for the VM boundary:

```bash
brew install --cask virtualbox
brew tap hashicorp/tap
brew install hashicorp/tap/hashicorp-vagrant
```

On Apple silicon, the box/provider pair should be selected explicitly per project. The `safe` scaffold does not assume one universal default box.

For `safe`, the current default scaffold uses:

- provider: `virtualbox`
- box: `hashicorp-education/ubuntu-24-04`
- version: `0.1.0`

If VirtualBox on Apple silicon fails to boot the guest, HashiCorp’s docs note this workaround:

```bash
VBoxManage setextradata global "VBoxInternal/Devices/pcbios/0/Config/DebugLevel"
```

## Ansible

Ansible is required on the host and is used to provision the guest:

```bash
brew install ansible
```

This repo does not yet define a Vagrant machine. The goal here is only to ensure the Mac host has the prerequisite installed before that work starts.

## One-shot installer

Run the installer in this repo to apply the machine-level setup:

```bash
cd ~/Projects/safe
bash MACOS/install.sh
```

Optional environment flags:

- `INSTALL_DOCKER=0` to skip Docker Desktop
- `INSTALL_CODEX=0` to skip the Codex cask
- `PYTHON_VERSION=3.12` to change the `uv python install` target

## Verification checklist

- `brew --version`
- `direnv version`
- `uv --version`
- `pyenv --version`
- `pre-commit --version`
- `opencode --version`
- `ansible --version`
- `multipass version`
- `codex --version`
- `docker --version`
- `docker compose version`

## Source notes

This document intentionally favors current working practice over preserving every older setup habit verbatim. In particular:

- shell aliases for `python` and `pip` are not installed by default
- `pip-tools` is not part of the default install because the active repos are using `uv`
- Codex and OpenCode are documented as user-scoped tools that happen to be simulated inside `safe/`
