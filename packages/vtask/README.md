# vtask 0.1.1

An Effect 4 CLI for running built-in VS Code shell/process tasks from a terminal.

```sh
pnpm install --frozen-lockfile
pnpm dev                 # searchable task picker
pnpm dev --list
pnpm dev build
pnpm dev --file project.code-workspace
pnpm dev build --input target=production
```

Discovery walks upward from the invocation directory and stops at the nearest
level containing `.vscode/tasks.json` or `.code-workspace` tasks. A workspace
file contributes its own tasks and each folder's `.vscode/tasks.json`.
Otherwise, the normal VS Code user `tasks.json` is tried under
`$XDG_CONFIG_HOME/Code/User` on Linux or
`~/Library/Application Support/Code/User` on macOS. `--file` selects an explicit
file, including another editor's profile. Global user tasks execute relative to
the invocation directory. Folder tasks execute relative to their owning folder;
`options.cwd` overrides that directory. Ambiguous labels require `folder:label`.

Task files accept comments and trailing commas through Microsoft's
`jsonc-parser`. Validation uses Microsoft's vendored schema, imported by Effect,
and a typed Effect execution projection. See `assets/README.md` for provenance
and the importer's precise limitations.

The picker, free text, passwords, and option selection use Effect's `Prompt`.
Referenced inputs are requested once, including inputs in dependencies. Text
prompts display defaults; choice prompts preselect defaults. `--input id=value`
can supply values for noninteractive execution. Command inputs require that
explicit override because they depend on VS Code's extension host.

Supported variables: `${input:id}`, `${env:NAME}`, `${workspaceFolder}`,
`${workspaceFolder:name}`, `${workspaceFolderBasename}`, `${cwd}`,
`${userHome}`, `${pathSeparator}`, `${/}`. Substitution is a single pass: an
input value containing another variable is treated as literal text. Editor
variables such as `${file}`, `${config:...}`, and `${command:...}` fail clearly.

Platform overrides, task environment, shell executable/arguments, quoted
arguments, sequential/parallel dependencies, composite tasks and exit codes are
supported. Shared dependencies execute once. All inputs and commands in the
whole plan are resolved before any subprocess starts. A failed sequential
dependency prevents later dependencies and the parent command from running.
Child processes inherit the terminal and are managed by Effect's scoped
`ChildProcessSpawner`. Shell quoting targets POSIX shells on Linux/macOS.

Background dependencies that need problem-matcher readiness, extension task
providers (npm, etc.), dependency identifiers as objects, and editor problem
reporting are outside this release. A selected background task runs in the
foreground until it exits or is interrupted. Hidden tasks can still be invoked
by label; they are omitted from the picker.

## Checks

```sh
pnpm test
pnpm lint
pnpm typecheck
pnpm fmt
```

## Compiled releases and Nix

Bun compiles the Effect implementation into a standalone executable. No Node,
Bun installation, node_modules, or TypeScript source is required at runtime.
Release 0.1.1 uses Bun 1.4.2:

- Linux x86_64 baseline: 81,774,048 bytes (77.99 MiB).
- macOS Apple Silicon: 62,689,266 bytes (59.79 MiB).

The Linux binary passed the integration tests and real-terminal prompt checks.
The macOS binary is cross-compiled; native macOS execution still needs checking.
The runtime makes these binaries larger than an AOT-only compiler's output.
See [COMPILER_INVESTIGATION.md](COMPILER_INVESTIGATION.md) for the reproduced
scriptc and Perry failures that led to the agreed Bun compilation path.

`nix run .#vtask` invokes the packaged executable. A normal configuration
switch installs it through the shared command-line module.

`bin/<system>/vtask` is tracked by Git LFS. `bin/manifest.json` records the
version, source fingerprint, compiler version, executable checksums, and sizes.
With LFS hydrated, matching source, and the same Nix-pinned Bun version, Nix
packages the checked-in executable directly. Changed source, changed Bun,
a missing binary, or an LFS pointer triggers an offline source build instead.
The source build embeds the current Nix-managed Bun executable, avoiding Bun's
network download for an explicit cross-compilation target inside the sandbox.

`nix build .#vtask-source` always exercises that source-build path. Its
production dependencies come from the locked, fixed-output pnpm dependency
closure. Linux executables receive Nix's ELF interpreter fixup. Switches never
regenerate the checked-in release artifacts.

To regenerate release artifacts with the pinned toolchain:

```sh
nix develop .#vtask
pnpm --dir packages/vtask install --frozen-lockfile
pnpm --dir packages/vtask release
VTASK_BINARY="$PWD/packages/vtask/bin/x86_64-linux/vtask" pnpm --dir packages/vtask test
nix build .#vtask
nix build .#vtask-source
git add packages/vtask/bin
```

Cross-compilation may download the corresponding official Bun runtime. Git LFS
objects are stored locally until published through a normal LFS-enabled push.
Both source and compiled artifacts belong in the same release revision.

Use SemVer for releases: `0.1.0` is the initial version, patch releases fix
behavior, minor releases extend the supported task format, and a `1.0.0` release
commits to a stable interface. Never change the version of an existing binary
without rebuilding and validating it.
