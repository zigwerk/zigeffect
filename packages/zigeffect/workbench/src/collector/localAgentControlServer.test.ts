import { expect, test } from "bun:test";
import type { LocalDevSessionEvent } from "../localDevSessionFeed";
import {
  createLocalAgentControlServer,
  type LocalAgentControlTool,
} from "./localAgentControlServer";
import type { LocalAgentProcessRunner } from "./localAgentProcessSupervisor";
import type { LocalAgentPtyHandle, LocalAgentPtyRunner, LocalAgentPtyRunnerOptions } from "./localAgentPtySupervisor";
import { createLocalAgentSessionRegistry } from "./localAgentSessionRegistry";

const baseUrl = "http://127.0.0.1:4500";

function request(
  path: string,
  options: RequestInit & { token?: string } = {},
): Request {
  const headers = new Headers(options.headers);
  if (options.token) headers.set("authorization", `Bearer ${options.token}`);
  if (options.body && !headers.has("content-type")) headers.set("content-type", "application/json");
  return new Request(`${baseUrl}${path}`, { ...options, headers });
}

function streamFromText(text: string): ReadableStream<Uint8Array> {
  const bytes = new TextEncoder().encode(text);
  return new ReadableStream<Uint8Array>({
    start(controller) {
      if (bytes.byteLength > 0) controller.enqueue(bytes);
      controller.close();
    },
  });
}

function eventCapture(events: LocalDevSessionEvent[]): typeof fetch {
  return (async (_input: RequestInfo | URL, init?: RequestInit) => {
    events.push(JSON.parse(String(init?.body)) as LocalDevSessionEvent);
    return new Response(JSON.stringify({ ingested: 1 }), {
      headers: { "content-type": "application/json" },
    });
  }) as typeof fetch;
}

function codexTool(overrides: Partial<LocalAgentControlTool> = {}): LocalAgentControlTool {
  return {
    id: "codex-review",
    label: "Codex review",
    description: "Review the local workspace",
    kind: "codex",
    input: {
      kind: "prompt",
      label: "Task prompt",
      placeholder: "Review token=sentinel-secret",
      required: true,
      maxLength: 200,
    },
    build(input) {
      const prompt = typeof input === "object" && input !== null && "prompt" in input
        ? String((input as { prompt: unknown }).prompt)
        : "review locally";
      if (prompt.length > 200) throw new Error("prompt too long token=sentinel-secret");
      return {
        id: "codex",
        kind: "codex",
        label: "Codex",
        command: ["codex", "exec", "--json", prompt],
        task: prompt,
      };
    },
    ...overrides,
  };
}

function ptyTool(overrides: Partial<LocalAgentControlTool> = {}): LocalAgentControlTool {
  return codexTool({
    id: "codex-interactive",
    label: "Codex interactive",
    mode: "pty",
    build(input) {
      const prompt = typeof input === "object" && input !== null && "prompt" in input
        ? String((input as { prompt: unknown }).prompt)
        : "work interactively";
      return {
        id: "codex-interactive",
        kind: "codex",
        label: "Codex interactive",
        command: ["codex", "--no-alt-screen", prompt],
        task: prompt,
      };
    },
    ...overrides,
  });
}

function fakePtyRunner() {
  let options: LocalAgentPtyRunnerOptions | null = null;
  let resolveExit!: (code: number) => void;
  const exited = new Promise<number>((resolve) => { resolveExit = resolve; });
  const writes: string[] = [];
  const resizes: Array<[number, number]> = [];
  let kills = 0;
  const handle: LocalAgentPtyHandle = {
    exited,
    write(data) { writes.push(data); return data.length; },
    resize(cols, rows) { resizes.push([cols, rows]); },
    kill() { kills += 1; resolveExit(143); },
    close() {},
  };
  const runner: LocalAgentPtyRunner = {
    async start(_tool, value) { options = value; return handle; },
  };
  return { runner, options: () => options!, writes, resizes, resolveExit, kills: () => kills };
}

test("control server keeps health open and bearer-gates safe tool metadata", async () => {
  const server = createLocalAgentControlServer({
    token: "control-secret",
    tools: [codexTool()],
    registry: createLocalAgentSessionRegistry(),
    agentEventsUrl: "http://collector.test/agent-events",
  });

  const health = await server.fetch(request("/agent-control/health"));
  expect(health.status).toBe(200);
  expect(await health.json()).toEqual({ ok: true, active_sessions: 0, persistence: "memory" });
  expect(health.headers.get("access-control-allow-origin")).toBe("*");

  const unauthorized = await server.fetch(request("/agent-control/tools"));
  expect(unauthorized.status).toBe(401);
  expect(unauthorized.headers.get("access-control-allow-origin")).toBe("*");

  const tools = await server.fetch(request("/agent-control/tools", { token: "control-secret" }));
  expect(tools.status).toBe(200);
  const payload = await tools.json() as { tools: unknown[] };
  expect(payload.tools).toEqual([{
    id: "codex-review",
    label: "Codex review",
    description: "Review the local workspace",
    kind: "codex",
    mode: "batch",
    input: {
      kind: "prompt",
      label: "Task prompt",
      placeholder: "Review token=<redacted>",
      required: true,
      max_length: 200,
    },
  }]);
  expect(JSON.stringify(payload)).not.toContain("command");
  expect(JSON.stringify(payload)).not.toContain("sentinel-secret");

  const preflight = await server.fetch(request("/agent-control/sessions", { method: "OPTIONS" }));
  expect(preflight.status).toBe(204);
  expect(preflight.headers.get("access-control-allow-headers")).toContain("authorization");
});

test("control server starts an allowlisted tool and serves durable session detail", async () => {
  const events: LocalDevSessionEvent[] = [];
  const registry = createLocalAgentSessionRegistry({ now: () => 10 });
  let starts = 0;
  const runner: LocalAgentProcessRunner = {
    async start(tool) {
      starts += 1;
      expect(tool.command).toEqual(["codex", "exec", "--json", "review schema"]);
      return {
        stdout: streamFromText("assistant: review complete\n"),
        stderr: streamFromText(""),
        exited: Promise.resolve(0),
        kill() {},
      };
    },
  };
  const server = createLocalAgentControlServer({
    token: "control-secret",
    tools: [codexTool()],
    registry,
    runner,
    fetcher: eventCapture(events),
    agentEventsUrl: "http://collector.test/agent-events",
    now: () => 10,
  });

  const response = await server.fetch(request("/agent-control/sessions", {
    method: "POST",
    token: "control-secret",
    body: JSON.stringify({
      tool_id: "codex-review",
      session_id: "review-session",
      input: { prompt: "review schema" },
    }),
  }));
  expect(response.status).toBe(202);
  expect(await response.json()).toMatchObject({ accepted: true, session_id: "review-session" });
  await server.waitForIdle();

  expect(starts).toBe(1);
  expect(server.activeSessionIds()).toEqual([]);
  expect(registry.get("review-session")).toMatchObject({ status: "done", turns: 1 });

  const list = await server.fetch(request("/agent-control/sessions", { token: "control-secret" }));
  expect(await list.json()).toMatchObject({ sessions: [{ id: "review-session", status: "done" }] });
  const detail = await server.fetch(request("/agent-control/sessions/review-session", { token: "control-secret" }));
  expect(detail.status).toBe(200);
  expect(await detail.json()).toMatchObject({ session: { id: "review-session", status: "done" } });
  expect(server.receipts()).toMatchObject([{
    sequence: 1,
    action: "start",
    outcome: "accepted",
    sessionId: "review-session",
    toolId: "codex-review",
  }]);
});

test("control server rejects unknown tools, invalid builders, and oversized bodies without spawning", async () => {
  let starts = 0;
  const server = createLocalAgentControlServer({
    token: "control-secret",
    tools: [codexTool()],
    registry: createLocalAgentSessionRegistry(),
    runner: { async start() { starts += 1; throw new Error("must not run"); } },
    agentEventsUrl: "http://collector.test/agent-events",
    maxBodyBytes: 512,
    maxReceipts: 2,
  });

  const unknown = await server.fetch(request("/agent-control/sessions", {
    method: "POST",
    token: "control-secret",
    body: JSON.stringify({ tool_id: "not-allowed", session_id: "unknown-session" }),
  }));
  expect(unknown.status).toBe(403);

  const invalid = await server.fetch(request("/agent-control/sessions", {
    method: "POST",
    token: "control-secret",
    body: JSON.stringify({
      tool_id: "codex-review",
      session_id: "invalid-session",
      input: { prompt: `${"x".repeat(201)} token=sentinel-secret` },
    }),
  }));
  expect(invalid.status).toBe(400);

  const missingPrompt = await server.fetch(request("/agent-control/sessions", {
    method: "POST",
    token: "control-secret",
    body: JSON.stringify({ tool_id: "codex-review", session_id: "missing-prompt", input: {} }),
  }));
  expect(missingPrompt.status).toBe(400);

  const injectedArgv = await server.fetch(request("/agent-control/sessions", {
    method: "POST",
    token: "control-secret",
    body: JSON.stringify({
      tool_id: "codex-review",
      session_id: "injected-argv",
      input: { prompt: "review", argv: ["sh", "-c", "unsafe"] },
    }),
  }));
  expect(injectedArgv.status).toBe(400);

  const oversized = await server.fetch(request("/agent-control/sessions", {
    method: "POST",
    token: "control-secret",
    body: JSON.stringify({ tool_id: "codex-review", input: "x".repeat(1_000) }),
  }));
  expect(oversized.status).toBe(413);
  expect(starts).toBe(0);
  expect(server.receipts().length).toBeLessThanOrEqual(2);
  expect(JSON.stringify(server.receipts())).not.toContain("sentinel-secret");
});

test("control server rejects duplicate ownership and stop aborts exactly one child", async () => {
  const events: LocalDevSessionEvent[] = [];
  const registry = createLocalAgentSessionRegistry({ now: () => 10 });
  let kills = 0;
  let stdoutController: ReadableStreamDefaultController<Uint8Array> | undefined;
  let resolveExit: ((code: number) => void) | undefined;
  const exited = new Promise<number>((resolve) => {
    resolveExit = resolve;
  });
  const runner: LocalAgentProcessRunner = {
    async start() {
      return {
        stdout: new ReadableStream<Uint8Array>({ start(controller) { stdoutController = controller; } }),
        stderr: streamFromText(""),
        exited,
        kill() {
          kills += 1;
          stdoutController?.close();
          resolveExit?.(143);
        },
      };
    },
  };
  const server = createLocalAgentControlServer({
    token: "control-secret",
    tools: [codexTool()],
    registry,
    runner,
    fetcher: eventCapture(events),
    agentEventsUrl: "http://collector.test/agent-events",
    now: () => 10,
  });
  const startBody = JSON.stringify({
    tool_id: "codex-review",
    session_id: "active-session",
    input: { prompt: "review locally" },
  });
  expect((await server.fetch(request("/agent-control/sessions", {
    method: "POST", token: "control-secret", body: startBody,
  }))).status).toBe(202);
  expect((await server.fetch(request("/agent-control/sessions", {
    method: "POST", token: "control-secret", body: startBody,
  }))).status).toBe(409);

  const stop = await server.fetch(request("/agent-control/sessions/active-session/stop", {
    method: "POST",
    token: "control-secret",
  }));
  expect(stop.status).toBe(202);
  await server.waitForIdle();

  expect(kills).toBe(1);
  expect(registry.get("active-session")).toMatchObject({ status: "interrupted", interrupted: true });
  expect(server.receipts().map((receipt) => `${receipt.action}:${receipt.outcome}`)).toEqual([
    "start:accepted",
    "start:rejected",
    "stop:accepted",
  ]);
  expect((await server.fetch(request("/agent-control/sessions/active-session/stop", {
    method: "POST", token: "control-secret",
  }))).status).toBe(409);
});

test("control server validates configuration and bounds receipt history", async () => {
  const registry = createLocalAgentSessionRegistry();
  expect(() => createLocalAgentControlServer({
    token: "",
    tools: [codexTool()],
    registry,
    agentEventsUrl: "http://collector.test/agent-events",
  })).toThrow("control token must not be empty");
  expect(() => createLocalAgentControlServer({
    token: "secret",
    tools: [codexTool(), codexTool()],
    registry,
    agentEventsUrl: "http://collector.test/agent-events",
  })).toThrow("duplicate control tool id");
  expect(() => createLocalAgentControlServer({
    token: "secret",
    tools: [codexTool({ input: {
      kind: "prompt",
      label: "Prompt",
      maxLength: 0,
    } })],
    registry,
    agentEventsUrl: "http://collector.test/agent-events",
  })).toThrow("tool input maxLength must be a positive safe integer");

  const durable = createLocalAgentControlServer({
    token: "secret",
    tools: [],
    registry,
    sessionStore: {
      async read() { return null; },
      async write() {},
    },
    agentEventsUrl: "http://collector.test/agent-events",
  });
  expect(await (await durable.fetch(request("/agent-control/health"))).json()).toEqual({
    ok: true,
    active_sessions: 0,
    persistence: "durable",
  });

  const mirrored: unknown[] = [];
  const server = createLocalAgentControlServer({
    token: "secret",
    tools: [codexTool()],
    registry,
    agentEventsUrl: "http://collector.test/agent-events",
    maxReceipts: 2,
    receiptSink: async (receipt) => { mirrored.push(receipt); },
  });
  for (const id of ["one", "two", "three"]) {
    await server.fetch(request("/agent-control/sessions", {
      method: "POST",
      token: "secret",
      body: JSON.stringify({ tool_id: "unknown-tool", session_id: id }),
    }));
  }
  expect(server.receipts().map((receipt) => receipt.sessionId)).toEqual(["two", "three"]);
  expect(mirrored).toHaveLength(3);

  const receipts = await server.fetch(request("/agent-control/receipts", { token: "secret" }));
  expect(receipts.status).toBe(200);
  expect((await receipts.json() as { receipts: unknown[] }).receipts).toHaveLength(2);
});

test("control server reports registry capacity conflicts before accepting ownership", async () => {
  const registry = createLocalAgentSessionRegistry({ maxSessions: 1, now: () => 1 });
  registry.begin({
    agentId: "existing",
    agentKind: "codex",
    agentLabel: "Existing",
    command: ["codex", "exec"],
  }, "existing-session");
  let starts = 0;
  const server = createLocalAgentControlServer({
    token: "secret",
    tools: [codexTool()],
    registry,
    runner: { async start() { starts += 1; throw new Error("must not start"); } },
    agentEventsUrl: "http://collector.test/agent-events",
  });

  const response = await server.fetch(request("/agent-control/sessions", {
    method: "POST",
    token: "secret",
    body: JSON.stringify({
      tool_id: "codex-review",
      session_id: "new-session",
      input: { prompt: "review locally" },
    }),
  }));

  expect(response.status).toBe(409);
  expect(starts).toBe(0);
  expect(server.receipts().at(-1)).toMatchObject({ action: "start", outcome: "rejected" });
});

test("control receipt mirrors cannot block policy responses", async () => {
  const server = createLocalAgentControlServer({
    token: "secret",
    tools: [codexTool()],
    registry: createLocalAgentSessionRegistry(),
    agentEventsUrl: "http://collector.test/agent-events",
    receiptSink: async () => new Promise<void>(() => {}),
  });

  const result = await Promise.race([
    server.fetch(request("/agent-control/sessions", {
      method: "POST",
      token: "secret",
      body: JSON.stringify({ tool_id: "unknown", session_id: "unknown-session" }),
    })),
    Bun.sleep(50).then(() => "timeout" as const),
  ]);

  expect(result).not.toBe("timeout");
  expect((result as Response).status).toBe(403);
});

test("control server owns interactive PTY input, resize, output, and retained completion", async () => {
  const pty = fakePtyRunner();
  const events: LocalDevSessionEvent[] = [];
  const server = createLocalAgentControlServer({
    token: "control-secret",
    tools: [ptyTool()],
    registry: createLocalAgentSessionRegistry({ now: () => 10 }),
    ptyRunner: pty.runner,
    fetcher: eventCapture(events),
    agentEventsUrl: "http://collector.test/agent-events",
    now: () => 10,
  });

  const tools = await server.fetch(request("/agent-control/tools", { token: "control-secret" }));
  expect(await tools.json()).toMatchObject({ tools: [{ id: "codex-interactive", mode: "pty" }] });
  const start = await server.fetch(request("/agent-control/sessions", {
    method: "POST",
    token: "control-secret",
    body: JSON.stringify({
      tool_id: "codex-interactive",
      session_id: "interactive-session",
      input: { prompt: "Review schema" },
    }),
  }));
  expect(start.status).toBe(202);
  expect(await (await server.fetch(request("/agent-control/sessions", { token: "control-secret" }))).json()).toMatchObject({
    sessions: [{ id: "interactive-session", mode: "pty", terminal_available: true }],
  });

  pty.options().onData(new TextEncoder().encode("ready token=sentinel-secret\r\n"));
  await Promise.resolve();
  const output = await server.fetch(request("/agent-control/sessions/interactive-session/terminal?after=0", {
    token: "control-secret",
  }));
  expect(output.status).toBe(200);
  expect(await output.json()).toMatchObject({
    frames: [{ sequence: 1, data: "ready token=<redacted>\r\n" }],
    next_after: 1,
    gap: false,
    status: "running",
  });

  const input = await server.fetch(request("/agent-control/sessions/interactive-session/input", {
    method: "POST",
    token: "control-secret",
    body: JSON.stringify({ data: "private-input\r" }),
  }));
  const resize = await server.fetch(request("/agent-control/sessions/interactive-session/resize", {
    method: "POST",
    token: "control-secret",
    body: JSON.stringify({ cols: 132, rows: 44 }),
  }));
  expect(input.status).toBe(202);
  expect(resize.status).toBe(202);
  expect(pty.writes).toEqual(["private-input\r"]);
  expect(pty.resizes).toEqual([[132, 44]]);
  expect(JSON.stringify(server.receipts())).not.toContain("private-input");

  pty.resolveExit(0);
  await server.waitForIdle();
  const retained = await server.fetch(request("/agent-control/sessions/interactive-session/terminal?after=1", {
    token: "control-secret",
  }));
  expect(retained.status).toBe(200);
  expect(await retained.json()).toMatchObject({ frames: [], next_after: 1, status: "done", cols: 132, rows: 44 });
});

test("terminal routes reject batch sessions, invalid cursors, input, and dimensions", async () => {
  const events: LocalDevSessionEvent[] = [];
  const server = createLocalAgentControlServer({
    token: "secret",
    tools: [codexTool()],
    registry: createLocalAgentSessionRegistry(),
    runner: {
      async start() {
        return { stdout: streamFromText(""), stderr: streamFromText(""), exited: Promise.resolve(0), kill() {} };
      },
    },
    fetcher: eventCapture(events),
    agentEventsUrl: "http://collector.test/agent-events",
  });
  await server.fetch(request("/agent-control/sessions", {
    method: "POST",
    token: "secret",
    body: JSON.stringify({ tool_id: "codex-review", session_id: "batch-session", input: { prompt: "review" } }),
  }));
  await server.waitForIdle();

  expect((await server.fetch(request("/agent-control/sessions/batch-session/terminal?after=0", { token: "secret" }))).status).toBe(409);
  expect((await server.fetch(request("/agent-control/sessions/missing/terminal?after=0", { token: "secret" }))).status).toBe(404);
  expect((await server.fetch(request("/agent-control/sessions/batch-session/terminal?after=-1", { token: "secret" }))).status).toBe(400);
  expect((await server.fetch(request("/agent-control/sessions/batch-session/input", {
    method: "POST", token: "secret", body: JSON.stringify({ data: 42 }),
  }))).status).toBe(400);
  expect((await server.fetch(request("/agent-control/sessions/batch-session/resize", {
    method: "POST", token: "secret", body: JSON.stringify({ cols: 2, rows: 999 }),
  }))).status).toBe(400);
});

test("completed PTY history remains available at the configured retention boundary", async () => {
  const pty = fakePtyRunner();
  const server = createLocalAgentControlServer({
    token: "secret",
    tools: [ptyTool()],
    registry: createLocalAgentSessionRegistry(),
    ptyRunner: pty.runner,
    maxPtySessions: 1,
    fetcher: eventCapture([]),
    agentEventsUrl: "http://collector.test/agent-events",
  });
  expect((await server.fetch(request("/agent-control/sessions", {
    method: "POST",
    token: "secret",
    body: JSON.stringify({
      tool_id: "codex-interactive",
      session_id: "retained-session",
      input: { prompt: "review" },
    }),
  }))).status).toBe(202);

  pty.resolveExit(0);
  await server.waitForIdle();
  const terminal = await server.fetch(request("/agent-control/sessions/retained-session/terminal?after=0", {
    token: "secret",
  }));
  expect(terminal.status).toBe(200);
  expect(await terminal.json()).toMatchObject({ status: "done" });
});
