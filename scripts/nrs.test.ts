import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { execFileSync } from "node:child_process";
import { chmod, mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { delimiter, join } from "node:path";
import { fileURLToPath } from "node:url";

type Fixture = {
  root: string;
  flakeRoot: string;
  callerDirectory: string;
  fakeBin: string;
  nixLog: string;
  nixEnvironmentLog: string;
  nhLog: string;
};

const nrsScriptPath =
  Bun.env.NRS_SCRIPT_PATH ?? fileURLToPath(new URL("../modules/command-line/assets/nrs", import.meta.url));
const bashExecutable = execFileSync("bash", ["-c", "command -v bash"], { encoding: "utf8" }).trim();

let fixture: Fixture;

const writeExecutable = async ({ path, content }: { path: string; content: string }) => {
  await writeFile(path, content);
  await chmod(path, 0o755);
};

// Fake nix and nh record each argv as NUL-separated fields, one empty field per call.
const recorder = (logVariable: string) =>
  [`#!${bashExecutable}`, `printf '%s\\0' "$@" >> "$${logVariable}"`, `printf '\\0' >> "$${logVariable}"`, ""].join("\n");

const createFixture = async (): Promise<Fixture> => {
  const root = await mkdtemp(join(tmpdir(), "nrs-behavior-test-"));
  const flakeRoot = join(root, "flake root with spaces");
  const callerDirectory = join(root, "unrelated-working-directory");
  const fakeBin = join(root, "fake-bin");
  await mkdir(flakeRoot, { recursive: true });
  await mkdir(callerDirectory, { recursive: true });
  await mkdir(fakeBin, { recursive: true });
  await writeFile(join(flakeRoot, "flake.nix"), '{ description = "test"; }\n');
  await writeExecutable({
    path: join(fakeBin, "nix"),
    content: `${recorder("NRS_NIX_ARGV_LOG")}printf '%s\\0\\0' "\${UPDATE_PINS_REPO_ROOT:-<empty>}" >> "$NRS_NIX_ENV_LOG"\n`,
  });
  await writeExecutable({ path: join(fakeBin, "nh"), content: recorder("NRS_NH_ARGV_LOG") });
  await writeExecutable({ path: join(fakeBin, "uname"), content: `#!${bashExecutable}\nprintf 'Linux\\n'\n` });
  return {
    root,
    flakeRoot,
    callerDirectory,
    fakeBin,
    nixLog: join(root, "nix-argv.log"),
    nixEnvironmentLog: join(root, "nix-environment.log"),
    nhLog: join(root, "nh-argv.log"),
  };
};

const readGroups = async (path: string): Promise<string[][]> => {
  const groups: string[][] = [];
  let current: string[] = [];
  for (const field of (await readFile(path, "utf8").catch(() => "")).split("\0")) {
    if (field !== "") {
      current.push(field);
    } else if (current.length > 0) {
      groups.push(current);
      current = [];
    }
  }
  return groups;
};

const runNrs = async (args: string[]) => {
  await Promise.all([fixture.nixLog, fixture.nixEnvironmentLog, fixture.nhLog].map((path) => writeFile(path, "")));
  const child = Bun.spawn(["bash", nrsScriptPath, ...args], {
    cwd: fixture.callerDirectory,
    env: {
      ...process.env,
      NH_FLAKE: fixture.flakeRoot,
      UPDATE_PINS_REPO_ROOT: "",
      PATH: `${fixture.fakeBin}${delimiter}${process.env.PATH ?? ""}`,
      NRS_NIX_ARGV_LOG: fixture.nixLog,
      NRS_NIX_ENV_LOG: fixture.nixEnvironmentLog,
      NRS_NH_ARGV_LOG: fixture.nhLog,
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

const updatePinsCall = (...args: string[]) => [
  "run",
  "--no-write-lock-file",
  `${fixture.flakeRoot}#update-pins`,
  "--",
  ...args,
];

beforeEach(async () => {
  fixture = await createFixture();
});

afterEach(async () => {
  await rm(fixture.root, { recursive: true, force: true });
});

describe("nrs update interface", () => {
  test("lists updates through update-pins in NH_FLAKE from outside the checkout", async () => {
    const result = await runNrs(["--list-updates"]);

    expect(result.exitCode).toBe(0);
    expect(await readGroups(fixture.nixLog)).toEqual([updatePinsCall("--list")]);
    expect(await readGroups(fixture.nixEnvironmentLog)).toEqual([[fixture.flakeRoot]]);
  });

  test("maps all inputs and all pins to the update-pins kind selectors", async () => {
    const result = await runNrs(["--update", "--inputs", "all", "--pins", "all", "--dry-run"]);

    expect(result.exitCode).toBe(0);
    expect(await readGroups(fixture.nixLog)).toEqual([updatePinsCall("--inputs", "--packages", "--dry-run")]);
    expect(await readGroups(fixture.nhLog)).toEqual([]);
  });

  test("maps named inputs and pins to --only and forwards --include-held", async () => {
    const result = await runNrs(["--update", "--inputs", "nixpkgs", "--pins", "codex", "--include-held"]);

    expect(result.exitCode).toBe(0);
    expect(await readGroups(fixture.nixLog)).toEqual([
      updatePinsCall("--only", "nixpkgs", "--only", "codex", "--include-held"),
    ]);
  });

  test("validates missing selectors, duplicates, lists, and incompatible options", async () => {
    const cases = [
      { args: ["--update"], error: "requires --inputs and/or --pins" },
      { args: ["--update", "--inputs", "a,b"], error: "one input name" },
      { args: ["--update", "--inputs"], error: "requires all or one input name" },
      { args: ["--update", "--pins", "codex", "--pins", "other"], error: "--pins may only be used once" },
      { args: ["--list-updates", "--dry-run"], error: "cannot be combined" },
      { args: ["--inputs", "all"], error: "require --update" },
      { args: ["--include-held"], error: "require --update" },
      { args: ["--update", "--inputs", "nixpkgs", "--ask"], error: "cannot be combined with switch or nh" },
      { args: ["--update", "--inputs", "nixpkgs", "--", "--dry-run"], error: "cannot be combined with switch or nh" },
    ];

    for (const { args, error } of cases) {
      const result = await runNrs(args);
      expect(result.exitCode).toBe(2);
      expect(result.stderr).toContain(error);
      expect(await readGroups(fixture.nixLog)).toEqual([]);
      expect(await readGroups(fixture.nhLog)).toEqual([]);
    }
  });

  test("rejects removed T3 Code patch overrides before calling nh", async () => {
    const result = await runNrs(["--no-t3-usage", "--dry-run", "--ask"]);

    expect(result.exitCode).toBe(2);
    expect(result.stderr).toContain("T3 Code patch overrides were removed");
    expect(await readGroups(fixture.nhLog)).toEqual([]);
    expect(await readGroups(fixture.nixLog)).toEqual([]);
  });

  test("uses --dry-run as an nh option when no update mode is selected", async () => {
    const result = await runNrs(["--dry-run", "--ask"]);

    expect(result.exitCode).toBe(0);
    expect(await readGroups(fixture.nhLog)).toEqual([["os", "switch", "--dry-run", "--ask"]]);
  });
});
