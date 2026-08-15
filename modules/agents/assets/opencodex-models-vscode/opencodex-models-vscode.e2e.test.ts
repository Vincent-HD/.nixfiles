import { homedir } from "node:os";
import { join } from "node:path";

import { describe, expect, test } from "bun:test";

import {
  discoverVscodeModels,
  type JsonObject,
} from "./opencodex-models-vscode";

const DEFAULT_BASE_URL = "http://127.0.0.1:10100";

const nonEmptyString = (value: unknown): string | undefined => (
  typeof value === "string" && value.trim() !== "" ? value.trim() : undefined
);

const isRecord = (value: unknown): value is JsonObject => (
  typeof value === "object" && value !== null && !Array.isArray(value)
);

const normalizeBaseUrl = (value: string): string => {
  const url = new URL(value);
  url.pathname = url.pathname.replace(/\/v1\/?$/, "").replace(/\/+$/, "");
  return url.toString().replace(/\/$/, "");
};

const readAdminToken = async (): Promise<string> => {
  const configuredToken = process.env.OPENCODEX_ADMIN_AUTH_TOKEN?.trim();
  if (configuredToken) return configuredToken;

  const home = process.env.OPENCODEX_HOME?.trim() || join(homedir(), ".opencodex");
  const token = (await Bun.file(join(home, "admin-api-token")).text()).trim();
  if (!token) throw new Error("OpenCodex admin-api-token is empty");
  return token;
};

describe("opencodex-models-vscode E2E", () => {
  test("queries the local OpenCodex API and exports its enabled catalog", async () => {
    const baseUrl = normalizeBaseUrl(
      process.env.OPENCODEX_E2E_BASE_URL
        ?? process.env.OPENCODEX_BASE_URL
        ?? DEFAULT_BASE_URL,
    );
    const models = await discoverVscodeModels({ baseUrl });
    const response = await fetch(`${baseUrl}/api/models`, {
      headers: { "x-opencodex-api-key": await readAdminToken() },
      signal: AbortSignal.timeout(10_000),
    });
    expect(response.ok).toBe(true);

    const payload: unknown = await response.json();
    const rows = Array.isArray(payload) ? payload.filter(isRecord) : [];
    expect(rows.length).toBe(Array.isArray(payload) ? payload.length : -1);

    const enabledIds = rows
      .filter((row) => row.disabled !== true)
      .map((row) => nonEmptyString(row.namespaced) ?? nonEmptyString(row.id))
      .filter((id): id is string => id !== undefined)
      .sort();
    const exportedIds = models.map((model) => model.id).sort();

    expect(models.length).toBeGreaterThan(0);
    expect(exportedIds).toEqual(enabledIds);
    expect(models.every((model) => (
      model.url === `${baseUrl}/v1/chat/completions`
      && model.apiType === "chat-completions"
      && typeof model.vision === "boolean"
      && model.streaming === true
    ))).toBe(true);

    const reasoningModels = models.filter((model) => (
      Array.isArray(model.supportsReasoningEffort)
      && model.supportsReasoningEffort.length > 0
    ));
    expect(reasoningModels.length).toBeGreaterThan(0);
    expect(reasoningModels.every((model) => (
      model.thinking === true
      && model.reasoningEffortFormat === "chat-completions"
    ))).toBe(true);

    expect(models.every((model) => (
      model.contextWindow === undefined
      || (
        typeof model.maxInputTokens === "number"
        && typeof model.maxOutputTokens === "number"
        && model.maxInputTokens + model.maxOutputTokens <= model.contextWindow
      )
    ))).toBe(true);
  }, 30_000);
});
