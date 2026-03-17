import type { Plugin } from "@opencode-ai/plugin"

const FORBIDDEN_SHELL_PATTERNS = [
  /\brm\s+-rf\b/,
  /\bgit\s+reset\s+--hard\b/,
  /--dangerously-bypass-approvals-and-sandbox/,
]

export const GuardrailsPlugin: Plugin = async ({ client }) => {
  return {
    "tool.execute.before": async (input, output) => {
      if (input.tool !== "bash") return

      const command = String(output.args.command ?? "")
      for (const pattern of FORBIDDEN_SHELL_PATTERNS) {
        if (pattern.test(command)) {
          throw new Error(`Blocked dangerous command: ${command}`)
        }
      }
    },

    "tool.execute.after": async (input, output) => {
      if (input.tool !== "bash") return

      const command = String(input.args?.command ?? output.args.command ?? "")
      const stderr = String(output.error ?? "")
      if (stderr.match(/permission denied|operation not permitted|outside workspace/i)) {
        await client.app.log({
          body: {
            service: "guardrails",
            level: "warn",
            message: "Command hit a guardrail boundary",
            extra: { command, stderr },
          },
        })
      }
    },

    "shell.env": async (input, output) => {
      output.env.PROJECT_ROOT = input.cwd
      output.env.CODEX_HOME = `${input.cwd}/.codex`
    },

    event: async ({ event }) => {
      if (event.type !== "session.idle") return
      await client.app.log({
        body: {
          service: "guardrails",
          level: "info",
          message: "Session became idle",
        },
      })
    },
  }
}
