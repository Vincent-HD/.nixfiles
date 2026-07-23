type StdioServer = {
  slug: string;
  name: string;
  description: string;
  transport: "stdio";
  command: string;
  args: string[];
  env: Record<string, string>;
};

type Declarations = {
  servers: StdioServer[];
};

const declarationsPath = process.env.EXECUTOR_DECLARATIONS;
const dataDirectory = process.env.EXECUTOR_DATA_DIR;
const executorBinary = process.env.EXECUTOR_BIN;
const baseUrl = process.env.EXECUTOR_URL ?? "http://127.0.0.1:4789";

if (declarationsPath === undefined || dataDirectory === undefined || executorBinary === undefined) {
  throw new Error("EXECUTOR_DECLARATIONS, EXECUTOR_DATA_DIR, and EXECUTOR_BIN must be set");
}

const declarations = (await Bun.file(declarationsPath).json()) as Declarations;
const authPath = `${dataDirectory}/server-control/auth.json`;

const sleep = (milliseconds: number) => new Promise((resolve) => setTimeout(resolve, milliseconds));

async function waitForDaemon(): Promise<string> {
  for (let attempt = 1; attempt <= 60; attempt += 1) {
    const health = await fetch(`${baseUrl}/api/health`).catch(() => null);
    const authFile = Bun.file(authPath);
    if (health?.ok && (await authFile.exists())) {
      const auth = (await authFile.json()) as { token?: unknown };
      if (typeof auth.token === "string" && auth.token !== "") {
        return auth.token;
      }
    }
    await sleep(1_000);
  }
  throw new Error(`Executor daemon did not become ready at ${baseUrl}`);
}

const token = await waitForDaemon();

async function request(path: string, method = "GET", body?: unknown): Promise<Response> {
  const response = await fetch(`${baseUrl}/api${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      ...(body === undefined ? {} : { "Content-Type": "application/json" }),
    },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  if (!response.ok) {
    throw new Error(`${method} ${path} failed: ${response.status} ${await response.text()}`);
  }
  return response;
}

async function executorCall(
  path: string[],
  payload: Record<string, unknown>,
  approve = false,
): Promise<Record<string, unknown>> {
  const call = (arguments_: string[]) => {
    const process = Bun.spawn([executorBinary, ...arguments_], {
      stdout: "pipe",
      stderr: "pipe",
    });
    return Promise.all([
      new Response(process.stdout).text(),
      new Response(process.stderr).text(),
      process.exited,
    ]);
  };

  const [stdout, stderr, exitCode] = await call([
    "call",
    "executor",
    ...path,
    JSON.stringify(payload),
  ]);
  const output = `${stdout}${stderr}`;
  const executionId = output.match(/executionId:\s*(\S+)/)?.[1];

  if (executionId !== undefined) {
    if (!approve) {
      throw new Error(`Executor requested approval for ${path.join(".")}`);
    }
    // This service only approves the fixed Nix declaration it is reconciling.
    const [resumeStdout, resumeStderr, resumeExitCode] = await call([
      "resume",
      "--execution-id",
      executionId,
      "--action",
      "accept",
      "--content",
      "{}",
    ]);
    if (resumeExitCode !== 0) {
      throw new Error(`Could not approve ${path.join(".")}: ${resumeStdout}${resumeStderr}`);
    }
    return JSON.parse(resumeStdout) as Record<string, unknown>;
  }

  if (exitCode !== 0) {
    throw new Error(`${path.join(".")} failed: ${output}`);
  }
  return JSON.parse(stdout) as Record<string, unknown>;
}

function serverConfig(server: StdioServer) {
  return {
    transport: server.transport,
    command: server.command,
    args: server.args,
    env: server.env,
    authenticationTemplate: [{ slug: "none", kind: "none" }],
  };
}

for (const server of declarations.servers) {
  const slug = encodeURIComponent(server.slug);
  const getServer = await executorCall(["mcp", "getServer"], { slug: server.slug });
  const existing = (getServer.data as { integration?: unknown } | undefined)?.integration;
  const desiredConfig = serverConfig(server);
  const configured =
    typeof existing === "object" &&
    existing !== null &&
    JSON.stringify((existing as { config?: unknown }).config) === JSON.stringify(desiredConfig);

  if (existing === null || existing === undefined) {
    await executorCall(["mcp", "addServer"], {
      ...server,
      authenticationTemplate: [{ slug: "none", kind: "none" }],
    }, true);
    console.log(`Registered Executor MCP server: ${server.slug}`);
  } else if (!configured) {
    // The released CLI can add and inspect MCP servers, but not update them.
    // Remove only this known managed slug, then recreate it with the new path.
    await request(`/integrations/${slug}`, "DELETE");
    await executorCall(["mcp", "addServer"], {
      ...server,
      authenticationTemplate: [{ slug: "none", kind: "none" }],
    }, true);
    console.log(`Reconciled Executor MCP server: ${server.slug}`);
  }

  const listConnections = await executorCall(
    ["coreTools", "connections", "list"],
    { owner: "org", integration: server.slug },
  );
  const configuredConnections =
    ((listConnections.data as { connections?: Array<{ name?: unknown }> } | undefined)?.connections ?? []);
  const hasDefaultConnection = configuredConnections.some((connection) => connection.name === "default");

  if (!hasDefaultConnection) {
    await executorCall(["coreTools", "connections", "create"], {
      owner: "org",
      name: "default",
      integration: server.slug,
      template: "none",
    }, true);
    console.log(`Created Executor connection: ${server.slug}/default`);
  }
}
