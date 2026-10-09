import { copyFile, mkdtemp, readFile, rename, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import {
  PrefetchResultSchema,
  Sha256HashSchema,
  UrlSchema,
  VersionSchema,
  z,
} from "../update-schema.ts";

const systems = ["aarch64-darwin", "x86_64-linux"] as const;
const placeholderHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";

const RegistryReleaseSchema = z
  .object({
    version: VersionSchema,
    dist: z.object({ tarball: UrlSchema }).passthrough(),
  })
  .passthrough();
const DerivationPathSchema = z.string().regex(/^\/nix\/store\/[^/\s]+\.drv$/);
const MismatchFieldsSchema = z.tuple([z.string(), z.string(), z.string()]);

type DependencyCalculation = (options: {
  root: string;
  packageFile: string;
  system: (typeof systems)[number];
  signal?: AbortSignal;
}) => Promise<string>;

type UpdatePackageOptions = {
  root: string;
  packageFile: string;
  version: string;
  sourceHash: string;
  bunLockHash: string;
  calculateDependencyHash: DependencyCalculation;
  signal?: AbortSignal;
};

type CommandResult = {
  exitCode: number;
  stdout: string;
  stderr: string;
};

function ensureNotAborted(signal?: AbortSignal): void {
  if (signal?.aborted) {
    throw signal.reason ?? new DOMException("Update was cancelled", "AbortError");
  }
}

export async function runCommand(
  command: string[],
  options: { cwd: string; signal?: AbortSignal },
): Promise<CommandResult> {
  ensureNotAborted(options.signal);
  const child = Bun.spawn(command, {
    cwd: options.cwd,
    stdout: "pipe",
    stderr: "pipe",
  });
  const abortChild = () => child.kill("SIGTERM");
  options.signal?.addEventListener("abort", abortChild, { once: true });
  if (options.signal?.aborted) abortChild();

  try {
    const [exitCode, stdout, stderr] = await Promise.all([
      child.exited,
      new Response(child.stdout).text(),
      new Response(child.stderr).text(),
    ]);
    ensureNotAborted(options.signal);
    return { exitCode, stdout, stderr };
  } finally {
    options.signal?.removeEventListener("abort", abortChild);
  }
}

function commandOutput(command: string[], cwd: string): string {
  const result = Bun.spawnSync(command, { cwd });
  const stdout = new TextDecoder().decode(result.stdout).trim();
  const stderr = new TextDecoder().decode(result.stderr).trim();
  if (!result.success) {
    throw new Error("Command failed: " + command.join(" ") + (stderr ? "\n" + stderr : ""));
  }
  return stdout;
}

function replaceRequired(text: string, pattern: RegExp, replacement: string, field: string): string {
  if (!pattern.test(text)) {
    throw new Error("Could not update " + field + " in the OpenCodex package definition");
  }
  return text.replace(pattern, replacement);
}

function replaceDependencyHash(text: string, system: string, hash: string): string {
  const mapStart = text.indexOf("  bunDepsHashes = {");
  const entryMarker = '    "' + system + '" = "';
  const entryStart = text.indexOf(entryMarker, mapStart);
  if (mapStart < 0 || entryStart < 0) {
    throw new Error("Could not find the " + system + " Bun dependency hash in default.nix");
  }

  const valueStart = entryStart + entryMarker.length;
  const valueEnd = text.indexOf('"', valueStart);
  if (valueEnd < 0) {
    throw new Error("Could not parse the " + system + " Bun dependency hash in default.nix");
  }
  return text.slice(0, valueStart) + hash + text.slice(valueEnd);
}

export function extractDependencyHash(
  output: string,
  expectedDrvPath: string,
  expectedHash: string,
): string {
  const drvPath = DerivationPathSchema.parse(expectedDrvPath);
  const validExpectedHash = Sha256HashSchema.parse(expectedHash);
  const mismatchPattern =
    /error: hash mismatch in fixed-output derivation '([^']+)':\s*specified:\s*(\S+)\s*got:\s*(\S+)/g;
  const mismatches = Array.from(output.matchAll(mismatchPattern));
  const mismatchCount = output.match(/hash mismatch in fixed-output derivation/g)?.length ?? 0;
  const specifiedCount = output.match(/^\s*specified:\s*\S+/gm)?.length ?? 0;
  const gotCount = output.match(/^\s*got:\s*\S+/gm)?.length ?? 0;
  if (
    mismatchCount !== 1 ||
    mismatches.length !== 1 ||
    specifiedCount !== 1 ||
    gotCount !== 1
  ) {
    throw new Error("Nix did not report exactly one fixed-output hash mismatch for the requested dependencies");
  }

  const [mismatchDrvPath, specifiedHash, gotHash] = MismatchFieldsSchema.parse(mismatches[0].slice(1));
  if (mismatchDrvPath !== drvPath || specifiedHash !== validExpectedHash) {
    throw new Error("Nix hash mismatch did not belong to the requested OpenCodex dependency derivation");
  }

  const errorLines = output
    .split(/\r?\n/)
    .map(line => line.trim())
    .filter(line => line.startsWith("error:"));
  const unrelatedErrors = errorLines.filter(
    line =>
      line !== `error: hash mismatch in fixed-output derivation '${drvPath}':` &&
      line !== `error: Cannot build '${drvPath}'.`,
  );
  if (unrelatedErrors.length > 0) {
    throw new Error("Nix reported an unrelated error while calculating OpenCodex dependencies");
  }

  return Sha256HashSchema.parse(gotHash);
}

function nixExpression(root: string, packageFile: string, system: string): string {
  const flakePath = JSON.stringify(root);
  const nixPackageFile = JSON.stringify(packageFile);
  const targetSystem = JSON.stringify(system);
  return `
    let
      flake = builtins.getFlake ${flakePath};
      currentSystem = builtins.currentSystem;
      pkgs = flake.inputs.nixpkgs.legacyPackages.\${currentSystem};
      updateScriptZod = flake.packages.\${currentSystem}.update-script-zod;
      package = pkgs.callPackage (builtins.toPath ${nixPackageFile}) {
        updateScriptZod = updateScriptZod;
      };
    in
      package.bunDepsBySystem.${targetSystem}
  `;
}

export async function calculateDependencyHash(options: {
  root: string;
  packageFile: string;
  system: (typeof systems)[number];
  signal?: AbortSignal;
}): Promise<string> {
  const expression = nixExpression(options.root, options.packageFile, options.system);
  const drvPath = DerivationPathSchema.parse(
    commandOutput(
      ["nix", "eval", "--impure", "--raw", "--expr", `(${expression}).drvPath`],
      options.root,
    ),
  );
  const result = await runCommand(
    ["nix", "build", "--impure", "--no-link", "--expr", expression],
    { cwd: options.root, signal: options.signal },
  );
  if (result.exitCode === 0) {
    throw new Error("Nix accepted the placeholder hash; refusing to guess the dependency hash");
  }
  return extractDependencyHash(
    result.stdout + "\n" + result.stderr,
    drvPath,
    placeholderHash,
  );
}

export async function updateOpenCodexPackage(options: UpdatePackageOptions): Promise<void> {
  const version = VersionSchema.parse(options.version);
  const sourceHash = Sha256HashSchema.parse(options.sourceHash);
  const bunLockHash = Sha256HashSchema.parse(options.bunLockHash);
  const originalText = await readFile(options.packageFile, "utf8");
  const currentVersion = originalText.match(/^  version = "([^"]+)";$/m)?.[1];
  if (currentVersion === undefined) {
    throw new Error("Could not read the current version from " + options.packageFile);
  }
  VersionSchema.parse(currentVersion);

  let finalText = replaceRequired(
    originalText,
    /^(  version = ")[^"]+(";)$/m,
    `$1${version}$2`,
    "version",
  );
  finalText = replaceRequired(
    finalText,
    /(src = fetchurl \{[\s\S]*?hash = ")[^"]+(";\n  \};)/,
    `$1${sourceHash}$2`,
    "source hash",
  );
  finalText = replaceRequired(
    finalText,
    /(bunLock = fetchurl \{[\s\S]*?hash = ")[^"]+(";\n  \};)/,
    `$1${bunLockHash}$2`,
    "Bun lockfile hash",
  );

  const calculationDirectory = await mkdtemp(join(tmpdir(), "opencodex-update-"));
  const calculationPackageFile = join(calculationDirectory, "default.nix");
  const publishTempFile = options.packageFile + ".tmp-" + crypto.randomUUID();
  let published = false;

  try {
    let calculationText = finalText;
    for (const system of systems) {
      calculationText = replaceDependencyHash(calculationText, system, placeholderHash);
    }
    await writeFile(calculationPackageFile, calculationText, { mode: 0o644 });
    await copyFile(join(dirname(options.packageFile), "update.ts"), join(calculationDirectory, "update.ts"));

    for (const system of systems) {
      ensureNotAborted(options.signal);
      const hash = Sha256HashSchema.parse(
        await options.calculateDependencyHash({
          root: options.root,
          packageFile: calculationPackageFile,
          system,
          signal: options.signal,
        }),
      );
      finalText = replaceDependencyHash(finalText, system, hash);
      console.log("opencodex " + system + " Bun dependencies: " + hash);
    }

    ensureNotAborted(options.signal);
    await writeFile(publishTempFile, finalText, { mode: 0o644 });
    ensureNotAborted(options.signal);
    await rename(publishTempFile, options.packageFile);
    published = true;
  } finally {
    await rm(calculationDirectory, { recursive: true, force: true });
    if (!published) await rm(publishTempFile, { force: true });
  }
}

async function prefetch(url: string, root: string): Promise<string> {
  const validUrl = UrlSchema.parse(url);
  const output = commandOutput(["nix", "store", "prefetch-file", "--json", validUrl], root);
  return PrefetchResultSchema.parse(JSON.parse(output)).hash;
}

function npmTarballUrlSchema(version: string) {
  return UrlSchema.refine(value => {
    const url = new URL(value);
    return (
      url.hostname === "registry.npmjs.org" &&
      url.pathname === `/@bitkyc08/opencodex/-/opencodex-${version}.tgz`
    );
  });
}

async function main(signal: AbortSignal): Promise<void> {
  const registryUrl = UrlSchema.parse("https://registry.npmjs.org/@bitkyc08%2fopencodex/latest");
  const response = await fetch(registryUrl);
  if (!response.ok) {
    throw new Error("Could not fetch " + registryUrl + ": HTTP " + response.status);
  }

  const release = RegistryReleaseSchema.parse(await response.json());
  const version = VersionSchema.parse(release.version);
  const tarballUrl = npmTarballUrlSchema(version).parse(release.dist.tarball);
  const root = commandOutput(["git", "rev-parse", "--show-toplevel"], process.cwd());
  const packageFile = join(root, "packages/opencodex/default.nix");
  const sourceHash = await prefetch(tarballUrl, root);
  const bunLockUrl = UrlSchema.parse(
    "https://raw.githubusercontent.com/lidge-jun/opencodex/v" + version + "/bun.lock",
  );
  const bunLockHash = await prefetch(bunLockUrl, root);

  await updateOpenCodexPackage({
    root,
    packageFile,
    version,
    sourceHash,
    bunLockHash,
    calculateDependencyHash,
    signal,
  });
  console.log("Updated " + packageFile);
}

if (import.meta.main) {
  const controller = new AbortController();
  const onSigint = () => controller.abort(new DOMException("Interrupted", "AbortError"));
  const onSigterm = () => controller.abort(new DOMException("Terminated", "AbortError"));
  process.on("SIGINT", onSigint);
  process.on("SIGTERM", onSigterm);

  try {
    await main(controller.signal);
  } catch (error) {
    console.error(error);
    process.exitCode = 1;
  } finally {
    process.off("SIGINT", onSigint);
    process.off("SIGTERM", onSigterm);
  }
}
