import * as NodeRuntime from "@effect/platform-node/NodeRuntime";
import * as NodeServices from "@effect/platform-node/NodeServices";
import { Console, Crypto, Effect, FileSystem, Path, Schema } from "effect";
import { Command, Flag } from "effect/cli";
import { ChildProcess, ChildProcessSpawner } from "effect/process";
import manifest from "../package.json" with { type: "json" };

const Artifact = Schema.Struct({ sha256: Schema.String, size: Schema.Int });
const ArtifactManifest = Schema.Struct({
  version: Schema.String,
  sourceHash: Schema.String,
  compilerVersion: Schema.String,
  binaries: Schema.Record(Schema.String, Artifact),
});
const targets = {
  "x86_64-linux": "bun-linux-x64-baseline",
  "aarch64-darwin": "bun-darwin-arm64",
};
class BuildError extends Schema.TaggedError<BuildError>()("vtask/BuildError", {
  message: Schema.String,
}) {}
const command = Command.make(
  "build-vtask",
  {
    all: Flag.Boolean("all").pipe(Flag.withDefault(false)),
    native: Flag.Boolean("native").pipe(Flag.withDefault(false)),
    release: Flag.Boolean("release").pipe(Flag.withDefault(false)),
    target: Flag.Literals("target", ["x86_64-linux", "aarch64-darwin"]).pipe(
      Flag.withDefault(process.platform === "darwin" ? "aarch64-darwin" : "x86_64-linux"),
    ),
  },
  Effect.fn("vtask.build")(function* (options) {
    const hostSystem =
      process.platform === "darwin" && process.arch === "arm64"
        ? "aarch64-darwin"
        : process.platform === "linux" && process.arch === "x64"
          ? "x86_64-linux"
          : undefined;
    if (options.native && (options.all || options.target !== hostSystem))
      return yield* new BuildError({
        message: "A native build must target the current configured platform.",
      });
    const fs = yield* FileSystem.FileSystem;
    const path = yield* Path.Path;
    const crypto = yield* Crypto.Crypto;
    const spawner = yield* ChildProcessSpawner.ChildProcessSpawner;
    const root = yield* path.fromFileUrl(new URL("../", import.meta.url));
    const digest = Effect.fn(function* (bytes: Uint8Array) {
      return Schema.encodeSync(Schema.Uint8ArrayFromHex)(yield* crypto.digest("SHA-256", bytes));
    });
    const sources = [
      "package.json",
      "pnpm-lock.yaml",
      "pnpm-workspace.yaml",
      "assets/tasks.schema.json",
      ...(yield* fs.readDirectory(path.join(root, "src")))
        .filter((name) => name.endsWith(".ts"))
        .map((name) => `src/${name}`),
    ].sort();
    let fingerprint = "";
    for (const file of sources)
      fingerprint += `${file}\n${yield* digest(yield* fs.readFile(path.join(root, file)))}\n`;
    const sourceHash = yield* digest(new TextEncoder().encode(fingerprint));
    const compilerVersion = (yield* spawner.string(ChildProcess.make("bun", ["--version"]))).trim();
    const output = path.join(root, options.release ? "bin" : "dist");
    yield* fs.makeDirectory(output, { recursive: true });
    const manifestFile = path.join(output, "manifest.json");
    let binaries: Record<string, typeof Artifact.Type> = {};
    if (yield* fs.exists(manifestFile)) {
      const previous = yield* Schema.decodeUnknownEffect(Schema.fromJsonString(ArtifactManifest))(
        yield* fs.readFileString(manifestFile),
      );
      if (previous.sourceHash === sourceHash && previous.version === manifest.version)
        binaries = { ...previous.binaries };
    }
    const systems: ReadonlyArray<keyof typeof targets> = options.all
      ? ["x86_64-linux", "aarch64-darwin"]
      : [options.target];
    for (const system of systems) {
      const directory = path.join(output, system);
      yield* fs.makeDirectory(directory, { recursive: true });
      const binary = path.join(directory, "vtask");
      const code = yield* spawner.exitCode(
        ChildProcess.make(
          "bun",
          [
            "build",
            "--compile",
            "--minify",
            "--no-compile-autoload-dotenv",
            "--no-compile-autoload-bunfig",
            ...(options.native ? [] : ["--target", targets[system]]),
            "--outfile",
            binary,
            path.join(root, "src", "main.ts"),
          ],
          { cwd: root, stdin: "inherit", stdout: "inherit", stderr: "inherit" },
        ),
      );
      if (Number(code) !== 0)
        return yield* new BuildError({ message: `Bun compilation failed for ${system}.` });
      const bytes = yield* fs.readFile(binary);
      binaries[system] = { sha256: yield* digest(bytes), size: bytes.length };
      yield* Console.log(
        `${system}: ${bytes.length} bytes (${(bytes.length / 1024 / 1024).toFixed(2)} MiB)`,
      );
    }
    yield* fs.writeFileString(
      manifestFile,
      `${JSON.stringify({ version: manifest.version, sourceHash, compilerVersion, binaries }, null, 2)}\n`,
    );
  }),
);
command.pipe(
  Command.run({ version: manifest.version }),
  Effect.provide(NodeServices.layer),
  NodeRuntime.runMain,
);
