# Help

Primary entrypoint:

```bash
bash infra/scripts/safectl.sh --help
```

Topic help:

```bash
bash infra/scripts/safectl.sh help local
bash infra/scripts/safectl.sh help remote
bash infra/scripts/safectl.sh help terraform
bash infra/scripts/safectl.sh help access
bash infra/scripts/safectl.sh help check
```

## Common Commands

```bash
# Local VM
bash infra/scripts/safectl.sh check host
bash infra/scripts/safectl.sh local bootstrap
bash infra/scripts/safectl.sh local status
bash infra/scripts/safectl.sh local test
bash infra/scripts/safectl.sh local shell
bash infra/scripts/safectl.sh local operator-shell
bash infra/scripts/safectl.sh local runner-shell
bash infra/scripts/safectl.sh local codex-login
bash infra/scripts/safectl.sh local fork-shell socialpredict

# Terraform
bash infra/scripts/safectl.sh terraform init
bash infra/scripts/safectl.sh terraform plan
bash infra/scripts/safectl.sh terraform apply
bash infra/scripts/safectl.sh terraform output-bootstrap
bash infra/scripts/safectl.sh terraform deploy

# Remote host
bash infra/scripts/safectl.sh --host <droplet-ip> remote bootstrap
bash infra/scripts/safectl.sh --host <droplet-ip> remote shell
bash infra/scripts/safectl.sh --host <droplet-ip> remote operator-shell
bash infra/scripts/safectl.sh --host <droplet-ip> remote runner-shell
bash infra/scripts/safectl.sh --host <droplet-ip> remote codex-login
bash infra/scripts/safectl.sh --host <droplet-ip> remote fork-shell socialpredict
bash infra/scripts/safectl.sh --host <droplet-ip> remote helper safe-runner-status
bash infra/scripts/safectl.sh --host <droplet-ip> remote helper safe-enter-fork <repo>
bash infra/scripts/safectl.sh --host <droplet-ip> remote exec -- whoami
```

## Layer Access

- Control plane layer:
  - run `safectl.sh` commands from your local machine
- Outer VM/VPS layer:
  - `safectl.sh local shell`
  - `safectl.sh --host <ip> remote shell`
- Runner container layer:
  - `safectl.sh --host <ip> remote helper safe-enter-fork <repo>`
  - from VM shell: `sudo /usr/local/bin/safe-enter-fork <repo>`
- App validation layer:
  - from VM/VPS shell: `sudo /usr/local/bin/safe-run-fork-compose <repo> up -d --build`

## Troubleshooting

- `fatal: detected dubious ownership` inside runner:
  - rebuild/start the runner so the updated image config is used:
    - `bash infra/scripts/safectl.sh local test`
  - this image now preconfigures git safe directories for `/workspace` and `/workspace/*`
- `go test` fails with `toolchain not available`:
  - the old runner image had Ubuntu `golang-go` (too old for newer toolchain directives)
  - rebuild the runner image to pick up bundled Go from the Dockerfile:
    - `bash infra/scripts/safectl.sh local test`
