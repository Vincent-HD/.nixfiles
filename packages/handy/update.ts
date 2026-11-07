import { PrefetchResultSchema, UrlSchema, VersionSchema, z } from "../update-schema.ts";

const commandOutput = (command: string[]): string => {
  const result = Bun.spawnSync(command);
  if (!result.success) throw new Error("Command failed: " + command.join(" "));
  return new TextDecoder().decode(result.stdout).trim();
};

const releaseSchema = z.object({
  tag_name: z.string().regex(/^v\d+\.\d+\.\d+$/),
  assets: z.array(z.object({ name: z.string(), browser_download_url: UrlSchema })),
});
const response = await fetch("https://api.github.com/repos/cjpais/Handy/releases/latest", {
  headers: { "User-Agent": "nix-update" },
});
if (!response.ok) throw new Error("Handy releases: HTTP " + response.status);
const release = releaseSchema.parse(await response.json());
const version = VersionSchema.parse(release.tag_name.slice(1));
const root = commandOutput(["git", "rev-parse", "--show-toplevel"]);
const packageFile = root + "/packages/handy/default.nix";
let packageText = await Bun.file(packageFile).text();
const sources: Record<string, string> = {
  "x86_64-linux": `Handy_${version}_amd64.AppImage`,
  "aarch64-darwin": "Handy_aarch64.app.tar.gz",
};
for (const [system, assetName] of Object.entries(sources)) {
  const asset = release.assets.find((candidate) => candidate.name === assetName);
  if (!asset) throw new Error(`Missing ${system} release asset: ${assetName}`);
  const hash = PrefetchResultSchema.parse(
    JSON.parse(
      commandOutput(["nix", "store", "prefetch-file", "--json", asset.browser_download_url]),
    ),
  ).hash;
  const block = new RegExp(`("${system}" = \\{\\s*asset = ")[^"]+(";\\s*hash = ")[^"]+(";)`);
  if (!block.test(packageText)) throw new Error(`Missing source block for ${system}`);
  packageText = packageText.replace(block, `$1${assetName}$2${hash}$3`);
  console.log(`${system}: ${hash}`);
}
packageText = packageText.replace(/^    version = "[^"]+";$/m, `    version = "${version}";`);
await Bun.write(packageFile, packageText);
