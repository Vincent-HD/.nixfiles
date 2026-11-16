import { VersionSchema, z } from "../update-schema.ts";

const appName = z.string().regex(/^[a-z]+craft$/).parse(Bun.argv[3]);

const commandOutput = (command: string[]): string => {
  const result = Bun.spawnSync(command);
  if (!result.success) throw new Error("Command failed: " + command.join(" "));
  return new TextDecoder().decode(result.stdout).trim();
};

const githubHeaders = { "User-Agent": "nix-update" };
const releaseSchema = z.object({ tag_name: z.string().regex(/^v\d+\.\d+\.\d+$/) });
const releaseResponse = await fetch(
  `https://api.github.com/repos/storytold/${appName}/releases/latest`,
  { headers: githubHeaders },
);
if (!releaseResponse.ok) throw new Error(`${appName} releases: HTTP ${releaseResponse.status}`);
const version = VersionSchema.parse(releaseSchema.parse(await releaseResponse.json()).tag_name.slice(1));

// Upstream publishes SHA256SUMS.txt per release, so no artifact download is needed.
const checksumsResponse = await fetch(
  `https://github.com/storytold/${appName}/releases/download/v${version}/SHA256SUMS.txt`,
  { headers: githubHeaders },
);
if (!checksumsResponse.ok) throw new Error(`${appName} checksums: HTTP ${checksumsResponse.status}`);
const checksums = new Map(
  (await checksumsResponse.text())
    .split("\n")
    .map((line) => line.trim().split(/\s+/))
    .filter((fields) => fields.length === 2)
    .map((fields) => [fields[1], fields[0]]),
);

const sourcesFile = commandOutput(["git", "rev-parse", "--show-toplevel"]) + "/packages/craft-apps/sources.json";
const sourcesSchema = z.record(
  z.string(),
  z.object({
    displayName: z.string(),
    description: z.string(),
    version: VersionSchema,
    hashes: z.record(z.string(), z.string()),
  }),
);
const sources = sourcesSchema.parse(await Bun.file(sourcesFile).json());
const app = sources[appName];
if (app === undefined) throw new Error(`Missing ${appName} entry in sources.json`);

for (const artifact of Object.keys(app.hashes)) {
  const assetName = `${appName}-${version}-${artifact}`;
  const hex = z.string().regex(/^[0-9a-f]{64}$/).parse(checksums.get(assetName));
  app.hashes[artifact] = "sha256-" + Buffer.from(hex, "hex").toString("base64");
  console.log(`${assetName}: ${app.hashes[artifact]}`);
}
app.version = version;
await Bun.write(sourcesFile, JSON.stringify(sources, null, 2) + "\n");
