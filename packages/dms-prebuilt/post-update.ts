// Move the `dms` flake input (QML and Nix modules) to the commit of the new CLI release.
import { rename, rm } from "node:fs/promises";

const root = Bun.env.NIXFILES_ROOT ?? "";
const packageFile = Bun.env.UPDATE_FILE ?? "";
const version = Bun.env.UPDATE_NEW_VERSION ?? "";
if (root === "" || packageFile === "" || version === "") {
  throw new Error("NIXFILES_ROOT, UPDATE_FILE, and UPDATE_NEW_VERSION are required");
}

const output = async (command: string[]): Promise<string> => {
  const child = Bun.spawn(command, { cwd: root, stdout: "pipe", stderr: "inherit" });
  const text = await new Response(child.stdout).text();
  if ((await child.exited) !== 0) throw new Error(`Command failed: ${command.join(" ")}`);
  return text.trim();
};

const tag = `refs/tags/v${version}`;
const refs = (await output(["git", "ls-remote", "https://github.com/duxlabs-dev/dux-shell.git", tag, `${tag}^{}`])).split("\n");
const releaseRevision = (refs.find((line) => line.endsWith(`${tag}^{}`)) ?? refs.find((line) => line.endsWith(tag)))?.split("\t")[0];
if (releaseRevision === undefined || !/^[0-9a-f]{40}$/.test(releaseRevision)) {
  throw new Error(`Could not resolve the commit of ${tag}`);
}

// Write the candidate lock beside flake.lock and swap it in atomically once it matches.
const candidateLock = `${root}/flake.lock.dms-update`;
await output(["nix", "flake", "update", "dms", "--output-lock-file", candidateLock]);
const lock = await Bun.file(candidateLock).json();
const lockedRevision: unknown = lock.nodes[lock.nodes.root.inputs.dms]?.locked?.rev;
if (lockedRevision !== releaseRevision) {
  await rm(candidateLock, { force: true });
  throw new Error(`The dms stable branch (${String(lockedRevision)}) is not at the v${version} release commit (${releaseRevision})`);
}
await rename(candidateLock, `${root}/flake.lock`);

const text = await Bun.file(packageFile).text();
const revisionPattern = /^  revision = "[0-9a-f]{40}";$/m;
if (!revisionPattern.test(text)) throw new Error(`Could not find the revision pin in ${packageFile}`);
await Bun.write(packageFile, text.replace(revisionPattern, `  revision = "${releaseRevision}";`));
console.log(`dms flake input and dms-prebuilt revision -> ${releaseRevision}`);
