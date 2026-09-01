type NpmPackage = {
  version?: string;
  dist?: {
    integrity?: string;
  };
};

function commandOutput(command: string[], cwd?: string): string {
  const result = Bun.spawnSync(command, { cwd });
  if (!result.success) {
    throw new Error("Command failed: " + command.join(" "));
  }
  return new TextDecoder().decode(result.stdout).trim();
}

async function fetchNpmPackage(name: string): Promise<NpmPackage> {
  const response = await fetch(`https://registry.npmjs.org/${name}`);
  if (!response.ok) {
    throw new Error(`Could not fetch ${name}: HTTP ${response.status}`);
  }
  return (await response.json()) as NpmPackage;
}

async function prefetchHash(url: string, root: string, unpack = false): Promise<string> {
  const arguments_ = ["nix", "store", "prefetch-file", "--json"];
  if (unpack) arguments_.push("--unpack");
  arguments_.push(url);
  const result = Bun.spawnSync(arguments_, { cwd: root });
  if (!result.success) {
    throw new Error("Could not prefetch " + url);
  }
  const parsed = JSON.parse(new TextDecoder().decode(result.stdout)) as { hash?: string };
  if (parsed.hash === undefined || parsed.hash === "") {
    throw new Error("Could not determine the hash for " + url);
  }
  return parsed.hash;
}

function replaceRequired(
  text: string,
  pattern: RegExp,
  replacement: string,
  field: string,
): string {
  if (!pattern.test(text)) {
    throw new Error(`Could not update ${field} in the Codeburn package definition`);
  }
  return text.replace(pattern, replacement);
}

const latest = await fetchNpmPackage("codeburn/latest");
if (latest.version === undefined || latest.version === "") {
  throw new Error("Could not determine the latest Codeburn version");
}

const npmIntegrity = latest.dist?.integrity;
if (npmIntegrity === undefined || !npmIntegrity.startsWith("sha")) {
  throw new Error("Could not read the npm integrity hash for codeburn@" + latest.version);
}

const root = commandOutput(["git", "rev-parse", "--show-toplevel"]);
const packageFile = root + "/packages/codeburn/default.nix";
let packageText = await Bun.file(packageFile).text();
const currentVersion = packageText.match(/^  version = "([^"]+)";$/m)?.[1];
if (currentVersion === undefined) {
  throw new Error(`Could not read the current version from ${packageFile}`);
}

console.log("codeburn current: " + currentVersion);
console.log("codeburn latest:  " + latest.version);

const sourceUrl =
  "https://github.com/getagentseal/codeburn/archive/refs/tags/v" + latest.version + ".tar.gz";
const sourceHash = await prefetchHash(sourceUrl, root, true);

packageText = replaceRequired(
  packageText,
  /^(  version = ")[^"]+(";)$/m,
  "$1" + latest.version + "$2",
  "version",
);
packageText = replaceRequired(
  packageText,
  /^(    hash = ")[^"]+(";\n  };\n\n  npmArtifact = fetchurl)/m,
  "$1" + sourceHash + "$2",
  "source hash",
);
packageText = replaceRequired(
  packageText,
  /^(    hash = ")[^"]+(";\n  };\n\n  npmDepsHash)/m,
  "$1" + npmIntegrity + "$2",
  "npm artifact hash",
);

await Bun.write(packageFile, packageText);
console.log("Updated " + packageFile);

// Recompute the lockfile-derived dependency cache after the source version
// changes. The package itself already contains the new source and artifact
// hashes, so nix-update can update only npmDepsHash without guessing them.
const updateDeps = Bun.spawnSync([
  "nix",
  "run",
  "github:Mic92/nix-update",
  "--",
  "--flake",
  "codeburn",
  "--version",
  "skip",
  "--no-src",
]);
if (!updateDeps.success) {
  throw new Error("Could not update Codeburn's npm dependency hash");
}
process.stdout.write(new TextDecoder().decode(updateDeps.stdout));
process.stderr.write(new TextDecoder().decode(updateDeps.stderr));
