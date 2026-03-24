# Linux Host Setup

This path is for a remote Linux host such as a DigitalOcean droplet.

Use this when the remote host itself is the outer VM boundary. In that setup:

1. your macOS machine remains the control plane
2. the DigitalOcean droplet is the first containment boundary
3. Docker on the droplet runs the coding runner and app containers

Do not add Multipass on the remote Linux host unless you explicitly want nested virtualization.

## Baseline

- Host OS: Ubuntu 24.04
- Access: SSH as an admin user
- Projects root: `/srv/workspaces`

## Install

Run:

```bash
cd ~/Projects/safe
bash LINUX/install.sh
```

This installs local control-plane requirements for working against a remote Ubuntu host:

- `ansible`
- `jq`
- `openssh-client`
- `python3`
- `python3-pip`
- `ripgrep`

## Remote Bootstrap

Once a DigitalOcean droplet or other Ubuntu host exists, bootstrap it from the control-plane machine:

```bash
cd ~/Projects/safe
TARGET_HOST=<droplet-ip> \
TARGET_USER=root \
SSH_KEY=$HOME/.ssh/id_ed25519 \
bash LINUX/bootstrap_remote.sh
```

What this does:

- copies the checked-in `safe` control repo to `/opt/safe-control` on the remote host
- renders host-side runtime credentials from `~/.keys/safe` into `/srv/safe-secrets/agent.env`
- writes a local Ansible inventory for the remote host
- runs the same `safe` Ansible roles used for the local Multipass path

After that, the remote host should have the same guest-side helper model as `safevm`.

## Safe Model On A Remote Linux Host

- keep fork clones under `/srv/workspaces/forks`
- run the coding agent in the `coding` container, not directly on the host
- use host-side helper scripts to run app containers from fork checkouts
- push only to sandbox forks, then open PRs back to upstream

## Suggested Flow

```bash
sudo /usr/local/bin/safe-clone-fork <fork-url> socialpredict <upstream-url>
sudo /usr/local/bin/safe-start-runner
sudo /usr/local/bin/safe-init-runner-auth
sudo /usr/local/bin/safe-enter-fork socialpredict
```

To validate app containers from the fork on the host boundary:

```bash
sudo /usr/local/bin/safe-run-fork-compose socialpredict up -d --build
sudo /usr/local/bin/safe-run-fork-compose socialpredict ps
```
