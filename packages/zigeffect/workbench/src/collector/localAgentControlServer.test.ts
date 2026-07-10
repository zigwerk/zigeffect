import { expect, test } from "bun:test";
import type { LocalDevSessionEvent } from "../localDevSessionFeed";
import {
  createLocalAgentControlServer,
  type LocalAgentControlTool,
} from "./localAgentControlServer";
import type { LocalAgentProcessRunner } from "./localAgentProcessSupervisor";
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

test("control server keeps health open and bearer-gates safe tool metadata", async () => {
  const server = createLocalAgentControlServer({
    token: "control-secret",
    tools: [codexTool()],
    registry: createLocalAgentSessionRegistry(),
    agentEventsUrl: "http://collector.test/agent-events",
  });

  const health = await server.fetch(request("/agent-control/health"));
  expect(health.status).toBe(200);
  expect(await health.json()).toEqual({ ok: true, active_sessions: 0 });
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
  }]);
  expect(JSON.stringify(payload)).not.toContain("command");

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
  const startBody = JSON.stringify({ tool_id: "codex-review", session_id: "active-session" });
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
    body: JSON.stringify({ tool_id: "codex-review", session_id: "new-session" }),
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
