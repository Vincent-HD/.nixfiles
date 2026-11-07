import { PrefetchResultSchema, UrlSchema, VersionSchema, z } from "../update-schema.ts";
const commandOutput = (command: string[]): string => {
  const result = Bun.spawnSync(command);
  if (!result.success) throw new Error(`Command failed: ${command.join(" ")}`);
  return new TextDecoder().decode(result.stdout).trim();
};
const response = await fetch("https://api.github.com/repos/duxlabs-dev/dux-shell/releases/latest", {
  headers: { "User-Agent": "nix-update" },
});
if (!response.ok) throw new Error(`DMS releases: HTTP ${response.status}`);
const release = z
  .object({
    tag_name: z.string().regex(/^v\d+\.\d+\.\d+$/),
    assets: z.array(z.object({ name: z.string(), browser_download_url: UrlSchema })),
  })
  .parse(await response.json());
const version = VersionSchema.parse(release.tag_name.slice(1));
const refs = commandOutput([
  "git",
  "ls-remote",
  "https://github.com/duxlabs-dev/dux-shell.git",
  `refs/tags/${release.tag_name}`,
  `refs/tags/${release.tag_name}^{}`,
]).split("\n");
const refLine =
  refs.find((line) => line.endsWith(`refs/tags/${release.tag_name}^{}`)) ??
  refs.find((line) => line.endsWith(`refs/tags/${release.tag_name}`));
const revision = refLine?.split("\t")[0];
if (!revision || !/^[0-9a-f]{40}$/.test(revision))
  throw new Error("Could not resolve release commit");
const stableRevision = commandOutput([
  "git",
  "ls-remote",
  "https://github.com/duxlabs-dev/dux-shell.git",
  "refs/heads/stable",
]).split("\t")[0];
if (stableRevision !== revision)
  throw new Error("The stable DMS flake is not at the latest release commit");
const root = commandOutput(["git", "rev-parse", "--show-toplevel"]);
const packageFile = `${root}/packages/dms-prebuilt/default.nix`;
const lockFile = `${root}/flake.lock`;
const oldLock = await Bun.file(lockFile).text();
let text = await Bun.file(packageFile).text();
for (const [system, name] of Object.entries({
  "x86_64-linux": "dms-full-amd64.tar.gz",
  "aarch64-linux": "dms-full-arm64.tar.gz",
})) {
  const asset = release.assets.find((item) => item.name === name);
  if (!asset) throw new Error(`Missing ${system} asset ${name}`);
  const prefetched = PrefetchResultSchema.extend({
    storePath: z.string().startsWith("/nix/store/"),
  }).parse(
    JSON.parse(
      commandOutput(["nix", "store", "prefetch-file", "--json", asset.browser_download_url]),
    ),
  );
  const files = commandOutput(["tar", "-tzf", prefetched.storePath]).split("\n");
  if (!files.includes("./bin/dms")) throw new Error(`Missing DMS CLI in ${system} archive`);
  const pattern = new RegExp(`("${system}" = \\{\\s*asset = "[^"]+";\\s*hash = ")[^"]+(";)`);
  if (!pattern.test(text)) throw new Error(`Missing source block: ${system}`);
  text = text.replace(pattern, `$1${prefetched.hash}$2`);
}
if (!/^  version = "[^"]+";$/m.test(text) || !/^  revision = "[^"]+";$/m.test(text))
  throw new Error("Missing DMS version or revision");
text = text
  .replace(/^  version = "[^"]+";$/m, `  version = "${version}";`)
  .replace(/^  revision = "[^"]+";$/m, `  revision = "${revision}";`);
if (Bun.env.DMS_UPDATE_CHECK_ONLY !== "1") {
  try {
    commandOutput(["nix", "flake", "update", "dms", "--flake", root]);
    const lock = JSON.parse(await Bun.file(lockFile).text());
    if (lock.nodes[lock.nodes.root.inputs.dms].locked.rev !== revision)
      throw new Error("The stable DMS flake is not at the latest release commit");
    await Bun.write(packageFile, text);
  } catch (error) {
    await Bun.write(lockFile, oldLock);
    throw error;
  }
}
console.log(`Verified DMS ${version} (${revision}) on both platforms`);
