# Codex Hooks Guardrails

This repo is pinned to the locally installed `codex-cli 0.114.0` as inspected on 2026-03-17.

## Confirmed hook surface in this build

- `SessionStart`
- `Stop`
- `after_tool_use`
- `after_agent`

## Important limitation

There is no confirmed pre-tool hook in this build. That means hooks alone cannot stop a dangerous shell command before it runs. Hard prevention still needs to come from:

- sandbox mode
- approval policy
- disabled tools
- writable root restrictions
- network restrictions

## Current strategy

- `SessionStart` for pre-session checks and extra system context
- `after_tool_use` for audit and failure escalation after risky tool calls
- `after_agent` for final message inspection before turn completion
- `Stop` for end-of-turn or end-of-task blocking when the session should not conclude yet

## Confirmed input and output contracts

The local binary embeds JSON schemas for `SessionStart` and `Stop`.

### `SessionStart` input

Fields observed in the shipped schema:

- `cwd`
- `hook_event_name`
- `model`
- `permission_mode`
- `session_id`
- `source`
- `transcript_path`

### `SessionStart` output

Fields observed in the shipped schema:

- `continue`
- `hookSpecificOutput.additionalContext`
- `hookSpecificOutput.hookEventName`
- `stopReason`
- `suppressOutput`
- `systemMessage`

### `Stop` input

Fields observed in the shipped schema:

- `cwd`
- `hook_event_name`
- `last_assistant_message`
- `model`
- `permission_mode`
- `session_id`
- `stop_hook_active`
- `transcript_path`

### `Stop` output

Fields observed in the shipped schema:

- `continue`
- `decision`
- `reason`
- `stopReason`
- `suppressOutput`
- `systemMessage`

## Suggested guardrails by stage

### Pre-session: `SessionStart`

- Fail closed if the cwd is not inside an approved workspace root
- Fail closed if sandbox or approval mode is looser than expected
- Inject a system reminder that destructive operations require explicit approval
- Inject repo policy reminders about `.codex/config.toml`, `.envrc`, and tracked state

### During execution: `after_tool_use`

- Watch for tool names like shell execution and patch application
- Escalate if output suggests permission bypass attempts, secret access, or writes outside the workspace
- Emit concise status messages for auditability

This is post-tool only, so use it for detection and interruption of follow-up work, not prevention of the first action.

### Post-turn: `after_agent`

- Reject turns that recommend bypass flags like `--dangerously-bypass-approvals-and-sandbox`
- Reject turns that expose likely secrets or tokens
- Reject turns that claim completion without required verification markers

### Stop gate: `Stop`

- Block final completion if the git worktree contains forbidden paths
- Block final completion if verification has not been run for code changes
- Block final completion if the assistant message contains unresolved TODO markers

## Scaffolded scripts

- `scripts/codex-hooks/session_start_guard.py`
- `scripts/codex-hooks/stop_guard.py`

These are intentionally limited to the parts of the hook contract confirmed from the local binary.

## Next implementation step

To wire `after_tool_use` and `after_agent` confidently, inspect the upstream hook registry format or validate it against a throwaway config with the exact parser used by this Codex build.

## Example config

See [docs/codex.toml.example](/Users/patrick/Projects/safe/docs/codex.toml.example) for a deliberately fake but structured example that shows how these guardrails fit together.

The example is intended for design discussion only:

- the feature flags and top-level safety settings match confirmed local behavior
- the hook command scripts are real files in this repo
- the hook registration block is illustrative until the exact Codex hook config schema is verified

## OpenCode alternative

If the goal is Claude Code style hooks today, OpenCode is the stronger match than Codex hooks right now.

As checked on 2026-03-17:

- OpenCode’s site advertises ChatGPT Plus/Pro login with OpenAI
- OpenCode documents a plugin system with event hooks
- OpenCode’s ecosystem lists `opencode-openai-codex-auth` for using ChatGPT Plus/Pro instead of API credits

That means the realistic split is:

- use Codex when you want the official OpenAI CLI and tighter built-in sandbox/approval semantics
- use OpenCode when you want a richer, more Claude Code like hook/plugin surface

If you want, the next step after this can be scaffolding a project-local `.opencode/` config and a minimal plugin that mirrors the same guardrails.

See:

- [docs/opencode.json.example](/Users/patrick/Projects/safe/docs/opencode.json.example)
- [docs/opencode-guardrails-plugin.example.ts](/Users/patrick/Projects/safe/docs/opencode-guardrails-plugin.example.ts)
