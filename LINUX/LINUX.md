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

This installs:

- `git`
- `curl`
- `jq`
- `ripgrep`
- `python3`
- `python3-pip`
- `ansible`
- `docker.io`
- `docker-compose-v2`
- `golang-go`
- `nodejs`
- `npm`

## Safe Model On A Remote Linux Host

- keep fork clones under `/srv/workspaces/forks`
- run the coding agent in the `coding` container, not directly on the host
- use host-side helper scripts to run app containers from fork checkouts
- push only to sandbox forks, then open PRs back to upstream

## Suggested Flow

```bash
sudo /usr/local/bin/safe-clone-fork <fork-url> socialpredict
sudo /usr/local/bin/safe-start-runner
sudo /usr/local/bin/safe-enter-fork socialpredict
```

To validate app containers from the fork on the host boundary:

```bash
sudo /usr/local/bin/safe-run-fork-compose socialpredict up -d --build
sudo /usr/local/bin/safe-run-fork-compose socialpredict ps
```
