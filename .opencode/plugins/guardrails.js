export const GuardrailsPlugin = async () => {
  const forbiddenShellPatterns = [
    /\brm\s+-rf\b/,
    /\bgit\s+reset\s+--hard\b/,
    /--dangerously-bypass-approvals-and-sandbox/,
  ]

  return {
    "tool.execute.before": async (input, output) => {
      if (input.tool === "read") {
        const filePath = String(output.args.filePath ?? "")
        if (filePath.includes(".env")) {
          throw new Error("Do not read .env files")
        }
      }

      if (input.tool !== "bash") return

      const command = String(output.args.command ?? "")
      for (const pattern of forbiddenShellPatterns) {
        if (pattern.test(command)) {
          throw new Error(`Blocked dangerous command: ${command}`)
        }
      }
    },

    "tool.execute.after": async (input, output) => {
      if (input.tool !== "bash") return

      const command = String(input.args?.command ?? output.args.command ?? "")
      const errorText = String(output.error ?? "")

      if (/(permission denied|operation not permitted|outside workspace)/i.test(errorText)) {
        throw new Error(
          `Command crossed a guardrail boundary and should be reviewed: ${command}`
        )
      }
    },

    "shell.env": async (input, output) => {
      output.env.CODEX_HOME = `${input.cwd}/.codex`
      output.env.PROJECT_ROOT = input.cwd
    },
  }
}
