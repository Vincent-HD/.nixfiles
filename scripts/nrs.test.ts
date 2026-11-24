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
    content: `${recorder("NRS_NIX_ARGV_LOG")}printf '%s\\0\\0' "\${UPDATE_PINS_REPO_ROOT:-<empty>}" >> "$NRS_NIX_ENV_LOG"\nif [ -e "${join(root, "nix-fails")}" ]; then exit 1; fi\n`,
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

describe("nrs", () => {
  test("updates everything through update-pins in NH_FLAKE from outside the checkout", async () => {
    const result = await runNrs(["update"]);

    expect(result.exitCode).toBe(0);
    expect(await readGroups(fixture.nixLog)).toEqual([updatePinsCall()]);
    expect(await readGroups(fixture.nixEnvironmentLog)).toEqual([[fixture.flakeRoot]]);
    expect(await readGroups(fixture.nhLog)).toEqual([]);
  });

  test("forwards update-pins options verbatim", async () => {
    const result = await runNrs(["update", "--only", "codex,nixpkgs", "--skip", "t3code", "--check"]);

    expect(result.exitCode).toBe(0);
    expect(await readGroups(fixture.nixLog)).toEqual([
      updatePinsCall("--only", "codex,nixpkgs", "--skip", "t3code", "--check"),
    ]);
  });

  test("switches after a successful update with --switch", async () => {
    const result = await runNrs(["update", "--switch", "--only", "codex"]);

    expect(result.exitCode).toBe(0);
    expect(await readGroups(fixture.nixLog)).toEqual([updatePinsCall("--only", "codex")]);
    expect(await readGroups(fixture.nhLog)).toEqual([["os", "switch"]]);
  });

  test("does not switch after a failed or dry-run update", async () => {
    const dryRun = await runNrs(["update", "--switch", "--dry-run"]);
    expect(dryRun.exitCode).toBe(0);
    expect(await readGroups(fixture.nixLog)).toEqual([updatePinsCall("--dry-run")]);
    expect(await readGroups(fixture.nhLog)).toEqual([]);

    await writeFile(join(fixture.root, "nix-fails"), "");
    const failed = await runNrs(["update", "--switch"]);
    expect(failed.exitCode).not.toBe(0);
    expect(await readGroups(fixture.nhLog)).toEqual([]);
  });

  test("rejects the old update flags before they reach nh", async () => {
    for (const flag of ["--update", "--list-updates", "--inputs", "--pins"]) {
      const result = await runNrs([flag, "all"]);
      expect(result.exitCode).toBe(2);
      expect(result.stderr).toContain("nrs update");
      expect(await readGroups(fixture.nhLog)).toEqual([]);
      expect(await readGroups(fixture.nixLog)).toEqual([]);
    }
  });

  test("switches with nh options and a local Tokitoki checkout", async () => {
    const checkout = join(fixture.root, "tokitoki");
    await mkdir(checkout);

    const result = await runNrs(["--tokitoki", checkout, "--ask"]);

    expect(result.exitCode).toBe(0);
    expect(await readGroups(fixture.nhLog)).toEqual([
      ["os", "switch", "--ask", "--override-input", "tokitoki", `path:${checkout}`],
    ]);
  });
});
