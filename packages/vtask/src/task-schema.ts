import { Effect, JsonSchema, Schema, SchemaRepresentation } from "effect";
import { parse, printParseErrorCode, type ParseError } from "jsonc-parser";
import publishedSchema from "../assets/tasks.schema.json" with { type: "json" };

export class TaskError extends Schema.TaggedError<TaskError>()("vtask/TaskError", {
  message: Schema.String,
}) {}

const importedSchema = SchemaRepresentation.fromJsonSchemaDocument(
  JsonSchema.fromSchemaDraft07(publishedSchema),
  {
    patterns: "apply",
    // Effect cannot import VS Code's typed extension keys alongside declared options.
    onEnter: (schema) =>
      typeof schema === "object" &&
      schema.properties !== undefined &&
      typeof schema.additionalProperties === "object"
        ? { ...schema, additionalProperties: true }
        : schema,
  },
);
const shellValue = Schema.Union([
  Schema.String,
  Schema.Struct({ value: Schema.String, quoting: Schema.Literals(["strong", "weak", "escape"]) }),
]);
const options = Schema.Struct({
  cwd: Schema.optional(Schema.String),
  env: Schema.optional(Schema.Record(Schema.String, Schema.String)),
  shell: Schema.optional(
    Schema.Struct({
      executable: Schema.String,
      args: Schema.optional(Schema.Array(Schema.String)),
    }),
  ),
});
const taskFields = {
  type: Schema.optional(Schema.String),
  command: Schema.optional(shellValue),
  args: Schema.optional(Schema.Array(shellValue)),
  options: Schema.optional(options),
  isBackground: Schema.optional(Schema.Boolean),
};
const task = Schema.Struct({
  ...taskFields,
  label: Schema.NonEmptyString,
  detail: Schema.optional(Schema.String),
  hide: Schema.optional(Schema.Boolean),
  dependsOn: Schema.optional(Schema.Union([Schema.String, Schema.Array(Schema.String)])),
  dependsOrder: Schema.optional(Schema.Literals(["sequence", "parallel"])),
  linux: Schema.optional(Schema.Struct(taskFields)),
  osx: Schema.optional(Schema.Struct(taskFields)),
  windows: Schema.optional(Schema.Struct(taskFields)),
});
const input = Schema.Union([
  Schema.Struct({
    id: Schema.NonEmptyString,
    type: Schema.Literal("promptString"),
    description: Schema.String,
    default: Schema.optional(Schema.String),
    password: Schema.optional(Schema.Boolean),
  }),
  Schema.Struct({
    id: Schema.NonEmptyString,
    type: Schema.Literal("pickString"),
    description: Schema.String,
    default: Schema.optional(Schema.String),
    options: Schema.NonEmptyArray(
      Schema.Union([Schema.String, Schema.Struct({ label: Schema.String, value: Schema.String })]),
    ),
  }),
  Schema.Struct({
    id: Schema.NonEmptyString,
    type: Schema.Literal("command"),
    command: Schema.String,
  }),
]);
export const TaskDocument = Schema.Struct({
  ...taskFields,
  version: Schema.Literal("2.0.0"),
  tasks: Schema.Array(task),
  inputs: Schema.optional(Schema.Array(input)),
  linux: Schema.optional(Schema.Struct(taskFields)),
  osx: Schema.optional(Schema.Struct(taskFields)),
  windows: Schema.optional(Schema.Struct(taskFields)),
});
export type TaskDocument = typeof TaskDocument.Type;
export type Task = typeof task.Type;
export type Input = typeof input.Type;
export type ShellValue = typeof shellValue.Type;

export const parseJsonc = Effect.fn("vtask.parseJsonc")(function* (text: string) {
  const errors: ParseError[] = [];
  const value: unknown = parse(text, errors, { allowTrailingComma: true });
  if (errors.length > 0) {
    return yield* new TaskError({
      message: errors
        .map((error) => `${printParseErrorCode(error.error)} at offset ${error.offset}`)
        .join("; "),
    });
  }
  return value;
});

export const decodeTasks = Effect.fn("vtask.decodeTasks")(function* (text: string) {
  const value = yield* parseJsonc(text);
  yield* Schema.decodeUnknownEffect(
    Schema.make<Schema.ConstraintDecoder<unknown>>(importedSchema.ast),
  )(value).pipe(
    Effect.mapError(
      (cause) => new TaskError({ message: `Invalid VS Code task file: ${cause.message}` }),
    ),
  );
  return yield* Schema.decodeUnknownEffect(TaskDocument)(value).pipe(
    Effect.mapError(
      (cause) =>
        new TaskError({ message: `Invalid executable task configuration: ${cause.message}` }),
    ),
  );
});
