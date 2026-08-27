import { chmod, mkdir, mkdtemp, rm } from "node:fs/promises";
import { join } from "node:path";
import { afterEach, describe, expect, test } from "bun:test";

import { compactJson, nonDefaultSettings, normalizeSetting, prettyJson, sortJson } from "./persist-dms";

// Bun owns the test runner, subprocesses, and file writes. Bun does not expose
// native recursive temp-directory or permission helpers, so the node:* imports
// above use Bun's built-in Node compatibility layer for those test fixtures.

type ProcessResult = {
  stdout: string;
  stderr: string;
  exitCode: number;
};

const temporaryRoots: string[] = [];

const runProcess = async (command: string[], cwd: string, extraEnvironment: Record<string, string> = {}): Promise<ProcessResult> => {
  const environment: Record<string, string> = {};
  for (const [key, value] of Object.entries(Bun.env)) {
    if (value !== undefined)
      environment[key] = value;
  }
  Object.assign(environment, extraEnvironment);

  const processHandle = Bun.spawn({
    cmd: command,
    cwd,
    env: environment,
    stdout: "pipe",
    stderr: "pipe",
  });
  const stdoutPromise = new Response(processHandle.stdout).text();
  const stderrPromise = new Response(processHandle.stderr).text();
  const [stdout, stderr] = await Promise.all([stdoutPromise, stderrPromise]);
  const exitCode = await processHandle.exited;
  return { stdout, stderr, exitCode };
};

const runChecked = async (command: string[], cwd: string): Promise<string> => {
  const result = await runProcess(command, cwd);
  if (result.exitCode !== 0)
    throw new Error(`${command.join(" ")} failed: ${result.stderr || result.stdout}`);
  return result.stdout;
};

afterEach(async () => {
  await Promise.all(temporaryRoots.splice(0).map((root) => rm(root, { recursive: true, force: true })));
});

describe("persist-dms transformation", () => {
  test("sorts objects recursively without changing array order", () => {
    const value = {
      z: { b: 1, a: 2 },
      a: [{ z: 1, a: 2 }],
    };

    expect(sortJson(value)).toEqual({
      a: [{ a: 2, z: 1 }],
      z: { a: 2, b: 1 },
    });
    expect(compactJson(value)).toBe('{"a":[{"a":2,"z":1}],"z":{"a":2,"b":1}}');
    expect(prettyJson(value)).toContain('"a": [');
  });

  test("keeps only non-default persistent settings and normalizes home paths", () => {
    const home = Bun.env.HOME;
    expect(home).toBeTruthy();
    const runtime = {
      clockFormat: "HH:mm",
      unchanged: true,
      skipped: "runtime-only",
      configVersion: 13,
      customThemeFile: `${home}/.config/DankMaterialShell/themes/custom/theme.json`,
      futureSetting: "unknown",
    };
    const defaults = {
      clockFormat: "auto",
      unchanged: true,
      skipped: "default",
      customThemeFile: "",
    };

    const result = nonDefaultSettings(runtime, defaults, new Set(["skipped"]));

    expect(result.settings).toEqual({
      clockFormat: "HH:mm",
      customThemeFile: "~/.config/DankMaterialShell/themes/custom/theme.json",
    });
    expect(result.unknown).toEqual(["futureSetting"]);
    expect(normalizeSetting("clockFormat", "HH:mm")).toBe("HH:mm");
  });
});

describe("persist-dms command", () => {
  test("commits only generated settings while preserving unrelated staged work", async () => {
    const root = await mkdtemp(join(Bun.env.TMPDIR ?? "/tmp", "persist-dms-test-"));
    temporaryRoots.push(root);
    const bin = join(root, "bin");
    await mkdir(bin, { recursive: true });

    const dmsPath = join(bin, "dms");
    await Bun.write(
      dmsPath,
      `#!/bin/sh
printf '%s\\n' '{"clockFormat":"HH:mm","cornerRadius":8,"configVersion":13}'
`,
    );
    await chmod(dmsPath, 0o755);

    const specPath = join(root, "SettingsSpec.js");
    await Bun.write(
      specPath,
      `.pragma library
var SPEC = {
  clockFormat: { def: "auto" },
  cornerRadius: { def: 16 },
  configVersion: { def: 0, persist: false }
};
`,
    );

    await runChecked(["git", "init", "-q"], root);
    await runChecked(["git", "config", "user.name", "persist-dms test"], root);
    await runChecked(["git", "config", "user.email", "persist-dms-test@example.invalid"], root);
    await Bun.write(join(root, "README"), "baseline\n");
    await Bun.write(join(root, "unrelated.txt"), "baseline unrelated\n");
    await runChecked(["git", "add", "README", "unrelated.txt"], root);
    await runChecked(["git", "commit", "-q", "-m", "baseline"], root);

    await Bun.write(join(root, "unrelated.txt"), "unrelated change\n");
    await runChecked(["git", "add", "unrelated.txt"], root);

    const scriptPath = join(import.meta.dir, "persist-dms.ts");
    const result = await runProcess(
      [process.execPath, scriptPath, "--repo", root, "--spec", specPath],
      root,
      { PATH: `${bin}${Bun.env.PATH ? `:${Bun.env.PATH}` : ""}` },
    );

    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain("2 non-default top-level value(s)");
    expect(JSON.parse(await Bun.file(join(root, "modules/dms/assets/generated-settings.json")).text())).toEqual({
      clockFormat: "HH:mm",
      cornerRadius: 8,
    });

    expect((await runChecked(["git", "log", "-1", "--format=%s"], root)).trim()).toMatch(/^chore: update dms setting \d{4}-\d{2}-\d{2}$/);
    expect((await runChecked(["git", "show", "--format=", "--name-only", "--no-renames", "HEAD"], root)).trim()).toBe("modules/dms/assets/generated-settings.json");
    expect((await runChecked(["git", "status", "--short"], root)).split("\n")).toContain("M  unrelated.txt");

    const repeat = await runProcess(
      [process.execPath, scriptPath, "--repo", root, "--spec", specPath, "--dry-run"],
      root,
      { PATH: `${bin}${Bun.env.PATH ? `:${Bun.env.PATH}` : ""}` },
    );
    expect(repeat.exitCode).toBe(0);
    expect(repeat.stdout).toContain("unchanged: modules/dms/assets/generated-settings.json");
    expect((await runChecked(["git", "log", "-1", "--format=%s"], root)).trim()).toMatch(/^chore: update dms setting \d{4}-\d{2}-\d{2}$/);
  });
});
