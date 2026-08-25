type Source = {
  arch: string;
  ext: string;
};

type GithubRelease = {
  tag_name?: string;
  prerelease?: boolean;
};

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

function currentSystem(): string {
  return commandOutput(["nix", "eval", "--raw", "--impure", "--expr", "builtins.currentSystem"]);
}

async function prefetchHash(url: string, root: string): Promise<string> {
  const output = commandOutput(["nix", "store", "prefetch-file", "--json", url], root);
  const parsed = JSON.parse(output) as { hash?: string };
  if (parsed.hash === undefined || parsed.hash === "") {
    throw new Error("Could not determine the hash for " + url);
  }
  return parsed.hash;
}

async function latestNightlyVersion(): Promise<string> {
  const response = await fetch("https://api.github.com/repos/pingdotgg/t3code/releases?per_page=30", {
    headers: { Accept: "application/vnd.github+json" },
  });
  if (!response.ok) {
    throw new Error("Could not list T3 Code releases: HTTP " + response.status);
  }

  const releases = (await response.json()) as GithubRelease[];
  for (const release of releases) {
    if (release.prerelease !== true || release.tag_name === undefined) {
      continue;
    }
    const match = release.tag_name.match(nightlyTag);
    if (match?.[1] !== undefined) {
      return match[1];
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

const version = await latestNightlyVersion();
const system = currentSystem();
const source = sources[system];
if (source === undefined) {
  throw new Error("T3 Code does not publish a nightly desktop artifact for " + system);
}

console.log("t3code current: " + currentVersion);
console.log("t3code latest:  " + version);
console.log("t3code system:  " + system);

if (currentVersion === version) {
  console.log("t3code is already current.");
  process.exit(0);
}

const url =
  "https://github.com/pingdotgg/t3code/releases/download/v" +
  version +
  "/T3-Code-" +
  version +
  "-" +
  source.arch +
  "." +
  source.ext;
const hash = await prefetchHash(url, root);
const block = new RegExp('("' + system + '" = \\{[\\s\\S]*?hash = ")[^"]+(";)');
if (!block.test(packageText)) {
  throw new Error("Could not find the " + system + " source block in " + packageFile);
}
packageText = packageText.replace(block, "$1" + hash + "$2");
packageText = packageText.replace(/^(  version = ")[^"]+(";)$/m, "$1" + version + "$2");

await Bun.write(packageFile, packageText);
console.log("Updated " + packageFile);
