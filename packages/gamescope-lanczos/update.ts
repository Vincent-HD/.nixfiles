import { $ } from "bun";

type PrefetchResult = {
  date?: string;
  hash?: string;
};

const sourceUrl = "https://github.com/ThomasEricB/gamescope-lanczos-downscaling.git";
const sourceRef = "refs/heads/master";

function repoPath(root: string, ...segments: string[]): string {
  return `${root.replace(/\/+$/, "")}/${segments.join("/")}`;
}

async function repoRoot(): Promise<string> {
  try {
    return (await $`git rev-parse --show-toplevel`.text()).trim();
  } catch {
    return Bun.env.PWD ?? ".";
  }
}

function readRevision(remoteOutput: string): string {
  const lines = remoteOutput
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line.length > 0);
  const matchingLine = lines.find((line) => line.endsWith(`\t${sourceRef}`));
  const revision = matchingLine?.split(/\s+/)[0];

  if (revision === undefined || !/^[0-9a-f]{40}$/.test(revision)) {
    throw new Error(`Could not resolve ${sourceRef} from ${sourceUrl}`);
  }

  return revision;
}

function updatePackageText(packageText: string, packageFile: string, revision: string, hash: string, date: string): string {
  const versionPattern = /^(  version = ")([^"]+)(";)$/m;
  const versionMatch = versionPattern.exec(packageText);
  if (versionMatch === null) {
    throw new Error(`Could not read the package version from ${packageFile}`);
  }

  const baseVersion = versionMatch[2].match(/^(\d+\.\d+\.\d+)-unstable-/)?.[1];
  if (baseVersion === undefined) {
    throw new Error(`Could not determine the Gamescope base version from ${packageFile}`);
  }

  const sourcePattern =
    /(  src = fetchFromGitHub \{\n    owner = "ThomasEricB";\n    repo = "gamescope-lanczos-downscaling";\n    rev = ")[^"]+(";\n    fetchSubmodules = true;\n    hash = ")[^"]+(";\n  \};)/;
  if (sourcePattern.exec(packageText) === null) {
    throw new Error(`Could not locate the Gamescope source block in ${packageFile}`);
  }

  const version = `${baseVersion}-unstable-${date}`;
  return packageText
    .replace(versionPattern, (_match, prefix: string, _current: string, suffix: string) => `${prefix}${version}${suffix}`)
    .replace(sourcePattern, (_match, prefix: string, afterRevision: string, afterHash: string) =>
      `${prefix}${revision}${afterRevision}${hash}${afterHash}`,
    );
}

const root = await repoRoot();
const packageFile = repoPath(root, "packages", "gamescope-lanczos", "default.nix");
const packageText = await Bun.file(packageFile).text();

const revision = readRevision(await $`git ls-remote ${sourceUrl} ${sourceRef}`.text());
console.log(`gamescope-lanczos latest: ${revision}`);

const prefetch = JSON.parse(
  await $`nix-prefetch-git --url ${sourceUrl} --rev ${revision} --fetch-submodules --quiet`.text(),
) as PrefetchResult;
if (prefetch.hash === undefined || prefetch.hash.length === 0) {
  throw new Error(`Could not determine the recursive source hash for ${revision}`);
}

const date = prefetch.date?.match(/^\d{4}-\d{2}-\d{2}/)?.[0];
if (date === undefined) {
  throw new Error(`Could not determine the commit date for ${revision}`);
}

const updatedPackageText = updatePackageText(packageText, packageFile, revision, prefetch.hash, date);
if (updatedPackageText === packageText) {
  console.log("gamescope-lanczos is already up to date.");
} else {
  await Bun.write(packageFile, updatedPackageText);
  console.log(`Updated ${packageFile}`);
}
