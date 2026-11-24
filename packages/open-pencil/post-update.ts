// Pin the OpenPencil MCP server closure to the app release, then refresh its npm dependency hash.
const root = Bun.env.NIXFILES_ROOT ?? "";
const version = Bun.env.UPDATE_NEW_VERSION ?? "";
if (root === "" || version === "") throw new Error("NIXFILES_ROOT and UPDATE_NEW_VERSION are required");

const mcpDirectory = `${root}/packages/open-pencil/mcp`;

const run = async (command: string[], cwd: string) => {
  const child = Bun.spawn(command, { cwd, stdout: "inherit", stderr: "inherit" });
  if ((await child.exited) !== 0) throw new Error(`Command failed: ${command.join(" ")}`);
};

const closure = {
  name: "open-pencil-mcp-closure",
  version,
  private: true,
  dependencies: { "@open-pencil/mcp": version },
};
await Bun.write(`${mcpDirectory}/package.json`, `${JSON.stringify(closure, null, 2)}\n`);
await run(["npm", "install", "--package-lock-only", "--ignore-scripts", "--no-audit", "--no-fund"], mcpDirectory);
await run(
  ["nix-update", "--flake", "open-pencil-mcp", "--version", "skip", "--override-filename", "packages/open-pencil/mcp/default.nix"],
  root,
);
