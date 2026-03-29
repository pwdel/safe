# Access Levels

Use these as explicit "layers" when operating `safe`.

## Level 1: VM Host (default user)

- command: `bash infra/scripts/safectl.sh local shell`
- lands in: Multipass VM shell as default VM user (`ubuntu`)
- use for: basic VM checks
- note: this user may not have direct docker socket access

## Level 2: Host Operator (docker-aware)

- local command: `bash infra/scripts/safectl.sh local operator-shell`
- remote command: `bash infra/scripts/safectl.sh --host <ip> remote operator-shell`
- lands in: host shell as `operator`
- use for: docker-aware host administration and `safe-*` helper execution

## Level 3: Coding Runner Container Shell

- local command: `bash infra/scripts/safectl.sh local runner-shell`
- remote command: `bash infra/scripts/safectl.sh --host <ip> remote runner-shell`
- login command: `bash infra/scripts/safectl.sh local codex-login` (or `remote codex-login`)
- lands in: coding container shell (`safe-enter-runner`)
- use for: coding runtime commands inside container

## Level 4: Fork-Scoped Container Shell

- local command: `bash infra/scripts/safectl.sh local fork-shell <fork-name>`
- remote command: `bash infra/scripts/safectl.sh --host <ip> remote fork-shell <fork-name>`
- lands in: `/workspace/<fork-name>` inside coding container
- use for: focused edits against a specific fork checkout
