import { $ } from "bun";
import { parseArgs as parseArgv } from "util";

type Options = {
  checkOnly: boolean;
  dryRun: boolean;
};

type CurseForgeState = {
  version: string;
  build: string;
};

function usage(): string {
  return `Usage: update.ts [--check] [--dry-run]

Updates packages/curseforge/default.nix from CurseForge's Linux update metadata.

Options:
  --check    Print the current and latest versions without prefetching or editing.
  --dry-run  Prefetch and print the change without editing default.nix.
  -h, --help Show this help.
`;
}

function parseOptions(argv: string[]): Options | "help" {
  const { values } = parseArgv({
    args: argv,
    options: {
      check: {
        type: "boolean",
        default: false,
      },
      "dry-run": {
        type: "boolean",
        default: false,
      },
      help: {
        type: "boolean",
        short: "h",
        default: false,
      },
    },
    strict: true,
    allowPositionals: false,
  });

  if (values.help === true) {
    return "help";
  }

  return {
    checkOnly: values.check === true,
    dryRun: values["dry-run"] === true,
  };
}

async function repoRoot(): Promise<string> {
  if (Bun.env.CURSEFORGE_REPO_ROOT !== undefined && Bun.env.CURSEFORGE_REPO_ROOT !== "") {
    return Bun.env.CURSEFORGE_REPO_ROOT;
  }

  try {
    return (await $`git rev-parse --show-toplevel`.text()).trim();
  } catch {
    return Bun.env.PWD ?? ".";
  }
}

function repoPath(root: string, ...segments: string[]): string {
  return `${root.replace(/\/+$/, "")}/${segments.join("/")}`;
}

function readCurrentState(packageText: string, packageFile: string): CurseForgeState {
  const version = packageText.match(/^    version = "([^"]+)";$/m)?.[1];
  const build = packageText.match(/^    build = "([^"]+)";$/m)?.[1];

  if (version === undefined || build === undefined) {
    throw new Error(`Could not read current CurseForge version/build from ${packageFile}`);
  }

  return { version, build };
}

function readLatestState(metadata: string, metadataUrl: string): CurseForgeState & { path: string } {
  const fullVersion = metadata.match(/^version:\s*([^\s]+)$/m)?.[1];
  const latestPath = metadata.match(/^\s*path:\s*([^\s]+)$/m)?.[1];

  if (fullVersion === undefined || latestPath === undefined) {
    throw new Error(`Could not read latest CurseForge version/path from ${metadataUrl}`);
  }

  const version = fullVersion.replace(/-[^-]+$/, "");
  const build = fullVersion.slice(version.length + 1);

  if (version === fullVersion || build.length === 0) {
    throw new Error(`Could not split CurseForge version/build from ${fullVersion}`);
  }

  return { version, build, path: latestPath };
}

async function prefetchHash(url: string, root: string): Promise<string> {
  const output = (await $`cd ${root} && nix store prefetch-file --json ${url}`.text()).trim();
  const parsed = JSON.parse(output) as { hash?: string };
  if (parsed.hash === undefined || parsed.hash === "") {
    throw new Error(`Could not determine hash for ${url}`);
  }
  return parsed.hash;
}

function updatedPackageText(packageText: string, latest: CurseForgeState, hash: string): string {
  return packageText
    .replace(/^(    version = ")[^"]+(";)$/m, `$1${latest.version}$2`)
    .replace(/^(    build = ")[^"]+(";)$/m, `$1${latest.build}$2`)
    .replace(/^(      hash = ")[^"]+(";)$/m, `$1${hash}$2`);
}

async function main(): Promise<void> {
  let options: Options;
  try {
    const parsed = parseOptions(Bun.argv.slice(2));
    if (parsed === "help") {
      await Bun.write(Bun.stdout, usage());
      return;
    }
    options = parsed;
  } catch (error) {
    await Bun.write(Bun.stderr, `${error instanceof Error ? error.message : String(error)}\n${usage()}`);
    process.exitCode = 2;
    return;
  }

  const root = await repoRoot();
  const packageFile = repoPath(root, "packages", "curseforge", "default.nix");
  const packageText = await Bun.file(packageFile).text();
  const current = readCurrentState(packageText, packageFile);

  const metadataUrl = "https://curseforge.overwolf.com/electron/linux/latest-linux.yml";
  const response = await fetch(metadataUrl);
  if (!response.ok) {
    throw new Error(`Could not fetch ${metadataUrl}: HTTP ${response.status}`);
  }

  const latest = readLatestState(await response.text(), metadataUrl);

  console.log(`curseforge current: ${current.version}-${current.build}`);
  console.log(`curseforge latest:  ${latest.version}-${latest.build}`);

  if (`${current.version}-${current.build}` === `${latest.version}-${latest.build}`) {
    console.log("curseforge is already up to date.");
    return;
  }

  if (options.checkOnly) {
    return;
  }

  const appImageUrl = `https://curseforge.overwolf.com/electron/linux/${latest.path}`;
  const hash = await prefetchHash(appImageUrl, root);
  console.log(`curseforge hash:    ${hash}`);

  if (options.dryRun) {
    console.log(`Dry run: would update ${packageFile}`);
    return;
  }

  await Bun.write(packageFile, updatedPackageText(packageText, latest, hash));
  console.log(`Updated ${packageFile}`);
}

await main();
