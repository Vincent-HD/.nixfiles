import { $ } from "bun";

type Asset = {
  name?: string;
  browser_download_url?: string;
};

type Release = {
  tag_name?: string;
  assets?: Asset[];
};

function repoRoot(): Promise<string> {
  return $`git rev-parse --show-toplevel`.text().then((output) => output.trim());
}

function currentVersion(packageText: string, packageFile: string): string {
  const version = packageText.match(/^  packageVersion = "([^"]+)";$/m)?.[1];
  if (version === undefined) {
    throw new Error(`Could not read the LocalSend version from ${packageFile}`);
  }
  return version;
}

function releaseAsset(release: Release, assetName: string): string {
  const url = release.assets?.find((asset) => asset.name === assetName)?.browser_download_url;
  if (url === undefined) {
    throw new Error(`The LocalSend release does not provide ${assetName}`);
  }
  return url;
}

async function prefetchHash(url: string, root: string): Promise<string> {
  const output = (await $`cd ${root} && nix store prefetch-file --json ${url}`.text()).trim();
  const hash = (JSON.parse(output) as { hash?: string }).hash;
  if (hash === undefined) {
    throw new Error(`Could not determine the fixed-output hash for ${url}`);
  }
  return hash;
}

function updatedPackageText(packageText: string, version: string, appImageHash: string, dmgHash: string): string {
  return packageText
    .replace(/^(  packageVersion = ")[^"]+(";)$/m, `$1${version}$2`)
    .replace(/^(    appImage = ")[^"]+(";)$/m, `$1${appImageHash}$2`)
    .replace(/^(    dmg = ")[^"]+(";)$/m, `$1${dmgHash}$2`);
}

async function main(): Promise<void> {
  const root = await repoRoot();
  const packageFile = `${root}/packages/localsend/default.nix`;
  const packageText = await Bun.file(packageFile).text();
  const current = currentVersion(packageText, packageFile);

  const response = await fetch("https://api.github.com/repos/localsend/localsend/releases/latest");
  if (!response.ok) {
    throw new Error(`Could not fetch the LocalSend release metadata: HTTP ${response.status}`);
  }
  const release = (await response.json()) as Release;
  const version = release.tag_name?.replace(/^v/, "");
  if (version === undefined || version.length === 0) {
    throw new Error("Could not read the latest LocalSend release version");
  }

  console.log(`localsend current: ${current}`);
  console.log(`localsend latest:  ${version}`);
  if (current === version) {
    return;
  }

  const appImageUrl = releaseAsset(release, `LocalSend-${version}-linux-x86-64.AppImage`);
  const dmgUrl = releaseAsset(release, `LocalSend-${version}.dmg`);
  const [appImageHash, dmgHash] = await Promise.all([
    prefetchHash(appImageUrl, root),
    prefetchHash(dmgUrl, root),
  ]);

  await Bun.write(packageFile, updatedPackageText(packageText, version, appImageHash, dmgHash));
  console.log(`Updated ${packageFile}`);
}

await main();
