import {
  Config,
  Console,
  Context,
  Effect,
  FileSystem,
  Layer,
  Path,
  PlatformError,
  Redacted,
  Schema,
  Stdio,
  Terminal,
} from "effect";
import { Prompt } from "effect/cli";
import { ChildProcess, ChildProcessSpawner } from "effect/process";
import type { TaskSource } from "./task-catalog.ts";
import { TaskError, type Input, type ShellValue, type Task } from "./task-schema.ts";

export interface TaskChoice {
  readonly source: TaskSource;
  readonly task: Task;
}
type PromptServices = FileSystem.FileSystem | Path.Path | Stdio.Stdio | Terminal.Terminal;
interface TaskNode {
  readonly choice: TaskChoice;
  readonly dependencies: ReadonlyArray<TaskNode>;
}
interface PreparedTask {
  readonly label: string;
  readonly command?: ChildProcess.Command;
  readonly parallel: boolean;
  readonly dependencies: ReadonlyArray<PreparedTask>;
}

const valueText = (value: ShellValue) => (typeof value === "string" ? value : value.value);
const strongQuote = (value: string) => `'${value.replaceAll("'", "'\\''")}'`;
const quote = (value: ShellValue) => {
  if (typeof value === "string" || value.quoting === "strong") return strongQuote(valueText(value));
  if (value.quoting === "weak") return `"${value.value.replace(/["\\]/g, "\\$&")}"`;
  return value.value.replace(/[^a-zA-Z0-9_./-]/g, "\\$&");
};
const effectiveTask = (choice: TaskChoice) => {
  const platform =
    process.platform === "darwin" ? "osx" : process.platform === "win32" ? "windows" : "linux";
  const global = choice.source.document;
  const local = choice.task;
  return {
    ...global,
    ...global[platform],
    ...local,
    ...local[platform],
    options: {
      ...global.options,
      ...global[platform]?.options,
      ...local.options,
      ...local[platform]?.options,
      env: {
        ...global.options?.env,
        ...global[platform]?.options?.env,
        ...local.options?.env,
        ...local[platform]?.options?.env,
      },
    },
  };
};
const taskStrings = (choice: TaskChoice) => {
  const task = effectiveTask(choice);
  return [
    task.command === undefined ? "" : valueText(task.command),
    ...(task.args ?? []).map(valueText),
    task.options.cwd ?? "",
    ...Object.values(task.options.env),
    task.options.shell?.executable ?? "",
    ...(task.options.shell?.args ?? []),
  ];
};

const makePlan = Effect.fn("vtask.makePlan")(function* (options: {
  choice: TaskChoice;
  ancestors: ReadonlyArray<string>;
}): Effect.fn.Return<TaskNode, TaskError> {
  const label = options.choice.task.label;
  if (options.ancestors.includes(label))
    return yield* new TaskError({
      message: `Cyclic task dependency: ${[...options.ancestors, label].join(" -> ")}`,
    });
  const task = effectiveTask(options.choice);
  if (task.type !== undefined && task.type !== "shell" && task.type !== "process")
    return yield* new TaskError({
      message: `Task ${label} uses VS Code extension type '${task.type}'; vtask runs shell/process tasks.`,
    });
  const labels = options.choice.task.dependsOn;
  const dependencies: TaskNode[] = [];
  for (const dependency of typeof labels === "string" ? [labels] : (labels ?? [])) {
    const matches = options.choice.source.document.tasks.filter(
      (candidate) => candidate.label === dependency,
    );
    if (matches.length !== 1)
      return yield* new TaskError({
        message: `Dependency '${dependency}' must identify exactly one task.`,
      });
    const child = matches[0];
    if (effectiveTask({ source: options.choice.source, task: child }).isBackground)
      return yield* new TaskError({
        message: `Background dependency '${dependency}' requires VS Code problem-matcher readiness; it cannot run as a vtask dependency.`,
      });
    dependencies.push(
      yield* makePlan({
        choice: { source: options.choice.source, task: child },
        ancestors: [...options.ancestors, label],
      }),
    );
  }
  if (task.command === undefined && dependencies.length === 0)
    return yield* new TaskError({
      message: `Task '${label}' has neither a command nor dependencies.`,
    });
  return { choice: options.choice, dependencies } satisfies TaskNode;
});

const promptInput = Effect.fn("vtask.promptInput")(function* (input: Input) {
  if (input.type === "command")
    return yield* new TaskError({
      message: `Input '${input.id}' calls VS Code command '${input.command}'. Supply its value with --input ${input.id}=value.`,
    });
  if (input.type === "pickString") {
    if (
      input.default !== undefined &&
      !input.options.some(
        (option) => valueText(typeof option === "string" ? option : option.value) === input.default,
      )
    )
      return yield* new TaskError({
        message: `Default for '${input.id}' is not one of its options.`,
      });
    return yield* Prompt.Select({
      message: input.description,
      choices: input.options.map((option) => ({
        title: typeof option === "string" ? option : option.label,
        value: typeof option === "string" ? option : option.value,
        selected: (typeof option === "string" ? option : option.value) === input.default,
      })),
    });
  }
  const options = {
    message: input.description,
    default: input.default ?? "",
    validate: (value: string) =>
      Schema.decodeUnknownEffect(Schema.NonEmptyString)(value).pipe(
        Effect.mapError(() => "Enter a value."),
      ),
  };
  if (input.password) return Redacted.value(yield* Prompt.Password(options));
  return yield* Prompt.String(options);
});

export class TaskRunner extends Context.Service<
  TaskRunner,
  {
    readonly run: (options: {
      readonly choice: TaskChoice;
      readonly inputs: Record<string, string>;
      readonly cwd: string;
      readonly sources: ReadonlyArray<TaskSource>;
    }) => Effect.Effect<number, TaskError>;
  }
>()("vtask/TaskRunner") {
  static readonly layer = Layer.effect(
    TaskRunner,
    Effect.gen(function* () {
      const promptContext = yield* Effect.context<PromptServices>();
      const path = yield* Path.Path;
      const spawner = yield* ChildProcessSpawner.ChildProcessSpawner;
      const run = Effect.fn("vtask.TaskRunner.run")(
        function* (options: {
          choice: TaskChoice;
          inputs: Record<string, string>;
          cwd: string;
          sources: ReadonlyArray<TaskSource>;
        }) {
          const plan = yield* makePlan({ choice: options.choice, ancestors: [] });
          const values = new Map<string, string>();
          const collect = Effect.fn("vtask.collectInputs")(function* (
            node: TaskNode,
          ): Effect.fn.Return<
            void,
            TaskError | PlatformError.PlatformError | Terminal.QuitError,
            PromptServices
          > {
            for (const text of taskStrings(node.choice)) {
              for (const match of text.matchAll(/\$\{input:([^}]+)\}/g)) {
                const id = match[1];
                const key = `${node.choice.source.file}:${id}`;
                if (values.has(key)) continue;
                const inputs = (node.choice.source.document.inputs ?? []).filter(
                  (input) => input.id === id,
                );
                if (inputs.length !== 1)
                  return yield* new TaskError({
                    message: `Input '${id}' must be defined exactly once.`,
                  });
                const input = inputs[0];
                const override = options.inputs[id];
                const value = override ?? (yield* promptInput(input));
                if (
                  input.type === "pickString" &&
                  !input.options.some(
                    (option) => (typeof option === "string" ? option : option.value) === value,
                  )
                )
                  return yield* new TaskError({
                    message: `Value for '${id}' is not one of its options.`,
                  });
                if (value.length === 0)
                  return yield* new TaskError({ message: `Input '${id}' cannot be empty.` });
                values.set(key, value);
              }
            }
            for (const dependency of node.dependencies) yield* collect(dependency);
          });
          yield* collect(plan).pipe(Effect.provideContext(promptContext));
          const home = yield* Config.String("HOME");
          const substitute = Effect.fn("vtask.substitute")(function* (options_: {
            text: string;
            source: TaskSource;
          }) {
            let result = "";
            let offset = 0;
            for (const match of options_.text.matchAll(/\$\{([^}]+)\}/g)) {
              const variable = match[1];
              let value: string;
              if (variable.startsWith("input:"))
                value = values.get(`${options_.source.file}:${variable.slice(6)}`) ?? "";
              else if (variable.startsWith("env:"))
                value = yield* Config.String(variable.slice(4)).pipe(Config.withDefault(""));
              else if (variable === "workspaceFolder") value = options_.source.root;
              else if (variable === "workspaceFolderBasename")
                value = path.basename(options_.source.root);
              else if (variable === "cwd") value = options.cwd;
              else if (variable === "userHome") value = home;
              else if (variable === "pathSeparator" || variable === "/") value = path.sep;
              else if (variable.startsWith("workspaceFolder:")) {
                const source = options.sources.find((source) => source.name === variable.slice(16));
                if (source === undefined)
                  return yield* new TaskError({
                    message: `Unknown workspace folder '${variable.slice(16)}'.`,
                  });
                value = source.root;
              } else
                return yield* new TaskError({
                  message: `Variable '${match[0]}' needs VS Code editor state or is unsupported.`,
                });
              result += options_.text.slice(offset, match.index) + value;
              offset = match.index + match[0].length;
            }
            return result + options_.text.slice(offset);
          });
          const prepare = Effect.fn("vtask.prepare")(function* (
            node: TaskNode,
          ): Effect.fn.Return<PreparedTask, TaskError | Config.ConfigError> {
            const task = effectiveTask(node.choice);
            const resolve = (text: string) => substitute({ text, source: node.choice.source });
            const resolveValue = Effect.fn(function* (value: ShellValue) {
              const text = yield* resolve(valueText(value));
              return typeof value === "string" ? text : { ...value, value: text };
            });
            const dependencies: PreparedTask[] = [];
            for (const dependency of node.dependencies)
              dependencies.push(yield* prepare(dependency));
            if (task.command === undefined)
              return {
                label: task.label,
                parallel: task.dependsOrder !== "sequence",
                dependencies,
              };
            const command = yield* resolveValue(task.command);
            const args = yield* Effect.forEach(task.args ?? [], resolveValue);
            const cwd = path.resolve(
              node.choice.source.root,
              yield* resolve(task.options.cwd ?? node.choice.source.root),
            );
            const env = Object.fromEntries(
              yield* Effect.forEach(
                Object.entries(task.options.env),
                Effect.fn(function* (entry) {
                  return [entry[0], yield* resolve(entry[1])];
                }),
              ),
            );
            const settings = {
              cwd,
              env,
              extendEnv: true,
              stdin: "inherit",
              stdout: "inherit",
              stderr: "inherit",
            } satisfies ChildProcess.CommandOptions;
            let child: ChildProcess.Command;
            if (task.type === "process")
              child = ChildProcess.make(valueText(command), args.map(valueText), settings);
            else {
              const shell = task.options.shell;
              const executable = yield* resolve(shell?.executable ?? "/bin/sh");
              const shellArgs = yield* Effect.forEach(shell?.args ?? ["-c"], resolve);
              const line = [
                typeof command === "string" ? command : quote(command),
                ...args.map(quote),
              ].join(" ");
              child = ChildProcess.make(executable, [...shellArgs, line], settings);
            }
            return {
              label: task.label,
              command: child,
              parallel: task.dependsOrder !== "sequence",
              dependencies,
            };
          });
          const prepared = yield* prepare(plan);
          const completed = new Map<string, Effect.Effect<number, PlatformError.PlatformError>>();
          const execute = (
            node: PreparedTask,
          ): Effect.Effect<number, PlatformError.PlatformError> =>
            Effect.gen(function* () {
              const cached = completed.get(node.label);
              if (cached !== undefined) return yield* cached;
              const execution = yield* Effect.cached(
                Effect.gen(function* () {
                  if (node.parallel) {
                    const codes = yield* Effect.forEach(node.dependencies, execute, {
                      concurrency: "unbounded",
                    });
                    const failed = codes.find((code) => code !== 0);
                    if (failed !== undefined) return failed;
                  } else {
                    for (const dependency of node.dependencies) {
                      const code = yield* execute(dependency);
                      if (code !== 0) return code;
                    }
                  }
                  if (node.command === undefined) return 0;
                  yield* Console.log(`Running ${node.label}`);
                  return Number(yield* spawner.exitCode(node.command));
                }),
              );
              completed.set(node.label, execution);
              return yield* execution;
            });
          return yield* execute(prepared);
        },
        Effect.scoped,
        Effect.mapError((cause) => new TaskError({ message: cause.message })),
      );
      return TaskRunner.of({ run });
    }),
  );
}
