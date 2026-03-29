# Safe Infra

This directory scaffolds the layered automation environment for `safe`.

Target model:

1. macOS host
2. Multipass VM
3. Docker inside the VM
4. automated coding inside containers against writable fork clones

## Isolation Layers

```text
+---------------------------+
| host control plane        |
| macOS laptop or admin box |
| - credentials             |
| - safe repo               |
| - bootstrap commands      |
+-------------+-------------+
              |
              v
+---------------------------+
| outer compute boundary    |
| Multipass VM or droplet   |
| - Ansible target          |
| - Docker host             |
| - fork storage            |
+-------------+-------------+
              |
              v
+---------------------------+
| coding runner container   |
| - non-root agent user     |
| - no Docker socket        |
| - fork workspace only     |
+-------------+-------------+
              |
              +----------------------+
              |                      |
              v                      v
+---------------------------+  +---------------------------+
| fork-only git workflow    |  | app/test containers       |
| - sandbox remotes         |  | - launched from VM        |
| - PR back to upstream     |  | - not from the agent      |
+---------------------------+  +---------------------------+
```

## Why The Layers Exist

- The host keeps primary credentials and interactive control out of the agent's direct write path.
- The VM or remote Linux host is the first real containment boundary if the agent or container misbehaves.
- The coding runner container reduces the blast radius inside that VM by keeping the agent non-root and away from the Docker socket.
- The fork-only workflow prevents the agent from writing directly to your primary checkout or primary GitHub account path.
- App validation runs from VM-controlled helper scripts so the agent does not need Docker-in-Docker or direct control of the Docker daemon.

## Safety Practices

- Run the coding agent as a non-root user in the container.
- Reserve `sudo` on the VM for explicit helper scripts you control.
- Keep fork work under `/srv/workspaces/forks`.
- Push only to sandbox or fork remotes.
- Open PRs from forks back to upstream.
- Do not mount the host checkout directly into the coding container.
- Do not mount `/var/run/docker.sock` into the coding container.
- Keep long-lived secrets out of shell history, dotfiles, and the guest filesystem where possible.
- Treat the VM and coding container as disposable runtime layers.

## Design goals

- keep the macOS host out of the direct write path for automated coding
- keep the checked-in `safe/` repo as a control plane and template source
- do actual code-writing inside Docker on the guest
- prefer writing to isolated fork clones under the guest's local disk
- create PRs from those forks back into the main upstream repos

## Current scaffold

- `infra/multipass/`
- `infra/ansible/`
- `infra/docker/compose.yml`
- `infra/docker/coding-runner/Dockerfile`
- `infra/terraform/`
- `infra/scripts/`

Important defaults:

- the checked-in `safe/` repo is copied into the guest at `/opt/safe-control`
- writable coding work is expected under `/srv/workspaces/forks`
- the macOS host remains the control plane rather than the direct automation runtime
- local inventory is generated at `infra/ansible/inventory/hosts.yml` and should not be committed

## Current workflow intent

- `bash infra/scripts/bootstrap_mac.sh` launches Ubuntu in Multipass and applies Ansible
- the bootstrap script seeds `~/.ssh/id_ed25519.pub` into the guest's `ubuntu` account so Ansible can connect
- Ansible installs Docker and creates users and workspace directories
- Ansible can build and start the coding runner automatically during provisioning
- Docker runs a non-root coding container against a fork cloned under `/srv/workspaces/forks`
- Codex or Claude Code may run inside that container with bypassed internal permissions because the outer VM and host boundaries still exist
- app validation containers should be started from VM helper scripts, not from Docker-in-Docker inside the coding runner

## VM Lifecycle

Host-side helpers exist for the outer VM boundary:

- `bash infra/scripts/vm-status.sh`
- `bash infra/scripts/vm-stop.sh`
- `bash infra/scripts/vm-delete.sh`
- `bash infra/scripts/vm-rebuild.sh`

These are intended to make the VM itself disposable in the same way the runner container is disposable.

A unified wrapper is also available:

- `bash infra/scripts/safectl.sh --help`
- `bash infra/scripts/safectl.sh local bootstrap`
- `bash infra/scripts/safectl.sh local test`
- `bash infra/scripts/safectl.sh --host <droplet-ip> remote bootstrap`
- `bash infra/scripts/safectl.sh --host <droplet-ip> remote helper safe-runner-status`
- `bash infra/scripts/safectl.sh terraform deploy`

## What Bootstrap Creates

After a successful bootstrap:

- Multipass instance `safevm` exists and is running
- the control-plane repo is available in the guest at `/opt/safe-control`
- Docker is installed in the guest
- coding runner image is built and the `coding` container is started by default during provisioning
- helper commands exist in the guest:
  - `/usr/local/bin/safe-prepare-runner-image`
  - `/usr/local/bin/safe-pull-runner-image`
  - `/usr/local/bin/safe-build-runner-image`
  - `/usr/local/bin/safe-start-runner`
  - `/usr/local/bin/safe-start-runner-offline`
  - `/usr/local/bin/safe-stop-runner`
  - `/usr/local/bin/safe-remove-runner`
  - `/usr/local/bin/safe-rebuild-runner`
  - `/usr/local/bin/safe-runner-status`
  - `/usr/local/bin/safe-init-runner-auth`
  - `/usr/local/bin/safe-enter-runner`
  - `/usr/local/bin/safe-enter-fork`
  - `/usr/local/bin/safe-clone-fork`
  - `/usr/local/bin/safe-guard-fork`
  - `/usr/local/bin/safe-run-fork-compose`
- writable fork workspaces exist at `/srv/workspaces/forks`

## Why Multipass here

This repo uses Multipass as the first working macOS Apple silicon path because:

- it maps better to the existing `sales-assist` provisioning pattern
- it avoids the current VirtualBox friction on Apple silicon hosts
- it still preserves the same layered security model: host -> VM -> Docker -> coding runtime

## Fork workflow

The intended git model is:

- create or clone a fork inside the guest at `/srv/workspaces/forks/<repo>`
- run automated coding only against that fork
- push changes to the fork
- open a PR from fork -> upstream

This keeps the primary account and primary checkout out of the direct automation write path.

The helper scripts enforce the intended structure:

- `safe-clone-fork <fork-url> <target-name> [upstream-url]` clones the fork as `origin`
- if an `upstream-url` is supplied, it is added as `upstream` with pushing disabled
- a `pre-push` hook is installed in the checkout to block pushes to any remote except `origin`

## App Validation Workflow

App containers should run from the VM boundary (not inside the coding runner).

Typical flow:

```bash
# inside the VM
sudo /usr/local/bin/safe-clone-fork <fork-url> socialpredict <upstream-url>
sudo /usr/local/bin/safe-start-runner
sudo /usr/local/bin/safe-enter-fork socialpredict
```

Run coding tasks in the runner shell, then exit back to the VM shell and validate:

```bash
# back on the VM host shell
sudo /usr/local/bin/safe-run-fork-compose socialpredict up -d --build
sudo /usr/local/bin/safe-run-fork-compose socialpredict ps
sudo /usr/local/bin/safe-run-fork-compose socialpredict logs --tail=200
```

When finished:

```bash
sudo /usr/local/bin/safe-run-fork-compose socialpredict down --remove-orphans
```

This separation keeps Docker control for app/test containers on the VM layer while the agent remains constrained to the non-root runner container.

## DigitalOcean Terraform Scaffold

`infra/terraform/` provides a baseline scaffold for DigitalOcean:

- VPC
- SSH-restricted firewall
- Ubuntu 24.04 droplet for the outer runtime boundary

See `infra/terraform/README.md` for usage, variables, and how to hand off to `LINUX/bootstrap_remote.sh`.

## Container Hardening

The coding runner is intended to:

- run as a non-root user
- drop Linux capabilities
- use `no-new-privileges`
- avoid access to the Docker socket
- mount only the fork workspace, not the whole VM filesystem

Runtime shell guardrails are also enabled in the runner:

- wrapped commands block a small set of high-risk operations by default
- current wrapped commands: `rm`, `chmod`, `chown`, `dd`, `mkfs`, `fdisk`, `sfdisk`, `parted`, `mount`, `umount`
- intentional bypass requires `SAFE_ALLOW_RISKY=1`

## Network Policy

The current network policy is:

- VM firewall: deny incoming, allow outgoing, allow SSH
- coding runner default: outbound network available on standard Docker bridge networking
- coding runner optional offline mode: `safe-start-runner-offline`
- no published ports from the coding runner

This keeps the default workflow usable for:

- cloning sandbox forks
- installing dependencies
- calling OpenAI or GitHub APIs

For tasks that do not need internet access, start the runner with:

```bash
sudo /usr/local/bin/safe-start-runner-offline
```

The runner lifecycle is intentionally disposable:

- `safe-prepare-runner-image` waits for Docker and runs retry-backed pull/build steps
- `safe-pull-runner-image` pulls a registry-backed `SAFE_RUNNER_IMAGE` without rebuilding
- `safe-build-runner-image` rebuilds the runner image from local Docker context
- `safe-stop-runner` stops the coding container
- `safe-remove-runner` removes the coding container without deleting fork data
- `safe-rebuild-runner` recreates the container from the current image definition
- `safe-runner-status` shows current runner status

Runner image defaults:

- `SAFE_RUNNER_IMAGE` defaults to `safe-coding-runner:local`
- pull behavior defaults to `SAFE_RUNNER_PULL=auto`:
  - skip pull for the default local tag
  - pull when `SAFE_RUNNER_IMAGE` is set to a non-local tag
- Ansible auto-run defaults are defined in `infra/ansible/group_vars/all.yml`:
  - `auto_build_runner_image: true`
  - `auto_start_runner: true`
  - `auto_show_runner_status: true`
  - `copy_bootstrap_authorized_keys_to_admin_user: true`
  - `admin_user_passwordless_safe_helpers: true`

Smoke test for pull/build/start reliability from inside the VM:

```bash
sudo /usr/local/bin/safe-build-runner-image
sudo /usr/local/bin/safe-start-runner
sudo /usr/local/bin/safe-runner-status
```

Optional pull smoke test when you have a published runner image:

```bash
sudo env SAFE_RUNNER_IMAGE=<registry>/<repo>:<tag> /usr/local/bin/safe-pull-runner-image
```

## Runtime Credentials

Host-side runtime credentials are expected under `~/.keys/safe` and are copied into the guest during bootstrap.

Supported host files:

- `~/.keys/safe/github.env`
- `~/.keys/safe/codex.env`
- `~/.keys/safe/claude.env`
- `~/.keys/safe/openai.env`
- or a combined `~/.keys/safe/agent.env`

Those files are rendered into:

- guest path: `/srv/safe-secrets/agent.env`
- guest mirror path: `/home/operator/.keys/safe/agent.env`
- container path: environment variables loaded through Docker Compose `env_file`
- container file mount: `/home/agent/.keys/safe/agent.env` (read-only)
- persistent Codex auth path: `/home/agent/.codex` backed by `/srv/safe-state/codex`

The intended values are:

- `GITHUB_TOKEN` or `GH_TOKEN` for sandbox GitHub access
- `OPENAI_API_KEY` for Codex / OpenAI runtime access
- `ANTHROPIC_API_KEY` for Claude runtime access

The helper `safe-init-runner-auth` initializes GitHub CLI auth inside the coding runner from those injected environment variables.
For Codex device auth, run `safe-codex-login` (or `safectl ... codex-login`).

Run host preflight checks before bootstrap:

```bash
bash infra/scripts/safectl.sh check host
```
