import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { chmod, mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { delimiter, dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

type Fixture = {
  root: string;
  fakeBin: string;
  packageFile: string;
  hookLog: string;
};

const updatePackageScript = fileURLToPath(new URL("./update-package.ts", import.meta.url));
const storeFile = `/nix/store/${"a".repeat(32)}-source/packages/demo/default.nix`;
let fixture: Fixture;

const writeExecutable = async ({ path, content }: { path: string; content: string }) => {
  await writeFile(path, content);
  await chmod(path, 0o755);
};

// Fake nix-update bumps the version and the running system's hash, like the real tool.
const nixUpdateScript = (latest: string) => `#!/bin/sh
file="$NIXFILES_ROOT/packages/demo/default.nix"
sed -i -e 's/version = "1.0.0"/version = "${latest}"/' "$file"
if [ "${latest}" != "1.0.0" ]; then sed -i -e 's/sha256-LINUXOLD/sha256-LINUXNEW/' "$file"; fi
`;

const createFixture = async (): Promise<Fixture> => {
  const root = await mkdtemp(join(tmpdir(), "update-package-test-"));
  const fakeBin = join(root, "fake-bin");
  const packageFile = join(root, "packages", "demo", "default.nix");
  const hookLog = join(root, "hook.log");
  await mkdir(dirname(packageFile), { recursive: true });
  await mkdir(fakeBin, { recursive: true });
  await writeFile(
    packageFile,
    `{\n  version = "1.0.0";\n  linuxHash = "sha256-LINUXOLD";\n  darwinHash = "sha256-DARWINOLD";\n}\n`,
  );
  // Answers the evaluations update-package makes by reading the fixture file.
  await writeExecutable({
    path: join(fakeBin, "nix"),
    content: `#!/bin/sh
file="$NIXFILES_ROOT/packages/demo/default.nix"
version=$(sed -n 's/.*version = "\\(.*\\)";/\\1/p' "$file")
darwin=$(sed -n 's/.*darwinHash = "\\(.*\\)";/\\1/p' "$file")
linux=$(sed -n 's/.*linuxHash = "\\(.*\\)";/\\1/p' "$file")
case "$*" in
  *builtins.currentSystem*) printf 'x86_64-linux' ;;
  *"p: p.version") printf '"%s"' "$version" ;;
  *"p.src.url"*) printf '"https://example.test/linux-%s"' "$version" ;;
  *"p.sources or"*) printf '[{"url":"https://example.test/darwin-%s","hash":"%s","unpack":false},{"url":"https://example.test/linux-%s","hash":"%s","unpack":false}]' "$version" "$darwin" "$version" "$linux" ;;
  "store prefetch-file --json https://example.test/darwin-"*) printf '{"hash":"sha256-DARWINNEW"}' ;;
  *) echo "unexpected nix call: $*" >&2; exit 64 ;;
esac
`,
  });
  return { root, fakeBin, packageFile, hookLog };
};

const runUpdatePackage = async ({ latest, extraArgs = [] }: { latest: string; extraArgs?: string[] }) => {
  await writeExecutable({ path: join(fixture.fakeBin, "nix-update"), content: nixUpdateScript(latest) });
  const child = Bun.spawn([process.execPath, updatePackageScript, "--attr=demo", `--file=${storeFile}`, ...extraArgs], {
    cwd: fixture.root,
    env: {
      ...process.env,
      NIXFILES_ROOT: fixture.root,
      GITHUB_TOKEN: "test",
      PATH: [fixture.fakeBin, dirname(process.execPath), process.env.PATH ?? ""].join(delimiter),
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

beforeEach(async () => {
  fixture = await createFixture();
});

afterEach(async () => {
  await rm(fixture.root, { recursive: true, force: true });
});

describe("update-package", () => {
  test("re-hashes every other platform source after nix-update bumps the version", async () => {
    const hook = join(fixture.root, "hook.ts");
    await writeFile(
      hook,
      `await Bun.write(${JSON.stringify(fixture.hookLog)}, [Bun.env.UPDATE_ATTR, Bun.env.UPDATE_OLD_VERSION, Bun.env.UPDATE_NEW_VERSION].join(" "));\n`,
    );

    const result = await runUpdatePackage({ latest: "2.0.0", extraArgs: [`--post-update=${hook}`] });

    expect(result.exitCode).toBe(0);
    const text = await readFile(fixture.packageFile, "utf8");
    expect(text).toContain('version = "2.0.0"');
    expect(text).toContain("sha256-LINUXNEW");
    expect(text).toContain("sha256-DARWINNEW");
    expect(await readFile(fixture.hookLog, "utf8")).toBe("demo 1.0.0 2.0.0");
  });

  test("stops after nix-update when the version did not change", async () => {
    const result = await runUpdatePackage({ latest: "1.0.0" });

    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain("demo is up to date (1.0.0)");
    expect(await readFile(fixture.packageFile, "utf8")).toContain("sha256-DARWINOLD");
  });

  test("rejects a --file outside the flake source", async () => {
    await writeExecutable({ path: join(fixture.fakeBin, "nix-update"), content: nixUpdateScript("2.0.0") });
    const child = Bun.spawn([process.execPath, updatePackageScript, "--attr=demo", "--file=/tmp/default.nix"], {
      env: { ...process.env, NIXFILES_ROOT: fixture.root, GITHUB_TOKEN: "test" },
      stdout: "pipe",
      stderr: "pipe",
    });
    const [stderr, exitCode] = await Promise.all([new Response(child.stderr).text(), child.exited]);

    expect(exitCode).not.toBe(0);
    expect(stderr).toContain("--file must point into the flake source");
  });
});
