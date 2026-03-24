# `.opencode`

This directory is tracked to prototype a user-scoped OpenCode setup inside this repo.

The intended long-term shape is user-scoped:

- `~/.config/opencode/opencode.json`
- `~/.config/opencode/plugins/`

For now, the repo-local version exists so the guardrails can be reviewed and iterated in git before promotion to a real machine-level setup.

Current repo-local wiring:

- [`opencode.json`](/Users/patrick/conductor/workspaces/safe/abuja/opencode.json) enables auto compaction with `reserved: 20000`.
- [`opencode.json`](/Users/patrick/conductor/workspaces/safe/abuja/opencode.json) also loads `opencode-openai-codex-auth` for ChatGPT Plus/Pro Codex auth.
- [`guardrails.js`](/Users/patrick/conductor/workspaces/safe/abuja/.opencode/plugins/guardrails.js) is auto-loaded from `.opencode/plugins/` and runs `experimental.chat.messages.transform` on every model call.
- [`precompact-context.sh`](/Users/patrick/conductor/workspaces/safe/abuja/scripts/opencode/precompact-context.sh) removes duplicate text parts and shortens oversized text parts before send.
