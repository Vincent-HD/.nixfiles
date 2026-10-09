import { SriHashSchema, UrlSchema, VersionSchema, z } from "../update-schema.ts";

type Source = {
  platform: string;
  architecture: string;
};

const LatestReleaseSchema = z
  .object({
    version: z.string().optional(),
    metadata: z.object({ package: z.string().optional() }).passthrough().optional(),
  })
  .passthrough();
const NpmPackageSchema = z
  .object({ dist: z.object({ integrity: SriHashSchema.optional() }).passthrough().optional() })
  .passthrough();

const sources: Record<string, Source> = {
  "aarch64-darwin": { platform: "darwin", architecture: "arm64" },
  "x86_64-linux": { platform: "linux", architecture: "x64" },
};

async function fetchJson(url: string): Promise<unknown> {
  const validUrl = UrlSchema.parse(url);
  const response = await fetch(validUrl);
  if (!response.ok) {
    throw new Error(`Could not fetch ${validUrl}: HTTP ${response.status}`);
  }
  return await response.json();
}

function packageUrl(packageName: string, version: string): string {
  return UrlSchema.parse(`https://registry.npmjs.org/${packageName.replace("/", "%2f")}/${version}`);
}

const latestUrl = "https://opencode.ai/update/api/latest/cli/npm";
const latest = LatestReleaseSchema.parse(await fetchJson(latestUrl));
if (latest.version === undefined || latest.version === "") {
  throw new Error(`Could not determine the latest OpenCode V2 version from ${latestUrl}`);
}
VersionSchema.parse(latest.version);

const packageScope = latest.metadata?.package;
if (packageScope === undefined || packageScope === "") {
  throw new Error(`Could not determine the OpenCode V2 npm package from ${latestUrl}`);
}
z.string().regex(/^@[a-z0-9._-]+\/[a-z0-9._-]+$/i).parse(packageScope);

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
VersionSchema.parse(currentVersion);

console.log(`opencodev2 current: ${currentVersion}`);
console.log(`opencodev2 latest:  ${latest.version}`);

for (const [system, source] of Object.entries(sources)) {
  const packageName = `${packageScope}-${source.platform}-${source.architecture}`;
  const metadata = NpmPackageSchema.parse(await fetchJson(packageUrl(packageName, latest.version)));
  const integrity = metadata.dist?.integrity;
  if (integrity === undefined) {
    throw new Error(`Could not read the release integrity hash for ${packageName}@${latest.version}`);
  }

  const block = new RegExp(`("${system}" = \\{[\\s\\S]*?hash = ")[^"]+(";)`);
  if (!block.test(packageText)) {
    throw new Error(`Could not find the ${system} source block in ${packageFile}`);
  }
  packageText = packageText.replace(block, `$1${SriHashSchema.parse(integrity)}$2`);
  console.log(`opencodev2 ${system}: ${integrity}`);
}

packageText = packageText.replace(/^(  version = ")[^"]+(";)$/m, `$1${latest.version}$2`);
await Bun.write(packageFile, packageText);
console.log(`Updated ${packageFile}`);
