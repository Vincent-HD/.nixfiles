import { $ } from "bun";

type PrefetchResult = {
  hash?: string;
};

type RegistryRelease = {
  version?: string;
  dist?: {
    tarball?: string;
  };
};

async function prefetch(url: string): Promise<string> {
  const result = JSON.parse(await $`nix store prefetch-file --json ${url}`.text()) as PrefetchResult;
  if (result.hash === undefined || result.hash === "") {
    throw new Error(`Could not prefetch ${url}`);
  }
  return result.hash;
}

const registryUrl = "https://registry.npmjs.org/@bitkyc08%2fopencodex/latest";
const response = await fetch(registryUrl);
if (!response.ok) {
  throw new Error(`Could not fetch ${registryUrl}: HTTP ${response.status}`);
}
const release = (await response.json()) as RegistryRelease;
const version = release.version;
const tarballUrl = release.dist?.tarball;
if (version === undefined || !/^\d+\.\d+\.\d+/.test(version) || tarballUrl === undefined) {
  throw new Error(`Could not read a release version and tarball URL from ${registryUrl}`);
}

const root = (await $`git rev-parse --show-toplevel`.text()).trim();
const packageFile = `${root}/packages/opencodex/default.nix`;
let packageText = await Bun.file(packageFile).text();
const currentVersion = packageText.match(/^  version = "([^"]+)";$/m)?.[1];
if (currentVersion === undefined) {
  throw new Error(`Could not read the current version from ${packageFile}`);
}

console.log(`opencodex current: ${currentVersion}`);
console.log(`opencodex latest:  ${version}`);
if (currentVersion === version) {
  console.log("opencodex is already current.");
  process.exit(0);
}

const sourceHash = await prefetch(tarballUrl);
const bunLockUrl = `https://raw.githubusercontent.com/lidge-jun/opencodex/v${version}/bun.lock`;
const bunLockHash = await prefetch(bunLockUrl);
const placeholderHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
packageText = packageText
  .replace(/^(  version = ")[^"]+(";)$/m, `$1${version}$2`)
  .replace(/^(    hash = ")[^"]+(";\n  \};\n\n  bunLock =)/m, `$1${sourceHash}$2`)
  .replace(/^(    hash = ")[^"]+(";\n  \};\n\n  # The npm package)/m, `$1${bunLockHash}$2`)
  .replace(/^(    outputHash = ")[^"]+(";)$/m, `$1${placeholderHash}$2`);
await Bun.write(packageFile, packageText);

const build = await $`nix build .#opencodex --no-link`.quiet().nothrow();
const output = `${build.stdout.toString()}\n${build.stderr.toString()}`;
const dependencyHash = output.match(/got:\s*(sha256-[^\s]+)/)?.[1];
if (dependencyHash === undefined) {
  throw new Error(`Could not determine OpenCodex dependency hash:\n${output}`);
}

packageText = await Bun.file(packageFile).text();
if (!packageText.includes(placeholderHash)) {
  throw new Error(`Could not find the dependency hash placeholder in ${packageFile}`);
}
await Bun.write(packageFile, packageText.replace(placeholderHash, dependencyHash));
console.log(`Updated ${packageFile}`);
