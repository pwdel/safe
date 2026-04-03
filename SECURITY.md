# Security Model

This project uses layered controls so no single misconfiguration gives full access.

## Layered Boundaries

1. Host control plane (macOS/admin machine)
- Holds primary credentials under `~/.keys/safe`.
- Runs orchestration commands (`./safe ...`) and keeps final operator control.

2. VM boundary (Multipass or DigitalOcean droplet)
- First containment layer for automation workloads.
- Runs Docker and helper scripts; can be rebuilt or destroyed as a disposable layer.
- Should enforce inbound restrictions (SSH only) and optional outbound policy at cloud firewall level.

3. Runner container boundary
- Non-root `agent` user.
- No Docker socket mount (`/var/run/docker.sock` is not exposed to the agent).
- Runs coding tasks only in mounted workspace paths.
- Uses command guardrails for high-risk commands; bypass is explicit via `SAFE_ALLOW_RISKY=1`.

4. Git boundary
- Global hooks are enforced via `core.hooksPath=/home/agent/.git-hooks`.
- `pre-push` allows pushes only to `origin` from inside the runner.
- If `upstream` exists, push is blocked when `origin` and `upstream` resolve to the same URL.

## Runner Home Lockdown

The runner keeps `/home/agent` root-owned and read-only by default.

- Read-only home and managed shell/git config reduce prompt-driven tampering.
- Writable paths are intentionally scoped (`/workspace`, `/home/agent/.tmp`, `/home/agent/.codex`).
- Managed hooks and guardrail shell config are root-owned.

This supports day-to-day coding while reducing the chance that an agent session can rewrite its own guardrails.

## TruffleHog Secret Scanning

Secret scanning is enforced at commit/push in runner hooks:

- `pre-commit`: scans staged files with TruffleHog.
- `pre-push`: scans commits being pushed.
- Both fail closed if TruffleHog is unavailable.

To avoid updater failures in a locked-down home:

- Immutable fallback binary: `/usr/local/bin/trufflehog` (root-managed).
- Writable updater binary path: `SAFE_TRUFFLEHOG_BIN=/home/agent/.tmp/trufflehog/bin/trufflehog`.
- Hooks resolve TruffleHog from `SAFE_TRUFFLEHOG_BIN` first, then fall back to `command -v trufflehog`.

This keeps hooks functional in a locked environment while allowing TruffleHog self-updates in a dedicated writable path.

## Credential Handling

- Store secrets in `~/.keys/safe/*.env` on the host.
- Render only required env into VM/container runtime.
- Avoid committing secrets; hook scanning is a backstop, not the primary secret-management mechanism.

## Network and Egress Notes

- Default runner networking allows normal dependency/API workflows.
- For stricter environments, enforce egress controls at VM/cloud firewall or proxy layer.
- Domain-only allowlisting is not natively reliable at basic firewall/IP layers without proxy or DNS-aware controls.

## Operational Guidance

- Treat VM and runner containers as disposable.
- Keep automation on fork remotes; merge via PR into upstream.
- Reserve manual operator steps for high-privilege actions (bootstrap, credential rotation, final merge decisions).
