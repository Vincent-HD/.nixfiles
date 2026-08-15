import { readFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";

export type JsonObject = Record<string, unknown>;

export type VscodeModel = {
  id: string;
  name: string;
  url: string;
  apiType: "chat-completions";
  toolCalling?: boolean;
  vision: boolean;
  contextWindow?: number;
  maxInputTokens?: number;
  maxOutputTokens?: number;
  thinking?: boolean;
  streaming?: boolean;
  supportsReasoningEffort?: string[];
  reasoningEffortFormat?: "chat-completions";
  requestHeaders?: Record<string, string>;
};

type ManagementData = {
  models: JsonObject[];
  catalog: JsonObject[];
  providers: JsonObject[];
};

const DEFAULT_PORT = 10100;
// OpenCodex exposes context windows but not a universal per-model output ceiling for VS Code.
// Keep the requested VS Code budget as a safe, overridable fallback.
const DEFAULT_MAX_OUTPUT_TOKENS = 16_000;
const REQUEST_TIMEOUT_MS = 10_000;

const isRecord = (value: unknown): value is JsonObject => (
  typeof value === "object" && value !== null && !Array.isArray(value)
);

const nonEmptyString = (value: unknown): string | undefined => (
  typeof value === "string" && value.trim() !== "" ? value.trim() : undefined
);

const positiveInteger = (value: unknown): number | undefined => {
  const number = typeof value === "number"
    ? value
    : typeof value === "string" && /^\d+$/.test(value.trim())
      ? Number(value)
      : undefined;
  return typeof number === "number" && Number.isSafeInteger(number) && number > 0
    ? number
    : undefined;
};

const firstPositiveInteger = (...values: unknown[]): number | undefined => {
  for (const value of values) {
    const number = positiveInteger(value);
    if (number !== undefined) return number;
  }
  return undefined;
};

const stringArray = (value: unknown): string[] | undefined => {
  if (!Array.isArray(value)) return undefined;
  const values = value
    .map((entry) => nonEmptyString(entry))
    .filter((entry): entry is string => entry !== undefined);
  return [...new Set(values)];
};

const reasoningEffortArray = (value: unknown): string[] | undefined => {
  if (!Array.isArray(value)) return undefined;
  const values = value
    .map((entry) => isRecord(entry)
      ? nonEmptyString(entry.effort) ?? nonEmptyString(entry.value)
      : nonEmptyString(entry))
    .filter((entry): entry is string => entry !== undefined);
  return [...new Set(values)];
};

const opencodexHome = process.env.OPENCODEX_HOME?.trim() || join(homedir(), ".opencodex");

const readJsonFile = async (path: string): Promise<JsonObject> => {
  try {
    const value: unknown = JSON.parse(await readFile(path, "utf8"));
    return isRecord(value) ? value : {};
  } catch {
    return {};
  }
};

const readBaseUrl = async (): Promise<string> => {
  const configuredBaseUrl = process.env.OPENCODEX_BASE_URL?.trim();
  if (configuredBaseUrl) return configuredBaseUrl;

  const config = await readJsonFile(join(opencodexHome, "config.json"));
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
  url.search = "";
  url.hash = "";
  return url.toString().replace(/\/$/, "");
};

const isLoopbackHostname = (hostname: string): boolean => (
  hostname === "localhost"
  || hostname === "::1"
  || hostname === "[::1]"
  || hostname === "127.0.0.1"
  || hostname.startsWith("127.")
);

const readAdminToken = async (baseUrl: string): Promise<string | undefined> => {
  const configuredToken = process.env.OPENCODEX_ADMIN_AUTH_TOKEN?.trim();
  if (configuredToken) return configuredToken;

  const hostname = new URL(baseUrl).hostname;
  if (!isLoopbackHostname(hostname)) return undefined;

  try {
    const token = (await readFile(join(opencodexHome, "admin-api-token"), "utf8")).trim();
    return token || undefined;
  } catch {
    return undefined;
  }
};

const requestJson = async ({
  url,
  token,
  label,
}: {
  url: string;
  token?: string;
  label: string;
}): Promise<unknown> => {
  const headers: Record<string, string> = {};
  if (token) headers["x-opencodex-api-key"] = token;

  let response: Response;
  try {
    response = await fetch(url, {
      headers,
      signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    throw new Error(`Could not contact OpenCodex at ${url}: ${message}`);
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
    throw new Error(`OpenCodex ${label} returned HTTP ${response.status}: ${apiError || body || response.statusText}`);
  }

  return payload;
};

const recordArray = ({
  payload,
  key,
  label,
}: {
  payload: unknown;
  key?: string;
  label: string;
}): JsonObject[] => {
  const value = key === undefined
    ? payload
    : isRecord(payload) ? payload[key] : undefined;
  if (!Array.isArray(value) || !value.every(isRecord)) {
    throw new Error(`OpenCodex returned an unexpected ${label} response`);
  }
  return value;
};

const readManagementData = async (baseUrl: string): Promise<ManagementData | undefined> => {
  const adminToken = await readAdminToken(baseUrl);
  if (!adminToken) return undefined;

  const [modelsPayload, catalogPayload, providersPayload] = await Promise.all([
    requestJson({ url: `${baseUrl}/api/models`, token: adminToken, label: "/api/models" }),
    requestJson({ url: `${baseUrl}/api/catalog`, token: adminToken, label: "/api/catalog" }),
    requestJson({ url: `${baseUrl}/api/providers`, token: adminToken, label: "/api/providers" }),
  ]);

  return {
    models: recordArray({ payload: modelsPayload, label: "/api/models" }),
    catalog: recordArray({ payload: catalogPayload, key: "models", label: "/api/catalog" }),
    providers: recordArray({ payload: providersPayload, label: "/api/providers" }),
  };
};

const readPublicModels = async (baseUrl: string): Promise<JsonObject[]> => {
  const apiToken = process.env.OPENCODEX_API_AUTH_TOKEN?.trim();
  const payload = await requestJson({
    url: `${baseUrl}/v1/models`,
    token: apiToken,
    label: "/v1/models",
  });
  return recordArray({ payload, key: "data", label: "/v1/models" });
};

const recordInteger = ({
  record,
  keys,
  candidates,
}: {
  record: JsonObject | undefined;
  keys: string[];
  candidates: string[];
}): number | undefined => {
  if (!record) return undefined;
  for (const key of keys) {
    const values = record[key];
    if (!isRecord(values)) continue;
    for (const candidate of candidates) {
      const number = positiveInteger(values[candidate]);
      if (number !== undefined) return number;
    }
  }
  return undefined;
};

const providerForModel = ({
  providers,
  providerName,
}: {
  providers: Map<string, JsonObject>;
  providerName: string | undefined;
}): JsonObject | undefined => (
  providerName === undefined ? undefined : providers.get(providerName)
);

export const mapModelToVscode = ({
  baseUrl,
  model,
  catalog,
  providers,
  includeAuthHeader,
}: {
  baseUrl: string;
  model: JsonObject;
  catalog: Map<string, JsonObject>;
  providers: Map<string, JsonObject>;
  includeAuthHeader: boolean;
}): VscodeModel | undefined => {
  const id = nonEmptyString(model.namespaced) ?? nonEmptyString(model.id);
  if (!id) return undefined;

  const providerName = nonEmptyString(model.provider);
  const provider = providerForModel({ providers, providerName });
  const catalogModel = catalog.get(id) ?? catalog.get(nonEmptyString(model.id) ?? id);
  const inputModalities = stringArray(model.inputModalities)
    ?? stringArray(model.input_modalities)
    ?? stringArray(catalogModel?.input_modalities)
    ?? [];
  const reasoningEfforts = reasoningEffortArray(model.reasoningEfforts)
    ?? reasoningEffortArray(model.reasoning_efforts)
    ?? reasoningEffortArray(catalogModel?.supported_reasoning_levels)
    ?? [];
  const contextWindow = firstPositiveInteger(
    model.contextWindow,
    model.context_window,
    catalogModel?.context_window,
    catalogModel?.max_context_window,
    provider?.modelContextWindows && isRecord(provider.modelContextWindows)
      ? provider.modelContextWindows[id]
      : undefined,
    provider?.contextWindow,
  );
  const modelIds = [id, nonEmptyString(model.id)].filter((entry): entry is string => entry !== undefined);
  const maxInputTokens = firstPositiveInteger(
    model.maxInputTokens,
    model.max_input_tokens,
    recordInteger({
      record: provider,
      keys: ["modelMaxInputTokens", "model_max_input_tokens"],
      candidates: modelIds,
    }),
  );
  const configuredMaxOutputTokens = firstPositiveInteger(
    model.maxOutputTokens,
    model.max_output_tokens,
    recordInteger({
      record: provider,
      keys: ["modelMaxOutputTokens", "model_max_output_tokens"],
      candidates: modelIds,
    }),
    provider?.defaultMaxOutputTokens,
    provider?.default_max_output_tokens,
    process.env.OPENCODEX_VSCODE_MAX_OUTPUT_TOKENS,
    DEFAULT_MAX_OUTPUT_TOKENS,
  );
  const tokenLimits = contextWindow === undefined || configuredMaxOutputTokens === undefined
    ? {}
    : (() => {
      const safeMaxOutputTokens = Math.min(
        configuredMaxOutputTokens,
        Math.max(1, contextWindow - 1),
      );
      const safeMaxInputTokens = maxInputTokens === undefined
        ? contextWindow - safeMaxOutputTokens
        : Math.min(maxInputTokens, contextWindow - safeMaxOutputTokens);
      return {
        contextWindow,
        maxInputTokens: Math.max(1, safeMaxInputTokens),
        maxOutputTokens: safeMaxOutputTokens,
      };
    })();
  const supportsToolCalling = typeof catalogModel?.supports_parallel_tool_calls === "boolean"
    ? catalogModel.supports_parallel_tool_calls
    : catalogModel?.tool_mode === "code_mode_only"
      || (Array.isArray(catalogModel?.experimental_supported_tools)
        && catalogModel.experimental_supported_tools.length > 0)
      ? true
      : undefined;
  const displayName = nonEmptyString(catalogModel?.display_name)
    ?? nonEmptyString(model.displayName)
    ?? id;

  return {
    id,
    name: displayName,
    url: `${baseUrl}/v1/chat/completions`,
    apiType: "chat-completions",
    ...(supportsToolCalling !== undefined ? { toolCalling: supportsToolCalling } : {}),
    vision: inputModalities.includes("image"),
    ...tokenLimits,
    ...(reasoningEfforts.length > 0
      ? {
        thinking: true,
        streaming: true,
        supportsReasoningEffort: reasoningEfforts,
        reasoningEffortFormat: "chat-completions" as const,
      }
      : { streaming: true }),
    ...(includeAuthHeader
      ? { requestHeaders: { "x-opencodex-api-key": "${apiKey}" } }
      : {}),
  };
};

export const discoverVscodeModels = async ({
  baseUrl,
}: {
  baseUrl?: string;
} = {}): Promise<VscodeModel[]> => {
  const normalizedBaseUrl = normalizeBaseUrl(baseUrl ?? await readBaseUrl());
  const management = await readManagementData(normalizedBaseUrl);
  const sourceModels = management?.models.filter((model) => model.disabled !== true)
    ?? await readPublicModels(normalizedBaseUrl);
  const catalog = new Map<string, JsonObject>();
  const providers = new Map<string, JsonObject>();
  for (const model of management?.catalog ?? []) {
    const slug = nonEmptyString(model.slug);
    if (slug) catalog.set(slug, model);
  }
  for (const provider of management?.providers ?? []) {
    const name = nonEmptyString(provider.name) ?? nonEmptyString(provider.id);
    if (name) providers.set(name, provider);
  }

  const models = sourceModels
    .map((model) => mapModelToVscode({
      baseUrl: normalizedBaseUrl,
      model,
      catalog,
      providers,
      includeAuthHeader: Boolean(process.env.OPENCODEX_API_AUTH_TOKEN?.trim())
        || process.env.OPENCODEX_VSCODE_INCLUDE_AUTH_HEADER === "1",
    }))
    .filter((model): model is VscodeModel => model !== undefined);

  return models;
};

const main = async (): Promise<void> => {
  const models = await discoverVscodeModels();

  console.log(JSON.stringify({ models }, null, 2));
};

if (import.meta.main) {
  try {
    await main();
  } catch (error) {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  }
}
