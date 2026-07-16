function commandOutput(command: string[], cwd?: string): string {
  const result = Bun.spawnSync(command, { cwd });
  if (!result.success) {
    const stderr = new TextDecoder().decode(result.stderr).trim();
    throw new Error(`Command failed: ${command.join(" ")}\n${stderr}`);
  }
  return new TextDecoder().decode(result.stdout).trim();
}

const sevenZip = Bun.argv[2];
if (sevenZip === undefined || sevenZip === "") {
  throw new Error("The absolute 7z executable path must be passed as the first argument");
}

const root = commandOutput(["git", "rev-parse", "--show-toplevel"]);
const packageFile = `${root}/packages/fusion360/default.nix`;
let packageText = await Bun.file(packageFile).text();

const installerUrl =
  "https://dl.appstreaming.autodesk.com/production/installers/Fusion%20Admin%20Install.exe";
const prefetch = JSON.parse(
  commandOutput([
    "nix",
    "store",
    "prefetch-file",
    "--name",
    "fusion360-admin-installer.exe",
    "--json",
    installerUrl,
  ], root),
) as { hash?: string; storePath?: string };

if (prefetch.hash === undefined || prefetch.storePath === undefined) {
  throw new Error("Could not prefetch the Autodesk Fusion Admin installer");
}

const manifest = commandOutput([
  sevenZip,
  "x",
  "-so",
  prefetch.storePath,
  "_payload/*/*/full.json",
]);
const latestVersion = manifest.match(/"build-version":\s*"([^"]+)"/)?.[1];
const currentVersion = packageText.match(/^  version = "([^"]+)";$/m)?.[1];

if (latestVersion === undefined || currentVersion === undefined) {
  throw new Error("Could not read the current or latest Fusion build version");
}

console.log(`fusion360 current: ${currentVersion}`);
console.log(`fusion360 latest:  ${latestVersion}`);

packageText = packageText
  .replace(/^(  version = ")[^"]+(";)$/m, `$1${latestVersion}$2`)
  .replace(
    /^(    name = "fusion360-admin-installer\.exe";\n    hash = ")[^"]+(";)$/m,
    `$1${prefetch.hash}$2`,
  );

await Bun.write(packageFile, packageText);
console.log(`Updated ${packageFile}`);
