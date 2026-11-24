import { parseArgs } from "util";

type Source = {
  url: string;
  hash: string;
  unpack: boolean;
};

const storeSourcePrefix = /^\/nix\/store\/[a-z0-9]{32}-source\//;
const versionPattern = /^[0-9A-Za-z][0-9A-Za-z.+_-]*$/;

const fail = (message: string): never => {
  throw new Error(message);
};

const run = async ({ command, cwd }: { command: string[]; cwd: string }): Promise<string> => {
  const child = Bun.spawn(command, { cwd, stdout: "pipe", stderr: "pipe" });
  const [stdout, stderr, code] = await Promise.all([
    new Response(child.stdout).text(),
    new Response(child.stderr).text(),
    child.exited,
  ]);
  if (code !== 0) fail(`Command failed (${code}): ${command.join(" ")}\n${stderr.trim()}`);
  return stdout.trim();
};

const runVisible = async ({ command, cwd, env }: { command: string[]; cwd: string; env?: Record<string, string> }) => {
  console.log(`$ ${command.join(" ")}`);
  const child = Bun.spawn(command, {
    cwd,
    env: { ...process.env, ...env },
    stdin: "inherit",
    stdout: "inherit",
    stderr: "inherit",
  });
  const code = await child.exited;
  if (code !== 0) fail(`Command failed (${code}): ${command.join(" ")}`);
};

const options = parseArgs({
  args: Bun.argv.slice(2),
  options: {
    attr: { type: "string" },
    file: { type: "string" },
    "nix-update-arg": { type: "string", multiple: true, default: [] },
    "latest-version": { type: "string" },
    "post-update": { type: "string" },
  },
  strict: true,
  allowPositionals: false,
}).values;

const attr = options.attr ?? fail("--attr is required");
const storeFile = options.file ?? fail("--file is required");
const root = Bun.env.NIXFILES_ROOT || (await run({ command: ["git", "rev-parse", "--show-toplevel"], cwd: process.cwd() }));
const relativeFile = storeSourcePrefix.test(storeFile)
  ? storeFile.replace(storeSourcePrefix, "")
  : fail(`--file must point into the flake source, got ${storeFile}`);
const packageFile = `${root}/${relativeFile}`;

if (!Bun.env.GITHUB_TOKEN && Bun.which("gh") !== null) {
  const token = await run({ command: ["gh", "auth", "token"], cwd: root }).catch(() => "");
  if (token !== "") process.env.GITHUB_TOKEN = token;
}

const system = await run({ command: ["nix", "eval", "--impure", "--raw", "--expr", "builtins.currentSystem"], cwd: root });

const evalPackage = async (apply: string): Promise<unknown> =>
  JSON.parse(await run({ command: ["nix", "eval", "--json", `.#packages.${system}.${attr}`, "--apply", apply], cwd: root }));

const evalString = async (apply: string): Promise<string> => {
  const value = await evalPackage(apply);
  return typeof value === "string" ? value : fail(`Expected a string from ${apply}`);
};

const latestVersion = async (command: string): Promise<string> => {
  const version = await run({ command: ["bash", "-euo", "pipefail", "-c", command], cwd: root });
  return versionPattern.test(version) ? version : fail(`latest-version printed an invalid version: "${version}"`);
};

const readSources = async (): Promise<Source[]> => {
  const value = await evalPackage(
    'p: builtins.attrValues (builtins.mapAttrs (_: s: { url = s.url or (builtins.head s.urls); hash = s.outputHash; unpack = (s.outputHashMode or "flat") == "recursive"; }) (p.sources or { }))',
  );
  if (!Array.isArray(value)) fail(`${attr}.sources must be an attribute set of fixed-output fetches`);
  return value.map((source: Record<string, unknown>) => ({
    url: typeof source.url === "string" ? source.url : fail(`${attr}.sources entry has no url`),
    hash: typeof source.hash === "string" ? source.hash : fail(`${attr}.sources entry has no hash`),
    unpack: source.unpack === true,
  }));
};

const prefetch = async (source: Source): Promise<string> => {
  const output = await run({
    command: ["nix", "store", "prefetch-file", "--json", ...(source.unpack ? ["--unpack"] : []), source.url],
    cwd: root,
  });
  const hash: unknown = JSON.parse(output).hash;
  return typeof hash === "string" ? hash : fail(`No hash returned for ${source.url}`);
};

// nix-update only hashes `src` for the running system; refresh every other pinned fetch by value.
const syncSources = async () => {
  const srcUrl = await evalString("p: p.src.url or (builtins.head p.src.urls)");
  const pending = new Map<string, Source>();
  for (const source of await readSources()) {
    if (source.url !== srcUrl) pending.set(source.url, source);
  }
  for (const source of pending.values()) {
    const hash = await prefetch(source);
    if (hash === source.hash) continue;
    const text = await Bun.file(packageFile).text();
    if (!text.includes(source.hash)) fail(`Could not find ${source.hash} (${source.url}) in ${relativeFile}`);
    await Bun.write(packageFile, text.replaceAll(source.hash, hash));
    console.log(`${attr}: ${source.url}\n  ${source.hash} -> ${hash}`);
  }
};

const oldVersion = await evalString("p: p.version");
const requestedVersion = options["latest-version"] === undefined ? null : await latestVersion(options["latest-version"]);

await runVisible({
  command: [
    "nix-update",
    "--flake",
    attr,
    "--override-filename",
    relativeFile,
    ...options["nix-update-arg"],
    ...(requestedVersion === null ? [] : ["--version", requestedVersion]),
  ],
  cwd: root,
});

const newVersion = await evalString("p: p.version");
if (newVersion === oldVersion) {
  console.log(`${attr} is up to date (${oldVersion})`);
  process.exit(0);
}

await syncSources();

if (options["post-update"] !== undefined) {
  await runVisible({
    command: ["bun", options["post-update"]],
    cwd: root,
    env: {
      NIXFILES_ROOT: root,
      UPDATE_ATTR: attr,
      UPDATE_FILE: packageFile,
      UPDATE_OLD_VERSION: oldVersion,
      UPDATE_NEW_VERSION: newVersion,
    },
  });
}

console.log(`${attr}: ${oldVersion} -> ${newVersion}`);
