#!/usr/bin/env bun

// Bun provides the runtime, process, file, and timer APIs used below. Bun has no
// native path/rename API or sandboxed JS evaluator, so these node:* imports use
// Bun's built-in Node compatibility layer.
import { mkdir, realpath, rename } from "node:fs/promises";
import { dirname, join, relative, resolve, sep } from "node:path";
import { runInNewContext } from "node:vm";
import { parseArgs } from "util";

type JsonValue = null | boolean | number | string | JsonValue[] | { [key: string]: JsonValue };

type JsonObject = { [key: string]: JsonValue };

type Options = {
  repo: string | undefined;
  output: string;
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

type SettingsSpec = {
  defaults: JsonObject;
  nonPersistent: Set<string>;
};

type Context = SettingsSpec & {
  repo: string;
  output: string;
  dmsPath: string;
  options: Options;
};

const defaultOutputPath = "modules/dms/assets/generated-settings.json";

// Values DMS writes for its own bookkeeping, not user preferences.
const runtimeOnlyKeys = new Set(["configVersion", "desktopClockCustomColor", "systemMonitorCustomColor"]);

// Settings that modules/dms/dms.nix sets directly.
const moduleManagedKeys = new Set(["calendarBackend"]);

// Paths stored with `~` so the generated file does not hardcode the home directory.
const homePathKeys = new Set([
  "customThemeFile",
  "greeterWallpaperPath",
  "lockScreenVideoPath",
  "lockScreenWallpaperPath",
  "launcherLogoCustomPath",
  "dockLauncherLogoCustomPath",
]);

const specRelativePath = "share/quickshell/dms/Common/settings/SettingsSpec.js";

const usage = `Usage: persist-dms [options]

Read DMS's in-memory settings, remove current defaults, write a deterministic
JSON settings file, and commit only that generated file.

Options:
  --repo <path>          Repository root (default: git root from cwd).
  --output <path>        Generated file relative to the repository root.
                         Default: ${defaultOutputPath}
  --spec <path>          DMS SettingsSpec.js override (also DMS_SETTINGS_SPEC).
  --watch                Poll DMS and persist each stable settings change.
  --interval-ms <n>      Poll interval in watch mode (default: 1500).
  --debounce-ms <n>      Stability period before writing in watch mode (default: 1200).
  --no-commit            Write the generated file without creating a Git commit.
  --dry-run              Print the diff but do not write or commit.
  -h, --help             Show this help.
`;

// The explicit type lets TypeScript narrow after `if (...) fail(...)`.
const fail: (message: string) => never = (message) => {
  throw new Error(message);
};

const errorMessage = (error: unknown): string => (error instanceof Error ? error.message : String(error));

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value);

const isJsonValue = (value: unknown): value is JsonValue => {
  if (value === null || ["string", "boolean", "number"].includes(typeof value)) return true;
  if (Array.isArray(value)) return value.every(isJsonValue);
  return isRecord(value) && Object.values(value).every(isJsonValue);
};

const isJsonObject = (value: unknown): value is JsonObject => isRecord(value) && isJsonValue(value);

export const sortJson = (value: JsonValue): JsonValue => {
  if (Array.isArray(value)) return value.map(sortJson);
  if (!isRecord(value)) return value;
  return Object.fromEntries(
    Object.keys(value)
      .sort((left, right) => left.localeCompare(right))
      .map((key) => [key, sortJson(value[key])]),
  );
};

export const compactJson = (value: JsonValue): string => JSON.stringify(sortJson(value));

export const prettyJson = (value: JsonValue): string => `${JSON.stringify(sortJson(value), null, 2)}\n`;

const parseObject = ({ text, label }: { text: string; label: string }): JsonObject => {
  let value: unknown;
  try {
    value = JSON.parse(text);
  } catch (error) {
    fail(`Unable to parse ${label}: ${errorMessage(error)}`);
  }
  if (!isJsonObject(value)) fail(`${label} must contain a JSON object`);
  return value;
};

const positiveInteger = ({ value, option }: { value: string; option: string }): number => {
  const parsed = Number(value);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : fail(`${option} expects a positive integer, got '${value}'`);
};

const parseOptions = (argv: string[]): Options | "help" => {
  const { values } = parseArgs({
    args: argv,
    options: {
      repo: { type: "string" },
      output: { type: "string", default: defaultOutputPath },
      spec: { type: "string" },
      watch: { type: "boolean", default: false },
      "interval-ms": { type: "string", default: "1500" },
      "debounce-ms": { type: "string", default: "1200" },
      "no-commit": { type: "boolean", default: false },
      "dry-run": { type: "boolean", default: false },
      help: { type: "boolean", short: "h", default: false },
    },
    strict: true,
    allowPositionals: false,
  });
  if (values.help) return "help";
  return {
    repo: values.repo,
    output: values.output,
    spec: values.spec ?? Bun.env.DMS_SETTINGS_SPEC,
    watch: values.watch,
    noCommit: values["no-commit"],
    dryRun: values["dry-run"],
    intervalMs: positiveInteger({ value: values["interval-ms"], option: "--interval-ms" }),
    debounceMs: positiveInteger({ value: values["debounce-ms"], option: "--debounce-ms" }),
  };
};

const runProcess = async ({ command, cwd }: { command: string[]; cwd?: string }): Promise<ProcessResult> => {
  const child = Bun.spawn({ cmd: command, cwd, stdout: "pipe", stderr: "pipe", timeout: 10_000 });
  const [stdout, stderr, exitCode] = await Promise.all([
    new Response(child.stdout).text(),
    new Response(child.stderr).text(),
    child.exited,
  ]);
  return { stdout, stderr, exitCode };
};

const runChecked = async ({ command, cwd }: { command: string[]; cwd?: string }): Promise<string> => {
  const result = await runProcess({ command, cwd });
  if (result.exitCode !== 0) {
    fail(`${command.join(" ")} failed: ${result.stderr.trim() || result.stdout.trim() || `exit code ${result.exitCode}`}`);
  }
  return result.stdout;
};

// QML JavaScript modules: `.pragma library` plus `.import "file.js" as Name` directives.
// Each file is evaluated once in its own context; its top-level var/function bindings become
// the namespace object that importers see under `Name`, as in the QML engine.
const qmlDirective = /^\s*\.(pragma|import)\b(.*)$/;
const qmlFileImport = /^\s+"([^"]+)"\s+as\s+([A-Za-z_$][\w$]*)\s*;?\s*$/;

export const loadQmlJs = async (
  path: string,
  loaded: Map<string, Record<string, unknown> | "loading"> = new Map(),
): Promise<Record<string, unknown>> => {
  const cached = loaded.get(path);
  if (cached === "loading") fail(`Circular QML JavaScript import: ${path}`);
  if (cached !== undefined) return cached;
  loaded.set(path, "loading");

  const file = Bun.file(path);
  if (!(await file.exists())) fail(`QML JavaScript import not found: ${path}`);
  const namespace: Record<string, unknown> = {};
  const lines = (await file.text()).split("\n");
  for (const [index, line] of lines.entries()) {
    const directive = qmlDirective.exec(line);
    if (directive === null) continue;
    if (directive[1] === "import") {
      const fileImport = qmlFileImport.exec(directive[2]);
      if (fileImport === null) fail(`${path}:${index + 1}: only file imports are supported: ${line.trim()}`);
      else namespace[fileImport[2]] = await loadQmlJs(resolve(dirname(path), fileImport[1]), loaded);
    }
    // Blank the directive but keep the line so stack traces point at the original source.
    lines[index] = "";
  }

  try {
    runInNewContext(lines.join("\n"), namespace, { filename: path });
  } catch (error) {
    fail(`Unable to evaluate ${path}: ${errorMessage(error)}`);
  }
  loaded.set(path, namespace);
  return namespace;
};

export const loadSettingsSpec = async (specPath: string): Promise<SettingsSpec> => {
  const spec = (await loadQmlJs(specPath)).SPEC;
  if (!isRecord(spec)) fail(`DMS SettingsSpec.js did not define SPEC: ${specPath}`);
  const defaults: JsonObject = {};
  const nonPersistent = new Set<string>();
  for (const [key, entry] of Object.entries(spec)) {
    if (!isRecord(entry) || !("def" in entry)) fail(`DMS SettingsSpec.js entry '${key}' has no default`);
    // Defaults come from another VM context; a JSON round-trip turns them into plain data.
    const serialized = JSON.stringify(entry.def);
    const value: unknown = serialized === undefined ? undefined : JSON.parse(serialized);
    if (!isJsonValue(value)) fail(`DMS SettingsSpec.js has an unsupported default for '${key}'`);
    defaults[key] = value;
    if (entry.persist === false) nonPersistent.add(key);
  }
  return { defaults, nonPersistent };
};

const findSpec = async (override: string | undefined): Promise<string> => {
  if (override !== undefined) return resolve(override);
  const dmsPath = Bun.which("dms") ?? fail("The 'dms' executable was not found in PATH");
  const packageRoot = dirname(dirname(await realpath(dmsPath)));
  const specPath = join(packageRoot, specRelativePath);
  if (await Bun.file(specPath).exists()) return specPath;
  return fail(`Could not find ${specRelativePath} next to ${dmsPath}; pass --spec <path>.`);
};

export const normalizeSetting = (key: string, value: JsonValue): JsonValue => {
  const home = Bun.env.HOME;
  if (!homePathKeys.has(key) || typeof value !== "string" || !home) return value;
  if (value !== home && !value.startsWith(`${home}/`)) return value;
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
    if (runtimeOnlyKeys.has(key) || moduleManagedKeys.has(key) || nonPersistent.has(key)) continue;
    if (!(key in defaults)) {
      unknown.push(key);
    } else if (compactJson(value) !== compactJson(defaults[key])) {
      settings[key] = normalizeSetting(key, value);
    }
  }
  return { settings, unknown };
};

const isInside = ({ parent, child }: { parent: string; child: string }): boolean => {
  const path = relative(parent, child);
  return path === "" || (path !== ".." && !path.startsWith(`..${sep}`));
};

const existingAncestor = async (path: string): Promise<string> => {
  try {
    return await realpath(path);
  } catch (error) {
    if (!isRecord(error) || (error.code !== "ENOENT" && error.code !== "ENOTDIR") || dirname(path) === path) throw error;
    return existingAncestor(dirname(path));
  }
};

const resolveRepository = async (requested: string | undefined): Promise<string> => {
  const start = await realpath(resolve(requested ?? process.cwd()));
  const repo = await realpath((await runChecked({ command: ["git", "rev-parse", "--show-toplevel"], cwd: start })).trim());
  if (requested !== undefined && start !== repo) fail(`--repo must point to the Git repository root: ${repo}`);
  return repo;
};

const resolveOutput = async ({ repo, requested }: { repo: string; requested: string }): Promise<string> => {
  const output = resolve(repo, requested);
  const relativeOutput = relative(repo, output);
  if (!isInside({ parent: repo, child: output })) fail(`Generated output must stay inside the repository: ${output}`);
  if (relativeOutput === "" || relativeOutput === ".git" || relativeOutput.startsWith(`.git${sep}`)) {
    fail(`Generated output must be a worktree file outside .git: ${output}`);
  }
  if (!isInside({ parent: repo, child: await existingAncestor(dirname(output)) })) {
    fail(`Generated output resolves outside the repository through a symlink: ${output}`);
  }
  return output;
};

const valueSummary = (value: JsonValue): string => {
  const compact = compactJson(value);
  if (compact.length <= 180) return compact;
  if (Array.isArray(value)) return `[array: ${value.length} entries]`;
  if (isRecord(value)) return `{object: ${Object.keys(value).length} keys}`;
  return `${compact.slice(0, 177)}...`;
};

const printDiff = ({ before, after }: { before: JsonObject; after: JsonObject }) => {
  const keys = [...new Set([...Object.keys(before), ...Object.keys(after)])].sort((left, right) => left.localeCompare(right));
  let count = 0;
  for (const key of keys) {
    const previous = before[key];
    const next = after[key];
    if (previous !== undefined && next !== undefined && compactJson(previous) === compactJson(next)) continue;
    count += 1;
    if (previous === undefined) console.log(`+ ${key}: ${valueSummary(next)}`);
    else if (next === undefined) console.log(`- ${key}: ${valueSummary(previous)}`);
    else console.log(`~ ${key}: ${valueSummary(previous)} -> ${valueSummary(next)}`);
  }
  console.log(count === 0 ? "  no generated settings change" : `  ${count} generated setting${count === 1 ? "" : "s"} changed`);
};

const readExisting = async (path: string): Promise<{ content: string | null; settings: JsonObject }> => {
  const file = Bun.file(path);
  if (!(await file.exists())) return { content: null, settings: {} };
  const content = await file.text();
  return { content, settings: parseObject({ text: content, label: path }) };
};

const writeAtomic = async ({ path, content }: { path: string; content: string }) => {
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
  return [now.getFullYear(), now.getMonth() + 1, now.getDate()].map((part) => String(part).padStart(2, "0")).join("-");
};

// Commit only the generated file, leaving any other staged work untouched.
const commitGeneratedFile = async ({ repo, output }: { repo: string; output: string }) => {
  const relativeOutput = relative(repo, output);
  const tracked = (await runProcess({ command: ["git", "ls-files", "--error-unmatch", "--", relativeOutput], cwd: repo })).exitCode === 0;
  if (!tracked) await runChecked({ command: ["git", "add", "--", relativeOutput], cwd: repo });

  const message = `chore: update dms settings ${localDate()}`;
  try {
    await runChecked({ command: ["git", "commit", "--only", "-m", message, "--", relativeOutput], cwd: repo });
  } catch (error) {
    if (!tracked) await runProcess({ command: ["git", "rm", "--cached", "--force", "--", relativeOutput], cwd: repo });
    throw error;
  }

  const committed = (await runChecked({ command: ["git", "show", "--format=", "--name-only", "--no-renames", "HEAD"], cwd: repo }))
    .split("\n")
    .map((file) => file.trim())
    .filter(Boolean);
  if (committed.length !== 1 || committed[0] !== relativeOutput) {
    fail(`Safety check failed: latest commit contains ${committed.join(", ") || "no files"}, expected only ${relativeOutput}`);
  }
  console.log(`  committed ${relativeOutput}: ${message}`);
};

const persistSnapshot = async ({ context, runtime }: { context: Context; runtime: JsonObject }): Promise<void> => {
  const filtered = nonDefaultSettings(runtime, context.defaults, context.nonPersistent);
  const existing = await readExisting(context.output);
  const content = prettyJson(filtered.settings);
  const relativeOutput = relative(context.repo, context.output);

  console.log(`DMS settings: ${Object.keys(filtered.settings).length} non-default top-level value(s)`);
  printDiff({ before: existing.settings, after: filtered.settings });
  if (filtered.unknown.length > 0) console.warn(`  ignored unknown/runtime keys: ${filtered.unknown.sort().join(", ")}`);

  if (existing.content === null) console.log("  generated file is missing");
  else if (existing.content === content) return console.log(`  unchanged: ${relativeOutput}`);
  else if (compactJson(existing.settings) === compactJson(filtered.settings)) console.log("  generated file formatting is not canonical");

  if (context.options.dryRun) return console.log("  dry-run: no file written and no commit created");
  await writeAtomic({ path: context.output, content });
  console.log(`  wrote ${relativeOutput}`);
  if (context.options.noCommit) return console.log("  commit skipped (--no-commit)");
  await commitGeneratedFile({ repo: context.repo, output: context.output });
};

const readRuntimeSettings = async (dmsPath: string): Promise<JsonObject> => {
  const dump = await runProcess({ command: [dmsPath, "ipc", "call", "settings", "dump"] });
  if (dump.exitCode !== 0) {
    fail(`Unable to read DMS settings through IPC: ${dump.stderr.trim() || dump.stdout.trim() || `exit code ${dump.exitCode}`}`);
  }
  return parseObject({ text: dump.stdout, label: "DMS settings dump" });
};

const buildContext = async (options: Options): Promise<Context> => {
  const repo = await resolveRepository(options.repo);
  const output = await resolveOutput({ repo, requested: options.output });
  const dmsPath = Bun.which("dms") ?? fail("The 'dms' executable was not found in PATH");
  const specPath = await findSpec(options.spec);
  const spec = await loadSettingsSpec(specPath);
  console.log(`DMS executable: ${dmsPath}`);
  console.log(`DMS defaults: ${specPath}`);
  console.log(`Generated file: ${relative(repo, output)}`);
  return { ...spec, repo, output, dmsPath, options };
};

// Persist once the dumped settings have stayed identical for the debounce period.
const watch = async (context: Context): Promise<never> => {
  const { intervalMs, debounceMs } = context.options;
  let observed = "";
  let pendingSince: number | null = null;
  console.log(`Watching DMS settings every ${intervalMs} ms (debounce ${debounceMs} ms)`);
  while (true) {
    try {
      const runtime = await readRuntimeSettings(context.dmsPath);
      const fingerprint = compactJson(runtime);
      if (fingerprint !== observed) {
        observed = fingerprint;
        pendingSince = Date.now();
      } else if (pendingSince !== null && Date.now() - pendingSince >= debounceMs) {
        // On failure, wait another debounce period before retrying.
        pendingSince = Date.now();
        await persistSnapshot({ context, runtime });
        pendingSince = null;
      }
    } catch (error) {
      console.error(`persist-dms: ${errorMessage(error)}`);
    }
    await Bun.sleep(intervalMs);
  }
};

export const main = async (): Promise<void> => {
  try {
    const options = parseOptions(Bun.argv.slice(2));
    if (options === "help") return console.log(usage);
    const context = await buildContext(options);
    if (options.watch) await watch(context);
    else await persistSnapshot({ context, runtime: await readRuntimeSettings(context.dmsPath) });
  } catch (error) {
    console.error(`persist-dms: ${errorMessage(error)}`);
    process.exitCode = 1;
  }
};

if (import.meta.main) await main();
