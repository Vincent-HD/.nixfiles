import { Sha256HashSchema, VersionSchema, z } from "../update-schema.ts";

// GitHub records a sha256 digest for every release asset, so no artifact download is needed.
const githubHeaders = { "User-Agent": "nix-update" };
const releaseSchema = z.object({
  tag_name: z.string().regex(/^v\d+\.\d+\.\d+$/),
  assets: z.array(z.object({ name: z.string(), digest: z.string().regex(/^sha256:[0-9a-f]{64}$/) })),
});
const releaseResponse = await fetch("https://api.github.com/repos/ibisjp/ibis-office/releases/latest", {
  headers: githubHeaders,
});
if (!releaseResponse.ok) throw new Error("ibisOffice releases: HTTP " + releaseResponse.status);
const release = releaseSchema.parse(await releaseResponse.json());
const version = VersionSchema.parse(release.tag_name.slice(1));
const digests = new Map(release.assets.map((asset) => [asset.name, asset.digest.slice("sha256:".length)]));

const result = Bun.spawnSync(["git", "rev-parse", "--show-toplevel"]);
if (!result.success) throw new Error("git rev-parse failed");
const packageFile = new TextDecoder().decode(result.stdout).trim() + "/packages/ibis-office/default.nix";
let packageText = await Bun.file(packageFile).text();

for (const [system, asset] of Object.entries({ "x86_64-linux": "Linux.AppImage", "aarch64-darwin": "macOS.zip" })) {
  const assetName = `ibisOffice-${version}-${asset}`;
  const hex = z.string().parse(digests.get(assetName));
  const hash = Sha256HashSchema.parse("sha256-" + Buffer.from(hex, "hex").toString("base64"));
  const block = new RegExp(`("${system}" = \\{\\s*asset = "${asset.replace(".", "\\.")}";\\s*hash = ")[^"]+(";)`);
  if (!block.test(packageText)) throw new Error(`Missing source block for ${system}`);
  packageText = packageText.replace(block, `$1${hash}$2`);
  console.log(`${assetName}: ${hash}`);
}
packageText = packageText.replace(/^  version = "[^"]+";$/m, `  version = "${version}";`);
await Bun.write(packageFile, packageText);
