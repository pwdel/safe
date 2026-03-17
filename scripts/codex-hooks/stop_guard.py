#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import subprocess
import sys


FORBIDDEN_ASSISTANT_PATTERNS = (
    r"--dangerously-bypass-approvals-and-sandbox",
    r"\bskipped tests\b",
    r"\bTODO\b",
)

FORBIDDEN_GIT_PATH_PREFIXES = (
    ".codex/",
    ".claude/",
)

ALLOWED_GIT_PATHS = {
    ".codex/config.toml",
    ".claude/README.md",
}


def staged_or_modified_paths() -> list[str]:
    result = subprocess.run(
        ["git", "status", "--short"],
        check=False,
        capture_output=True,
        text=True,
    )
    paths: list[str] = []
    for line in result.stdout.splitlines():
        if len(line) < 4:
            continue
        paths.append(line[3:])
    return paths


def main() -> int:
    payload = json.load(sys.stdin)
    last_message = payload.get("last_assistant_message") or ""

    for pattern in FORBIDDEN_ASSISTANT_PATTERNS:
        if re.search(pattern, last_message, flags=re.IGNORECASE):
            json.dump(
                {
                    "continue": False,
                    "decision": "block",
                    "reason": f"Assistant message matched forbidden pattern: {pattern}",
                    "suppressOutput": False,
                },
                sys.stdout,
            )
            sys.stdout.write("\n")
            return 0

    for path in staged_or_modified_paths():
        if path in ALLOWED_GIT_PATHS:
            continue
        if path.startswith(FORBIDDEN_GIT_PATH_PREFIXES):
            json.dump(
                {
                    "continue": False,
                    "decision": "block",
                    "reason": f"Forbidden tracked local-state path detected: {path}",
                    "suppressOutput": False,
                },
                sys.stdout,
            )
            sys.stdout.write("\n")
            return 0

    json.dump({"continue": True, "suppressOutput": False}, sys.stdout)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
