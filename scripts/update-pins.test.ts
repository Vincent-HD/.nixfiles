import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { chmod, mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { delimiter, join } from "node:path";
import { fileURLToPath } from "node:url";

type Fixture = {
  root: string;
  fakeBin: string;
  updater: string;
  flakeUpdateLog: string;
  packageLog: string;
};

const updatePinsScript = fileURLToPath(new URL("./update-pins.ts", import.meta.url));
let fixture: Fixture;

const writeExecutable = async ({ path, content }: { path: string; content: string }) => {
  await writeFile(path, content);
  await chmod(path, 0o755);
};

const writeRegistry = async (registry: unknown) =>
  writeFile(join(fixture.root, "scripts", "update-pins.json"), JSON.stringify(registry, null, 2));

const writePackages = async (packages: Record<string, { command: string[] | null }>) =>
  writeFile(
    join(fixture.root, "packages.json"),
    JSON.stringify({ updater: fixture.updater, allPackages: Object.keys(packages), packages }),
  );

const createFixture = async (): Promise<Fixture> => {
  const root = await mkdtemp(join(tmpdir(), "update-pins-test-"));
  const fakeBin = join(root, "fake-bin");
  const updater = join(root, "package-updater");
  const flakeUpdateLog = join(root, "flake-update.log");
  const packageLog = join(root, "package.log");
  await mkdir(join(root, "scripts"), { recursive: true });
  await mkdir(fakeBin, { recursive: true });

  await writeFile(
    join(root, "flake.lock"),
    JSON.stringify({
      nodes: {
        root: { inputs: { nixpkgs: "nixpkgs", noctalia: "noctalia", herdr: "herdr", follower: ["nixpkgs"] } },
        nixpkgs: { original: { type: "github", owner: "NixOS", repo: "nixpkgs" } },
        noctalia: { original: { type: "github", owner: "noctalia-dev", repo: "noctalia-shell", rev: "0".repeat(40) } },
        herdr: { original: { type: "github", owner: "ogulcancelik", repo: "herdr", ref: "v0.7.3" } },
      },
    }),
  );
  // A stand-in for nix: answers the system query, serves the discovered packages, and records lock updates.
  await writeExecutable({
    path: join(fakeBin, "nix"),
    content: `#!/bin/sh
case "$*" in
  *builtins.currentSystem*) printf 'x86_64-linux' ;;
  "eval --json .#packages --apply"*) cat "${join(root, "packages.json")}" ;;
  "flake update"*) shift 2; printf '%s\\n' "$*" >> "${flakeUpdateLog}" ;;
  "build "*) ;;
  *) echo "unexpected nix call: $*" >&2; exit 64 ;;
esac
`,
  });
  await writeExecutable({ path: updater, content: `#!/bin/sh\nprintf '%s\\n' "$*" >> "${packageLog}"\necho "updated $*"\n` });
  return { root, fakeBin, updater, flakeUpdateLog, packageLog };
};

const runUpdatePins = async (args: string[]) => {
  const child = Bun.spawn([process.execPath, updatePinsScript, ...args], {
    cwd: fixture.root,
    env: {
      ...process.env,
      UPDATE_PINS_REPO_ROOT: fixture.root,
      GITHUB_TOKEN: "test",
      PATH: `${fixture.fakeBin}${delimiter}${process.env.PATH ?? ""}`,
    },
    stdout: "pipe",
    stderr: "pipe",
  });
  const [stdout, stderr, exitCode] = await Promise.all([
    new Response(child.stdout).text(),
    new Response(child.stderr).text(),
    child.exited,
  ]);
  return { stdout, stderr, exitCode };
};

const readLog = (path: string) => readFile(path, "utf8").catch(() => "");

beforeEach(async () => {
  fixture = await createFixture();
  await writeRegistry({ holds: { herdr: "tag-pinned" }, validations: {} });
  await writePackages({ lightjj: { command: [fixture.updater, "--attr=lightjj"] } });
});

afterEach(async () => {
  await rm(fixture.root, { recursive: true, force: true });
});

describe("update-pins", () => {
  test("updates unpinned inputs in one lock refresh, then every package through its updater", async () => {
    const result = await runUpdatePins([]);

    expect(result.exitCode).toBe(0);
    expect(await readLog(fixture.flakeUpdateLog)).toBe("nixpkgs\n");
    expect(await readLog(fixture.packageLog)).toBe("--attr=lightjj\n");
    expect(result.stdout).toContain("skipped herdr (held: tag-pinned)");
    expect(result.stdout).toContain("skipped noctalia (pinned: pinned to a commit in flake.nix)");
  });

  test("fails the drift check for a package without the shared updater", async () => {
    await writePackages({
      lightjj: { command: [fixture.updater, "--attr=lightjj"] },
      orphan: { command: null },
      custom: { command: ["/nix/store/custom-update.sh"] },
    });

    const result = await runUpdatePins(["--check"]);

    expect(result.exitCode).toBe(2);
    expect(result.stderr).toContain('package "orphan" has no passthru.updateScript');
    expect(result.stderr).toContain('package "custom" has a custom updateScript');
  });

  test("rejects holds that name no input or package", async () => {
    await writeRegistry({ holds: { herdr: "tag-pinned", removed: "stale" }, validations: {} });

    const result = await runUpdatePins(["--check"]);

    expect(result.exitCode).toBe(2);
    expect(result.stderr).toContain('hold "removed" matches no flake input or package');
  });

  test("rejects an invalid registry before running anything", async () => {
    await writeRegistry({ holds: { herdr: 17 } });

    const result = await runUpdatePins([]);

    expect(result.exitCode).toBe(2);
    expect(result.stderr).toContain("Invalid update registry: holds.herdr must be a non-empty reason");
    expect(await readLog(fixture.packageLog)).toBe("");
  });

  test("refuses a selection with nothing runnable and skips validation", async () => {
    const result = await runUpdatePins(["--only", "herdr", "--validate", "fast"]);

    expect(result.exitCode).toBe(2);
    expect(result.stderr).toContain("validation was not run");
    expect(await readLog(fixture.flakeUpdateLog)).toBe("");
  });

  test("combines --inputs with named packages", async () => {
    await writePackages({
      lightjj: { command: [fixture.updater, "--attr=lightjj"] },
      codex: { command: [fixture.updater, "--attr=codex"] },
    });

    const result = await runUpdatePins(["--inputs", "--only", "codex"]);

    expect(result.exitCode).toBe(0);
    expect(await readLog(fixture.flakeUpdateLog)).toBe("nixpkgs\n");
    expect(await readLog(fixture.packageLog)).toBe("--attr=codex\n");
  });

  test("reports unknown names passed to --only", async () => {
    const result = await runUpdatePins(["--only", "missing"]);

    expect(result.exitCode).toBe(2);
    expect(result.stderr).toContain("Unknown inputs or packages: missing");
  });
});
