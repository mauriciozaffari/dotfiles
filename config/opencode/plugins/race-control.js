// config/opencode/plugin/race-control.ts
import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { pathToFileURL } from "node:url";
var DEFAULT_PLUGIN_URL = "http://192.168.1.253:8317/v0/resource/plugins/race-control/opencode-plugin.js";
var DEFAULT_MODELS_URL = "http://192.168.1.253:8317/v0/resource/plugins/race-control/models.json";
var CACHE_PATH = join(homedir(), ".cache", "opencode", "race-control-plugin.js");
var race_control_default = async (input, options) => {
  const pluginURL = process.env.RACE_CONTROL_PLUGIN_URL ?? DEFAULT_PLUGIN_URL;
  const modelsURL = process.env.RACE_CONTROL_MODELS_URL ?? DEFAULT_MODELS_URL;
  const modelsMode = options?.modelsMode ?? process.env.RACE_CONTROL_MODELS_MODE ?? "profiles";
  let pluginSource;
  try {
    pluginSource = await refreshCache(pluginURL);
  } catch (error) {
    if (!(error instanceof Error))
      throw error;
    pluginSource = await readFile(CACHE_PATH, "utf8");
  }
  let models = null;
  try {
    models = await fetchModels(modelsURL, modelsMode);
  } catch {}
  const plugin = await importPlugin(pluginSource);
  return plugin(input, { ...options, models });
};
async function refreshCache(pluginURL) {
  const response = await fetch(pluginURL, { signal: AbortSignal.timeout(2000) });
  if (!response.ok) {
    throw new Error(`Race Control plugin download failed with status ${response.status}`);
  }
  const text = await response.text();
  if (text.trim() === "") {
    throw new Error("Race Control plugin download returned an empty body");
  }
  await mkdir(dirname(CACHE_PATH), { recursive: true });
  const tmpPath = `${CACHE_PATH}.tmp`;
  await writeFile(tmpPath, text, "utf8");
  await rename(tmpPath, CACHE_PATH);
  return text;
}
async function fetchModels(modelsURL, modelsMode) {
  const url = new URL(modelsURL);
  url.searchParams.set("models", modelsMode);
  const response = await fetch(url.toString(), { signal: AbortSignal.timeout(2000) });
  if (!response.ok)
    return null;
  const data = await response.json();
  return data?.models ?? null;
}
async function importPlugin(source) {
  await mkdir(dirname(CACHE_PATH), { recursive: true });
  await writeFile(CACHE_PATH, source, "utf8");
  const mod = await import(pathToFileURL(CACHE_PATH).href);
  if (typeof mod !== "object" || mod === null || !("default" in mod) || typeof mod.default !== "function") {
    throw new Error("Race Control plugin module does not export a plugin function");
  }
  return mod.default;
}
export {
  race_control_default as default
};
