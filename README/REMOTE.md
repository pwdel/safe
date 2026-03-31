# Remote VPS / DigitalOcean Flow

Use this path when the remote host is the outer boundary (no Multipass).

## 1) Install local control-plane prerequisites

```bash
bash LINUX/install.sh
./safe check remote
```

## 2) Provision target host

### Option A: Existing Ubuntu VPS

```bash
./safe --host <droplet-ip> remote bootstrap
```

### Option B: Create VPS with Terraform then deploy

```bash
./safe terraform init
./safe terraform plan
./safe terraform deploy
```

`terraform deploy` applies infra and executes the generated bootstrap command.

## 3) Verify and control remote runtime

```bash
./safe --host <droplet-ip> remote helper safe-runner-status
./safe --host <droplet-ip> remote helper safe-start-runner
./safe --host <droplet-ip> remote helper safe-enter-fork <repo>
```

## 4) Open remote shell

```bash
./safe --host <droplet-ip> remote shell
```

## 5) Open coding container shell remotely

```bash
./safe --host <droplet-ip> remote runner-shell
```

Run Codex device auth in the runner:

```bash
./safe --host <droplet-ip> remote codex-login
```

If you see:
`Enable device code authorization for Codex in ChatGPT Security Settings`
then enable device code authorization in your ChatGPT account security settings and run the command again.

For a specific fork workspace:

```bash
./safe --host <droplet-ip> remote fork-shell <fork-name>
```

## Access model applied by Ansible

- `operator` user receives SSH key access copied from bootstrap SSH user
- `operator` can run `/usr/local/bin/safe-*` helpers with passwordless sudo
