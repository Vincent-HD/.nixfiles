# Native compiler probes

Tested on x86_64 NixOS, Node 24.11.1, clang 21.1.8, with the published npm
packages `scriptc@0.2.4`, `@scriptc/compiler@0.2.4` and
`@perryts/perry@0.5.1520`. Effect 4.0.0 and 4.0.1 were tested.

The native scriptc compiler and its Node-hosted API behave differently. It is
incorrect to conclude that scriptc has no Effect support: the Node-hosted API
compiles and runs the core probe successfully. The actual CLI platform probe
is the failing compatibility gate.

## Core probe

```ts
import { Effect } from "effect";
Effect.runPromise(
  Effect.gen(function* () {
    yield* Effect.log("hello");
  }),
);
```

Native CLI:

```sh
scriptc build core.ts --npm-static effect --optimization dev -o core
```

Result with 4.0.0 and 4.0.1: `SC3004: null is not representable in the target
union (a value narrowed or asserted past it still held it)`.

Node-hosted API:

```ts
import { compile } from "@scriptc/compiler";
const result = await compile("core.ts", {
  outPath: "core",
  outDir: "output",
  backend: "llvm",
  optimization: "dev",
  npmStatic: ["effect"],
});
console.log(result);
```

Result: compile succeeds; binary prints `hello` through Effect's logger.

Perry:

```sh
perry compile core.ts -o core-perry
./core-perry
```

Result: compile succeeds (63.3 MB binary); runtime fails with
`RangeError: Maximum BigInt size exceeded`.

## Platform CLI probe

```ts
import * as NodeRuntime from "@effect/platform-node/NodeRuntime";
import * as NodeServices from "@effect/platform-node/NodeServices";
import { Effect, FileSystem } from "effect";
import { Command } from "effect/cli";
import { ChildProcess, ChildProcessSpawner } from "effect/process";

Command.make("probe", {}, () =>
  Effect.gen(function* () {
    const fs = yield* FileSystem.FileSystem;
    yield* fs.readDirectory(".");
    const spawner = yield* ChildProcessSpawner.ChildProcessSpawner;
    const result = yield* spawner.string(ChildProcess.make("echo", ["effect works"]));
    yield* Effect.log(result);
  }),
).pipe(Command.run({ version: "0.1.0" }), Effect.provide(NodeServices.layer), NodeRuntime.runMain);
```

Compile using the Node-hosted API with:

```ts
npmStatic: ["effect", "@effect/platform-node", "@effect/platform-node-shared", "undici"];
```

Compilation succeeds with direct platform subpath imports. The executable
fails for a normal run, `--help`, and `--version`:

```text
ERROR (#1): TypeError: expected boolean at $, got undefined
```

The original top-level `@effect/platform-node` barrel import encounters SC2013
instead. Direct imports therefore fix one compiler limitation but do not solve
the runtime problem.

In dynamic mode, an entry importing a package containing the same idiomatic
Effect implementation successfully builds, but runtime initialization fails:

```text
Uncaught ReferenceError: Intl is not defined
```

Effect CLI initializes `Intl.Segmenter` for terminal text handling. No custom
terminal or Intl implementations were introduced to circumvent the framework.

## Full vtask source

The investigation invoked the Node-hosted API on the full source. In addition to the runtime failure
above, the source encounters native representation limits on task types,
schema JSON imports, and recursive Effect functions, and requires dynamic
execution for the `jsonc-parser` package. Changing these structures alone would
not fix the already reproduced platform-probe runtime failure.

The agreed release now uses Bun 1.4.2 to compile the Effect source. Its Linux
executable passes the same integration tests, lint, type checking, and formatting. Interactive picker, text defaults, option defaults and masked
password entry were also exercised through a real PTY.

## Upstream references

- [Scriptc README](https://github.com/vercel-labs/scriptc)
- [Effect 4 harness](https://github.com/vercel-labs/scriptc/blob/main/tests/harness/effect4.test.ts)
- [Effect 4 test dependencies](https://github.com/vercel-labs/scriptc/blob/main/tests/fixtures/effect4/package.json)
- [Perry](https://github.com/PerryTS/perry)

The upstream Effect harness runs the compiler source through Node. That is why
the Node-hosted API was tested separately from the published native CLI.
