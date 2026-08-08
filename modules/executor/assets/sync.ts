type StdioServer = {
  slug: string;
  name: string;
  description: string;
  transport: "stdio";
  command: string;
  args: string[];
  envVars?: string[];
  createConnection?: boolean;
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

console.log(`Starting Executor MCP sync for ${declarations.servers.length} declarations`);

const sleep = (milliseconds: number) => new Promise((resolve) => setTimeout(resolve, milliseconds));

async function waitForDaemon(): Promise<string> {
  console.log(`Waiting for Executor daemon at ${baseUrl}`);
  for (let attempt = 1; attempt <= 60; attempt += 1) {
    const health = await fetch(`${baseUrl}/api/health`).catch(() => null);
    const authFile = Bun.file(authPath);
    if (health?.ok && (await authFile.exists())) {
      const auth = (await authFile.json()) as { token?: unknown };
      if (typeof auth.token === "string" && auth.token !== "") {
        console.log("Executor daemon is ready");
        return auth.token;
      }
    }
    if (attempt % 10 === 0) {
      console.log(`Still waiting for Executor daemon (${attempt}/60)`);
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
  const envVars = server.envVars ?? [];

  return {
    transport: server.transport,
    command: server.command,
    args: server.args,
    authenticationTemplate:
      envVars.length > 0
        ? [{ slug: "env", kind: "stdio_env", vars: envVars }]
        : [{ slug: "none", kind: "none" }],
  };
}

function serverPayload(server: StdioServer) {
  return {
    slug: server.slug,
    name: server.name,
    description: server.description,
    transport: server.transport,
    command: server.command,
    args: server.args,
    ...(server.envVars === undefined ? {} : { envVars: server.envVars }),
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
      ...serverPayload(server),
    }, true);
    console.log(`Registered Executor MCP server: ${server.slug}`);
  } else if (!configured) {
    // Update the stdio command in place so manually managed connections are
    // not deleted when a Nix path or argument changes.
    await request(`/mcp/servers/${slug}/config`, "POST", {
      config: desiredConfig,
    });
    console.log(`Reconciled Executor MCP server: ${server.slug}`);
  } else {
    console.log(`Executor MCP server already current: ${server.slug}`);
  }

  if (server.createConnection === false) {
    console.log(`Skipped Executor connection provisioning: ${server.slug}`);
    continue;
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

console.log("Executor MCP sync complete");
