type Source = {
  platform: string;
  architecture: string;
};

const sources: Record<string, Source> = {
  "x86_64-linux": { platform: "linux", architecture: "x64" },
  "aarch64-linux": { platform: "linux", architecture: "arm64" },
  "x86_64-darwin": { platform: "darwin", architecture: "x64" },
  "aarch64-darwin": { platform: "darwin", architecture: "arm64" },
};

function commandOutput(command: string[], cwd?: string): string {
  const result = Bun.spawnSync(command, { cwd });
  if (!result.success) {
    throw new Error("Command failed: " + command.join(" "));
  }
  return new TextDecoder().decode(result.stdout).trim();
}

async function prefetchHash(url: string, root: string): Promise<string> {
  const output = commandOutput(["nix", "store", "prefetch-file", "--json", url], root);
  const parsed = JSON.parse(output) as { hash?: string };
  if (parsed.hash === undefined || parsed.hash === "") {
    throw new Error("Could not determine the hash for " + url);
  }
  return parsed.hash;
}

const installerUrl = "https://cursor.com/install";
const installerResponse = await fetch(installerUrl);
if (!installerResponse.ok) {
  throw new Error("Could not fetch " + installerUrl + ": HTTP " + installerResponse.status);
}

const installer = await installerResponse.text();
const version = installer.match(/downloads\.cursor\.com\/lab\/([^/]+)\//)?.[1];
if (version === undefined) {
  throw new Error("Could not read the current Cursor Agent version from " + installerUrl);
}

const root = commandOutput(["git", "rev-parse", "--show-toplevel"]);
const packageFile = root + "/packages/cursor-agent/default.nix";
let packageText = await Bun.file(packageFile).text();
const currentVersion = packageText.match(/^  version = "([^"]+)";$/m)?.[1];
if (currentVersion === undefined) {
  throw new Error("Could not read the current version from " + packageFile);
}

console.log("cursor-agent current: " + currentVersion);
console.log("cursor-agent latest:  " + version);

for (const [system, source] of Object.entries(sources)) {
  const url =
    "https://downloads.cursor.com/lab/" +
    version +
    "/" +
    source.platform +
    "/" +
    source.architecture +
    "/agent-cli-package.tar.gz";
  const hash = await prefetchHash(url, root);
  const block = new RegExp('("' + system + '" = \\{[\\s\\S]*?hash = ")[^"]+(";)');
  if (!block.test(packageText)) {
    throw new Error("Could not find the " + system + " source block in " + packageFile);
  }
  packageText = packageText.replace(block, "$1" + hash + "$2");
}

packageText = packageText.replace(
  /^(  version = ")[^"]+(";)$/m,
  "$1" + version + "$2",
);

await Bun.write(packageFile, packageText);
console.log("Updated " + packageFile);
