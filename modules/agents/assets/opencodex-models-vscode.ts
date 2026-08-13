import { readFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";

type JsonObject = Record<string, unknown>;

type VscodeModel = {
  id: string;
  name: string;
  url: string;
  toolCalling: true;
  vision: true;
  maxInputTokens: 128000;
  maxOutputTokens: 16000;
};

const DEFAULT_PORT = 10100;
const REQUEST_TIMEOUT_MS = 10_000;

const isRecord = (value: unknown): value is JsonObject => (
  typeof value === "object" && value !== null && !Array.isArray(value)
);

const nonEmptyString = (value: unknown): string | undefined => (
  typeof value === "string" && value.trim() !== "" ? value.trim() : undefined
);

const positiveInteger = (value: unknown): number | undefined => (
  typeof value === "number" && Number.isSafeInteger(value) && value > 0 ? value : undefined
);

const opencodexHome = process.env.OPENCODEX_HOME?.trim() || join(homedir(), ".opencodex");

const readBaseUrl = async (): Promise<string> => {
  const configuredBaseUrl = process.env.OPENCODEX_BASE_URL?.trim();
  if (configuredBaseUrl) return configuredBaseUrl;

  let config: JsonObject = {};
  try {
    const value: unknown = JSON.parse(await readFile(join(opencodexHome, "config.json"), "utf8"));
    if (isRecord(value)) config = value;
  } catch {
    // The default loopback address is enough for a standard OpenCodex installation.
  }

  const port = positiveInteger(config.port) ?? DEFAULT_PORT;
  const configuredHostname = nonEmptyString(config.hostname);
  const hostname = configuredHostname && configuredHostname !== "0.0.0.0"
    ? configuredHostname
    : "127.0.0.1";
  const displayHostname = hostname.includes(":") && !hostname.startsWith("[")
    ? `[${hostname}]`
    : hostname;
  return `http://${displayHostname}:${port}`;
};

const normalizeBaseUrl = (value: string): string => {
  const url = new URL(value);
  url.pathname = url.pathname.replace(/\/v1\/?$/, "").replace(/\/+$/, "");
  return url.toString().replace(/\/$/, "");
};

const readModels = async (baseUrl: string): Promise<JsonObject[]> => {
  const headers: Record<string, string> = {};
  const apiToken = process.env.OPENCODEX_API_AUTH_TOKEN?.trim();
  if (apiToken) headers["x-opencodex-api-key"] = apiToken;

  let response: Response;
  try {
    response = await fetch(`${baseUrl}/v1/models`, {
      headers,
      signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    throw new Error(`Could not contact OpenCodex at ${baseUrl}: ${message}`);
  }

  const body = await response.text();
  let payload: unknown = body;
  try {
    payload = JSON.parse(body);
  } catch {
    // Keep the response text for the error below.
  }

  if (!response.ok) {
    const apiError = isRecord(payload) ? nonEmptyString(payload.error) : undefined;
    throw new Error(`OpenCodex returned HTTP ${response.status}: ${apiError || body || response.statusText}`);
  }

  const data = isRecord(payload) && Array.isArray(payload.data) ? payload.data : undefined;
  if (!data || !data.every(isRecord)) {
    throw new Error("OpenCodex returned an unexpected /v1/models response");
  }
  return data;
};

const toVscodeModel = (baseUrl: string, model: JsonObject): VscodeModel | undefined => {
  const id = nonEmptyString(model.id);
  if (!id) return undefined;

  return {
    id,
    name: id,
    url: `${baseUrl}/v1/chat/completions`,
    toolCalling: true,
    vision: true,
    maxInputTokens: 128000,
    maxOutputTokens: 16000,
  };
};

const main = async (): Promise<void> => {
  const baseUrl = normalizeBaseUrl(await readBaseUrl());
  const models = (await readModels(baseUrl))
    .map((model) => toVscodeModel(baseUrl, model))
    .filter((model): model is VscodeModel => model !== undefined);

  console.log(JSON.stringify({ models }, null, 2));
};

try {
  await main();
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
}
