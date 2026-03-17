#!/usr/bin/env python3
from __future__ import annotations

import json
import pathlib
import sys


APPROVED_ROOTS = (
    pathlib.Path("/Users/patrick/Projects/safe"),
)

EXPECTED_PERMISSION_MODES = {
    "default",
    "acceptEdits",
    "plan",
}


def main() -> int:
    payload = json.load(sys.stdin)

    cwd = pathlib.Path(payload["cwd"]).resolve()
    permission_mode = payload["permission_mode"]

    allowed = any(cwd == root or root in cwd.parents for root in APPROVED_ROOTS)
    if not allowed:
        json.dump(
            {
                "continue": False,
                "stopReason": f"Refusing to start outside approved workspace: {cwd}",
                "suppressOutput": False,
            },
            sys.stdout,
        )
        sys.stdout.write("\n")
        return 0

    if permission_mode not in EXPECTED_PERMISSION_MODES:
        json.dump(
            {
                "continue": False,
                "stopReason": f"Refusing to start with permission_mode={permission_mode}",
                "suppressOutput": False,
            },
            sys.stdout,
        )
        sys.stdout.write("\n")
        return 0

    json.dump(
        {
            "continue": True,
            "hookSpecificOutput": {
                "hookEventName": "SessionStart",
                "additionalContext": (
                    "Repository policy: stay inside /Users/patrick/Projects/safe, "
                    "prefer workspace-write sandboxing, never recommend bypass flags, "
                    "and treat extra state under .codex/ and .claude/ as private unless "
                    "explicitly tracked."
                ),
            },
            "systemMessage": (
                "Guardrail reminder: do not propose or rely on "
                "--dangerously-bypass-approvals-and-sandbox. "
                "Prefer apply_patch for edits and require explicit user approval for "
                "destructive actions."
            ),
            "suppressOutput": False,
        },
        sys.stdout,
    )
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
