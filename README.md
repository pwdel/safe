# safe

Control-plane repo for running an isolated coding runtime on local Multipass or a remote VPS.

## Quick Start

```bash
# local
./safe check local
./safe local bootstrap

# remote
./safe check remote
./safe --host <droplet-ip> remote bootstrap
```

## Machine Setup Hint

Put runtime credentials under `~/.keys/safe`:

- split files: `github.env`, `codex.env`, `claude.env`
- or one combined file: `agent.env`

Then run:

```bash
./safe check host
```

This prints per-file and per-key checks (`GH_TOKEN`, `GITHUB_TOKEN`, `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`).

For normal Codex account login (device/web flow) inside the runner:

```bash
./safe local codex-login
```

If Codex returns:
`Enable device code authorization for Codex in ChatGPT Security Settings`
enable that setting in your ChatGPT account, then retry `local codex-login`.

## Sandbox Fork Inputs (Required)

Use two sandbox forks under your automation GitHub account and configure them in
`~/.keys/safe/task-spec.env`:

1. task repo fork (the workflow/spec repo)
2. target repo fork (the codebase the runner edits)

`SAFE_TASK_SPEC_REF` is required and must exist in the task repo fork
(branch or tag; recommended: release tag such as `v0.0.1`).

Example:

```bash
SAFE_TASK_SPEC_REPO=https://github.com/<sandbox-user>/<task-spec-fork>
SAFE_TASK_SPEC_REF=<tag-or-branch>
SAFE_TASK_TARGET_FORK_URL=https://github.com/<sandbox-user>/<target-repo-fork>
SAFE_TASK_TARGET_UPSTREAM_URL=https://github.com/<upstream-org>/<target-repo>
SAFE_TASK_TARGET_DIR=<target-repo-dir-name>
```

Then sync:

```bash
./safe local helper safe-sync-task-spec
```

## Docs

- Command reference: `README/HELP.md`
- Local flow: `README/LOCAL.md`
- Remote flow: `README/REMOTE.md`
- Access levels: `README/ACCESS.md`
- Security model and hardening: `SECURITY.md`
- Isolation model and architecture: `README/ISOLATION.md`
- Infra details: `infra/README.md`
