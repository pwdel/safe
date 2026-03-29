# Local macOS Flow

Use this path to test the full isolation stack locally:

- macOS host
- Multipass VM
- Docker runner in VM

## 1) Install host prerequisites

```bash
bash MACOS/install.sh
bash infra/scripts/safectl.sh check local
```

## 2) Bootstrap VM + provision runtime

```bash
bash infra/scripts/safectl.sh local bootstrap
```

This runs the same provisioning as `infra/scripts/bootstrap_mac.sh`.

## 3) Verify local runtime

```bash
bash infra/scripts/safectl.sh local status
bash infra/scripts/safectl.sh local test
```

`local test` verifies:

- `operator` SSH access into VM
- runner start via safe helper
- runner status check

## 4) Enter VM when needed

```bash
bash infra/scripts/safectl.sh local shell
```

## 5) Enter VM as operator (docker-aware)

```bash
bash infra/scripts/safectl.sh local operator-shell
docker ps -a
```

## 6) Enter coding container shell directly

```bash
bash infra/scripts/safectl.sh local runner-shell
```

Run Codex device auth in the runner:

```bash
bash infra/scripts/safectl.sh local codex-login
```

If you see:
`Enable device code authorization for Codex in ChatGPT Security Settings`
then enable device code authorization in your ChatGPT account security settings and run the command again.

Or for a specific fork workspace:

```bash
bash infra/scripts/safectl.sh local fork-shell <fork-name>
```

## 7) Optional manual fallback commands in VM

```bash
sudo /usr/local/bin/safe-build-runner-image
sudo /usr/local/bin/safe-start-runner
sudo /usr/local/bin/safe-runner-status
```
