# Help

Primary entrypoint:

```bash
./safe --help
```

Topic help:

```bash
./safe help local
./safe help remote
./safe help terraform
./safe help access
./safe help check
```

## Common Commands

```bash
# Local VM
./safe check host
./safe local bootstrap
./safe local status
./safe local test
./safe local shell
./safe local operator-shell
./safe local runner-shell
./safe local codex-login
./safe local fork-shell socialpredict

# Terraform
./safe terraform init
./safe terraform plan
./safe terraform apply
./safe terraform output-bootstrap
./safe terraform deploy

# Remote host
./safe --host <droplet-ip> remote bootstrap
./safe --host <droplet-ip> remote shell
./safe --host <droplet-ip> remote operator-shell
./safe --host <droplet-ip> remote runner-shell
./safe --host <droplet-ip> remote codex-login
./safe --host <droplet-ip> remote fork-shell socialpredict
./safe --host <droplet-ip> remote helper safe-runner-status
./safe --host <droplet-ip> remote helper safe-enter-fork <repo>
./safe --host <droplet-ip> remote exec -- whoami
```

## Layer Access

- Control plane layer:
  - run `./safe` commands from your local machine
- Outer VM/VPS layer:
  - `./safe local shell`
  - `./safe --host <ip> remote shell`
- Runner container layer:
  - `./safe --host <ip> remote helper safe-enter-fork <repo>`
  - from VM shell: `sudo /usr/local/bin/safe-enter-fork <repo>`
- App validation layer:
  - from VM/VPS shell: `sudo /usr/local/bin/safe-run-fork-compose <repo> up -d --build`

## Troubleshooting

- `fatal: detected dubious ownership` inside runner:
  - rebuild/start the runner so the updated image config is used:
    - `./safe local test`
  - this image now preconfigures git safe directories for `/workspace` and `/workspace/*`
- `go test` fails with `toolchain not available`:
  - the old runner image had Ubuntu `golang-go` (too old for newer toolchain directives)
  - rebuild the runner image to pick up bundled Go from the Dockerfile:
    - `./safe local test`
