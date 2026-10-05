type Source = {
  platform: string;
  architecture: string;
};

type LatestRelease = {
  version?: string;
  metadata?: {
    package?: string;
  };
};

type NpmPackage = {
  dist?: {
    integrity?: string;
  };
};

const sources: Record<string, Source> = {
  "aarch64-darwin": { platform: "darwin", architecture: "arm64" },
  "x86_64-linux": { platform: "linux", architecture: "x64" },
};

function currentSystem(): string {
  const result = Bun.spawnSync(["nix", "eval", "--raw", "--impure", "--expr", "builtins.currentSystem"]);
  if (!result.success) {
    throw new Error("Could not determine the current system");
  }
  return new TextDecoder().decode(result.stdout).trim();
}

async function fetchJson<T>(url: string): Promise<T> {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Could not fetch ${url}: HTTP ${response.status}`);
  }
  return (await response.json()) as T;
}

function packageUrl(packageName: string, version: string): string {
  return `https://registry.npmjs.org/${packageName.replace("/", "%2f")}/${version}`;
}

const system = currentSystem();
const source = sources[system];
if (source === undefined) {
  throw new Error(`OpenCode V2 does not publish a release binary for ${system}`);
}

const latestUrl = "https://opencode.ai/update/api/latest/cli/npm";
const latest = await fetchJson<LatestRelease>(latestUrl);
if (latest.version === undefined || latest.version === "") {
  throw new Error(`Could not determine the latest OpenCode V2 version from ${latestUrl}`);
}

const packageScope = latest.metadata?.package;
if (packageScope === undefined || packageScope === "") {
  throw new Error(`Could not determine the OpenCode V2 npm package from ${latestUrl}`);
}

const packageName = `${packageScope}-${source.platform}-${source.architecture}`;
const metadata = await fetchJson<NpmPackage>(packageUrl(packageName, latest.version));
const integrity = metadata.dist?.integrity;
if (integrity === undefined || !integrity.startsWith("sha")) {
  throw new Error(`Could not read the release integrity hash for ${packageName}@${latest.version}`);
}

const rootResult = Bun.spawnSync(["git", "rev-parse", "--show-toplevel"]);
if (!rootResult.success) {
  throw new Error("Could not determine the repository root");
}
const root = new TextDecoder().decode(rootResult.stdout).trim();
const packageFile = `${root}/packages/opencodev2/default.nix`;
let packageText = await Bun.file(packageFile).text();

const currentVersion = packageText.match(/^  version = "([^"]+)";$/m)?.[1];
if (currentVersion === undefined) {
  throw new Error(`Could not read the current version from ${packageFile}`);
}

console.log(`opencodev2 current: ${currentVersion}`);
console.log(`opencodev2 latest:  ${latest.version}`);
console.log(`opencodev2 system:  ${system}`);

const block = new RegExp(`("${system}" = \\{[\\s\\S]*?hash = ")[^"]+(";)`);
if (!block.test(packageText)) {
  throw new Error(`Could not find the ${system} source block in ${packageFile}`);
}

packageText = packageText.replace(block, `$1${integrity}$2`);
packageText = packageText.replace(/^(  version = ")[^"]+(";)$/m, `$1${latest.version}$2`);
await Bun.write(packageFile, packageText);
console.log(`Updated ${packageFile}`);
