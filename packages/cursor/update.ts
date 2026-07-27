function commandOutput(command: string[], cwd?: string): string {
  const result = Bun.spawnSync(command, { cwd });
  if (!result.success) {
    throw new Error("Command failed: " + command.join(" "));
  }
  return new TextDecoder().decode(result.stdout).trim();
}

const system = commandOutput(["nix", "eval", "--raw", "--impure", "--expr", "builtins.currentSystem"]);
if (system !== "aarch64-darwin") {
  throw new Error("Cursor's local package only supports aarch64-darwin, not " + system);
}

const response = await fetch("https://api2.cursor.sh/updates/api/download/stable/darwin-arm64/cursor");
if (!response.ok) {
  throw new Error("Could not fetch Cursor's stable macOS ARM update metadata: HTTP " + response.status);
}

const release = (await response.json()) as { downloadUrl?: string; version?: string };
if (release.version === undefined || release.downloadUrl === undefined) {
  throw new Error("Cursor's stable macOS ARM update metadata is missing a version or download URL");
}

const commit = release.downloadUrl.match(/downloads\.cursor\.com\/production\/([a-f0-9]+)\/darwin\/arm64\//)?.[1];
if (commit === undefined) {
  throw new Error("Could not read Cursor's release commit from " + release.downloadUrl);
}

const root = commandOutput(["git", "rev-parse", "--show-toplevel"]);
const packageFile = root + "/packages/cursor/default.nix";
const hashOutput = commandOutput(["nix", "store", "prefetch-file", "--json", release.downloadUrl], root);
const hash = (JSON.parse(hashOutput) as { hash?: string }).hash;
if (hash === undefined || hash === "") {
  throw new Error("Could not determine the Nix hash for " + release.downloadUrl);
}

let packageText = await Bun.file(packageFile).text();
for (const [field, value] of [
  ["version", release.version],
  ["releaseCommit", commit],
] as const) {
  const pattern = new RegExp('^(  ' + field + ' = ")[^"]+(";)$', "m");
  if (!pattern.test(packageText)) {
    throw new Error("Could not find " + field + " in " + packageFile);
  }
  packageText = packageText.replace(pattern, "$1" + value + "$2");
}

const hashPattern = /^(      hash = ")[^"]+(";)$/m;
if (!hashPattern.test(packageText)) {
  throw new Error("Could not find the source hash in " + packageFile);
}
packageText = packageText.replace(hashPattern, "$1" + hash + "$2");

await Bun.write(packageFile, packageText);
console.log("cursor current: " + release.version);
console.log("Updated " + packageFile);
