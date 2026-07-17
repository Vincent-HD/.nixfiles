type Source = {
  artifact: string;
};

const sources: Record<string, Source> = {
  "x86_64-linux": { artifact: "plannotator-linux-x64" },
  "aarch64-linux": { artifact: "plannotator-linux-arm64" },
  "x86_64-darwin": { artifact: "plannotator-darwin-x64" },
  "aarch64-darwin": { artifact: "plannotator-darwin-arm64" },
};

function commandOutput(command: string[], cwd?: string): string {
  const result = Bun.spawnSync(command, { cwd });
  if (!result.success) {
    const stderr = new TextDecoder().decode(result.stderr).trim();
    throw new Error(`Command failed: ${command.join(" ")}\n${stderr}`);
  }
  return new TextDecoder().decode(result.stdout).trim();
}

async function fetchText(url: string): Promise<string> {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Could not fetch ${url}: HTTP ${response.status}`);
  }
  return await response.text();
}

function checksumToSri(checksum: string, url: string): string {
  const hex = checksum.trim().split(/\s+/)[0];
  if (!/^[0-9a-f]{64}$/i.test(hex)) {
    throw new Error(`Could not read a SHA-256 checksum from ${url}`);
  }
  return `sha256-${Buffer.from(hex, "hex").toString("base64")}`;
}

const releaseApi = "https://api.github.com/repos/backnotprop/plannotator/releases/latest";
const release = JSON.parse(await fetchText(releaseApi)) as { tag_name?: string };
const tag = release.tag_name;
if (tag === undefined || !/^v\d/.test(tag)) {
  throw new Error(`Could not read the latest release tag from ${releaseApi}`);
}
const version = tag.slice(1);

const root = commandOutput(["git", "rev-parse", "--show-toplevel"]);
const packageFile = `${root}/packages/plannotator/default.nix`;
let packageText = await Bun.file(packageFile).text();
const currentVersion = packageText.match(/^  version = "([^"]+)";$/m)?.[1];
if (currentVersion === undefined) {
  throw new Error(`Could not read the current version from ${packageFile}`);
}

console.log(`plannotator current: ${currentVersion}`);
console.log(`plannotator latest:  ${version}`);

const releaseBase = `https://github.com/backnotprop/plannotator/releases/download/${tag}`;
for (const [system, source] of Object.entries(sources)) {
  const checksumUrl = `${releaseBase}/${source.artifact}.sha256`;
  const hash = checksumToSri(await fetchText(checksumUrl), checksumUrl);
  const block = new RegExp(`("${system}" = \\{[\\s\\S]*?hash = ")[^"]+(";)`);
  if (!block.test(packageText)) {
    throw new Error(`Could not find the ${system} source block in ${packageFile}`);
  }
  packageText = packageText.replace(block, `$1${hash}$2`);
}

const sourceUrl = `https://github.com/backnotprop/plannotator/archive/refs/tags/${tag}.tar.gz`;
const sourcePrefetch = JSON.parse(
  commandOutput(["nix", "store", "prefetch-file", "--unpack", "--json", sourceUrl], root),
) as { hash?: string };
if (sourcePrefetch.hash === undefined || sourcePrefetch.hash === "") {
  throw new Error(`Could not determine the source hash for ${sourceUrl}`);
}

packageText = packageText
  .replace(/^(  version = ")[^"]+(";)$/m, `$1${version}$2`)
  .replace(
    /^(    hash = ")[^"]+(";\n  \};\n\n  nativeBuildInputs)/m,
    `$1${sourcePrefetch.hash}$2`,
  );

await Bun.write(packageFile, packageText);
console.log(`Updated ${packageFile}`);
