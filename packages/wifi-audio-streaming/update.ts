type Source = {
  suffix: string;
};

const sources: Record<string, Source> = {
  "x86_64-linux": { suffix: "-linux-x86_64.AppImage" },
  "aarch64-darwin": { suffix: "-macos-arm64.tar.gz" },
};

const commandOutput = (command: string[], cwd?: string): string => {
  const result = Bun.spawnSync(command, { cwd });
  if (!result.success) {
    throw new Error("Command failed: " + command.join(" "));
  }
  return new TextDecoder().decode(result.stdout).trim();
};

const currentSystem = (): string =>
  commandOutput(["nix", "eval", "--raw", "--impure", "--expr", "builtins.currentSystem"]);

const prefetchHash = (url: string, root: string): string => {
  const output = commandOutput(["nix", "store", "prefetch-file", "--json", url], root);
  const parsed = JSON.parse(output) as { hash?: string };
  if (parsed.hash === undefined || parsed.hash === "") {
    throw new Error("Could not determine the hash for " + url);
  }
  return parsed.hash;
};

const latestRelease = async (): Promise<{ tag: string; assetsHtml: string }> => {
  const response = await fetch(
    "https://github.com/marcomorosi06/WiFiAudioStreaming-Desktop/releases/latest",
    { headers: { "User-Agent": "nix-update" } },
  );
  if (!response.ok) {
    throw new Error("Could not read WiFi Audio Streaming releases: HTTP " + response.status);
  }

  const tag = new URL(response.url).pathname.split("/").at(-1);
  if (tag === undefined || tag === "" || tag === "latest") {
    throw new Error("Could not resolve the latest WiFi Audio Streaming release tag");
  }

  const assetsResponse = await fetch(
    "https://github.com/marcomorosi06/WiFiAudioStreaming-Desktop/releases/expanded_assets/" + tag,
    { headers: { "User-Agent": "nix-update" } },
  );
  if (!assetsResponse.ok) {
    throw new Error("Could not read release assets for " + tag + ": HTTP " + assetsResponse.status);
  }

  return { tag, assetsHtml: await assetsResponse.text() };
};

const root = commandOutput(["git", "rev-parse", "--show-toplevel"]);
const packageFile = root + "/packages/wifi-audio-streaming/default.nix";
let packageText = await Bun.file(packageFile).text();
const currentVersion = packageText.match(/^    version = "([^"]+)";$/m)?.[1];
const currentTag = packageText.match(/^    releaseTag = "([^"]+)";$/m)?.[1];
if (currentVersion === undefined || currentTag === undefined) {
  throw new Error("Could not read the current version and release tag from " + packageFile);
}

const system = currentSystem();
const source = sources[system];
if (source === undefined) {
  throw new Error("WiFi Audio Streaming has no pinned artifact for " + system);
}

const release = await latestRelease();
const assetLink = Array.from(
  release.assetsHtml.matchAll(
    /href="([^" ]*\/releases\/download\/([^/]+)\/(WiFi-Audio-Streaming-[^"? ]+))"/g,
  ),
)
  .map(match => ({ url: "https://github.com" + match[1], tag: match[2], name: match[3] }))
  .find(
    candidate =>
      candidate.tag === release.tag &&
      candidate.name.startsWith("WiFi-Audio-Streaming-") &&
      candidate.name.endsWith(source.suffix),
  );
if (assetLink === undefined) {
  throw new Error("Could not find the " + system + " asset in " + release.tag);
}

const assetPrefix = "WiFi-Audio-Streaming-";
const version = assetLink.name.slice(assetPrefix.length, -source.suffix.length);
if (!/^\d+\.\d+\.\d+(?:-[\w.-]+)?$/.test(version)) {
  throw new Error("Could not parse a semantic version from " + assetLink.name);
}

const hash = prefetchHash(assetLink.url, root);
const sourceBlock = new RegExp('("' + system + '" = \\{[\\s\\S]*?hash = ")[^"]+(";)');
if (!sourceBlock.test(packageText)) {
  throw new Error("Could not find the " + system + " source block in " + packageFile);
}

packageText = packageText.replace(sourceBlock, "$1" + hash + "$2");
packageText = packageText.replace(/^    version = "[^"]+";$/m, '    version = "' + version + '";');
packageText = packageText.replace(/^    releaseTag = "[^"]+";$/m, '    releaseTag = "' + release.tag + '";');

await Bun.write(packageFile, packageText);
console.log("Updated " + packageFile + " for " + system + " to " + version + " (" + release.tag + ").");
