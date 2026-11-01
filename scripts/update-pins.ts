import { $ } from "bun";
import { parseArgs as parseArgv } from "util";

type Command = string[];
type SystemScopedEntry = { systems?: string[] };

type UpdateEntry = {
  name: string;
  type: string;
  description?: string;
  enabled?: boolean;
  systems?: string[];
  command: Command;
};

type ValidationEntry = {
  name: string;
  command: Command;
  systems?: string[];
};

type UpdateConfig = {
  denylist?: string[];
  updates: UpdateEntry[];
  validations?: Record<string, ValidationEntry[]>;
};

type Options = {
  dryRun: boolean;
  includeDenylisted: boolean;
  list: boolean;
  only: Set<string> | null;
  skip: Set<string>;
  validate: string | null;
};

type Result = {
  name: string;
  status: "ok" | "failed" | "skipped";
  reason?: string;
  code?: number;
};

function usage(): string {
  return `Usage: update-pins.ts [options]

Through the flake app:
  nix run .#update-pins -- [options]

Options:
  --dry-run              Print selected commands without running them.
  --only <a,b>           Run only the named update entries.
  --skip <a,b>           Skip the named update entries.
  --include-denylisted   Allow entries listed in scripts/update-pins.json denylist.
  --validate <name>      Run a validation set after successful updates.
  --list                 List configured updates and validation sets.
  -h, --help             Show this help.
`;
}

function parseNameList(value: string): string[] {
  return value
    .split(",")
    .map((name) => name.trim())
    .filter((name) => name.length > 0);
}

function stringValues(value: string | string[] | boolean | undefined): string[] {
  if (typeof value === "string") {
    return [value];
  }
  if (Array.isArray(value)) {
    return value;
  }
  return [];
}

function parseOptions(argv: string[]): Options | "help" {
  const { values } = parseArgv({
    args: argv,
    options: {
      "dry-run": {
        type: "boolean",
        default: false,
      },
      only: {
        type: "string",
        multiple: true,
      },
      skip: {
        type: "string",
        multiple: true,
      },
      "include-denylisted": {
        type: "boolean",
        default: false,
      },
      validate: {
        type: "string",
      },
      list: {
        type: "boolean",
        default: false,
      },
      help: {
        type: "boolean",
        short: "h",
        default: false,
      },
    },
    strict: true,
    allowPositionals: false,
  });

  if (values.help === true) {
    return "help";
  }

  const only = stringValues(values.only).flatMap(parseNameList);
  const skip = stringValues(values.skip).flatMap(parseNameList);

  return {
    dryRun: values["dry-run"] === true,
    includeDenylisted: values["include-denylisted"] === true,
    list: values.list === true,
    only: only.length > 0 ? new Set(only) : null,
    skip: new Set(skip),
    validate: typeof values.validate === "string" ? values.validate : null,
  };
}

async function repoRoot(): Promise<string> {
  if (Bun.env.UPDATE_PINS_REPO_ROOT !== undefined && Bun.env.UPDATE_PINS_REPO_ROOT !== "") {
    return Bun.env.UPDATE_PINS_REPO_ROOT;
  }

  try {
    return (await $`git rev-parse --show-toplevel`.text()).trim();
  } catch {
    return Bun.env.PWD ?? ".";
  }
}

function repoPath(root: string, ...segments: string[]): string {
  return `${root.replace(/\/+$/, "")}/${segments.join("/")}`;
}

async function loadConfig(root: string): Promise<UpdateConfig> {
  const configPath = repoPath(root, "scripts", "update-pins.json");
  const value: unknown = await Bun.file(configPath).json();
  return validateConfig(value);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isStringArray(value: unknown): value is string[] {
  return Array.isArray(value) && value.every((item) => typeof item === "string");
}

function validateUpdateCommand(value: unknown, label: string): Command {
  if (!isStringArray(value) || value.length === 0) {
    throw new Error(`${label}.command must be a non-empty array of strings`);
  }
  return value;
}

function validateSystems(value: Record<string, unknown>, label: string): string[] | undefined {
  if (!Object.hasOwn(value, "systems")) {
    return undefined;
  }
  if (!isStringArray(value.systems)) {
    throw new Error(`${label}.systems must be an array of strings`);
  }
  return value.systems;
}

function validateConfig(value: unknown): UpdateConfig {
  if (!isRecord(value)) {
    throw new Error("registry must be a JSON object");
  }
  if (!Array.isArray(value.updates)) {
    throw new Error("updates must be an array");
  }
  if (Object.hasOwn(value, "denylist") && !isStringArray(value.denylist)) {
    throw new Error("denylist must be an array of strings");
  }

  const updates: UpdateEntry[] = [];
  const names = new Set<string>();
  for (const [index, candidate] of value.updates.entries()) {
    const label = `updates[${index}]`;
    if (!isRecord(candidate)) {
      throw new Error(`${label} must be a JSON object`);
    }
    if (typeof candidate.name !== "string" || candidate.name.length === 0) {
      throw new Error(`${label}.name must be a non-empty string`);
    }
    if (names.has(candidate.name)) {
      throw new Error(`duplicate update name: ${candidate.name}`);
    }
    names.add(candidate.name);
    if (typeof candidate.type !== "string" || candidate.type.length === 0) {
      throw new Error(`${label}.type must be a non-empty string`);
    }
    if (Object.hasOwn(candidate, "description") && typeof candidate.description !== "string") {
      throw new Error(`${label}.description must be a string`);
    }
    if (Object.hasOwn(candidate, "enabled") && typeof candidate.enabled !== "boolean") {
      throw new Error(`${label}.enabled must be a boolean`);
    }
    const systems = validateSystems(candidate, label);
    updates.push({
      name: candidate.name,
      type: candidate.type,
      ...(Object.hasOwn(candidate, "description") ? { description: candidate.description as string } : {}),
      ...(Object.hasOwn(candidate, "enabled") ? { enabled: candidate.enabled as boolean } : {}),
      ...(systems !== undefined ? { systems } : {}),
      command: validateUpdateCommand(candidate.command, label),
    });
  }

  let validations: Record<string, ValidationEntry[]> | undefined;
  if (Object.hasOwn(value, "validations")) {
    if (!isRecord(value.validations)) {
      throw new Error("validations must be an object of validation arrays");
    }
    validations = {};
    for (const [setName, candidates] of Object.entries(value.validations)) {
      if (!Array.isArray(candidates)) {
        throw new Error(`validations.${setName} must be an array`);
      }
      validations[setName] = candidates.map((candidate, index) => {
        const label = `validations.${setName}[${index}]`;
        if (!isRecord(candidate)) {
          throw new Error(`${label} must be a JSON object`);
        }
        if (typeof candidate.name !== "string" || candidate.name.length === 0) {
          throw new Error(`${label}.name must be a non-empty string`);
        }
        const systems = validateSystems(candidate, label);
        return {
          name: candidate.name,
          ...(systems !== undefined ? { systems } : {}),
          command: validateUpdateCommand(candidate.command, label),
        };
      });
    }
  }

  return {
    ...(Object.hasOwn(value, "denylist") ? { denylist: value.denylist as string[] } : {}),
    updates,
    ...(validations !== undefined ? { validations } : {}),
  };
}

function validateSelectedNames(config: UpdateConfig, options: Options): string[] {
  const knownNames = new Set(config.updates.map((entry) => entry.name));
  const selectedNames = [...(options.only ?? []), ...options.skip];
  return [...new Set(selectedNames.filter((name) => !knownNames.has(name)))].sort();
}

async function currentSystem(): Promise<string> {
  return (await $`nix eval --impure --raw --expr builtins.currentSystem`.text()).trim();
}

function unsupportedSystemReason(entry: SystemScopedEntry, system: string): string | null {
  if (entry.systems === undefined || entry.systems.includes(system)) {
    return null;
  }

  return `unsupported on ${system}`;
}

function shellQuote(value: string): string {
  if (/^[A-Za-z0-9_./:=@%+,-]+$/.test(value)) {
    return value;
  }
  return `'${value.replaceAll("'", "'\\''")}'`;
}

function formatCommand(command: Command): string {
  return command.map(shellQuote).join(" ");
}

async function runCommand(name: string, command: Command, cwd: string, dryRun: boolean): Promise<Result> {
  console.log(`\n==> ${name}`);
  console.log(formatCommand(command));

  if (dryRun) {
    return { name, status: "skipped", reason: "dry run" };
  }

  const proc = Bun.spawn(command, {
    cwd,
    stdin: "inherit",
    stdout: "inherit",
    stderr: "inherit",
  });
  const code = await proc.exited;

  if (code === 0) {
    return { name, status: "ok" };
  }

  return { name, status: "failed", code };
}

function selectedEntries(config: UpdateConfig, options: Options, system: string): Result[] {
  const denylist = new Set(config.denylist ?? []);
  const skipped: Result[] = [];

  for (const entry of config.updates) {
    const unsupportedReason = unsupportedSystemReason(entry, system);

    if (options.only !== null && !options.only.has(entry.name)) {
      skipped.push({ name: entry.name, status: "skipped", reason: "not selected" });
    } else if (options.skip.has(entry.name)) {
      skipped.push({ name: entry.name, status: "skipped", reason: "skipped by CLI" });
    } else if (entry.type === "manual" || entry.enabled === false) {
      skipped.push({ name: entry.name, status: "skipped", reason: "manual" });
    } else if (unsupportedReason !== null) {
      skipped.push({ name: entry.name, status: "skipped", reason: unsupportedReason });
    } else if (denylist.has(entry.name) && !options.includeDenylisted) {
      skipped.push({ name: entry.name, status: "skipped", reason: "denylisted" });
    }
  }

  return skipped;
}

function runnableEntries(config: UpdateConfig, options: Options, system: string): UpdateEntry[] {
  const denylist = new Set(config.denylist ?? []);
  return config.updates.filter((entry) => {
    if (options.only !== null && !options.only.has(entry.name)) {
      return false;
    }
    if (options.skip.has(entry.name) || entry.type === "manual" || entry.enabled === false) {
      return false;
    }
    if (unsupportedSystemReason(entry, system) !== null) {
      return false;
    }
    if (denylist.has(entry.name) && !options.includeDenylisted) {
      return false;
    }
    return true;
  });
}

function printList(config: UpdateConfig): void {
  const denylist = new Set(config.denylist ?? []);
  console.log("Updates:");
  for (const entry of config.updates) {
    const markers = [
      entry.type,
      entry.enabled === false ? "disabled" : null,
      denylist.has(entry.name) ? "denylisted" : null,
    ].filter((value): value is string => value !== null);
    const systems = entry.systems === undefined ? "all systems" : entry.systems.join(", ");
    console.log(`- ${entry.name} (${markers.join(", ")}, ${systems}): ${entry.description ?? formatCommand(entry.command)}`);
  }

  console.log("\nValidation sets:");
  for (const [name, entries] of Object.entries(config.validations ?? {})) {
    console.log(`- ${name}: ${entries.map((entry) => entry.name).join(", ")}`);
  }
}

function printSummary(results: Result[]): void {
  const groups = {
    ok: results.filter((result) => result.status === "ok"),
    skipped: results.filter((result) => result.status === "skipped"),
    failed: results.filter((result) => result.status === "failed"),
  };

  console.log("\nSummary:");
  for (const result of groups.ok) {
    console.log(`  ok      ${result.name}`);
  }
  for (const result of groups.skipped) {
    console.log(`  skipped ${result.name}${result.reason !== undefined ? ` (${result.reason})` : ""}`);
  }
  for (const result of groups.failed) {
    console.log(`  failed  ${result.name}${result.code !== undefined ? ` (exit ${result.code})` : ""}`);
  }
}

async function main(): Promise<void> {
  let options: Options;
  try {
    const parsed = parseOptions(Bun.argv.slice(2));
    if (parsed === "help") {
      await Bun.write(Bun.stdout, usage());
      return;
    }
    options = parsed;
  } catch (error) {
    await Bun.write(Bun.stderr, `${error instanceof Error ? error.message : String(error)}\n${usage()}`);
    process.exitCode = 2;
    return;
  }

  const root = await repoRoot();
  let config: UpdateConfig;
  try {
    config = await loadConfig(root);
  } catch (error) {
    await Bun.write(
      Bun.stderr,
      `Invalid update registry: ${error instanceof Error ? error.message : String(error)}\n`,
    );
    process.exitCode = 2;
    return;
  }

  const unknownNames = validateSelectedNames(config, options);
  if (unknownNames.length > 0) {
    await Bun.write(Bun.stderr, `Unknown update entries: ${unknownNames.join(", ")}\n`);
    process.exitCode = 2;
    return;
  }

  if (options.list) {
    printList(config);
    return;
  }

  const system = await currentSystem();
  const results: Result[] = selectedEntries(config, options, system);
  const runnable = runnableEntries(config, options, system);

  if (options.only !== null && runnable.length === 0) {
    printSummary(results);
    await Bun.write(
      Bun.stderr,
      "None of the explicitly selected updates are runnable; validation was not run. Check --list and docs/UPDATE_COMMANDS.md for manual entries.\n",
    );
    process.exitCode = 2;
    return;
  }

  for (const entry of runnable) {
    results.push(await runCommand(entry.name, entry.command, root, options.dryRun));
  }

  const failed = results.some((result) => result.status === "failed");
  if (!failed && options.validate !== null) {
    const validations = config.validations?.[options.validate];
    if (validations === undefined) {
      await Bun.write(Bun.stderr, `Unknown validation set: ${options.validate}\n`);
      process.exitCode = 2;
      return;
    }
    for (const entry of validations) {
      const unsupportedReason = unsupportedSystemReason(entry, system);
      if (unsupportedReason !== null) {
        results.push({ name: `validate:${entry.name}`, status: "skipped", reason: unsupportedReason });
      } else {
        results.push(await runCommand(`validate:${entry.name}`, entry.command, root, options.dryRun));
      }
    }
  }

  printSummary(results);
  if (results.some((result) => result.status === "failed")) {
    process.exitCode = 1;
  }
}

await main();
