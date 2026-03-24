# Objective

Ensure OpenCode guardrails run reliably in the full `safe` runtime stack:

- macOS host
- Multipass VM
- Docker container inside the VM

Specifically, the pre-compaction hook path must work end-to-end when OpenCode runs in-container:

1. A project-local Python environment is created with `uv` / `uv sync`.
2. OpenCode runs from that environment in the container.
3. OpenCode hooks can execute Python-based scripts (including `scripts/opencode/precompact-context.sh`, which depends on `python3`).
4. Hook execution is verifiable from logs (`Precompact complete`) during normal OpenCode runs.

## Acceptance Criteria

- Docker image/container includes `python3`, `uv`, and required runtime dependencies.
- `uv sync` succeeds in-container and creates a usable virtual environment.
- OpenCode session in-container successfully executes the precompact hook script.
- A documented smoke test command proves hook execution inside the Multipass -> Docker path.
