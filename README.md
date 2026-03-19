# safe

Local git repo used to simulate a user-scoped AI coding environment.

This repo is intentionally checked in as a project so the setup can be versioned, reviewed, and shared. The target operating model is still a user-scoped machine configuration. In other words:

- the guardrails are designed as if they would normally live in `~/.codex`, `~/.opencode`, shell startup files, and user-level hook directories
- this repo exists to prototype and document that setup safely before promoting pieces of it to a real user-scoped machine

## Start here

- For the consolidated machine setup guide, read `MACOS/MACOS.md`
- For the one-shot macOS installer, run `bash MACOS/install.sh`
- For a remote Linux host such as DigitalOcean, read `LINUX/LINUX.md`
- For Codex and OpenCode guardrail details, see `docs/`

## Chat runtime choice

- Use `opencode` as the primary ChatGPT runtime for this repo.
- Reason: this repo now uses OpenCode hooks to pre-compact context on every model call (`experimental.chat.messages.transform`).
- Keep `codex` installed as a fallback for simpler sessions without custom pre-send compaction.

## Agent teams

- `opencode.json` now sets `default_agent` to `team-orchestrator`.
- Team subagents are configured as `team-review` and `team-implement` under `agent`.
- The orchestrator is allowed to delegate via `permission.task` to `general`, `explore`, and `team-*`.

Quick checks:

```bash
opencode debug agent team-orchestrator
opencode debug agent team-review
opencode debug agent team-implement
```

## Required installs for this repo

- `opencode` CLI
- OpenCode plugin package: `opencode-openai-codex-auth`
- `codex` CLI (recommended fallback)
- `direnv` (optional, only if using repo-local `.envrc`)

Quick check:

```bash
opencode --version
codex --version
```

## Included setup areas

- repo-local Codex configuration under `.codex/`
- repo-local OpenCode configuration under `opencode.json` and `.opencode/`
- pre-commit guardrails for tracked config safety
- Multipass and Ansible scaffolding for a VM -> Docker automation layer
- macOS machine bootstrap steps consolidated from related repos under `~/Projects`

## Key repo-local commands

```bash
cd ~/Projects/safe
pre-commit install
codex
bash scripts/opencode-local.sh
bash infra/scripts/bootstrap_mac.sh
```

For the Multipass workflow, `direnv` is optional. It is only needed if you want the repo-local `.envrc` behavior for tools like Codex.
