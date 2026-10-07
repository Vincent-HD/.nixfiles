import { Config, Context, Effect, FileSystem, Layer, Path, Schema } from "effect";
import { decodeTasks, parseJsonc, TaskError, type TaskDocument } from "./task-schema.ts";

export interface TaskSource {
  readonly file: string;
  readonly root: string;
  readonly name: string;
  readonly document: TaskDocument;
}
const workspaceSchema = Schema.Struct({
  folders: Schema.optional(
    Schema.Array(Schema.Struct({ path: Schema.String, name: Schema.optional(Schema.String) })),
  ),
  tasks: Schema.optional(Schema.Unknown),
});

export class TaskCatalog extends Context.Service<
  TaskCatalog,
  {
    readonly discover: (options: {
      readonly cwd: string;
      readonly file?: string;
    }) => Effect.Effect<ReadonlyArray<TaskSource>, TaskError>;
  }
>()("vtask/TaskCatalog") {
  static readonly layer = Layer.effect(
    TaskCatalog,
    Effect.gen(function* () {
      const fs = yield* FileSystem.FileSystem;
      const path = yield* Path.Path;
      const load = Effect.fn("vtask.TaskCatalog.load")(function* (options: {
        file: string;
        root: string;
        name?: string;
      }) {
        const text = yield* fs.readFileString(options.file);
        const document = yield* decodeTasks(text);
        return {
          file: options.file,
          root: options.root,
          name: options.name ?? path.basename(options.root),
          document,
        };
      });
      const loadWorkspace = Effect.fn("vtask.TaskCatalog.loadWorkspace")(function* (file: string) {
        const root = path.dirname(file);
        const raw = yield* parseJsonc(yield* fs.readFileString(file));
        const workspace = yield* Schema.decodeUnknownEffect(workspaceSchema)(raw);
        const sources: TaskSource[] = [];
        if (workspace.tasks !== undefined) {
          sources.push({
            file,
            root,
            name: path.basename(file),
            document: yield* decodeTasks(JSON.stringify(workspace.tasks)),
          });
        }
        for (const folder of workspace.folders ?? []) {
          const folderRoot = path.resolve(root, folder.path);
          const taskFile = path.join(folderRoot, ".vscode", "tasks.json");
          if (yield* fs.exists(taskFile)) {
            sources.push(yield* load({ file: taskFile, root: folderRoot, name: folder.name }));
          }
        }
        return sources;
      });
      const discover = Effect.fn("vtask.TaskCatalog.discover")(
        function* (options: { cwd: string; file?: string }) {
          if (options.file !== undefined) {
            const file = path.resolve(options.cwd, options.file);
            if (file.endsWith(".code-workspace")) return yield* loadWorkspace(file);
            const directory = path.dirname(file);
            const root =
              path.basename(directory) === ".vscode" ? path.dirname(directory) : directory;
            return [yield* load({ file, root })];
          }
          let directory = path.resolve(options.cwd);
          while (true) {
            const sources: TaskSource[] = [];
            const file = path.join(directory, ".vscode", "tasks.json");
            if (yield* fs.exists(file)) sources.push(yield* load({ file, root: directory }));
            const files = (yield* fs.readDirectory(directory))
              .filter((name) => name.endsWith(".code-workspace"))
              .sort();
            for (const workspace of files)
              sources.push(...(yield* loadWorkspace(path.join(directory, workspace))));
            if (sources.length > 0) {
              return sources.filter(
                (source, index) =>
                  sources.findIndex(
                    (candidate) => candidate.file === source.file && candidate.root === source.root,
                  ) === index,
              );
            }
            const parent = path.dirname(directory);
            if (parent === directory) break;
            directory = parent;
          }
          const home = yield* Config.String("HOME");
          const xdg = yield* Config.String("XDG_CONFIG_HOME").pipe(
            Config.withDefault(path.join(home, ".config")),
          );
          const globalFile =
            process.platform === "darwin"
              ? path.join(home, "Library", "Application Support", "Code", "User", "tasks.json")
              : path.join(xdg, "Code", "User", "tasks.json");
          if (yield* fs.exists(globalFile))
            return [yield* load({ file: globalFile, root: options.cwd, name: "User tasks" })];
          return yield* new TaskError({
            message: `No .vscode/tasks.json, .code-workspace tasks, or VS Code user tasks found from ${options.cwd}. Use --file to choose a file.`,
          });
        },
        Effect.mapError((cause) => new TaskError({ message: cause.message })),
      );
      return TaskCatalog.of({ discover });
    }),
  );
}
