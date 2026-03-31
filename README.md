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

## Docs

- Command reference: `README/HELP.md`
- Local flow: `README/LOCAL.md`
- Remote flow: `README/REMOTE.md`
- Access levels: `README/ACCESS.md`
- Isolation model and architecture: `README/ISOLATION.md`
- Infra details: `infra/README.md`
