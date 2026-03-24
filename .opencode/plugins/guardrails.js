import path from "node:path"
import { pathToFileURL } from "node:url"

const SCRIPT_PATH = path.join(process.cwd(), "scripts/opencode/precompact-context.mjs")
const SCRIPT_URL = pathToFileURL(SCRIPT_PATH).href
let precompactModulePromise

async function logPlugin(client, level, message, extra = {}) {
  if (client?.app?.log) {
    await client.app.log({
      body: {
        service: "guardrails",
        level,
        message,
        extra,
      },
    })
    return
  }

  const details = Object.keys(extra).length ? ` ${JSON.stringify(extra)}` : ""
  // eslint-disable-next-line no-console
  console.log(`[guardrails:${level}] ${message}${details}`)
}

async function precompactMessages(messages, client) {
  if (!Array.isArray(messages) || messages.length === 0) return messages

  try {
    if (!precompactModulePromise) {
      precompactModulePromise = import(SCRIPT_URL)
    }
    const precompactModule = await precompactModulePromise
    if (typeof precompactModule.compactMessages !== "function") {
      await logPlugin(client, "warn", "Precompact script export missing", { script: SCRIPT_PATH })
      return messages
    }

    const output = precompactModule.compactMessages(messages)

    if (!Array.isArray(output.messages)) {
      await logPlugin(client, "warn", "Precompact script returned invalid payload")
      return messages
    }

    await logPlugin(client, "info", "Precompact complete", {
      before: messages.length,
      after: output.messages.length,
      removed_parts: output.stats?.removedParts ?? 0,
      shortened_parts: output.stats?.shortenedParts ?? 0,
    })

    return output.messages
  } catch (error) {
    await logPlugin(client, "warn", "Precompact script execution error", {
      error: String(error),
    })
    return messages
  }
}

export const GuardrailsPlugin = async ({ client } = {}) => {
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

    // Run before each model call to remove duplicate and oversized context text.
    "experimental.chat.messages.transform": async (_input, output) => {
      output.messages = await precompactMessages(output.messages, client)
    },

    // Runs on auto/manual compaction passes only.
    "experimental.session.compacting": async (_input, output) => {
      output.context.push(
        "Deduplicate repeated decisions and commands. Keep only actionable outputs."
      )
    },
  }
}
