/**
 * OpenCode auto-discovers this stable loader from the global plugin directory.
 * The loader refreshes the full Race Control plugin from the gateway and keeps
 * the previous successful download available for offline starts.
 */

import { createHash } from "node:crypto"
import { mkdir, readFile, rename, writeFile } from "node:fs/promises"
import { homedir } from "node:os"
import { dirname, join } from "node:path"
import { pathToFileURL } from "node:url"
import type { Hooks, Plugin, PluginInput, PluginOptions } from "@opencode-ai/plugin"

const DEFAULT_PLUGIN_URL =
  "https://race-control.zaffari.casa/v0/resource/plugins/race-control/opencode-plugin.js"
const CACHE_PATH = join(homedir(), ".cache", "opencode", "race-control-plugin.js")

export default (async (input: PluginInput, options?: PluginOptions): Promise<Hooks> => {
  const pluginURL = process.env.RACE_CONTROL_PLUGIN_URL ?? DEFAULT_PLUGIN_URL
  let cachedPlugin: string
  try {
    cachedPlugin = await refreshCache(pluginURL)
  } catch (error: unknown) {
    if (!(error instanceof Error)) {
      throw error
    }
    cachedPlugin = await readFile(CACHE_PATH, "utf8")
  }

  const plugin = await importPlugin(cachedPlugin)
  return plugin(input, options)
}) satisfies Plugin

async function refreshCache(pluginURL: string): Promise<string> {
  const response = await fetch(pluginURL, { signal: AbortSignal.timeout(2000) })
  if (!response.ok) {
    throw new Error(`Race Control plugin download failed with status ${response.status}`)
  }

  const plugin = await response.text()
  if (plugin.trim() === "") {
    throw new Error("Race Control plugin download returned an empty body")
  }

  await mkdir(dirname(CACHE_PATH), { recursive: true })
  const temporaryPath = `${CACHE_PATH}.tmp`
  await writeFile(temporaryPath, plugin, "utf8")
  await rename(temporaryPath, CACHE_PATH)
  return plugin
}

async function importPlugin(source: string): Promise<Plugin> {
  const digest = createHash("sha256").update(source).digest("hex")
  const moduleURL = `${pathToFileURL(CACHE_PATH).href}?digest=${digest}`
  const module: unknown = await import(moduleURL)
  if (!isPluginModule(module)) {
    throw new Error("Race Control plugin module does not export a plugin function")
  }
  return module.default
}

function isPluginModule(value: unknown): value is { readonly default: Plugin } {
  if (typeof value !== "object" || value === null || !("default" in value)) {
    return false
  }
  return typeof value.default === "function"
}
