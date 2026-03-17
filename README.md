# safe

Local git repo used to simulate a user-scoped AI coding environment.

This repo is intentionally checked in as a project so the setup can be versioned, reviewed, and shared. The target operating model is still a user-scoped machine configuration. In other words:

- the guardrails are designed as if they would normally live in `~/.codex`, `~/.opencode`, shell startup files, and user-level hook directories
- this repo exists to prototype and document that setup safely before promoting pieces of it to a real user-scoped machine

## Codex setup

- This repo uses `~/Projects/safe/.envrc` to set `CODEX_HOME=~/Projects/safe/.codex`
- `direnv` loads that variable when you `cd` into this directory, so new `codex` sessions use the repo-local home
- The project-local Codex config lives at `~/Projects/safe/.codex/config.toml`
- Pre-commit hooks enforce the repo's safe Codex defaults before each commit
- Codex hook and guardrail experiments are documented under `docs/`

## `.envrc`

- `.envrc` is a directory-local environment file managed by `direnv`
- Entering this repo exports `CODEX_HOME`; leaving the repo removes that override from the shell environment
- If `.envrc` changes, run `direnv allow ~/Projects/safe`

## `codex -c`

- Use `codex -c key=value ...` for one-off config overrides without editing `config.toml`
- Example: ``codex -c model='"gpt-5.4"' -c approval_policy='"on-request"'``
- CLI `-c` overrides win over both project-local and global Codex config for that invocation only

## Config precedence

- `codex -c` / CLI flags
- `~/Projects/safe/.codex/config.toml`
- `~/.codex/config.toml`

## Path note

- Use `~/Projects/...` in shell-facing files like `.envrc`, README examples, and terminal commands
- Keep `[projects."/absolute/path"]` entries in `config.toml` as absolute paths when you need them; `config.toml` is not shell-expanded like `.envrc`
- To avoid checking in machine-specific paths, prefer keeping path-specific trust settings in `~/.codex/config.toml` or setting trust locally instead of committing them to the repo

## Sample commands

- Start Codex with this repo's local `CODEX_HOME` and safe defaults: `cd ~/Projects/safe && codex`
- Override the model for one run: `cd ~/Projects/safe && codex -c model='"gpt-5.4"'`
- Override approvals for one run: `cd ~/Projects/safe && codex -c approval_policy='"on-request"'`
- Override sandbox mode for one run: `cd ~/Projects/safe && codex -s workspace-write`

## Pre-commit guardrails

- Install `pre-commit`, then run `cd ~/Projects/safe && pre-commit install`
- Run all checks on demand with `cd ~/Projects/safe && pre-commit run --all-files`
- The repo blocks commits that weaken the checked-in Codex safety defaults in `.codex/config.toml`
- The repo also blocks accidental commits of extra repo-local state under `.codex/` or `.claude/`

## OpenCode integration

- OpenCode is documented here because it currently offers a more Claude Code like hook/plugin surface than Codex
- Treat any repo-local OpenCode config in this repo the same way as the Codex config: as a simulation of what would eventually live in a user-scoped machine setup
- The active project-level OpenCode config is `opencode.json`
- The active project-level guardrails plugin is `.opencode/plugins/guardrails.js`
- `scripts/opencode-local.sh` runs OpenCode with repo-local XDG paths so the user-scoped runtime can be simulated safely inside this repo
- See `docs/opencode.json.example` for a minimal config example
- See `docs/opencode-guardrails-plugin.example.ts` for a TypeScript sample guardrails plugin
- See `docs/codex-hooks.md` for the Codex versus OpenCode tradeoff
- Start the local simulation with `cd ~/Projects/safe && bash scripts/opencode-local.sh`
