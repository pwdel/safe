# Objective

Ensure OpenCode guardrails run reliably in the full `safe` runtime stack:

- macOS host
- Multipass VM
- Docker container inside the VM

Specifically, the pre-compaction hook path must work end-to-end when OpenCode runs in-container:

1. A project-local Python environment is created with `uv` / `uv sync`.
2. OpenCode runs from that environment in the container.
3. OpenCode hooks can execute Python-based scripts, including `scripts/opencode/precompact-context.sh`, which depends on `python3`.
4. Hook execution is verifiable from logs (`Precompact complete`) during normal OpenCode runs.

## Acceptance Criteria

- Docker image/container includes `python3`, `uv`, and required runtime dependencies.
- `uv sync` succeeds in-container and creates a usable virtual environment.
- OpenCode session in-container successfully executes the precompact hook script.
- A documented smoke test command proves hook execution inside the Multipass -> Docker path.

## Project Checklist

This remains the working checklist for turning `safe` into a guardrailed automated-coding environment.

Current direction:

1. Keep the macOS host as the control plane.
2. Use a VM as the first containment boundary.
3. Run the coding agent inside a non-root Docker container in that VM.
4. Work only on fork clones.
5. Validate app containers from VM-controlled helper scripts instead of giving the agent direct Docker control.

Already in place:

- Multipass VM bootstrap on macOS
- Ansible provisioning for the guest
- Docker installed in the guest
- Non-root coding runner container
- Container hardening basics: dropped capabilities, `no-new-privileges`, and no Docker socket mounted into the runner
- Fork workspace model under `/srv/workspaces/forks`
- Helper-script model for starting the runner and app validation from the VM
- Local generated inventory and Ansible temp state ignored from git
- Documentation for the isolation layers and rationale

Still incomplete:

- Create a new repo that serves as the source of truth for the auto-coding environment pulled into `safe` runtimes
- Define the machine setup performed inside the coding image, including Codex, Claude, OpenCode, Go, and required Go tools
- Validate that pulling code from within the VM works from inside the Docker container
- Validate authentication from inside the container to Codex, Claude, and OpenCode against the chosen models
- Ensure hooks, agents, skills, and the full auto-coding environment can be installed and activated inside the container
- Create a sandbox GitHub account for fork-only automation
- Review `MACOS/` and `LINUX/` for consolidation into `../machinesetup` and replace local setup docs with pointers where appropriate
- Wire a real `socialpredict` fork workflow through the hardened runner
- Fully document the final operating procedure in the main README

## Checklist

- [x] Bootstrap a working macOS -> Multipass -> Docker flow for `safe`
- [x] Get Ansible provisioning working reliably against `safevm`
- [ ] Create a new repo for the reusable auto-coding environment
- [x] Make the coding runner non-root
- [x] Add baseline container hardening
- [x] Keep generated inventory and local Ansible state out of git
- [x] Document the current isolation model and threat rationale
- [x] Enforce fork-only git remotes and sandbox-only push targets
- [x] Define how sandbox GitHub credentials are injected into the runtime
- [x] Define how Codex / OpenAI auth is injected into the runtime without leaving broad secrets behind
- [x] Ensure the VM can install Docker and reliably build, pull, and start the coding image
- [ ] Define and automate the machine setup inside the coding image for Codex, Claude, OpenCode, Go, and required Go tools
- [ ] Validate pull operations from inside the VM-hosted Docker container
- [ ] Validate container auth flows for Codex, Claude, and OpenCode against the chosen models
- [ ] Ensure hooks, agents, skills, and the full auto-coding environment can be installed and activated inside the container
- [x] Add disposable runner reset / teardown scripts
- [x] Add VM reset / rebuild scripts
- [x] Add stronger runtime guardrails around risky shell behavior
- [x] Decide and implement the outbound network policy for the VM and coding runner
- [x] Build the Linux host bootstrap path for remote targets such as DigitalOcean droplets
- [x] Add Terraform scaffolding for DigitalOcean droplet and network resources
- [ ] Human task: create a sandbox GitHub account and token for fork-only automation
- [ ] Review `MACOS/` and `LINUX/` setup content for migration into `../machinesetup`
- [ ] Wire a real `socialpredict` fork workflow through the hardened runner
- [x] Add a documented workflow for app validation containers launched from the VM layer
- [x] Review whether any additional artifacts should be gitignored
- [ ] Document the final end-to-end operating procedure in `README.md`

## DigitalOcean Terraform Setup Plan

Goal: make DigitalOcean deployment repeatable while keeping secrets out of git and making the expected local key formats explicit in `safectl check local`.

Draft `~/.keys/safe` file map to implement:

- Runtime auth files use `.env` format (`KEY=VALUE`, optional `#` comments, uppercase keys only).
- `~/.keys/safe/agent.env` (preferred combined file) may include: `GH_TOKEN`, `GITHUB_TOKEN`, `OPENAI_API_KEY`, `OPENAI_ORG_ID`, `OPENAI_BASE_URL`, `ANTHROPIC_API_KEY`, `ANTHROPIC_BASE_URL`.
- Split runtime files remain supported when `agent.env` is absent: `github.env`, `codex.env`, `claude.env`, `openai.env`.
- Terraform secret file: `~/.keys/safe/terraform.env` with at least `TF_VAR_do_token=<digitalocean_token>`.

- [x] Add this plan section to `OBJECTIVE.md`.
- [x] Finalize and document the host key/env convention under `~/.keys/safe` for runtime auth + Terraform.
- [x] Define and document file format rules for `~/.keys/safe/*.env`: `KEY=VALUE`, `#` comments allowed, no committed secrets.
- [x] Define required Terraform secret file: `~/.keys/safe/terraform.env` with at least `TF_VAR_do_token=<digitalocean_token>`.
- [x] Define optional Terraform override variables for `terraform.env` (for example: `TF_VAR_region`, `TF_VAR_droplet_size`, `TF_VAR_allowed_ssh_cidrs`).
- [x] Update `infra/scripts/safectl.sh check local`/`check host` output to explicitly show expected `~/.keys/safe` files and env format requirements.
- [x] Extend `infra/scripts/check_host_prereqs.sh` to validate presence/shape of `terraform.env` entries when DigitalOcean checks are requested.
- [x] Decide how `safectl terraform ...` loads local Terraform vars (explicit `--var-file`, sourced env file, or both) and implement one clear path.
- [ ] Add docs for secure local setup flow: create key files, run `safectl check local`, run `safectl terraform init/plan/apply`.
- [ ] Validate full DigitalOcean path end-to-end (provision droplet, run bootstrap command, confirm runner lifecycle commands work on remote host).
