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
- Docker runs a non-root coding container against a fork cloned under `/srv/workspaces/forks`
- Codex or Claude Code may run inside that container with bypassed internal permissions because the outer VM and host boundaries still exist
- app validation containers should be started from VM helper scripts, not from Docker-in-Docker inside the coding runner

## What Bootstrap Creates

After a successful bootstrap:

- Multipass instance `safevm` exists and is running
- the control-plane repo is available in the guest at `/opt/safe-control`
- Docker is installed in the guest
- helper commands exist in the guest:
  - `/usr/local/bin/safe-start-runner`
  - `/usr/local/bin/safe-enter-runner`
  - `/usr/local/bin/safe-enter-fork`
  - `/usr/local/bin/safe-clone-fork`
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

## Container Hardening

The coding runner is intended to:

- run as a non-root user
- drop Linux capabilities
- use `no-new-privileges`
- avoid access to the Docker socket
- mount only the fork workspace, not the whole VM filesystem
