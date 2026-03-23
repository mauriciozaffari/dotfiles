import type { Plugin } from "@opencode-ai/plugin"

const SECRET_PATTERN =
  /(api[_-]?key|secret|password|token|credential)\s*[:=]\s*['"][^'"]{8,}['"]/i

const TS_EXTENSIONS = /\.ts$/

export const BlockHardcodedSecrets: Plugin = async () => {
  return {
    "tool.execute.before": async (input, output) => {
      if (input.tool !== "write" && input.tool !== "edit") return

      const filePath = output.args?.filePath
      if (!filePath || !TS_EXTENSIONS.test(filePath)) return

      // Check the content being written
      let content: string | undefined

      if (input.tool === "write") {
        content = output.args?.content
      } else if (input.tool === "edit") {
        content = output.args?.newString
      }

      if (content && SECRET_PATTERN.test(content)) {
        throw new Error(
          `Hardcoded secret detected - Use environment variables instead.

Example:
  // Blocked
  const apiKey = 'sk-abc123...';

  // Preferred
  const apiKey = process.env.API_KEY;

Never commit secrets to source control.`
        )
      }
    },
  }
}
