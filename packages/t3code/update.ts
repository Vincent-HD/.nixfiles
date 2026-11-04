import { PrefetchResultSchema, UrlSchema, VersionSchema, z } from "../update-schema.ts";

type Source = {
  arch: string;
  ext: string;
};

const GithubReleaseSchema = z
  .object({
    tag_name: z.string().optional(),
    prerelease: z.boolean().optional(),
  })
  .passthrough();

const sources: Record<string, Source> = {
  "x86_64-linux": { arch: "x86_64", ext: "AppImage" },
  "aarch64-darwin": { arch: "arm64", ext: "dmg" },
  "x86_64-darwin": { arch: "x64", ext: "dmg" },
};

const nightlyTag = /^v(\d+\.\d+\.\d+-nightly\.\d{8}\.\d+)$/;

function commandOutput(command: string[], cwd?: string): string {
  const result = Bun.spawnSync(command, { cwd });
  if (!result.success) {
    throw new Error("Command failed: " + command.join(" "));
  }
  return new TextDecoder().decode(result.stdout).trim();
}

async function prefetchHash(url: string, root: string): Promise<string> {
  const validUrl = UrlSchema.parse(url);
  const output = commandOutput(["nix", "store", "prefetch-file", "--json", validUrl], root);
  return PrefetchResultSchema.parse(JSON.parse(output)).hash;
}

async function latestNightlyVersion(): Promise<string> {
  const response = await fetch("https://api.github.com/repos/pingdotgg/t3code/releases?per_page=30", {
    headers: { Accept: "application/vnd.github+json" },
  });
  if (!response.ok) {
    throw new Error("Could not list T3 Code releases: HTTP " + response.status);
  }

  const releases = z.array(GithubReleaseSchema).parse(await response.json());
  for (const release of releases) {
    if (release.prerelease !== true || release.tag_name === undefined) {
      continue;
    }
    const match = release.tag_name.match(nightlyTag);
    if (match?.[1] !== undefined) {
      return VersionSchema.parse(match[1]);
    }
  }

  throw new Error("Could not find a T3 Code nightly GitHub prerelease");
}

const root = commandOutput(["git", "rev-parse", "--show-toplevel"]);
const packageFile = root + "/packages/t3code/default.nix";
let packageText = await Bun.file(packageFile).text();
const currentVersion = packageText.match(/^  version = "([^"]+)";$/m)?.[1];
if (currentVersion === undefined) {
  throw new Error("Could not read the current version from " + packageFile);
}
VersionSchema.parse(currentVersion);

const version = await latestNightlyVersion();

console.log("t3code current: " + currentVersion);
console.log("t3code latest:  " + version);

// GitHub can replace a nightly asset without changing its tag; always refresh its hash.
for (const [system, source] of Object.entries(sources)) {
  const url = UrlSchema.parse(
    "https://github.com/pingdotgg/t3code/releases/download/v" +
    version +
    "/T3-Code-" +
    version +
    "-" +
    source.arch +
    "." +
    source.ext,
  );
  const hash = await prefetchHash(url, root);
  const block = new RegExp('("' + system + '" = \\{[\\s\\S]*?hash = ")[^"]+(";)');
  if (!block.test(packageText)) {
    throw new Error("Could not find the " + system + " source block in " + packageFile);
  }
  packageText = packageText.replace(block, "$1" + hash + "$2");
  console.log("t3code " + system + ": " + hash);
}
packageText = packageText.replace(/^(  version = ")[^"]+(";)$/m, "$1" + version + "$2");

await Bun.write(packageFile, packageText);
console.log("Updated " + packageFile);
