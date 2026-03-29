# Isolation Model

`safe` is designed as layered containment:

1. Control plane machine (macOS/Linux host)
2. Outer runtime boundary (Multipass VM or Ubuntu VPS)
3. Non-root coding runner container
4. Fork-only git workflow for writable code

## Boundary Intent

- Host control plane:
  - holds bootstrap tooling and primary operator workflow
- VM/VPS boundary:
  - runs Docker daemon and stores fork workspaces
- Runner boundary:
  - runs coding tools as non-root user
  - no Docker socket mounted into runner
- Git boundary:
  - pushes intended for fork remotes, not primary upstream

## Runtime Paths

- local: macOS -> Multipass -> Docker runner
- remote: control plane -> Ubuntu VPS -> Docker runner

## Operational Model

- run coding tasks in runner container
- run app/test containers from VM/VPS helper scripts
- keep control plane and primary checkouts out of direct automated write path

For deeper implementation details, see:

- `infra/README.md`
