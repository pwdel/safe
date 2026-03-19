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

- Define safe runtime injection for GitHub and OpenAI credentials
- Add stronger runtime guardrails around shell behavior
- Decide how much outbound network access to allow
- Finish the Linux / DigitalOcean provisioning path
- Fully document the final operating procedure in the main README

## Checklist

- [x] Bootstrap a working macOS -> Multipass -> Docker flow for `safe`
- [x] Get Ansible provisioning working reliably against `safevm`
- [x] Make the coding runner non-root
- [x] Add baseline container hardening
- [x] Keep generated inventory and local Ansible state out of git
- [x] Document the current isolation model and threat rationale
- [x] Enforce fork-only git remotes and sandbox-only push targets
- [x] Define how sandbox GitHub credentials are injected into the runtime
- [x] Define how Codex / OpenAI auth is injected into the runtime without leaving broad secrets behind
- [x] Add disposable runner reset / teardown scripts
- [x] Add VM reset / rebuild scripts
- [x] Add stronger runtime guardrails around risky shell behavior
- [ ] Decide and implement the outbound network policy for the VM and coding runner
- [ ] Build the Linux host bootstrap path for remote targets such as DigitalOcean
- [ ] Wire a real `socialpredict` fork workflow through the hardened runner
- [ ] Add a documented workflow for app validation containers launched from the VM layer
- [ ] Review whether any additional artifacts should be gitignored
- [ ] Document the final end-to-end operating procedure in `README.md`
