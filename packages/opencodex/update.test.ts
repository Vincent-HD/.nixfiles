import { afterEach, expect, test } from "bun:test";
import { copyFile, mkdtemp, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { extractDependencyHash, runCommand, updateOpenCodexPackage } from "./update.ts";

const temporaryDirectories: string[] = [];

afterEach(async () => {
  await Promise.all(
    temporaryDirectories.splice(0).map(directory => rm(directory, { recursive: true, force: true })),
  );
});

const createFixture = async (): Promise<{ root: string; packageFile: string }> => {
  const root = await mkdtemp(join(tmpdir(), "opencodex-update-test-"));
  temporaryDirectories.push(root);
  const packageFile = join(root, "default.nix");
  await copyFile(join(import.meta.dir, "default.nix"), packageFile);
  await copyFile(join(import.meta.dir, "update.ts"), join(root, "update.ts"));
  return { root, packageFile };
};

const updateOptions = (root: string, packageFile: string) => ({
  root,
  packageFile,
  version: "2.81.0",
  sourceHash: "sha256-hhckJB28+QZJQt1qa7g/NN0zgBQAB6bnh5FgabQzir0=",
  bunLockHash: "sha256-6B58rZq7oSUVhS0zWOb0fvPxWkxMpTOceEIIhUPSPdk=",
});

test("extracts only the requested placeholder mismatch from Nix's nonzero build result", () => {
  const drvPath = "/nix/store/dependency-bun-deps.drv";
  const hash = "sha256-BJ7oaKKQ+QP2v7f2LiL7sP8JJksb5+MTfwAphxl2XkQ=";
  const output =
    `error: hash mismatch in fixed-output derivation '${drvPath}':\n` +
    "         specified: sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=\n" +
    `            got:    ${hash}\n`;

  expect(
    extractDependencyHash(
      output,
      drvPath,
      "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
    ),
  ).toBe(hash);
});

test("rejects source or lockfile mismatches and ambiguous Nix output", () => {
  const requestedDrvPath = "/nix/store/dependency-bun-deps.drv";
  const unrelatedDrvPath = "/nix/store/opencodex-source.drv";
  const placeholder = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  const hash = "sha256-BJ7oaKKQ+QP2v7f2LiL7sP8JJksb5+MTfwAphxl2XkQ=";
  const mismatch = (drvPath: string) =>
    `error: hash mismatch in fixed-output derivation '${drvPath}':\n` +
    `         specified: ${placeholder}\n            got: ${hash}\n`;

  expect(() => extractDependencyHash(mismatch(unrelatedDrvPath), requestedDrvPath, placeholder)).toThrow();
  expect(() => extractDependencyHash(mismatch(requestedDrvPath) + "error: source fetch failed\n", requestedDrvPath, placeholder)).toThrow();
  expect(() => extractDependencyHash(mismatch(requestedDrvPath) + mismatch(unrelatedDrvPath), requestedDrvPath, placeholder)).toThrow();
  expect(() => extractDependencyHash(mismatch(requestedDrvPath) + `got: ${hash}\n`, requestedDrvPath, placeholder)).toThrow();
});

test("leaves the package untouched when the second platform calculation fails", async () => {
  const { root, packageFile } = await createFixture();
  const original = await readFile(packageFile, "utf8");

  await expect(
    updateOpenCodexPackage({
      ...updateOptions(root, packageFile),
      calculateDependencyHash: async ({ system }) => {
        if (system === "aarch64-darwin") {
          return "sha256-BJ7oaKKQ+QP2v7f2LiL7sP8JJksb5+MTfwAphxl2XkQ=";
        }
        throw new Error("second platform calculation failed");
      },
    }),
  ).rejects.toThrow("second platform calculation failed");

  expect(await readFile(packageFile, "utf8")).toBe(original);
});

test("cancelling a dependency calculation kills its child and preserves the package", async () => {
  const { root, packageFile } = await createFixture();
  const original = await readFile(packageFile, "utf8");
  const controller = new AbortController();
  const started = Date.now();

  const update = updateOpenCodexPackage({
    ...updateOptions(root, packageFile),
    signal: controller.signal,
    calculateDependencyHash: async ({ signal }) => {
      await runCommand(
        [process.execPath, "-e", "await new Promise(resolve => setTimeout(resolve, 2000))"],
        { cwd: root, signal },
      );
      return "sha256-BJ7oaKKQ+QP2v7f2LiL7sP8JJksb5+MTfwAphxl2XkQ=";
    },
  });
  setTimeout(() => controller.abort(new DOMException("Cancelled", "AbortError")), 50);

  await expect(update).rejects.toMatchObject({ name: "AbortError" });
  expect(Date.now() - started).toBeLessThan(1000);
  expect(await readFile(packageFile, "utf8")).toBe(original);
});
