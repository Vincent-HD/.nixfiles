import { PrefetchResultSchema, UrlSchema, VersionSchema, z } from "../update-schema.ts";

type Source = {
  artifact: string;
};

const GithubReleaseSchema = z
  .object({ tag_name: z.string().regex(/^v\d+\.\d+\.\d+(?:-[\w.-]+)?$/).optional() })
  .passthrough();

const sources: Record<string, Source> = {
  "aarch64-darwin": { artifact: "ryu-darwin-arm64.tar.gz" },
  "x86_64-linux": { artifact: "ryu-linux-x64.tar.gz" },
};

function commandOutput(command: string[], cwd?: string): string {
  const result = Bun.spawnSync(command, { cwd });
  if (!result.success) {
    const stderr = new TextDecoder().decode(result.stderr).trim();
    throw new Error("Command failed: " + command.join(" ") + "\n" + stderr);
  }
  return new TextDecoder().decode(result.stdout).trim();
}

async function prefetchHash(url: string, root: string): Promise<string> {
  const validUrl = UrlSchema.parse(url);
  const output = commandOutput(["nix", "store", "prefetch-file", "--json", validUrl], root);
  return PrefetchResultSchema.parse(JSON.parse(output)).hash;
}

const releaseUrl = "https://api.github.com/repos/dmmulroy/jj-ryu/releases/latest";
const response = await fetch(releaseUrl, {
  headers: { Accept: "application/vnd.github+json" },
});
if (!response.ok) {
  throw new Error("Could not fetch " + releaseUrl + ": HTTP " + response.status);
}

const release = GithubReleaseSchema.parse(await response.json());
const tag = release.tag_name;
if (tag === undefined) {
  throw new Error("Could not read a version tag from " + releaseUrl);
}
const version = VersionSchema.parse(tag.slice(1));

const root = commandOutput(["git", "rev-parse", "--show-toplevel"]);
const packageFile = root + "/packages/jj-ryu/default.nix";
let packageText = await Bun.file(packageFile).text();
const currentVersion = packageText.match(/^  version = "([^"]+)";$/m)?.[1];
if (currentVersion === undefined) {
  throw new Error("Could not read the current version from " + packageFile);
}
VersionSchema.parse(currentVersion);

console.log("jj-ryu current: " + currentVersion);
console.log("jj-ryu latest:  " + version);

for (const [system, source] of Object.entries(sources)) {
  const url = UrlSchema.parse(
    "https://github.com/dmmulroy/jj-ryu/releases/download/" +
    tag +
    "/" +
    source.artifact,
  );
  const hash = await prefetchHash(url, root);
  const block = new RegExp('("' + system + '" = \\{[\\s\\S]*?hash = ")[^"]+(";)');
  if (!block.test(packageText)) {
    throw new Error("Could not find the " + system + " source block in " + packageFile);
  }
  packageText = packageText.replace(block, "$1" + hash + "$2");
  console.log("jj-ryu " + system + ": " + hash);
}

packageText = packageText.replace(/^(  version = ")[^"]+(";)$/m, "$1" + version + "$2");
await Bun.write(packageFile, packageText);
console.log("Updated " + packageFile);
