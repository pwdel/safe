#!/usr/bin/env bash
set -euo pipefail

VM_NAME="${VM_NAME:-safevm}"

exec multipass shell "$VM_NAME"
