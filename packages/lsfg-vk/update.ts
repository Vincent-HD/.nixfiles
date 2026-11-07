import { PrefetchResultSchema, UrlSchema, VersionSchema, z } from "../update-schema.ts";

const commandOutput = (command: string[]): string => {
  const result = Bun.spawnSync(command);
  if (!result.success) throw new Error(`Command failed: ${command.join(" ")}`);
  return new TextDecoder().decode(result.stdout).trim();
};
const response = await fetch("https://builds.lsfg-vk.dev/");
if (!response.ok) throw new Error(`Could not read releases: HTTP ${response.status}`);
const html = await response.text();
const version = html.match(
  /href="lsfg-vk-(\d+\.\d+\.\d+)\.tar\.xz">&gt;&gt; Latest release \([^)]+\) &lt;&lt;/,
)?.[1];
if (!version) throw new Error("Could not identify the latest stable LSFG-VK release");
VersionSchema.parse(version);
const url = UrlSchema.parse(`https://builds.lsfg-vk.dev/lsfg-vk-${version}.tar.xz`);
const result = PrefetchResultSchema.extend({
  storePath: z.string().startsWith("/nix/store/"),
}).parse(JSON.parse(commandOutput(["nix", "store", "prefetch-file", "--json", url])));
const files = new Set(
  commandOutput(["tar", "-tf", result.storePath])
    .split("\n")
    .map((file) => file.replace(/^\.\//, "")),
);
for (const file of [
  "bin/lsfg-vk-cli",
  "bin/lsfg-vk-ui",
  "lib/liblsfg-vk-layer.so",
  "lib/liblsfg-vk-layer.x86.so",
  "share/vulkan/implicit_layer.d/VkLayer_LSFGVK_frame_generation.json",
  "share/vulkan/implicit_layer.d/VkLayer_LSFGVK_frame_generation.x86.json",
]) {
  if (!files.has(file)) throw new Error(`Missing release artifact: ${file}`);
}
const root = commandOutput(["git", "rev-parse", "--show-toplevel"]);
const path = `${root}/packages/lsfg-vk/default.nix`;
let text = await Bun.file(path).text();
if (!/^  version = "[^"]+";$/m.test(text) || !/^    hash = "[^"]+";$/m.test(text))
  throw new Error("Could not find version and hash");
text = text
  .replace(/^  version = "[^"]+";$/m, `  version = "${version}";`)
  .replace(/^    hash = "[^"]+";$/m, `    hash = "${result.hash}";`);
await Bun.write(path, text);
console.log(`Updated LSFG-VK ${version}: ${result.hash}`);
