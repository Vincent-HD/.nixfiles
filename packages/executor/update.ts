import { SriHashSchema, UrlSchema, VersionSchema, z } from "../update-schema.ts";

type Source = {
  platform: string;
  architecture: string;
};

const NpmPackageSchema = z
  .object({
    version: z.string().optional(),
    dist: z.object({ integrity: SriHashSchema.optional() }).passthrough().optional(),
  })
  .passthrough();

const sources: Record<string, Source> = {
  "x86_64-linux": { platform: "linux", architecture: "x64" },
  "aarch64-linux": { platform: "linux", architecture: "arm64" },
  "x86_64-darwin": { platform: "darwin", architecture: "x64" },
  "aarch64-darwin": { platform: "darwin", architecture: "arm64" },
};

async function fetchNpmPackage(name: string) {
  const url = UrlSchema.parse(`https://registry.npmjs.org/${name}`);
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Could not fetch ${name}: HTTP ${response.status}`);
  }
  return NpmPackageSchema.parse(await response.json());
}

const latest = await fetchNpmPackage("executor/latest");
if (latest.version === undefined || latest.version === "") {
  throw new Error("Could not determine the latest Executor version");
}
VersionSchema.parse(latest.version);

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
VersionSchema.parse(currentVersion);

console.log(`executor current: ${currentVersion}`);
console.log(`executor latest:  ${latest.version}`);

for (const [system, source] of Object.entries(sources)) {
  const platformVersion = `${latest.version}-${source.platform}-${source.architecture}`;
  const metadata = await fetchNpmPackage(`executor/${platformVersion}`);
  const integrity = metadata.dist?.integrity;
  if (integrity === undefined || metadata.version !== platformVersion) {
    throw new Error(`Could not read the release integrity hash for executor@${platformVersion}`);
  }

  const block = new RegExp(`("${system}" = \\{[\\s\\S]*?hash = ")[^"]+(";)`);
  if (!block.test(packageText)) {
    throw new Error(`Could not find the ${system} source block in ${packageFile}`);
  }
  packageText = packageText.replace(block, `$1${SriHashSchema.parse(integrity)}$2`);
  console.log(`executor ${system}: ${integrity}`);
}

packageText = packageText.replace(
  /^(  version = ")[^"]+(";)$/m,
  `$1${latest.version}$2`,
);

await Bun.write(packageFile, packageText);
console.log(`Updated ${packageFile}`);
