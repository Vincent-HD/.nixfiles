type Source = {
  platform: string;
  architecture: string;
};

type NpmPackage = {
  version?: string;
  dist?: {
    integrity?: string;
  };
};

const sources: Record<string, Source> = {
  "x86_64-linux": { platform: "linux", architecture: "x64" },
  "aarch64-linux": { platform: "linux", architecture: "arm64" },
  "x86_64-darwin": { platform: "darwin", architecture: "x64" },
  "aarch64-darwin": { platform: "darwin", architecture: "arm64" },
};

function currentSystem(): string {
  const result = Bun.spawnSync(["nix", "eval", "--raw", "--impure", "--expr", "builtins.currentSystem"]);
  if (!result.success) {
    throw new Error("Could not determine the current system");
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

const latest = await fetchNpmPackage("executor/latest");
if (latest.version === undefined || latest.version === "") {
  throw new Error("Could not determine the latest Executor version");
}

const root = Bun.spawnSync(["git", "rev-parse", "--show-toplevel"]);
if (!root.success) {
  throw new Error("Could not determine the repository root");
}
const rootPath = new TextDecoder().decode(root.stdout).trim();
const packageFile = `${rootPath}/packages/executor/default.nix`;
let packageText = await Bun.file(packageFile).text();

const currentVersion = packageText.match(/^  version = "([^"]+)";$/m)?.[1];
if (currentVersion === undefined) {
  throw new Error(`Could not read the current version from ${packageFile}`);
}

const system = currentSystem();
const source = sources[system];
if (source === undefined) {
  throw new Error(`Executor does not publish a release binary for ${system}`);
}

console.log(`executor current: ${currentVersion}`);
console.log(`executor latest:  ${latest.version}`);
console.log(`executor system:  ${system}`);

const platformVersion = `${latest.version}-${source.platform}-${source.architecture}`;
const metadata = await fetchNpmPackage(`executor/${platformVersion}`);
const integrity = metadata.dist?.integrity;
if (integrity === undefined || !integrity.startsWith("sha")) {
  throw new Error(`Could not read the release integrity hash for executor@${platformVersion}`);
}

const block = new RegExp(`("${system}" = \\{[\\s\\S]*?hash = ")[^"]+(")`);
if (!block.test(packageText)) {
  throw new Error(`Could not find the ${system} source block in ${packageFile}`);
}
packageText = packageText.replace(block, `$1${integrity}$2`);

packageText = packageText.replace(
  /^(  version = ")[^"]+(";)$/m,
  `$1${latest.version}$2`,
);

await Bun.write(packageFile, packageText);
console.log(`Updated ${packageFile}`);
