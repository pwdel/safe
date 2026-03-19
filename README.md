# safe

Local git repo used to simulate a user-scoped AI coding environment.

This repo is intentionally checked in as a project so the setup can be versioned, reviewed, and shared. The target operating model is still a user-scoped machine configuration. In other words:

- the guardrails are designed as if they would normally live in `~/.codex`, `~/.opencode`, shell startup files, and user-level hook directories
- this repo exists to prototype and document that setup safely before promoting pieces of it to a real user-scoped machine

## Start here

- For the consolidated machine setup guide, read `MACOS/MACOS.md`
- For the one-shot macOS installer, run `bash MACOS/install.sh`
- For Codex and OpenCode guardrail details, see `docs/`

## Included setup areas

- repo-local Codex configuration under `.codex/`
- repo-local OpenCode configuration under `opencode.json` and `.opencode/`
- pre-commit guardrails for tracked config safety
- Multipass and Ansible scaffolding for a VM -> Docker automation layer
- macOS machine bootstrap steps consolidated from related repos under `~/Projects`

## Key repo-local commands

```bash
cd ~/Projects/safe
direnv allow
pre-commit install
codex
bash scripts/opencode-local.sh
bash infra/scripts/bootstrap_mac.sh
```
