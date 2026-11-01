import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { chmod, mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { delimiter, join } from "node:path";
import { tmpdir } from "node:os";
import { fileURLToPath } from "node:url";

type Fixture = {
  root: string;
  markerPath: string;
  fakeBin: string;
};

const updatePinsScriptPath = fileURLToPath(new URL("./update-pins.ts", import.meta.url));
let fixture: Fixture;

async function writeExecutable(path: string, content: string): Promise<void> {
  await writeFile(path, content);
  await chmod(path, 0o755);
}

async function createFixture(): Promise<Fixture> {
  const root = await mkdtemp(join(tmpdir(), "update-pins-validation-test-"));
  const scriptsDirectory = join(root, "scripts");
  const fakeBin = join(root, "fake-bin");
  const markerPath = join(root, "update-command-ran");
  const updateCommandPath = join(root, "fake-update-command");
  await mkdir(scriptsDirectory, { recursive: true });
  await mkdir(fakeBin, { recursive: true });

  await writeFile(
    join(scriptsDirectory, "update-pins.json"),
    JSON.stringify(
      {
        denylist: [17],
        updates: [
          {
            name: "codex",
            type: "nix-update",
            command: [updateCommandPath, markerPath],
          },
        ],
      },
      null,
      2,
    ),
  );
  await writeExecutable(updateCommandPath, '#!/bin/sh\nprintf ran > "$1"\n');
  await writeExecutable(join(fakeBin, "nix"), '#!/bin/sh\nprintf "x86_64-linux\\n"\n');

  return { root, markerPath, fakeBin };
}

async function runUpdate(): Promise<{ stdout: string; stderr: string; exitCode: number }> {
  const processHandle = Bun.spawn([process.execPath, updatePinsScriptPath, "--only", "codex"], {
    cwd: fixture.root,
    env: {
      ...process.env,
      UPDATE_PINS_REPO_ROOT: fixture.root,
      PATH: `${fixture.fakeBin}${delimiter}${process.env.PATH ?? ""}`,
    },
    stdout: "pipe",
    stderr: "pipe",
  });
  const [stdout, stderr, exitCode] = await Promise.all([
    new Response(processHandle.stdout).text(),
    new Response(processHandle.stderr).text(),
    processHandle.exited,
  ]);
  return { stdout, stderr, exitCode };
}

beforeEach(async () => {
  fixture = await createFixture();
});

afterEach(async () => {
  await rm(fixture.root, { recursive: true, force: true });
});

describe("update-pins registry validation", () => {
  test("rejects non-string denylist entries before running an update command", async () => {
    const result = await runUpdate();

    expect(result.exitCode).toBe(2);
    expect(result.stderr).toContain("Invalid update registry: denylist must be an array of strings");
    await expect(readFile(fixture.markerPath, "utf8")).rejects.toThrow();
  });
});
