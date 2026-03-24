#!/usr/bin/env sh
set -eu

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required for precompact-context.sh" >&2
  exit 127
fi

tmp_input="$(mktemp)"
trap 'rm -f "$tmp_input"' EXIT INT TERM
cat > "$tmp_input"

python3 - "$tmp_input" <<'PY'
import json
import re
import sys

MAX_TEXT_CHARS = 6000
HEAD_CHARS = 2500
TAIL_CHARS = 1500


def normalize_text(value):
    return re.sub(r"\s+", " ", str(value or "")).strip()


def shorten_text(value):
    if len(value) <= MAX_TEXT_CHARS:
        return value
    return value[:HEAD_CHARS] + "\n...[trimmed]...\n" + value[-TAIL_CHARS:]


def role_of(message):
    role = message.get("info", {}).get("role", message.get("role", "unknown"))
    return role if isinstance(role, str) else "unknown"


def compact_messages(messages):
    seen_text = set()
    compacted = []
    stats = {"removedParts": 0, "shortenedParts": 0}

    latest_user_index = -1
    for idx in range(len(messages) - 1, -1, -1):
        if role_of(messages[idx]) == "user":
            latest_user_index = idx
            break

    for idx, message in enumerate(messages):
        role = role_of(message)
        protect_latest_user = role == "user" and idx == latest_user_index
        parts = message.get("parts") if isinstance(message, dict) else None
        if not isinstance(parts, list):
            parts = []
        next_parts = []

        for part in parts:
            if not isinstance(part, dict):
                next_parts.append(part)
                continue
            if part.get("type") != "text":
                next_parts.append(part)
                continue

            raw_text = part.get("text", "")
            normalized = normalize_text(raw_text)
            if not normalized:
                stats["removedParts"] += 1
                continue

            fingerprint = f"{role}:{normalized}"
            if not protect_latest_user and fingerprint in seen_text:
                stats["removedParts"] += 1
                continue
            seen_text.add(fingerprint)

            text = str(raw_text).strip()
            if not protect_latest_user:
                shortened = shorten_text(text)
                if shortened != text:
                    text = shortened
                    stats["shortenedParts"] += 1

            new_part = dict(part)
            new_part["text"] = text
            next_parts.append(new_part)

        if next_parts:
            new_message = dict(message) if isinstance(message, dict) else message
            if isinstance(new_message, dict):
                new_message["parts"] = next_parts
            compacted.append(new_message)
            continue

        if not parts or protect_latest_user:
            compacted.append(message)
            continue

        stats["removedParts"] += 1

    return {"messages": compacted, "stats": stats}


def main():
    payload_path = sys.argv[1]
    with open(payload_path, "r", encoding="utf-8") as handle:
        payload = json.load(handle)
    messages = payload.get("messages")
    if not isinstance(messages, list):
        messages = []
    result = compact_messages(messages)
    json.dump(result, sys.stdout, separators=(",", ":"))


if __name__ == "__main__":
    main()
PY
