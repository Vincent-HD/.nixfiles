import * as NodeRuntime from "@effect/platform-node/NodeRuntime";
import * as NodeServices from "@effect/platform-node/NodeServices";
import { Console, Effect, Layer, Option } from "effect";
import { Argument, Command, Flag, Prompt } from "effect/cli";
import manifest from "../package.json" with { type: "json" };
import { TaskCatalog } from "./task-catalog.ts";
import { TaskRunner, type TaskChoice } from "./task-runner.ts";
import { TaskError } from "./task-schema.ts";

const services = Layer.mergeAll(TaskCatalog.layer, TaskRunner.layer).pipe(
  Layer.provideMerge(NodeServices.layer),
);
const command = Command.make(
  "vtask",
  {
    task: Argument.String("task").pipe(Argument.optional),
    file: Flag.String("file").pipe(
      Flag.withAlias("f"),
      Flag.withDescription("A tasks.json or .code-workspace file"),
      Flag.optional,
    ),
    list: Flag.Boolean("list").pipe(
      Flag.withDescription("List tasks without running them"),
      Flag.withDefault(false),
    ),
    inputs: Flag.KeyValuePair("input").pipe(
      Flag.withDescription("Provide an input by id: --input name=value"),
      Flag.withDefault({}),
    ),
  },
  Effect.fn("vtask.main")(function* (options) {
    const catalog = yield* TaskCatalog;
    const cwd = process.cwd();
    const sources = yield* catalog.discover({ cwd, file: Option.getOrUndefined(options.file) });
    const choices: TaskChoice[] = sources.flatMap((source) =>
      source.document.tasks.map((task) => ({ source, task })),
    );
    if (choices.length === 0)
      return yield* new TaskError({ message: "The task files contain no tasks." });
    if (options.list) {
      for (const choice of choices)
        yield* Console.log(`${choice.task.label}\t${choice.source.name}\t${choice.source.file}`);
      return;
    }
    let choice: TaskChoice;
    if (Option.isSome(options.task)) {
      const requested = options.task.value;
      const matches = choices.filter(
        (choice) =>
          choice.task.label === requested ||
          `${choice.source.name}:${choice.task.label}` === requested,
      );
      if (matches.length !== 1)
        return yield* new TaskError({
          message: `Task '${requested}' must identify exactly one task. Use --list or folder:label.`,
        });
      choice = matches[0];
    } else {
      const visible = choices.filter((choice) => !choice.task.hide);
      if (visible.length === 0)
        return yield* new TaskError({
          message: "All tasks are hidden. Use --list and invoke a task by label.",
        });
      choice = yield* Prompt.AutoComplete({
        message: "Run a VS Code task",
        choices: visible.map((choice) => ({
          title: `${choice.task.label} (${choice.source.name})`,
          description: choice.task.detail,
          value: choice,
        })),
      });
    }
    const runner = yield* TaskRunner;
    const code = yield* runner.run({ choice, cwd, sources, inputs: options.inputs });
    yield* Effect.sync(() => {
      process.exitCode = code;
    });
  }),
).pipe(
  Command.withDescription("Pick a VS Code task, resolve its inputs, and run it in its workspace."),
);

command.pipe(
  Command.run({ version: manifest.version }),
  Effect.catchTag("vtask/TaskError", (error) =>
    Console.error(error.message).pipe(
      Effect.andThen(
        Effect.sync(() => {
          process.exitCode = 1;
        }),
      ),
    ),
  ),
  Effect.provide(services),
  NodeRuntime.runMain,
);
