import { Sha256HashSchema, VersionSchema, z } from "../update-schema.ts";

// Updates the OpenPencil app artifacts and the version-matched MCP server closure together.
const commandOutput = (command: string[], cwd?: string): string => {
  const result = Bun.spawnSync(command, { cwd });
  if (!result.success) {
    throw new Error("Command failed: " + command.join(" ") + "\n" + new TextDecoder().decode(result.stderr));
  }
  return new TextDecoder().decode(result.stdout).trim();
};

const githubHeaders = { "User-Agent": "nix-update" };
const releaseSchema = z.object({ tag_name: z.string().regex(/^v\d+\.\d+\.\d+$/) });
const releaseResponse = await fetch("https://api.github.com/repos/open-pencil/open-pencil/releases/latest", {
  headers: githubHeaders,
});
if (!releaseResponse.ok) throw new Error("OpenPencil releases: HTTP " + releaseResponse.status);
const version = VersionSchema.parse(releaseSchema.parse(await releaseResponse.json()).tag_name.slice(1));

const checksumsResponse = await fetch(
  `https://github.com/open-pencil/open-pencil/releases/download/v${version}/SHA256SUMS`,
  { headers: githubHeaders },
);
if (!checksumsResponse.ok) throw new Error("OpenPencil checksums: HTTP " + checksumsResponse.status);
const checksums = new Map(
  (await checksumsResponse.text())
    .split("\n")
    .map((line) => line.trim().split(/\s+/))
    .filter((fields) => fields.length === 2)
    .map((fields) => [fields[1], fields[0]]),
);

const root = commandOutput(["git", "rev-parse", "--show-toplevel"]);
const appFile = `${root}/packages/open-pencil/default.nix`;
let appText = await Bun.file(appFile).text();
const assets: Record<string, string> = {
  "x86_64-linux": `OpenPencil_${version}_amd64.deb`,
  "aarch64-darwin": "OpenPencil_aarch64.app.tar.gz",
  "x86_64-darwin": "OpenPencil_x64.app.tar.gz",
};
for (const [system, assetName] of Object.entries(assets)) {
  const hex = z.string().regex(/^[0-9a-f]{64}$/).parse(checksums.get(assetName));
  const hash = Sha256HashSchema.parse("sha256-" + Buffer.from(hex, "hex").toString("base64"));
  const block = new RegExp(`("${system}" = \\{\\s*asset = ")[^"]+(";\\s*hash = ")[^"]+(";)`);
  if (!block.test(appText)) throw new Error(`Missing source block for ${system}`);
  appText = appText.replace(block, `$1${assetName}$2${hash}$3`);
  console.log(`${assetName}: ${hash}`);
}
appText = appText.replace(/^  version = "[^"]+";$/m, `  version = "${version}";`);
await Bun.write(appFile, appText);

// Regenerate the MCP lockfile for the same version, then refresh its npm dependency hash.
const mcpDirectory = `${root}/packages/open-pencil/mcp`;
const closure = {
  name: "open-pencil-mcp-closure",
  version,
  private: true,
  dependencies: { "@open-pencil/mcp": version },
};
await Bun.write(`${mcpDirectory}/package.json`, JSON.stringify(closure, null, 2) + "\n");
commandOutput(
  ["nix", "shell", "nixpkgs#nodejs_24", "--command", "npm", "install", "--package-lock-only", "--ignore-scripts", "--no-audit", "--no-fund"],
  mcpDirectory,
);
const npmDepsHash = Sha256HashSchema.parse(
  commandOutput(["nix", "shell", "nixpkgs#prefetch-npm-deps", "--command", "prefetch-npm-deps", `${mcpDirectory}/package-lock.json`])
    .split("\n")
    .at(-1),
);
const mcpFile = `${mcpDirectory}/default.nix`;
const mcpText = (await Bun.file(mcpFile).text()).replace(/npmDepsHash = "[^"]+";/, `npmDepsHash = "${npmDepsHash}";`);
await Bun.write(mcpFile, mcpText);
console.log(`open-pencil-mcp ${version}: ${npmDepsHash}`);
