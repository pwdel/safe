# Multipass Defaults

This repo uses Multipass as the recommended VM layer for macOS Apple silicon.

Default instance settings:

- name: `safevm`
- image: `24.04`
- cpus: `2`
- memory: `4G`
- disk: `30G`

Guest paths:

- control repo copy: `/opt/safe-control`
- writable forks: `/srv/workspaces/forks`
