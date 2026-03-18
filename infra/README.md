# Safe Infra

This directory scaffolds the layered automation environment for `safe`.

Target model:

1. macOS host
2. Vagrant VM
3. Docker inside the VM
4. automated coding inside containers against writable fork clones

## Design goals

- keep the macOS host out of the direct write path for automated coding
- keep the checked-in `safe/` repo as a control plane and template source
- do actual code-writing inside Docker on the guest
- prefer writing to isolated fork clones under the guest's local disk
- create PRs from those forks back into the main upstream repos

## Current scaffold

- `infra/vagrant/Vagrantfile`
- `infra/ansible/`
- `infra/docker/compose.yml`
- `infra/docker/coding-runner/Dockerfile`
- `infra/scripts/`

Important defaults:

- the usual Vagrant `/vagrant` sync is disabled
- the checked-in `safe/` repo is mounted read-only at `/opt/safe-control`
- writable coding work is expected under `/srv/workspaces/forks`

## Current workflow intent

- `SAFE_VAGRANT_BOX=<provider-compatible-arm-box> vagrant up` boots Ubuntu
- Ansible installs Docker and creates users and workspace directories
- Docker runs a coding container against a fork cloned under `/srv/workspaces/forks`
- Codex or Claude Code may run inside that container with bypassed internal permissions because the outer VM and host boundaries still exist

## Box selection

The Vagrantfile intentionally requires `SAFE_VAGRANT_BOX` instead of hard-coding a legacy default.

Reason:

- macOS Apple silicon support changed recently
- provider support and available ARM boxes are still uneven
- older Ubuntu Vagrant box names are not a reliable universal default anymore

## Fork workflow

The intended git model is:

- create or clone a fork inside the guest at `/srv/workspaces/forks/<repo>`
- run automated coding only against that fork
- push changes to the fork
- open a PR from fork -> upstream

This keeps the primary account and primary checkout out of the direct automation write path.
