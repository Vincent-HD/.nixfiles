import { $ } from "bun";
import { mkdtemp } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { parseArgs } from "util";

type Command = string[];

type ValidationEntry = {
  name: string;
  command: Command;
  systems?: string[];
};

type Config = {
  holds: Record<string, string>;
  validations: Record<string, ValidationEntry[]>;
};

type Discovery = {
  updater: string;
  allPackages: string[];
  packages: Record<string, { command: Command | null }>;
};

type Entry = {
  name: string;
  kind: "input" | "package";
  status: "update" | "held" | "pinned";
  reason?: string;
  command?: Command;
};

type Result = {
  name: string;
  status: "ok" | "failed" | "skipped";
  detail?: string;
};

const usage = `Usage: nix run .#update-pins -- [options]

Updates every flake input and every flake package that has a package-updater
passthru.updateScript, except the holds listed in scripts/update-pins.json.

Options:
  --dry-run              Print the selected commands without running them.
  --inputs               Select every flake input.
  --packages             Select every flake package.
  --only <a,b>           Select the named inputs or packages (combines with the above).
  --skip <a,b>           Skip the named inputs or packages.
  --include-held         Also update held entries selected with --only.
  --jobs <n>             Package updates to run in parallel (default 4).
  --validate <name>      Run a validation set after successful updates.
  --list                 List inputs, packages, holds, and validation sets.
  --check                Fail when a package or hold drifts from the update conventions.
  -h, --help             Show this help.
`;

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value);

const isStringArray = (value: unknown): value is string[] =>
  Array.isArray(value) && value.every((item) => typeof item === "string");

const fail = (message: string): never => {
  throw new Error(message);
};

const splitNames = (values: string[]): string[] =>
  values.flatMap((value) => value.split(",")).map((name) => name.trim()).filter((name) => name.length > 0);

const parseOptions = (argv: string[]) => {
  const { values } = parseArgs({
    args: argv,
    options: {
      "dry-run": { type: "boolean", default: false },
      inputs: { type: "boolean", default: false },
      packages: { type: "boolean", default: false },
      only: { type: "string", multiple: true, default: [] },
      skip: { type: "string", multiple: true, default: [] },
      "include-held": { type: "boolean", default: false },
      jobs: { type: "string", default: "4" },
      validate: { type: "string" },
      list: { type: "boolean", default: false },
      check: { type: "boolean", default: false },
      help: { type: "boolean", short: "h", default: false },
    },
    strict: true,
    allowPositionals: false,
  });
  const jobs = Number.parseInt(values.jobs, 10);
  if (!Number.isInteger(jobs) || jobs < 1) fail("--jobs must be a positive integer");
  const only = splitNames(values.only);
  return {
    help: values.help,
    dryRun: values["dry-run"],
    only: only.length > 0 ? new Set(only) : null,
    inputs: values.inputs,
    packages: values.packages,
    skip: new Set(splitNames(values.skip)),
    includeHeld: values["include-held"],
    jobs,
    validate: values.validate ?? null,
    list: values.list,
    check: values.check,
  };
};

const repoRoot = async (): Promise<string> =>
  Bun.env.UPDATE_PINS_REPO_ROOT || (await $`git rev-parse --show-toplevel`.text()).trim();

const validateCommand = (value: unknown, label: string): Command =>
  isStringArray(value) && value.length > 0 ? value : fail(`${label}.command must be a non-empty array of strings`);

const loadConfig = async (root: string): Promise<Config> => {
  const value: unknown = await Bun.file(join(root, "scripts", "update-pins.json")).json();
  if (!isRecord(value)) fail("registry must be a JSON object");
  const record = isRecord(value) ? value : {};
  const unknownKeys = Object.keys(record).filter((key) => key !== "holds" && key !== "validations");
  if (unknownKeys.length > 0) fail(`unknown registry keys: ${unknownKeys.join(", ")}`);

  const holds = record.holds ?? {};
  if (!isRecord(holds)) fail("holds must map names to reasons");
  for (const [name, reason] of Object.entries(isRecord(holds) ? holds : {})) {
    if (typeof reason !== "string" || reason.trim() === "") fail(`holds.${name} must be a non-empty reason`);
  }

  const validations: Record<string, ValidationEntry[]> = {};
  const rawValidations = record.validations ?? {};
  if (!isRecord(rawValidations)) fail("validations must map set names to arrays");
  for (const [setName, entries] of Object.entries(isRecord(rawValidations) ? rawValidations : {})) {
    if (!Array.isArray(entries)) fail(`validations.${setName} must be an array`);
    validations[setName] = (Array.isArray(entries) ? entries : []).map((entry: unknown, index) => {
      const label = `validations.${setName}[${index}]`;
      if (!isRecord(entry) || typeof entry.name !== "string") fail(`${label} needs a name`);
      const candidate = isRecord(entry) ? entry : {};
      if (Object.hasOwn(candidate, "systems") && !isStringArray(candidate.systems)) {
        fail(`${label}.systems must be an array of strings`);
      }
      return {
        name: String(candidate.name),
        command: validateCommand(candidate.command, label),
        ...(isStringArray(candidate.systems) ? { systems: candidate.systems } : {}),
      };
    });
  }

  return { holds: Object.fromEntries(Object.entries(isRecord(holds) ? holds : {}).map(([key, reason]) => [key, String(reason)])), validations };
};

const currentSystem = async (): Promise<string> =>
  (await $`nix eval --impure --raw --expr builtins.currentSystem`.quiet().text()).trim();

const discoverPackages = async (root: string, system: string): Promise<Discovery> => {
  const apply = `packages: {
    updater = "\${packages.${system}.package-updater}/bin/package-updater";
    allPackages = builtins.attrNames (builtins.foldl' (all: system: all // packages.\${system}) { } (builtins.attrNames packages));
    packages = builtins.mapAttrs (_: package: {
      command = if package ? updateScript then (package.updateScript.command or package.updateScript) else null;
    }) packages.${system};
  }`;
  const value: unknown = JSON.parse(await $`nix eval --json .#packages --apply ${apply}`.cwd(root).quiet().text());
  if (!isRecord(value) || typeof value.updater !== "string" || !isStringArray(value.allPackages) || !isRecord(value.packages)) {
    fail("Unexpected package discovery output");
  }
  const record = isRecord(value) ? value : {};
  const packages: Discovery["packages"] = {};
  for (const [name, info] of Object.entries(isRecord(record.packages) ? record.packages : {})) {
    const command = isRecord(info) && isStringArray(info.command) ? info.command : null;
    packages[name] = { command };
  }
  return { updater: String(record.updater), allPackages: isStringArray(record.allPackages) ? record.allPackages : [], packages };
};

// Inputs whose flake.nix URL names an exact commit cannot move with `nix flake update`.
const readInputs = async (root: string): Promise<{ name: string; pinnedRevision: boolean }[]> => {
  const lock: unknown = await Bun.file(join(root, "flake.lock")).json();
  const nodes = isRecord(lock) && isRecord(lock.nodes) ? lock.nodes : {};
  const rootNode = isRecord(nodes.root) && isRecord(nodes.root.inputs) ? nodes.root.inputs : {};
  return Object.entries(rootNode)
    .filter((entry): entry is [string, string] => typeof entry[1] === "string")
    .map(([name, key]) => {
      const node = nodes[key];
      const original = isRecord(node) && isRecord(node.original) ? node.original : {};
      return { name, pinnedRevision: typeof original.rev === "string" };
    });
};

const buildEntries = ({
  config,
  discovery,
  inputs,
}: {
  config: Config;
  discovery: Discovery;
  inputs: { name: string; pinnedRevision: boolean }[];
}): Entry[] => {
  const inputEntries: Entry[] = inputs.map((input) => {
    if (config.holds[input.name] !== undefined) {
      return { name: input.name, kind: "input", status: "held", reason: config.holds[input.name] };
    }
    if (input.pinnedRevision) {
      return { name: input.name, kind: "input", status: "pinned", reason: "pinned to a commit in flake.nix" };
    }
    return { name: input.name, kind: "input", status: "update" };
  });
  const packageEntries: Entry[] = Object.entries(discovery.packages).map(([name, info]) => {
    if (config.holds[name] !== undefined) return { name, kind: "package", status: "held", reason: config.holds[name] };
    return { name, kind: "package", status: "update", ...(info.command === null ? {} : { command: info.command }) };
  });
  return [...inputEntries, ...packageEntries].sort((left, right) => left.name.localeCompare(right.name));
};

// Every package must use the shared updater or carry a documented hold, so nothing silently stops updating.
const findDrift = ({
  config,
  discovery,
  inputs,
  entries,
}: {
  config: Config;
  discovery: Discovery;
  inputs: { name: string }[];
  entries: Entry[];
}): string[] => {
  const problems: string[] = [];
  const known = new Set([...inputs.map((input) => input.name), ...discovery.allPackages]);
  for (const name of Object.keys(config.holds)) {
    if (!known.has(name)) problems.push(`hold "${name}" matches no flake input or package`);
  }
  for (const entry of entries) {
    if (entry.kind !== "package" || entry.status !== "update") continue;
    if (entry.command === undefined) {
      problems.push(`package "${entry.name}" has no passthru.updateScript; use packageUpdater.script or add a hold`);
    } else if (entry.command[0] !== discovery.updater) {
      problems.push(`package "${entry.name}" has a custom updateScript; use packageUpdater.script (packages/package-updater)`);
    }
  }
  return problems;
};

const runCaptured = async ({ command, root, logDirectory, name }: { command: Command; root: string; logDirectory: string; name: string }): Promise<Result> => {
  const child = Bun.spawn(command, {
    cwd: root,
    env: { ...process.env, NIXFILES_ROOT: root },
    stdout: "pipe",
    stderr: "pipe",
  });
  const [stdout, stderr, code] = await Promise.all([
    new Response(child.stdout).text(),
    new Response(child.stderr).text(),
    child.exited,
  ]);
  const logPath = join(logDirectory, `${name}.log`);
  const log = `$ ${command.join(" ")}\n${stdout}${stderr}`;
  await Bun.write(logPath, log);
  const lines = log.trimEnd().split("\n");
  if (code === 0) {
    console.log(`ok      ${name}: ${stdout.trimEnd().split("\n").at(-1) ?? ""}`);
    return { name, status: "ok" };
  }
  console.log(`failed  ${name} (exit ${code}, log: ${logPath})\n${lines.slice(-25).map((line) => `  | ${line}`).join("\n")}`);
  return { name, status: "failed", detail: `exit ${code}` };
};

const runInherited = async ({ command, root, name }: { command: Command; root: string; name: string }): Promise<Result> => {
  console.log(`\n==> ${name}\n$ ${command.join(" ")}`);
  const child = Bun.spawn(command, { cwd: root, stdin: "inherit", stdout: "inherit", stderr: "inherit" });
  const code = await child.exited;
  return code === 0 ? { name, status: "ok" } : { name, status: "failed", detail: `exit ${code}` };
};

const runPool = async <T,>({ items, jobs, worker }: { items: T[]; jobs: number; worker: (item: T) => Promise<Result> }) => {
  const results: Result[] = [];
  let next = 0;
  const lanes = Array.from({ length: Math.min(jobs, items.length) }, async () => {
    while (next < items.length) {
      const item = items[next];
      next += 1;
      results.push(await worker(item));
    }
  });
  await Promise.all(lanes);
  return results;
};

const printList = ({ entries, config }: { entries: Entry[]; config: Config }) => {
  for (const kind of ["input", "package"] as const) {
    console.log(kind === "input" ? "Flake inputs:" : "\nPackages:");
    for (const entry of entries.filter((candidate) => candidate.kind === kind)) {
      console.log(`  ${entry.status.padEnd(7)} ${entry.name}${entry.reason === undefined ? "" : ` — ${entry.reason}`}`);
    }
  }
  console.log("\nValidation sets:");
  for (const [name, validations] of Object.entries(config.validations)) {
    console.log(`  ${name}: ${validations.map((validation) => validation.name).join(", ")}`);
  }
};

const printSummary = (results: Result[]) => {
  console.log("\nSummary:");
  for (const status of ["ok", "skipped", "failed"] as const) {
    for (const result of results.filter((candidate) => candidate.status === status)) {
      console.log(`  ${status.padEnd(7)} ${result.name}${result.detail === undefined ? "" : ` (${result.detail})`}`);
    }
  }
};

const updatePins = async (): Promise<number> => {
  const options = parseOptions(Bun.argv.slice(2));
  if (options.help) {
    console.log(usage);
    return 0;
  }

  const root = await repoRoot();
  const config = await loadConfig(root).catch((error: unknown) =>
    fail(`Invalid update registry: ${error instanceof Error ? error.message : String(error)}`),
  );
  const system = await currentSystem();
  const [discovery, inputs] = await Promise.all([discoverPackages(root, system), readInputs(root)]);
  const entries = buildEntries({ config, discovery, inputs });
  const drift = findDrift({ config, discovery, inputs, entries });

  if (options.list) printList({ entries, config });
  if (drift.length > 0) {
    console.error(`Update convention drift (see docs/UPDATE_COMMANDS.md):\n${drift.map((problem) => `  - ${problem}`).join("\n")}`);
    return 2;
  }
  if (options.check) {
    console.log(`Update conventions hold for ${entries.length} inputs and packages on ${system}.`);
    return 0;
  }
  if (options.list) return 0;

  const names = new Set(entries.map((entry) => entry.name));
  const unknown = [...(options.only ?? []), ...options.skip].filter((name) => !names.has(name));
  if (unknown.length > 0) {
    console.error(`Unknown inputs or packages: ${[...new Set(unknown)].sort().join(", ")}`);
    return 2;
  }

  const filtered = options.inputs || options.packages || options.only !== null;
  const named = (entry: Entry) => options.only?.has(entry.name) === true;
  const inScope = (entry: Entry) =>
    !filtered || named(entry) || (options.inputs && entry.kind === "input") || (options.packages && entry.kind === "package");

  const results: Result[] = [];
  const selected = entries.filter((entry) => {
    if (!inScope(entry)) return false;
    if (options.skip.has(entry.name)) {
      results.push({ name: entry.name, status: "skipped", detail: "skipped by CLI" });
      return false;
    }
    if (entry.status === "update") return true;
    if (entry.status === "held" && options.includeHeld && named(entry)) return true;
    results.push({ name: entry.name, status: "skipped", detail: `${entry.status}: ${entry.reason}` });
    return false;
  });

  if (filtered && selected.length === 0) {
    printSummary(results);
    console.error("None of the selected entries can be updated; validation was not run.");
    return 2;
  }

  const inputNames = selected.filter((entry) => entry.kind === "input").map((entry) => entry.name);
  const packageEntries = selected.filter((entry) => entry.kind === "package");
  const inputCommand = ["nix", "flake", "update", ...inputNames];

  if (options.dryRun) {
    if (inputNames.length > 0) console.log(inputCommand.join(" "));
    for (const entry of packageEntries) console.log(`${entry.name}: ${(entry.command ?? []).join(" ")}`);
    return 0;
  }

  if (!Bun.env.GITHUB_TOKEN && Bun.which("gh") !== null) {
    const token = (await $`gh auth token`.quiet().nothrow().text()).trim();
    if (token !== "") process.env.GITHUB_TOKEN = token;
  }

  // Inputs first: package updates evaluate the flake against the refreshed lock.
  if (inputNames.length > 0) {
    const result = await runInherited({ command: inputCommand, root, name: "flake inputs" });
    results.push(...inputNames.map((name) => ({ ...result, name })));
  }

  if (packageEntries.length > 0) {
    const build = await runInherited({ command: ["nix", "build", "--no-link", ".#package-updater"], root, name: "package-updater" });
    if (build.status === "failed") {
      results.push(build);
    } else {
      const logDirectory = await mkdtemp(join(tmpdir(), "update-pins-"));
      console.log(`\n==> ${packageEntries.length} package updates, ${options.jobs} at a time (logs: ${logDirectory})`);
      results.push(
        ...(await runPool({
          items: packageEntries,
          jobs: options.jobs,
          worker: (entry) => runCaptured({ command: entry.command ?? [], root, logDirectory, name: entry.name }),
        })),
      );
    }
  }

  const failed = results.some((result) => result.status === "failed");
  if (!failed && options.validate !== null) {
    const validations = config.validations[options.validate];
    if (validations === undefined) {
      console.error(`Unknown validation set: ${options.validate}`);
      return 2;
    }
    for (const validation of validations) {
      if (validation.systems !== undefined && !validation.systems.includes(system)) {
        results.push({ name: `validate:${validation.name}`, status: "skipped", detail: `unsupported on ${system}` });
      } else {
        results.push(await runInherited({ command: validation.command, root, name: `validate:${validation.name}` }));
      }
    }
  }

  printSummary(results);
  return results.some((result) => result.status === "failed") ? 1 : 0;
};

// The flake app imports this module and calls `main`; `bun scripts/update-pins.ts` runs it directly.
const main = async () => {
  process.exitCode = await updatePins().catch((error: unknown) => {
    console.error(error instanceof Error ? error.message : String(error));
    return 2;
  });
};

export { main };

if (import.meta.main) await main();
