#!/usr/bin/env node
import fs from "node:fs/promises"
import path from "node:path"
import { fileURLToPath } from "node:url"

const MAX_TEXT_CHARS = 6000
const HEAD_CHARS = 2500
const TAIL_CHARS = 1500

function normalizeText(input) {
  return String(input ?? "")
    .replace(/\s+/g, " ")
    .trim()
}

function shortenText(text) {
  if (text.length <= MAX_TEXT_CHARS) return text
  return `${text.slice(0, HEAD_CHARS)}\n...[trimmed]...\n${text.slice(-TAIL_CHARS)}`
}

function roleOf(message) {
  const role = message?.info?.role ?? message?.role
  return typeof role === "string" ? role : "unknown"
}

function clonePart(part, text) {
  return { ...part, text }
}

export function compactMessages(messages) {
  const seenText = new Set()
  const compacted = []
  const stats = { removedParts: 0, shortenedParts: 0 }

  let latestUserIndex = -1
  for (let i = messages.length - 1; i >= 0; i -= 1) {
    if (roleOf(messages[i]) === "user") {
      latestUserIndex = i
      break
    }
  }

  for (let i = 0; i < messages.length; i += 1) {
    const message = messages[i]
    const role = roleOf(message)
    const protectLatestUser = role === "user" && i === latestUserIndex
    const parts = Array.isArray(message?.parts) ? message.parts : []
    const nextParts = []

    for (const part of parts) {
      if (part?.type !== "text") {
        nextParts.push(part)
        continue
      }

      const rawText = typeof part.text === "string" ? part.text : ""
      const normalized = normalizeText(rawText)
      if (!normalized) {
        stats.removedParts += 1
        continue
      }

      const fingerprint = `${role}:${normalized}`
      if (!protectLatestUser && seenText.has(fingerprint)) {
        stats.removedParts += 1
        continue
      }
      seenText.add(fingerprint)

      let text = rawText.trim()
      if (!protectLatestUser) {
        const shortened = shortenText(text)
        if (shortened !== text) {
          text = shortened
          stats.shortenedParts += 1
        }
      }

      nextParts.push(clonePart(part, text))
    }

    if (nextParts.length > 0) {
      compacted.push({ ...message, parts: nextParts })
      continue
    }

    if (parts.length === 0 || protectLatestUser) {
      compacted.push(message)
      continue
    }

    stats.removedParts += 1
  }

  return { messages: compacted, stats }
}

async function main() {
  const [inputPath, outputPath] = process.argv.slice(2)
  if (!inputPath || !outputPath) {
    throw new Error("Usage: precompact-context.mjs <input.json> <output.json>")
  }

  const inputRaw = await fs.readFile(inputPath, "utf8")
  const input = JSON.parse(inputRaw)
  const messages = Array.isArray(input.messages) ? input.messages : []
  const result = compactMessages(messages)
  await fs.writeFile(outputPath, JSON.stringify(result), "utf8")
}

const isMain = process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)

if (isMain) {
  main().catch((error) => {
    // eslint-disable-next-line no-console
    console.error(String(error?.stack || error))
    process.exit(1)
  })
}
