import assert from "node:assert/strict";
import { test } from "node:test";
import { NodeServices } from "@effect/platform-node";
import { Effect, FileSystem, Layer, Path, Scope, Stream } from "effect";
import { ChildProcess, ChildProcessSpawner } from "effect/process";
import { TaskCatalog } from "../src/task-catalog.ts";
import { decodeTasks } from "../src/task-schema.ts";

const main = new URL("../src/main.ts", import.meta.url).pathname;
const fixture = Effect.fn(function* (document: unknown) {
  const fs = yield* FileSystem.FileSystem;
  const path = yield* Path.Path;
  const root = yield* fs.makeTempDirectoryScoped({ prefix: "vtask-test-" });
  yield* fs.makeDirectory(path.join(root, ".vscode"));
  yield* fs.writeFileString(path.join(root, ".vscode", "tasks.json"), JSON.stringify(document));
  return root;
});
const cli = Effect.fn(function* (options: { cwd: string; args: ReadonlyArray<string> }) {
  const spawner = yield* ChildProcessSpawner.ChildProcessSpawner;
  const child = yield* spawner.spawn(
    ChildProcess.make(
      process.env.VTASK_BINARY ?? process.execPath,
      process.env.VTASK_BINARY === undefined
        ? ["--experimental-strip-types", main, ...options.args]
        : options.args,
      {
        cwd: options.cwd,
      },
    ),
  );
  const [output, code] = yield* Effect.all(
    [
      child.all.pipe(
        Stream.decodeText(),
        Stream.runFold(
          () => "",
          (text, chunk) => text + chunk,
        ),
      ),
      child.exitCode,
    ],
    { concurrency: "unbounded" },
  );
  return { output, code: Number(code) };
});
const run = <A, E>(
  effect: Effect.Effect<
    A,
    E,
    FileSystem.FileSystem | Path.Path | ChildProcessSpawner.ChildProcessSpawner | Scope.Scope
  >,
) => Effect.runPromise(effect.pipe(Effect.scoped, Effect.provide(NodeServices.layer)));

test("imports the published schema and parses JSONC with comments and trailing commas", async () => {
  const document = await Effect.runPromise(
    decodeTasks('{ // tasks\n "version": "2.0.0", "tasks": [{"label":"ok","command":"echo",}], }'),
  );
  assert.equal(document.tasks[0].label, "ok");
  await assert.rejects(
    () => Effect.runPromise(decodeTasks('{"version":"1.0.0","tasks":[]}')),
    /Invalid VS Code task file/,
  );
  await assert.rejects(
    () => Effect.runPromise(decodeTasks('{"version":"2.0.0", "tasks": [}')),
    /offset/,
  );
});

test("discovers tasks from a nested directory and uses the owning workspace as cwd", async () => {
  await run(
    Effect.gen(function* () {
      const fs = yield* FileSystem.FileSystem;
      const root = yield* fixture({
        version: "2.0.0",
        tasks: [
          {
            label: "where",
            type: "process",
            command: process.execPath,
            problemMatcher: [],
            args: ["-e", "console.log(process.cwd())"],
          },
        ],
      });
      yield* fs.makeDirectory(`${root}/nested/deep`, { recursive: true });
      const result = yield* cli({ cwd: `${root}/nested/deep`, args: ["where"] });
      assert.equal(result.code, 0, result.output);
      assert.match(result.output, new RegExp(`${root}\n`));
    }),
  );
});

test("validates upstream problem matcher names, objects, arrays and platform overrides", async () => {
  const inline = {
    owner: "custom",
    fileLocation: ["relative", "${workspaceFolder}"],
    pattern: { regexp: "^(.*):(\\d+): (.*)$", file: 1, line: 2, message: 3 },
  };
  const watching = {
    base: "$tsc-watch",
    background: {
      activeOnStart: true,
      beginsPattern: { regexp: "start" },
      endsPattern: "end",
    },
  };
  const document = (problemMatcher: unknown) =>
    JSON.stringify({
      version: "2.0.0",
      problemMatcher,
      tasks: [
        {
          label: "matcher",
          type: "shell",
          command: "true",
          problemMatcher,
          linux: { problemMatcher },
          osx: { problemMatcher },
          windows: { problemMatcher },
        },
      ],
    });
  for (const matcher of [
    [],
    "$tsc",
    "$extension-matcher",
    ["$tsc"],
    inline,
    watching,
    ["$tsc", inline],
  ]) {
    const decoded = await Effect.runPromise(decodeTasks(document(matcher)));
    assert.equal(decoded.tasks[0].label, "matcher");
  }
  for (const matcher of [
    null,
    42,
    [42],
    { owner: 42 },
    { pattern: { regexp: 42 } },
    { fileLocation: ["relative", 42] },
  ]) {
    await assert.rejects(
      () => Effect.runPromise(decodeTasks(document(matcher))),
      /Invalid VS Code task file/,
    );
  }
});

test("resolves repeated inputs, env, args and cwd without shell interpretation for process tasks", async () => {
  await run(
    Effect.gen(function* () {
      const fs = yield* FileSystem.FileSystem;
      const root = yield* fixture({
        version: "2.0.0",
        inputs: [{ id: "name", type: "promptString", description: "Name", default: "world" }],
        tasks: [
          {
            label: "capture",
            type: "process",
            command: process.execPath,
            args: [
              "-e",
              "console.log(JSON.stringify({args:process.argv.slice(1),env:process.env.VTASK_VALUE,cwd:process.cwd()}))",
              "${input:name}",
              "${input:name}",
            ],
            options: { cwd: "${workspaceFolder}/nested", env: { VTASK_VALUE: "${input:name}" } },
          },
        ],
      });
      yield* fs.makeDirectory(`${root}/nested`);
      const value = "two words; $(echo injected) ' quoted ${env:HOME}";
      const result = yield* cli({ cwd: root, args: ["capture", "--input", `name=${value}`] });
      assert.equal(result.code, 0, result.output);
      const captured = JSON.parse(result.output.trim().split("\n").at(-1) ?? "null");
      assert.deepEqual(captured, { args: [value, value], env: value, cwd: `${root}/nested` });
    }),
  );
});

test("quotes shell arguments safely and respects Linux platform overrides", async () => {
  await run(
    Effect.gen(function* () {
      const root = yield* fixture({
        version: "2.0.0",
        tasks: [
          {
            label: "echo",
            type: "shell",
            command: "false",
            linux: { command: "printf '%s\\n'", args: ["two words; $(echo injected) ' quote"] },
          },
        ],
      });
      const result = yield* cli({ cwd: root, args: ["echo"] });
      assert.equal(result.code, 0, result.output);
      assert.ok(result.output.includes("two words; $(echo injected) ' quote"));
    }),
  );
});

test("prepares every dependency before any command runs", async () => {
  await run(
    Effect.gen(function* () {
      const fs = yield* FileSystem.FileSystem;
      const root = yield* fixture({
        version: "2.0.0",
        tasks: [
          { label: "write", type: "shell", command: "touch should-not-exist" },
          { label: "invalid", type: "process", command: "echo", args: ["${command:editorOnly}"] },
          { label: "all", dependsOn: ["write", "invalid"], dependsOrder: "sequence" },
        ],
      });
      const result = yield* cli({ cwd: root, args: ["all"] });
      assert.equal(result.code, 1, result.output);
      assert.match(result.output, /unsupported/);
      assert.equal(yield* fs.exists(`${root}/should-not-exist`), false);
    }),
  );
});

test("stops sequential dependencies after failure and propagates the exit code", async () => {
  await run(
    Effect.gen(function* () {
      const fs = yield* FileSystem.FileSystem;
      const root = yield* fixture({
        version: "2.0.0",
        tasks: [
          {
            label: "fail",
            type: "process",
            command: process.execPath,
            args: ["-e", "process.exit(7)"],
          },
          { label: "later", type: "shell", command: "touch should-not-exist" },
          { label: "all", dependsOn: ["fail", "later"], dependsOrder: "sequence" },
        ],
      });
      const result = yield* cli({ cwd: root, args: ["all"] });
      assert.equal(result.code, 7, result.output);
      assert.equal(yield* fs.exists(`${root}/should-not-exist`), false);
    }),
  );
});

test("runs a shared dependency only once", async () => {
  await run(
    Effect.gen(function* () {
      const fs = yield* FileSystem.FileSystem;
      const root = yield* fixture({
        version: "2.0.0",
        tasks: [
          { label: "once", type: "shell", command: "echo once >> count" },
          { label: "a", dependsOn: "once" },
          { label: "b", dependsOn: "once" },
          { label: "all", dependsOn: ["a", "b"] },
        ],
      });
      const result = yield* cli({ cwd: root, args: ["all"] });
      assert.equal(result.code, 0, result.output);
      assert.equal(yield* fs.readFileString(`${root}/count`), "once\n");
    }),
  );
});

test("detects dependency cycles, unsupported task types and invalid pick values", async () => {
  for (const options of [
    {
      tasks: [
        { label: "a", dependsOn: "b" },
        { label: "b", dependsOn: "a" },
      ],
      args: ["a"],
      message: /Cyclic/,
    },
    {
      tasks: [{ label: "a", type: "npm", command: "echo" }],
      args: ["a"],
      message: /Invalid VS Code task file/,
    },
    {
      tasks: [{ label: "a", type: "process", command: "echo", args: ["${input:mode}"] }],
      args: ["a", "--input", "mode=invalid"],
      message: /not one of its options/,
    },
  ]) {
    await run(
      Effect.gen(function* () {
        const root = yield* fixture({
          version: "2.0.0",
          tasks: options.tasks,
          inputs: [
            { id: "mode", type: "pickString", description: "Mode", options: ["dev", "prod"] },
          ],
        });
        const result = yield* cli({ cwd: root, args: options.args });
        assert.equal(result.code, 1, result.output);
        assert.match(result.output, options.message);
      }),
    );
  }
});

test("loads workspace-level tasks and folder tasks with their own cwd", async () => {
  const services = TaskCatalog.layer.pipe(Layer.provideMerge(NodeServices.layer));
  await Effect.runPromise(
    Effect.gen(function* () {
      const fs = yield* FileSystem.FileSystem;
      const root = yield* fs.makeTempDirectoryScoped({ prefix: "vtask-workspace-" });
      yield* fs.makeDirectory(`${root}/app/.vscode`, { recursive: true });
      yield* fs.writeFileString(
        `${root}/app/.vscode/tasks.json`,
        '{"version":"2.0.0","tasks":[{"label":"folder","command":"echo"}]}',
      );
      yield* fs.writeFileString(
        `${root}/project.code-workspace`,
        '{"folders":[{"name":"frontend","path":"app"}],"tasks":{"version":"2.0.0","tasks":[{"label":"workspace","command":"echo"}]}}',
      );
      const catalog = yield* TaskCatalog;
      const sources = yield* catalog.discover({ cwd: root });
      assert.deepEqual(
        sources.map((source) => [source.name, source.root]),
        [
          ["project.code-workspace", root],
          ["frontend", `${root}/app`],
        ],
      );
    }).pipe(Effect.scoped, Effect.provide(services)),
  );
});
