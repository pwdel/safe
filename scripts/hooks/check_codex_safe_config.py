#!/usr/bin/env python3
from __future__ import annotations

import pathlib
import re
import sys


REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
CONFIG_PATH = REPO_ROOT / ".codex" / "config.toml"
ENVRC_PATH = REPO_ROOT / ".envrc"

REQUIRED_PATTERNS = {
    'web_search = "disabled"': r'(?m)^\s*web_search\s*=\s*"disabled"\s*$',
    "tools.view_image = false": r"(?m)^\s*tools\.view_image\s*=\s*false\s*$",
    "shell_tool enabled": r"(?ms)^\s*\[features\]\s*.*?^\s*shell_tool\s*=\s*true\s*$",
    "multi_agent disabled": r"(?ms)^\s*\[features\]\s*.*?^\s*multi_agent\s*=\s*false\s*$",
    "apps disabled": r"(?ms)^\s*\[features\]\s*.*?^\s*apps\s*=\s*false\s*$",
    "image_generation disabled": r"(?ms)^\s*\[features\]\s*.*?^\s*image_generation\s*=\s*false\s*$",
}

FORBIDDEN_PATTERNS = {
    "machine-specific trusted project entries": r'(?m)^\s*\[projects\."[^"]+"\]\s*$',
    "global home references": r"(?m)^\s*codex_home\s*=",
}


def main() -> int:
    errors: list[str] = []

    if not CONFIG_PATH.exists():
        errors.append(f"Missing required config file: {CONFIG_PATH}")
    else:
        config_text = CONFIG_PATH.read_text(encoding="utf-8")

        for label, pattern in REQUIRED_PATTERNS.items():
            if not re.search(pattern, config_text):
                errors.append(f".codex/config.toml must include {label}.")

        for label, pattern in FORBIDDEN_PATTERNS.items():
            if re.search(pattern, config_text):
                errors.append(f".codex/config.toml must not contain {label}.")

    if not ENVRC_PATH.exists():
        errors.append(f"Missing required env file: {ENVRC_PATH}")
    else:
        envrc_text = ENVRC_PATH.read_text(encoding="utf-8")
        if "CODEX_HOME=~/Projects/safe/.codex" not in envrc_text:
            errors.append(".envrc must export CODEX_HOME=~/Projects/safe/.codex.")

    if errors:
        print("Codex safety policy check failed:", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
