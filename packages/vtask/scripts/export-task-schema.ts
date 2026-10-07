import { stripTypeScriptTypes } from "node:module";
import * as NodeRuntime from "@effect/platform-node/NodeRuntime";
import * as NodeServices from "@effect/platform-node/NodeServices";
import { Console, Effect, FileSystem, Path, Schema } from "effect";
import { Argument, Command } from "effect/cli";

const evaluate = (options: {
  source: string;
  bindings: Record<string, unknown>;
  result: string;
}) => {
  // Preserve exports inside namespaces: TypeScript emits their member assignments.
  const source = options.source
    .replace(/^import .*;\n/gm, "")
    .replace("export default schema;", "")
    .replace(/^export /gm, "");
  const javascript = stripTypeScriptTypes(source, { mode: "transform" });
  return Schema.decodeUnknownSync(Schema.Record(Schema.String, Schema.Unknown))(
    new Function(...Object.keys(options.bindings), `${javascript}; return ${options.result};`)(
      ...Object.values(options.bindings),
    ),
  );
};

const command = Command.make(
  "export-task-schema",
  { checkout: Argument.String("vscode-checkout") },
  Effect.fn("vtask.exportTaskSchema")(function* (options) {
    const fs = yield* FileSystem.FileSystem;
    const path = yield* Path.Path;
    const read = (file: string) => fs.readFileString(path.join(options.checkout, "src/vs", file));
    const localize = (_id: string, message: string) => message;
    const bindings = { nls: { localize }, Objects: { deepClone: structuredClone } };
    const matcher = yield* read("workbench/contrib/tasks/common/problemMatcher.ts");
    const Schemas = evaluate({
      source: matcher.slice(
        matcher.indexOf("export namespace Schemas {"),
        matcher.indexOf("\nconst problemPatternExtPoint"),
      ),
      bindings: { ...bindings, localize },
      result: "Schemas",
    });
    const commonSchema = evaluate({
      source: yield* read("workbench/contrib/tasks/common/jsonSchemaCommon.ts"),
      bindings: { ...bindings, Schemas },
      result: "schema",
    });
    const inputsSchema = evaluate({
      source: yield* read(
        "workbench/services/configurationResolver/common/configurationResolverSchema.ts",
      ),
      bindings,
      result: "inputsSchema",
    });
    const register = (id: string) => ({ id });
    const codiconsLibrary = evaluate({
      source: yield* read("base/common/codiconsLibrary.ts"),
      bindings: { register },
      result: "codiconsLibrary",
    });
    const codicons = evaluate({
      source: yield* read("base/common/codicons.ts"),
      bindings: { register, codiconsLibrary },
      result: "Codicon",
    });
    const pending = () => new Promise<never>(() => {});
    const schema = evaluate({
      source: yield* read("workbench/contrib/tasks/common/jsonSchema_v2.ts"),
      bindings: {
        ...bindings,
        commonSchema,
        inputsSchema,
        TaskDefinitionRegistry: { all: () => [], onReady: pending },
        ProblemMatcherRegistry: { keys: () => [], onReady: pending },
        ConfigurationResolverUtils: { applyDeprecatedVariableMessage: () => {} },
        getAllCodicons: () => Object.values(codicons),
      },
      result: "schema",
    });
    const text = JSON.stringify(
      { $schema: "http://json-schema.org/draft-07/schema#", ...schema },
      (key, value) => {
        if (value === undefined) throw new Error(`Missing schema export at ${key}`);
        // VS Code mixes prefixItems with Draft-07 additionalItems; export consistent tuples.
        if (value !== null && typeof value === "object" && Array.isArray(value.prefixItems)) {
          const tuple = { ...value, items: value.prefixItems };
          delete tuple.prefixItems;
          return tuple;
        }
        return value;
      },
      2,
    );
    const output = yield* path.fromFileUrl(new URL("../assets/tasks.schema.json", import.meta.url));
    yield* fs.writeFileString(output, `${text}\n`);
    yield* Console.log(output);
  }),
);

command.pipe(
  Command.run({ version: "1.0.0" }),
  Effect.provide(NodeServices.layer),
  NodeRuntime.runMain,
);
