# safe

Local git repo with a project-scoped Codex configuration.

## Codex setup

- This repo uses `~/Projects/safe/.envrc` to set `CODEX_HOME=~/Projects/safe/.codex`
- `direnv` loads that variable when you `cd` into this directory, so new `codex` sessions use the repo-local home
- The project-local Codex config lives at `~/Projects/safe/.codex/config.toml`

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
