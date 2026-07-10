import { stat } from "node:fs/promises";
import { isAbsolute, join, resolve } from "node:path";
import type { Server, WebSocketHandler } from "bun";
import { createCollector, type Collector } from "./collector";
import {
  createLocalAgentControlServer,
  type LocalAgentControlServer,
  type LocalAgentControlTool,
} from "./localAgentControlServer";
import type { LocalAgentProcessRunner } from "./localAgentProcessSupervisor";
import type { LocalAgentPtyRunner } from "./localAgentPtySupervisor";
import {
  bunLocalAgentSessionStore,
  createLocalAgentSessionRegistry,
  restoreLocalAgentSessionRegistry,
  saveLocalAgentSessionRegistry,
  type LocalAgentSessionRegistry,
  type LocalAgentSessionRestoreResult,
} from "./localAgentSessionRegistry";
import {
  claudeCodeLocalAgentProcessTool,
  codexLocalAgentProcessTool,
} from "./localAgentTranscriptAdapters";

export type LocalAgentControlHostOptions = {
  token: string;
  origin: string;
  workspace: string;
  statePath?: string;
  tools?: readonly LocalAgentControlTool[];
  runner?: LocalAgentProcessRunner;
  ptyRunner?: LocalAgentPtyRunner;
  fetcher?: typeof fetch;
  now?: () => number;
};

export type LocalAgentControlHost = {
  origin: string;
  workspace: string;
  statePath: string;
  restoreStatus: LocalAgentSessionRestoreResult;
  collector: Collector;
  control: LocalAgentControlServer;
  registry: LocalAgentSessionRegistry;
  fetch: (request: Request, server: Server<undefined>) => Response | Promise<Response> | undefined;
  websocket: WebSocketHandler<undefined>;
  close: () => Promise<void>;
};

export type LocalAgentControlHostConfig = {
  token: string;
  port: number;
  workspace: string;
  statePath: string;
};

const DEFAULT_PORT = 4500;
const DEFAULT_MAX_PROMPT_LENGTH = 32 * 1024;
const MAX_TOKEN_LENGTH = 4096;

export async function createLocalAgentControlHost(
  options: LocalAgentControlHostOptions,
): Promise<LocalAgentControlHost> {
  const origin = normalizeHostOrigin(options.origin);
  requireToken(options.token);
  const workspace = resolve(options.workspace);
  const workspaceStat = await stat(workspace).catch(() => null);
  if (!workspaceStat?.isDirectory()) throw new Error("local agent workspace must be an existing directory");
  const statePath = options.statePath
    ? absoluteFrom(workspace, options.statePath)
    : join(workspace, ".zigeffect", "local-agent-sessions.json");
  const registry = createLocalAgentSessionRegistry({ now: options.now });
  const sessionStore = bunLocalAgentSessionStore(statePath);
  const restoreStatus = await restoreLocalAgentSessionRegistry(registry, sessionStore);
  if (restoreStatus === "invalid") throw new Error("invalid local agent session snapshot");
  if (restoreStatus === "restored") {
    await saveLocalAgentSessionRegistry(registry, sessionStore);
  }

  const collector = createCollector();
  const control = createLocalAgentControlServer({
    token: options.token,
    tools: options.tools ?? builtInTools(workspace),
    registry,
    sessionStore,
    runner: options.runner,
    ptyRunner: options.ptyRunner,
    ptySecretLiterals: [options.token, ...secretEnvironmentValues(process.env)],
    fetcher: options.fetcher,
    agentEventsUrl: `${origin}/agent-events`,
    now: options.now,
  });
  let closed = false;

  function fetchHandler(
    request: Request,
    server: Server<undefined>,
  ): Response | Promise<Response> | undefined {
    const path = new URL(request.url).pathname;
    return path === "/agent-control" || path.startsWith("/agent-control/")
      ? control.fetch(request)
      : collector.fetch(request, server);
  }

  async function close(): Promise<void> {
    if (closed) return;
    closed = true;
    for (const sessionId of control.activeSessionIds()) {
      await control.fetch(new Request(`${origin}/agent-control/sessions/${encodeURIComponent(sessionId)}/stop`, {
        method: "POST",
        headers: { authorization: `Bearer ${options.token}` },
      }));
    }
    await control.waitForIdle();
  }

  return {
    origin,
    workspace,
    statePath,
    restoreStatus,
    collector,
    control,
    registry,
    fetch: fetchHandler,
    websocket: collector.websocket,
    close,
  };
}

export function localAgentControlHostConfigFromEnv(
  env: Record<string, string | undefined>,
  cwd: string,
): LocalAgentControlHostConfig {
  const token = env.ZIGEFFECT_CONTROL_TOKEN ?? "";
  requireToken(token);
  const portText = env.ZIGEFFECT_CONTROL_PORT ?? String(DEFAULT_PORT);
  const port = Number(portText);
  if (!Number.isSafeInteger(port) || port < 1 || port > 65535) {
    throw new Error("ZIGEFFECT_CONTROL_PORT must be an integer from 1 to 65535");
  }
  const workspace = resolve(env.ZIGEFFECT_WORKSPACE ?? cwd);
  const statePath = env.ZIGEFFECT_CONTROL_STATE
    ? absoluteFrom(workspace, env.ZIGEFFECT_CONTROL_STATE)
    : join(workspace, ".zigeffect", "local-agent-sessions.json");
  return { token, port, workspace, statePath };
}

function builtInTools(workspace: string): LocalAgentControlTool[] {
  const input = {
    kind: "prompt" as const,
    label: "Task prompt",
    placeholder: "Describe the local development task",
    required: true,
    maxLength: DEFAULT_MAX_PROMPT_LENGTH,
  };
  return [
    {
      id: "codex",
      label: "Codex",
      description: "Run one non-interactive Codex task in the local workspace",
      kind: "codex",
      input,
      build(value) {
        const prompt = promptFromInput(value);
        return codexLocalAgentProcessTool({
          id: "codex",
          prompt,
          cwd: workspace,
          task: prompt,
          checkLabel: "Codex local task",
        });
      },
    },
    {
      id: "claude-code",
      label: "Claude Code",
      description: "Run one non-interactive Claude Code task in the local workspace",
      kind: "claude-code",
      input,
      build(value) {
        const prompt = promptFromInput(value);
        return claudeCodeLocalAgentProcessTool({
          id: "claude-code",
          prompt,
          cwd: workspace,
          task: prompt,
          checkLabel: "Claude Code local task",
        });
      },
    },
    {
      id: "codex-interactive",
      label: "Codex interactive",
      description: "Run an interactive Codex TUI in the local workspace",
      kind: "codex",
      mode: "pty",
      input,
      build(value) {
        const prompt = promptFromInput(value);
        return {
          id: "codex-interactive",
          kind: "codex",
          label: "Codex interactive",
          command: ["codex", "--no-alt-screen", prompt],
          cwd: workspace,
          task: prompt,
          checkLabel: "Codex interactive task",
        };
      },
    },
    {
      id: "claude-code-interactive",
      label: "Claude Code interactive",
      description: "Run an interactive Claude Code TUI in the local workspace",
      kind: "claude-code",
      mode: "pty",
      input,
      build(value) {
        const prompt = promptFromInput(value);
        return {
          id: "claude-code-interactive",
          kind: "claude-code",
          label: "Claude Code interactive",
          command: ["claude", prompt],
          cwd: workspace,
          task: prompt,
          checkLabel: "Claude Code interactive task",
        };
      },
    },
  ];
}

function secretEnvironmentValues(env: Record<string, string | undefined>): string[] {
  const values = new Set<string>();
  for (const [key, value] of Object.entries(env)) {
    if (value && value.length >= 4 && /(token|secret|password|api[_-]?key|authorization|cookie)/i.test(key)) {
      values.add(value);
    }
  }
  return [...values];
}

function promptFromInput(value: unknown): string {
  if (typeof value !== "object" || value === null || !("prompt" in value) || typeof value.prompt !== "string") {
    throw new Error("prompt input is required");
  }
  return value.prompt;
}

function normalizeHostOrigin(value: string): string {
  let url: URL;
  try {
    url = new URL(value);
  } catch {
    throw new Error("local control origin must be loopback HTTP");
  }
  const hostname = url.hostname.toLowerCase();
  const loopback = hostname === "localhost" || hostname === "127.0.0.1" || hostname === "::1" || hostname === "[::1]";
  if (
    url.protocol !== "http:" || !loopback || url.username || url.password ||
    url.search || url.hash || (url.pathname !== "/" && url.pathname !== "")
  ) {
    throw new Error("local control origin must be loopback HTTP without credentials, paths, or parameters");
  }
  return url.origin;
}

function requireToken(value: string): void {
  if (value.length === 0) throw new Error("ZIGEFFECT_CONTROL_TOKEN is required");
  if (value.length > MAX_TOKEN_LENGTH) throw new Error("ZIGEFFECT_CONTROL_TOKEN is too long");
}

function absoluteFrom(base: string, path: string): string {
  return isAbsolute(path) ? path : resolve(base, path);
}

if (import.meta.main) {
  const config = localAgentControlHostConfigFromEnv(process.env, process.cwd());
  const origin = `http://127.0.0.1:${config.port}`;
  const host = await createLocalAgentControlHost({
    token: config.token,
    origin,
    workspace: config.workspace,
    statePath: config.statePath,
  });
  const server = Bun.serve({
    hostname: "127.0.0.1",
    port: config.port,
    fetch: host.fetch,
    websocket: host.websocket,
  });
  const workbenchQuery = `?live=${encodeURIComponent(`ws://127.0.0.1:${server.port}/live`)}&control=${encodeURIComponent(origin)}`;
  // eslint-disable-next-line no-console
  console.log(`zigeffect local agent host on ${origin}`);
  // eslint-disable-next-line no-console
  console.log(`workbench query: ${workbenchQuery}`);
  // eslint-disable-next-line no-console
  console.log(`workspace: ${config.workspace}  sessions: ${config.statePath}`);

  let shuttingDown = false;
  const shutdown = async () => {
    if (shuttingDown) return;
    shuttingDown = true;
    await host.close();
    server.stop(true);
  };
  process.once("SIGINT", () => { void shutdown(); });
  process.once("SIGTERM", () => { void shutdown(); });
}
