import { expect, test } from "bun:test";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { Server } from "bun";
import type { LocalDevSessionEvent } from "../localDevSessionFeed";
import type { LocalAgentProcessRunner } from "./localAgentProcessSupervisor";
import type { LocalAgentPtyRunner } from "./localAgentPtySupervisor";
import { createLocalAgentSessionRegistry } from "./localAgentSessionRegistry";
import {
  createLocalAgentControlHost,
  localAgentControlHostConfigFromEnv,
  type LocalAgentControlHost,
} from "./localAgentControlHost";

function request(path: string, options: RequestInit & { token?: string } = {}): Request {
  const headers = new Headers(options.headers);
  if (options.token) headers.set("authorization", `Bearer ${options.token}`);
  if (options.body) headers.set("content-type", "application/json");
  return new Request(`http://127.0.0.1:4510${path}`, { ...options, headers });
}

function hostFetch(host: LocalAgentControlHost, value: Request): Promise<Response> | Response | undefined {
  return host.fetch(value, { upgrade() { return false; } } as unknown as Server<undefined>);
}

function stream(text: string): ReadableStream<Uint8Array> {
  const bytes = new TextEncoder().encode(text);
  return new ReadableStream({
    start(controller) {
      if (bytes.length > 0) controller.enqueue(bytes);
      controller.close();
    },
  });
}

test("local control host composes collector routes with durable Codex and Claude tools", async () => {
  const directory = await mkdtemp(join(tmpdir(), "zigeffect-control-host-"));
  try {
    const host = await createLocalAgentControlHost({
      token: "control-secret",
      origin: "http://127.0.0.1:4510",
      workspace: directory,
    });

    expect(host.restoreStatus).toBe("empty");
    expect(await (await hostFetch(host, request("/health"))!).json()).toEqual({ ok: true, clients: 0 });
    expect(await (await hostFetch(host, request("/agent-control/health"))!).json()).toEqual({
      ok: true,
      active_sessions: 0,
      persistence: "durable",
    });
    const tools = await (await hostFetch(host, request("/agent-control/tools", { token: "control-secret" }))!).json() as {
      tools: Array<Record<string, unknown>>;
    };
    expect(tools.tools.map((tool) => tool.id)).toEqual([
      "codex",
      "claude-code",
      "codex-interactive",
      "claude-code-interactive",
    ]);
    expect(tools.tools.every((tool) => (tool.input as { kind?: string }).kind === "prompt")).toBe(true);
    expect(JSON.stringify(tools)).not.toContain("command");
    await host.close();
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});

test("local control host persists recovery interruption before serving history", async () => {
  const directory = await mkdtemp(join(tmpdir(), "zigeffect-control-recovery-"));
  const statePath = join(directory, "sessions.json");
  try {
    const registry = createLocalAgentSessionRegistry({ now: () => 10 });
    registry.begin({
      agentId: "codex",
      agentKind: "codex",
      agentLabel: "Codex",
      command: ["codex", "exec", "--json", "review"],
    }, "stale-session");
    registry.markRunning("stale-session");
    await Bun.write(statePath, JSON.stringify(registry.snapshot()));

    const host = await createLocalAgentControlHost({
      token: "control-secret",
      origin: "http://localhost:4510",
      workspace: directory,
      statePath,
      now: () => 20,
    });

    expect(host.restoreStatus).toBe("restored");
    expect(host.registry.get("stale-session")).toMatchObject({
      status: "interrupted",
      interrupted: true,
      finishedAt: 20,
    });
    expect(JSON.parse(await readFile(statePath, "utf8"))).toMatchObject({
      sessions: [{ id: "stale-session", status: "interrupted", interrupted: true }],
    });
    await host.close();
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});

test("local control host runs built-in tools in the configured workspace and closes ownership", async () => {
  const directory = await mkdtemp(join(tmpdir(), "zigeffect-control-run-"));
  const events: LocalDevSessionEvent[] = [];
  const commands: string[][] = [];
  const runner: LocalAgentProcessRunner = {
    async start(tool) {
      commands.push([...tool.command]);
      expect(tool.cwd).toBe(directory);
      return {
        stdout: stream(""),
        stderr: stream(""),
        exited: Promise.resolve(0),
        kill() {},
      };
    },
  };
  try {
    const host = await createLocalAgentControlHost({
      token: "control-secret",
      origin: "http://127.0.0.1:4510",
      workspace: directory,
      runner,
      fetcher: (async (_input: RequestInfo | URL, init?: RequestInit) => {
        events.push(JSON.parse(String(init?.body)) as LocalDevSessionEvent);
        return Response.json({ ingested: 1 });
      }) as unknown as typeof fetch,
    });
    const response = await hostFetch(host, request("/agent-control/sessions", {
      method: "POST",
      token: "control-secret",
      body: JSON.stringify({
        tool_id: "codex",
        session_id: "host-session",
        input: { prompt: "Review schema" },
      }),
    }));
    expect(response?.status).toBe(202);
    await host.control.waitForIdle();

    expect(commands).toEqual([["codex", "exec", "--json", "Review schema"]]);
    expect(events.length).toBeGreaterThan(1);
    expect(host.registry.get("host-session")?.status).toBe("done");
    await host.close();
    expect(host.control.activeSessionIds()).toEqual([]);
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});

test("local control host configuration requires a token and loopback port", async () => {
  expect(() => localAgentControlHostConfigFromEnv({}, "/workspace")).toThrow("ZIGEFFECT_CONTROL_TOKEN is required");
  expect(() => localAgentControlHostConfigFromEnv({
    ZIGEFFECT_CONTROL_TOKEN: "secret",
    ZIGEFFECT_CONTROL_PORT: "70000",
  }, "/workspace")).toThrow("ZIGEFFECT_CONTROL_PORT");
  expect(localAgentControlHostConfigFromEnv({
    ZIGEFFECT_CONTROL_TOKEN: "secret",
    ZIGEFFECT_CONTROL_PORT: "4510",
    ZIGEFFECT_WORKSPACE: "/workspace/project",
  }, "/workspace")).toEqual({
    token: "secret",
    port: 4510,
    workspace: "/workspace/project",
    statePath: "/workspace/project/.zigeffect/local-agent-sessions.json",
  });

  await expect(createLocalAgentControlHost({
    token: "secret",
    origin: "http://192.168.1.2:4510",
    workspace: "/workspace",
  })).rejects.toThrow("loopback HTTP");
});

test("local control host interactive tools use PTY-safe Codex and Claude argv without bypasses", async () => {
  const directory = await mkdtemp(join(tmpdir(), "zigeffect-control-interactive-"));
  const commands: string[][] = [];
  const ptyRunner: LocalAgentPtyRunner = {
    async start(tool) {
      commands.push([...tool.command]);
      return {
        exited: Promise.resolve(0),
        write() { return 0; },
        resize() {},
        kill() {},
        close() {},
      };
    },
  };
  try {
    const host = await createLocalAgentControlHost({
      token: "control-secret",
      origin: "http://127.0.0.1:4510",
      workspace: directory,
      ptyRunner,
      fetcher: (async () => Response.json({ ingested: 1 })) as unknown as typeof fetch,
    });
    for (const toolId of ["codex-interactive", "claude-code-interactive"]) {
      const response = await hostFetch(host, request("/agent-control/sessions", {
        method: "POST",
        token: "control-secret",
        body: JSON.stringify({
          tool_id: toolId,
          session_id: `${toolId}-session`,
          input: { prompt: "Review schema" },
        }),
      }));
      expect(response?.status).toBe(202);
      await host.control.waitForIdle();
    }

    expect(commands).toEqual([
      ["codex", "--no-alt-screen", "Review schema"],
      ["claude", "Review schema"],
    ]);
    expect(commands.flat().join(" ")).not.toContain("dangerously");
    expect(commands.flat().join(" ")).not.toContain("bypass");
    await host.close();
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});
