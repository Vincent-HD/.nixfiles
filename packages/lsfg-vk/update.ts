import { $ } from "bun";

type PrefetchResult = {
  hash?: string;
};

type SourceTag = {
  name: string;
  object: string;
  revision: string;
};

const sourceUrl = "https://git.lsfg-vk.dev/lsfg-vk.git";
const v2TagPattern = /^2\.\d+\.\d+(?:-rc(\d+))?$/;

const compareTags = (left: SourceTag, right: SourceTag): number => {
  const leftMatch = v2TagPattern.exec(left.name);
  const rightMatch = v2TagPattern.exec(right.name);
  if (leftMatch === null || rightMatch === null) return 0;

  const leftParts = left.name.split(".").map((part) => Number.parseInt(part, 10));
  const rightParts = right.name.split(".").map((part) => Number.parseInt(part, 10));
  for (let index = 0; index < leftParts.length; index += 1) {
    if (leftParts[index] !== rightParts[index]) {
      return leftParts[index] - rightParts[index];
    }
  }

  const leftReleaseCandidate = leftMatch[1] === undefined ? Number.MAX_SAFE_INTEGER : Number.parseInt(leftMatch[1], 10);
  const rightReleaseCandidate = rightMatch[1] === undefined ? Number.MAX_SAFE_INTEGER : Number.parseInt(rightMatch[1], 10);
  return leftReleaseCandidate - rightReleaseCandidate;
};

const remoteTags = (await $`git ls-remote --tags ${sourceUrl}`.text())
  .split("\n")
  .map((line) => line.trim())
  .filter((line) => line.length > 0)
  .map((line) => {
    const [object, ref] = line.split("\t");
    const dereferenced = ref.endsWith("^{}");
    const name = ref.replace(/^refs\/tags\//, "").replace(/\^\{\}$/, "");
    return { dereferenced, name, object };
  });

const tags = new Map<string, { object?: string; revision?: string }>();
for (const tag of remoteTags) {
  if (!v2TagPattern.test(tag.name)) continue;
  const entry = tags.get(tag.name) ?? {};
  if (tag.dereferenced) {
    entry.revision = tag.object;
  } else {
    entry.object = tag.object;
  }
  tags.set(tag.name, entry);
}

const latest = [...tags.entries()]
  .map(([name, refs]) => ({ name, object: refs.object ?? "", revision: refs.revision ?? refs.object ?? "" }))
  .filter((tag) => tag.revision.length > 0)
  .sort(compareTags)
  .at(-1);
if (latest === undefined) {
  throw new Error(`Could not find a v2 release tag in ${sourceUrl}`);
}

const root = (await $`git rev-parse --show-toplevel`.text()).trim();
const packageFile = `${root}/packages/lsfg-vk/default.nix`;
let packageText = await Bun.file(packageFile).text();
const currentVersion = packageText.match(/^  version = "([^"]+)";$/m)?.[1];
const currentRevision = packageText.match(/^    rev = "([^"]+)";$/m)?.[1];
if (currentVersion === undefined || currentRevision === undefined) {
  throw new Error(`Could not read the current version and revision from ${packageFile}`);
}

console.log(`lsfg-vk current: ${currentVersion} (${currentRevision})`);
console.log(`lsfg-vk latest:  ${latest.name} (${latest.revision})`);

const prefetch = JSON.parse(
  await $`nix-prefetch-git --url ${sourceUrl} --rev ${latest.revision} --no-deepClone`.text(),
) as PrefetchResult;
if (prefetch.hash === undefined || prefetch.hash === "") {
  throw new Error(`Could not determine the source hash for ${latest.revision}`);
}

packageText = packageText
  .replace(/^(  version = ")[^"]+(";)$/m, `$1${latest.name}$2`)
  .replace(/^(    rev = ")[^"]+(";)$/m, `$1${latest.revision}$2`)
  .replace(/^(    hash = ")[^"]+(";)$/m, `$1${prefetch.hash}$2`);

await Bun.write(packageFile, packageText);
console.log(`Updated ${packageFile}`);
