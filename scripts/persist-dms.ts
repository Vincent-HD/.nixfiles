#!/usr/bin/env bun

// Bun provides the runtime, process, file, environment, and timer APIs used
// below. Bun has no native path/directory/rename API or sandboxed JS evaluator,
// so these node:* imports use Bun's built-in Node compatibility layer.
import { mkdir, realpath, rename } from "node:fs/promises";
import { dirname, join, relative, resolve, sep } from "node:path";
import { runInNewContext } from "node:vm";

type JsonValue = null | boolean | number | string | JsonValue[] | { [key: string]: JsonValue };

type JsonObject = { [key: string]: JsonValue };

type SpecEntry = {
  def: JsonValue;
  persist?: boolean;
};

type Options = {
  repo: string | undefined;
  output: string | undefined;
  spec: string | undefined;
  watch: boolean;
  noCommit: boolean;
  dryRun: boolean;
  intervalMs: number;
  debounceMs: number;
};

type ProcessResult = {
  stdout: string;
  stderr: string;
  exitCode: number;
};

const defaultOutputPath = "modules/dms/assets/generated-settings.json";

const runtimeOnlyKeys = new Set([
  "configVersion",
  "desktopClockCustomColor",
  "systemMonitorCustomColor",
]);

const homePathKeys = new Set([
  "customThemeFile",
  "greeterWallpaperPath",
  "lockScreenVideoPath",
  "lockScreenWallpaperPath",
  "launcherLogoCustomPath",
  "dockLauncherLogoCustomPath",
]);

const usage = `Usage: persist-dms [options]

Read DMS's in-memory settings, remove current defaults, write a deterministic
JSON settings file, and commit only that generated file.

Options:
  --repo <path>          Repository root (default: git root from cwd).
  --output <path>        Generated file relative to the repository root.
                         Default: ${defaultOutputPath}
  --spec <path>          DMS SettingsSpec.js override.
  --watch                Poll DMS and persist each stable settings change.
  --interval-ms <n>      Poll interval in watch mode (default: 1500).
  --debounce-ms <n>      Stability period before writing in watch mode (default: 1200).
  --no-commit            Write the generated file without creating a Git commit.
  --dry-run              Print the diff but do not write or commit.
  -h, --help             Show this help.
`;

const fail = (message: string): never => {
  throw new Error(message);
};

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value);

const isJsonValue = (value: unknown): value is JsonValue => {
  if (value === null || typeof value === "string" || typeof value === "boolean" || typeof value === "number")
    return true;
  if (Array.isArray(value))
    return value.every(isJsonValue);
  if (!isRecord(value))
    return false;
  return Object.values(value).every(isJsonValue);
};

export const sortJson = (value: JsonValue): JsonValue => {
  if (Array.isArray(value))
    return value.map(sortJson);
  if (!isRecord(value))
    return value;
  return Object.fromEntries(
    Object.keys(value)
      .sort((left, right) => left.localeCompare(right))
      .map((key) => [key, sortJson(value[key])]),
  );
};

export const compactJson = (value: JsonValue): string => JSON.stringify(sortJson(value));

export const prettyJson = (value: JsonValue): string => `${JSON.stringify(sortJson(value), null, 2)}\n`;

const parseJson = (text: string, label: string): JsonValue => {
  try {
    const value: unknown = JSON.parse(text);
    if (!isJsonValue(value))
      fail(`${label} does not contain a JSON value`);
    return value;
  } catch (error) {
    const detail = error instanceof Error ? error.message : String(error);
    fail(`Unable to parse ${label}: ${detail}`);
  }
};

const parseObject = (text: string, label: string): JsonObject => {
  const value = parseJson(text, label);
  if (!isRecord(value))
    fail(`${label} must contain a JSON object`);
  return value as JsonObject;
};

const parsePositiveInteger = (value: string, option: string): number => {
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed < 1)
    fail(`${option} expects a positive integer, got '${value}'`);
  return parsed;
};

const parseOptions = (argv: string[]): Options => {
  let repo: string | undefined;
  let output: string | undefined;
  let spec: string | undefined;
  let watch = false;
  let noCommit = false;
  let dryRun = false;
  let intervalMs = 1500;
  let debounceMs = 1200;

  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (argument === "-h" || argument === "--help") {
      console.log(usage);
      process.exit(0);
    }
    if (argument === "--watch") {
      watch = true;
      continue;
    }
    if (argument === "--no-commit") {
      noCommit = true;
      continue;
    }
    if (argument === "--dry-run") {
      dryRun = true;
      continue;
    }

    const next = argv[index + 1];
    if (argument === "--repo" || argument === "--output" || argument === "--spec" || argument === "--interval-ms" || argument === "--debounce-ms") {
      if (!next || next.startsWith("--"))
        fail(`${argument} expects a value`);
      index += 1;
      if (argument === "--repo")
        repo = next;
      else if (argument === "--output")
        output = next;
      else if (argument === "--spec")
        spec = next;
      else if (argument === "--interval-ms")
        intervalMs = parsePositiveInteger(next, argument);
      else
        debounceMs = parsePositiveInteger(next, argument);
      continue;
    }
    fail(`Unknown option '${argument}'.\n\n${usage}`);
  }

  return { repo, output, spec, watch, noCommit, dryRun, intervalMs, debounceMs };
};

const runProcess = async (command: string[], cwd?: string, timeoutMs = 10_000): Promise<ProcessResult> => {
  const processHandle = Bun.spawn({
    cmd: command,
    cwd,
    stdout: "pipe",
    stderr: "pipe",
    maxBuffer: 10 * 1024 * 1024,
    timeout: timeoutMs,
  });
  const stdoutPromise = new Response(processHandle.stdout).text();
  const stderrPromise = new Response(processHandle.stderr).text();
  const [stdout, stderr] = await Promise.all([stdoutPromise, stderrPromise]);
  const exitCode = await processHandle.exited;
  return { stdout, stderr, exitCode };
};

const runChecked = async (command: string[], cwd?: string): Promise<string> => {
  const result = await runProcess(command, cwd);
  if (result.exitCode !== 0) {
    const details = result.stderr.trim() || result.stdout.trim() || `exit code ${result.exitCode}`;
    fail(`${command.join(" ")} failed: ${details}`);
  }
  return result.stdout;
};

const findRepositoryRoot = async (requested: string | undefined): Promise<string> => {
  if (requested)
    return resolve(requested);
  return (await runChecked(["git", "rev-parse", "--show-toplevel"], process.cwd())).trim();
};

const isInside = (parent: string, child: string): boolean => {
  const path = relative(parent, child);
  return path === "" || (!path.startsWith(`..${sep}`) && path !== "..");
};

const findDmsSpec = async (override: string | undefined): Promise<string> => {
  const candidates: string[] = [];
  if (override)
    candidates.push(resolve(override));
  if (Bun.env.DMS_SETTINGS_SPEC)
    candidates.push(resolve(Bun.env.DMS_SETTINGS_SPEC));

  const dmsPath = Bun.which("dms");
  if (dmsPath) {
    const resolvedDmsPath = await realpath(dmsPath).catch(() => dmsPath);
    const packageRoot = dirname(dirname(resolvedDmsPath));
    candidates.push(join(packageRoot, "share/quickshell/dms/Common/settings/SettingsSpec.js"));
    candidates.push(join(dirname(resolvedDmsPath), "../share/quickshell/dms/Common/settings/SettingsSpec.js"));
  }

  for (const candidate of candidates) {
    if (await Bun.file(candidate).exists())
      return candidate;
  }

  fail(
    "Could not locate DMS SettingsSpec.js. Use --spec <path> or DMS_SETTINGS_SPEC, " +
      "and ensure the DMS package exposes share/quickshell/dms/Common/settings/SettingsSpec.js.",
  );
};

const loadDefaults = async (specPath: string): Promise<{ defaults: JsonObject; nonPersistent: Set<string> }> => {
  const source = await Bun.file(specPath).text();
  const executableSource = source.replace(/^\s*\.pragma library\s*\r?\n/, "");
  let evaluated: unknown;
  try {
    evaluated = runInNewContext(`${executableSource}\nSPEC`, Object.create(null), { filename: specPath });
  } catch (error) {
    const detail = error instanceof Error ? error.message : String(error);
    fail(`Unable to evaluate DMS SettingsSpec.js: ${detail}`);
  }
  if (!isRecord(evaluated))
    fail(`DMS SettingsSpec.js did not expose SPEC: ${specPath}`);

  const defaults: JsonObject = {};
  const nonPersistent = new Set<string>();
  for (const [key, rawEntry] of Object.entries(evaluated)) {
    if (!isRecord(rawEntry) || !("def" in rawEntry) || !isJsonValue(rawEntry.def))
      fail(`DMS SettingsSpec.js has an unsupported default for '${key}'`);
    defaults[key] = rawEntry.def;
    if (rawEntry.persist === false)
      nonPersistent.add(key);
  }
  return { defaults, nonPersistent };
};

export const normalizeSetting = (key: string, value: JsonValue): JsonValue => {
  if (!homePathKeys.has(key) || typeof value !== "string")
    return value;
  const home = Bun.env.HOME;
  if (!home || (value !== home && !value.startsWith(`${home}/`)))
    return value;
  return `~${value.slice(home.length)}`;
};

export const nonDefaultSettings = (
  runtime: JsonObject,
  defaults: JsonObject,
  nonPersistent: Set<string>,
): { settings: JsonObject; unknown: string[] } => {
  const settings: JsonObject = {};
  const unknown: string[] = [];
  for (const [key, value] of Object.entries(runtime)) {
    if (runtimeOnlyKeys.has(key) || nonPersistent.has(key))
      continue;
    if (!(key in defaults)) {
      unknown.push(key);
      continue;
    }
    if (compactJson(value) !== compactJson(defaults[key]))
      settings[key] = normalizeSetting(key, value);
  }
  return { settings, unknown };
};

const valueSummary = (value: JsonValue): string => {
  const compact = compactJson(value);
  if (compact.length <= 180)
    return compact;
  if (Array.isArray(value))
    return `[array: ${value.length} entries]`;
  if (isRecord(value))
    return `{object: ${Object.keys(value).length} keys}`;
  return `${compact.slice(0, 177)}...`;
};

const printDiff = (before: JsonObject, after: JsonObject): void => {
  const keys = new Set([...Object.keys(before), ...Object.keys(after)]);
  const changed = [...keys].sort((left, right) => left.localeCompare(right));
  let count = 0;
  for (const key of changed) {
    const previous = before[key];
    const next = after[key];
    const hadPrevious = previous !== undefined;
    const hasNext = next !== undefined;
    if (hadPrevious && hasNext && compactJson(previous) === compactJson(next))
      continue;
    count += 1;
    if (!hadPrevious)
      console.log(`+ ${key}: ${valueSummary(next)}`);
    else if (!hasNext)
      console.log(`- ${key}: ${valueSummary(previous)}`);
    else
      console.log(`~ ${key}: ${valueSummary(previous)} -> ${valueSummary(next)}`);
  }
  if (count === 0)
    console.log("  no generated settings change");
  else
    console.log(`  ${count} generated setting${count === 1 ? "" : "s"} changed`);
};

const readExisting = async (path: string): Promise<JsonObject> => {
  if (!(await Bun.file(path).exists()))
    return {};
  try {
    const value: unknown = await Bun.file(path).json();
    if (!isRecord(value))
      fail(`${path} must contain a JSON object`);
    return value as JsonObject;
  } catch (error) {
    const detail = error instanceof Error ? error.message : String(error);
    fail(`Unable to read ${path}: ${detail}`);
  }
};

const writeAtomic = async (path: string, content: string): Promise<void> => {
  await mkdir(dirname(path), { recursive: true });
  const temporaryPath = `${path}.tmp-${process.pid}-${crypto.randomUUID()}`;
  try {
    await Bun.write(temporaryPath, content);
    await rename(temporaryPath, path);
  } catch (error) {
    await Bun.file(temporaryPath).delete().catch(() => undefined);
    throw error;
  }
};

const localDate = (): string => {
  const now = new Date();
  const year = now.getFullYear();
  const month = String(now.getMonth() + 1).padStart(2, "0");
  const day = String(now.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
};

const commitGeneratedFile = async (repo: string, output: string): Promise<void> => {
  const relativeOutput = relative(repo, output);
  await runChecked(["git", "add", "--", relativeOutput], repo);
  const message = `chore: update dms setting ${localDate()}`;
  await runChecked(["git", "commit", "--only", "-m", message, "--", relativeOutput], repo);

  const committedFiles = (await runChecked(["git", "show", "--format=", "--name-only", "--no-renames", "HEAD"], repo))
    .split("\n")
    .map((file) => file.trim())
    .filter(Boolean);
  if (committedFiles.length !== 1 || committedFiles[0] !== relativeOutput)
    fail(`Safety check failed: latest commit contains ${committedFiles.join(", ") || "no files"}, expected only ${relativeOutput}`);
  console.log(`  committed ${relativeOutput}: ${message}`);
};

type Context = {
  repo: string;
  output: string;
  dmsPath: string;
  defaults: JsonObject;
  nonPersistent: Set<string>;
  options: Options;
};

const persistSnapshot = async (context: Context, runtime: JsonObject): Promise<boolean> => {
  const filtered = nonDefaultSettings(runtime, context.defaults, context.nonPersistent);
  const before = await readExisting(context.output);
  const after = filtered.settings;

  console.log(`DMS settings: ${Object.keys(after).length} non-default top-level value(s)`);
  printDiff(before, after);
  if (filtered.unknown.length > 0)
    console.warn(`  ignored unknown/runtime keys: ${filtered.unknown.sort().join(", ")}`);

  const content = prettyJson(after);
  if (compactJson(before) === compactJson(after)) {
    console.log(`  unchanged: ${relative(context.repo, context.output)}`);
    return false;
  }
  if (context.options.dryRun) {
    console.log("  dry-run: no file written and no commit created");
    return true;
  }

  await writeAtomic(context.output, content);
  console.log(`  wrote ${relative(context.repo, context.output)}`);
  if (!context.options.noCommit)
    await commitGeneratedFile(context.repo, context.output);
  else
    console.log("  commit skipped (--no-commit)");
  return true;
};

const getRuntimeSettings = async (dmsPath: string): Promise<JsonObject> => {
  const dump = await runProcess([dmsPath, "ipc", "call", "settings", "dump"]);
  if (dump.exitCode !== 0) {
    const details = dump.stderr.trim() || dump.stdout.trim() || `exit code ${dump.exitCode}`;
    fail(`Unable to read DMS settings through IPC: ${details}`);
  }
  return parseObject(dump.stdout, "DMS settings dump");
};

const buildContext = async (options: Options): Promise<Context> => {
  const repo = await findRepositoryRoot(options.repo);
  const requestedOutput = options.output ?? defaultOutputPath;
  const output = resolve(repo, requestedOutput);
  if (!isInside(repo, output))
    fail(`Generated output must stay inside the repository: ${output}`);

  const dmsPath = Bun.which("dms");
  if (!dmsPath)
    fail("The 'dms' executable was not found in PATH");
  const specPath = await findDmsSpec(options.spec);
  const spec = await loadDefaults(specPath);
  console.log(`DMS executable: ${dmsPath}`);
  console.log(`DMS defaults: ${specPath}`);
  console.log(`Generated file: ${relative(repo, output)}`);
  return { repo, output, dmsPath, defaults: spec.defaults, nonPersistent: spec.nonPersistent, options };
};

const runOnce = async (context: Context): Promise<void> => {
  await persistSnapshot(context, await getRuntimeSettings(context.dmsPath));
};

const runWatch = async (context: Context): Promise<void> => {
  let observed = "";
  let pending = "";
  let pendingSince = 0;
  console.log(`Watching DMS settings every ${context.options.intervalMs} ms (debounce ${context.options.debounceMs} ms)`);
  while (true) {
    try {
      const runtime = await getRuntimeSettings(context.dmsPath);
      const fingerprint = compactJson(runtime);
      if (fingerprint !== observed) {
        observed = fingerprint;
        pending = fingerprint;
        pendingSince = Date.now();
      } else if (pending && fingerprint === pending && Date.now() - pendingSince >= context.options.debounceMs) {
        try {
          await persistSnapshot(context, runtime);
          pending = "";
        } catch (error) {
          pendingSince = Date.now();
          throw error;
        }
      }
    } catch (error) {
      console.error(error instanceof Error ? error.message : String(error));
    }
    await Bun.sleep(context.options.intervalMs);
  }
};

export const main = async (): Promise<void> => {
  const options = parseOptions(Bun.argv.slice(2));
  const context = await buildContext(options);
  if (options.watch)
    await runWatch(context);
  else
    await runOnce(context);
};

if (import.meta.main) {
  main().catch((error: unknown) => {
    console.error(`persist-dms: ${error instanceof Error ? error.message : String(error)}`);
    process.exitCode = 1;
  });
}
