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
  nhEnvironmentLog: string;
};

const nrsScriptPath =
  Bun.env.NRS_SCRIPT_PATH ?? fileURLToPath(new URL("../modules/command-line/assets/nrs", import.meta.url));
const bashExecutable = execFileSync("bash", ["-c", "command -v bash"], { encoding: "utf8" }).trim();

let fixture: Fixture;

async function writeExecutable(path: string, content: string): Promise<void> {
  await writeFile(path, content);
  await chmod(path, 0o755);
}

async function createFixture(): Promise<Fixture> {
  const root = await mkdtemp(join(tmpdir(), "nrs-behavior-test-"));
  const flakeRoot = join(root, "flake root with spaces");
  const callerDirectory = join(root, "unrelated-working-directory");
  const fakeBin = join(root, "fake-bin");
  const nixLog = join(root, "nix-argv.log");
  const nixEnvironmentLog = join(root, "nix-environment.log");
  const nhLog = join(root, "nh-argv.log");
  const nhEnvironmentLog = join(root, "nh-environment.log");

  await mkdir(join(flakeRoot, "scripts"), { recursive: true });
  await mkdir(callerDirectory, { recursive: true });
  await mkdir(fakeBin, { recursive: true });
  await writeFile(join(flakeRoot, "flake.nix"), "{ description = \"test\"; }\n");
  await writeFile(
    join(flakeRoot, "scripts", "update-pins.json"),
    JSON.stringify(
      {
        denylist: ["denylisted-input"],
        updates: [
          { name: "managed-input", type: "flake-input", command: ["nix", "flake", "update", "managed-input"] },
          {
            name: "denylisted-input",
            type: "flake-input",
            command: ["nix", "flake", "update", "denylisted-input"],
          },
          {
            name: "disabled-input",
            type: "flake-input",
            enabled: false,
            command: ["nix", "flake", "update", "disabled-input"],
          },
          { name: "manual-input", type: "manual", enabled: true, command: ["nix", "flake", "update", "manual-input"] },
          { name: "codex", type: "nix-update", command: ["nix-update", "codex"] },
          { name: "manual-pin", type: "manual", enabled: false, command: ["manual", "manual-pin"] },
        ],
      },
      null,
      2,
    ),
  );
  await writeFile(
    join(root, "metadata.json"),
    JSON.stringify({
      locks: {
        nodes: {
          root: {
            inputs: {
              "managed-input": "managed-node",
              "denylisted-input": "denylisted-node",
              "disabled-input": "disabled-node",
              "manual-input": "manual-node",
              "loose-input": "loose-node",
              nixpkgs: "nixpkgs-node",
            },
          },
        },
      },
    }),
  );

  await writeExecutable(
    join(fakeBin, "nix"),
    [
      `#!${bashExecutable}`,
      'printf \'%s\\0\' "$@" >> "$NRS_NIX_ARGV_LOG"',
      "printf '\\0' >> \"$NRS_NIX_ARGV_LOG\"",
      'printf \'%s\\0\' "${UPDATE_PINS_REPO_ROOT:-<empty>}" >> "$NRS_NIX_ENV_LOG"',
      "printf '\\0' >> \"$NRS_NIX_ENV_LOG\"",
      'if [[ "$1" == flake && "$2" == metadata ]]; then',
      '  cat "$NRS_METADATA_FILE"',
      'elif [[ "$1" == run ]]; then',
      '  printf \'fake update-pins app\\n\'',
      "fi",
      "",
    ].join("\n"),
  );
  await writeExecutable(
    join(fakeBin, "nh"),
    [
      `#!${bashExecutable}`,
      'printf \'%s\\0\' "$@" >> "$NRS_NH_ARGV_LOG"',
      "printf '\\0' >> \"$NRS_NH_ARGV_LOG\"",
      'printf \'%s\\0\' "${NRS_Z_CODE:-}:${NRS_T3_USAGE:-}:${NRS_T3_JJ:-}:${NRS_T3_TEMPORARY:-}" >> "$NRS_NH_ENV_LOG"',
      "printf '\\0' >> \"$NRS_NH_ENV_LOG\"",
      "",
    ].join("\n"),
  );
  await writeExecutable(join(fakeBin, "uname"), `#!${bashExecutable}\nprintf 'Linux\\n'\n`);

  return {
    root,
    flakeRoot,
    callerDirectory,
    fakeBin,
    nixLog,
    nixEnvironmentLog,
    nhLog,
    nhEnvironmentLog,
  };
}

async function readGroups(path: string): Promise<string[][]> {
  const fileContents = await readFile(path, "utf8").catch(() => "");
  const groups: string[][] = [];
  let current: string[] = [];
  for (const field of fileContents.split("\0")) {
    if (field === "") {
      if (current.length > 0) {
        groups.push(current);
        current = [];
      }
    } else {
      current.push(field);
    }
  }
  return groups;
}

async function runNrs(args: string[]) {
  await Promise.all([
    writeFile(fixture.nixLog, ""),
    writeFile(fixture.nixEnvironmentLog, ""),
    writeFile(fixture.nhLog, ""),
    writeFile(fixture.nhEnvironmentLog, ""),
  ]);
  const result = Bun.spawn(["bash", nrsScriptPath, ...args], {
    cwd: fixture.callerDirectory,
    env: {
      ...process.env,
      NH_FLAKE: fixture.flakeRoot,
      UPDATE_PINS_REPO_ROOT: "",
      PATH: `${fixture.fakeBin}${delimiter}${process.env.PATH ?? ""}`,
      NRS_METADATA_FILE: join(fixture.root, "metadata.json"),
      NRS_NIX_ARGV_LOG: fixture.nixLog,
      NRS_NIX_ENV_LOG: fixture.nixEnvironmentLog,
      NRS_NH_ARGV_LOG: fixture.nhLog,
      NRS_NH_ENV_LOG: fixture.nhEnvironmentLog,
    },
    stdout: "pipe",
    stderr: "pipe",
  });
  const [stdout, stderr, exitCode] = await Promise.all([
    new Response(result.stdout).text(),
    new Response(result.stderr).text(),
    result.exited,
  ]);
  return { stdout, stderr, exitCode };
}

beforeEach(async () => {
  fixture = await createFixture();
});

afterEach(async () => {
  await rm(fixture.root, { recursive: true, force: true });
});

describe("nrs update interface", () => {
  test("lists direct inputs and the registry from NH_FLAKE outside the checkout", async () => {
    const result = await runNrs(["--list-updates"]);
    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain("Nix flake inputs");
    expect(result.stdout).toContain("- loose-input");
    expect(result.stdout).toContain("update-pins registry:");
    expect(result.stdout).toContain("fake update-pins app");
    expect(await readGroups(fixture.nixLog)).toEqual([
      ["flake", "metadata", "--json", "--no-write-lock-file", fixture.flakeRoot],
      ["run", "--no-write-lock-file", `${fixture.flakeRoot}#update-pins`, "--", "--list"],
    ]);
    expect(await readGroups(fixture.nixEnvironmentLog)).toEqual([["<empty>"], [fixture.flakeRoot]]);
  });

  test("rejects non-string denylist entries before listing or updating inputs and pins", async () => {
    const registryPath = join(fixture.flakeRoot, "scripts", "update-pins.json");
    const registry = JSON.parse(await readFile(registryPath, "utf8"));
    registry.denylist = [17];
    await writeFile(registryPath, JSON.stringify(registry, null, 2));

    for (const args of [
      ["--list-updates"],
      ["--update", "--inputs", "all", "--dry-run"],
      ["--update", "--inputs", "denylisted-input", "--dry-run"],
      ["--update", "--pins", "all", "--dry-run"],
    ]) {
      const result = await runNrs(args);
      expect(result.exitCode).toBe(2);
      expect(result.stderr).toContain("invalid update registry");
      expect(await readGroups(fixture.nixLog)).toEqual([]);
    }
  });

  test("updates all eligible inputs without bypassing manual, disabled, or denylisted entries", async () => {
    const result = await runNrs(["--update", "--inputs", "all", "--dry-run"]);
    expect(result.exitCode).toBe(0);
    expect(result.stderr).toContain("skipped protected input denylisted-input (denylisted)");
    expect(result.stderr).toContain("skipped protected input disabled-input (disabled)");
    expect(result.stderr).toContain("skipped protected input manual-input (manual)");
    expect(result.stdout).toContain("nix flake update loose-input nixpkgs --flake");
    const groups = await readGroups(fixture.nixLog);
    expect(groups.some((args) => args[0] === "flake" && args[1] === "update")).toBe(false);
    expect(groups).toContainEqual([
      "run",
      "--no-write-lock-file",
      `${fixture.flakeRoot}#update-pins`,
      "--",
      "--only",
      "managed-input",
      "--dry-run",
    ]);
    expect(groups.some((args) => args[0] === "flake" && args[1] === "update" && args.includes("managed-input"))).toBe(
      false,
    );
    expect(groups.some((args) => args[0] === "flake" && args[1] === "update" && args.includes("denylisted-input"))).toBe(
      false,
    );
  });

  test("updates input and registry scopes together while routing a shared flake input only once", async () => {
    const result = await runNrs(["--update", "--inputs", "all", "--pins", "all", "--dry-run"]);
    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain("nix flake update loose-input nixpkgs --flake");
    const groups = await readGroups(fixture.nixLog);
    expect(groups.some((args) => args[0] === "flake" && args[1] === "update")).toBe(false);
    expect(groups).toContainEqual([
      "run",
      "--no-write-lock-file",
      `${fixture.flakeRoot}#update-pins`,
      "--",
      "--dry-run",
    ]);
    expect(
      groups.filter((args) => args[0] === "run" && args[2] === `${fixture.flakeRoot}#update-pins`),
    ).toHaveLength(1);
    expect(groups.some((args) => args[0] === "flake" && args[1] === "update" && args.includes("managed-input"))).toBe(
      false,
    );
  });

  test("selects one input and one registry entry without duplicating a shared input", async () => {
    const result = await runNrs(["--update", "--inputs", "managed-input", "--pins", "codex", "--dry-run"]);
    expect(result.exitCode).toBe(0);
    expect(await readGroups(fixture.nixLog)).toEqual([
      ["flake", "metadata", "--json", "--no-write-lock-file", fixture.flakeRoot],
      [
        "run",
        "--no-write-lock-file",
        `${fixture.flakeRoot}#update-pins`,
        "--",
        "--only",
        "codex",
        "--only",
        "managed-input",
        "--dry-run",
      ],
    ]);
  });

  test("runs the selected update argv through fake nix commands without a dry-run flag", async () => {
    const result = await runNrs(["--update", "--inputs", "loose-input", "--pins", "codex"]);
    expect(result.exitCode).toBe(0);
    expect(await readGroups(fixture.nixLog)).toEqual([
      ["flake", "metadata", "--json", "--no-write-lock-file", fixture.flakeRoot],
      ["flake", "update", "loose-input", "--flake", fixture.flakeRoot],
      ["run", "--no-write-lock-file", `${fixture.flakeRoot}#update-pins`, "--", "--only", "codex"],
    ]);
    expect(await readGroups(fixture.nhLog)).toHaveLength(0);
  });

  test("deduplicates one flake input selected through both categories", async () => {
    const result = await runNrs([
      "--update",
      "--inputs",
      "managed-input",
      "--pins",
      "managed-input",
      "--dry-run",
    ]);
    expect(result.exitCode).toBe(0);
    expect(await readGroups(fixture.nixLog)).toEqual([
      ["flake", "metadata", "--json", "--no-write-lock-file", fixture.flakeRoot],
      [
        "run",
        "--no-write-lock-file",
        `${fixture.flakeRoot}#update-pins`,
        "--",
        "--only",
        "managed-input",
        "--dry-run",
      ],
    ]);
  });

  test("explicitly enables a denylisted entry only with the opt-in flag", async () => {
    const rejected = await runNrs(["--update", "--inputs", "denylisted-input", "--dry-run"]);
    expect(rejected.exitCode).toBe(2);
    expect(rejected.stderr).toContain("denylisted");
    expect(await readGroups(fixture.nixLog)).toHaveLength(1);

    const allowed = await runNrs([
      "--update",
      "--inputs",
      "denylisted-input",
      "--include-denylisted",
      "--dry-run",
    ]);
    expect(allowed.exitCode).toBe(0);
    expect(await readGroups(fixture.nixLog)).toContainEqual([
      "run",
      "--no-write-lock-file",
      `${fixture.flakeRoot}#update-pins`,
      "--",
      "--only",
      "denylisted-input",
      "--include-denylisted",
      "--dry-run",
    ]);
  });

  test("applies denylist policy to direct flake inputs without registry entries", async () => {
    const registryPath = join(fixture.flakeRoot, "scripts", "update-pins.json");
    const registry = JSON.parse(await readFile(registryPath, "utf8"));
    registry.denylist.push("loose-input");
    await writeFile(registryPath, JSON.stringify(registry, null, 2));

    const allInputs = await runNrs(["--update", "--inputs", "all", "--dry-run"]);
    expect(allInputs.exitCode).toBe(0);
    expect(allInputs.stderr).toContain("skipped protected input loose-input (denylisted)");
    expect(allInputs.stdout).not.toContain("nix flake update loose-input");

    const explicitInput = await runNrs(["--update", "--inputs", "loose-input", "--dry-run"]);
    expect(explicitInput.exitCode).toBe(2);
    expect(explicitInput.stderr).toContain("denylisted");

    const optedInInput = await runNrs([
      "--update",
      "--inputs",
      "loose-input",
      "--include-denylisted",
      "--dry-run",
    ]);
    expect(optedInInput.exitCode).toBe(0);
    expect(optedInInput.stdout).toContain("nix flake update loose-input");
  });

  test("refuses explicit manual and disabled inputs and registry entries", async () => {
    for (const args of [
      ["--update", "--inputs", "manual-input"],
      ["--update", "--inputs", "disabled-input"],
      ["--update", "--pins", "manual-pin"],
      ["--update", "--pins", "disabled-input"],
    ]) {
      const result = await runNrs(args);
      expect(result.exitCode).toBe(2);
      expect(result.stderr).toMatch(/manual|disabled/);
      expect((await readGroups(fixture.nixLog)).filter((group) => group[0] === "run")).toHaveLength(0);
    }
  });

  test("validates unknown names, missing selectors, duplicate selectors, and incompatible options", async () => {
    const cases = [
      { args: ["--update"], error: "requires --inputs and/or --pins" },
      { args: ["--update", "--inputs", "unknown-input"], error: "unknown Nix flake input" },
      { args: ["--update", "--pins", "unknown-pin"], error: "unknown update-pins entry" },
      { args: ["--update", "--inputs", "a,b"], error: "one input name" },
      { args: ["--update", "--inputs"], error: "requires all or one input name" },
      { args: ["--update", "--pins", "codex", "--pins", "other"], error: "--pins may only be used once" },
      { args: ["--list-updates", "--dry-run"], error: "cannot be combined" },
      { args: ["--inputs", "all"], error: "require --update" },
      { args: ["--update", "--inputs", "loose-input", "--ask"], error: "cannot be combined with switch or nh" },
      {
        args: ["--update", "--inputs", "loose-input", "--", "--dry-run"],
        error: "cannot be combined with switch or nh",
      },
    ];

    for (const { args, error } of cases) {
      const result = await runNrs(args);
      expect(result.exitCode).toBe(2);
      expect(result.stderr).toContain(error);
      expect(await readGroups(fixture.nhLog)).toHaveLength(0);
      expect((await readGroups(fixture.nixLog)).filter((group) => group[0] === "flake" && group[1] === "update")).toHaveLength(
        0,
      );
    }
  });

  test("keeps existing rebuild arguments and T3 overrides on the nh switch path", async () => {
    const result = await runNrs(["--no-t3-usage", "--dry-run", "--ask"]);
    expect(result.exitCode).toBe(0);
    expect(await readGroups(fixture.nhLog)).toEqual([["os", "switch", "--dry-run", "--ask", "--impure"]]);
    expect(await readGroups(fixture.nhEnvironmentLog)).toEqual([["0:0::"]]);
    expect(await readGroups(fixture.nixLog)).toEqual([]);
  });

  test("uses --dry-run as an nh option when no update mode is selected", async () => {
    const result = await runNrs(["--dry-run", "--ask"]);
    expect(result.exitCode).toBe(0);
    expect(await readGroups(fixture.nhLog)).toEqual([["os", "switch", "--dry-run", "--ask"]]);
  });
});
