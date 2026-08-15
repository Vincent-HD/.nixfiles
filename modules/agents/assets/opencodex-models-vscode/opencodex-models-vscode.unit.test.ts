import { describe, expect, test } from "bun:test";

import {
  mapModelToVscode,
  type JsonObject,
} from "./opencodex-models-vscode";

const mapOf = (entries: Array<[string, JsonObject]>): Map<string, JsonObject> => (
  new Map<string, JsonObject>(entries)
);

describe("mapModelToVscode", () => {
  test("maps live capability metadata into VS Code custom-endpoint fields", () => {
    const model = mapModelToVscode({
      baseUrl: "http://127.0.0.1:10100",
      model: {
        provider: "openai",
        id: "gpt-test",
        namespaced: "gpt-test",
        contextWindow: 100_000,
        inputModalities: ["text", "image"],
        reasoningEfforts: ["low", "medium", "high"],
      },
      catalog: mapOf([
        ["gpt-test", {
          slug: "gpt-test",
          display_name: "GPT Test",
          supports_parallel_tool_calls: true,
        }],
      ]),
      providers: mapOf([
        ["openai", { defaultMaxOutputTokens: 16_000 }],
      ]),
      includeAuthHeader: false,
    });

    expect(model).toEqual({
      id: "gpt-test",
      name: "GPT Test",
      url: "http://127.0.0.1:10100/v1/chat/completions",
      apiType: "chat-completions",
      toolCalling: true,
      vision: true,
      contextWindow: 100_000,
      maxInputTokens: 84_000,
      maxOutputTokens: 16_000,
      thinking: true,
      streaming: true,
      supportsReasoningEffort: ["low", "medium", "high"],
      reasoningEffortFormat: "chat-completions",
    });
  });

  test("does not invent unsupported capability fields", () => {
    const model = mapModelToVscode({
      baseUrl: "http://127.0.0.1:10100",
      model: {
        id: "cursor/unknown",
        contextWindow: 50_000,
        inputModalities: ["text"],
        reasoningEfforts: [],
      },
      catalog: new Map<string, JsonObject>(),
      providers: new Map<string, JsonObject>(),
      includeAuthHeader: false,
    });

    expect(model).toEqual({
      id: "cursor/unknown",
      name: "cursor/unknown",
      url: "http://127.0.0.1:10100/v1/chat/completions",
      apiType: "chat-completions",
      vision: false,
      contextWindow: 50_000,
      maxInputTokens: 34_000,
      maxOutputTokens: 16_000,
      streaming: true,
    });
  });

  test("drops rows without a model identifier", () => {
    expect(mapModelToVscode({
      baseUrl: "http://127.0.0.1:10100",
      model: {},
      catalog: new Map<string, JsonObject>(),
      providers: new Map<string, JsonObject>(),
      includeAuthHeader: false,
    })).toBeUndefined();
  });
});
