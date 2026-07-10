import { expect, test } from "bun:test";
import {
  LocalAgentControlClientError,
  createLocalAgentControlClient,
  localAgentControlBootstrapFromLocation,
  normalizeLocalAgentControlUrl,
  scrubLocalAgentControlTokenFragment,
} from "./localAgentControlClient";

const session = {
  id: "session-1",
  agentId: "codex",
  agentKind: "codex",
  agentLabel: "Codex",
  command: "codex exec --json <redacted>",
  cwd: "/workspace",
  task: "Review schema",
  mode: "pty",
  terminalAvailable: true,
  status: "running",
  startedAt: 10,
  updatedAt: 20,
  finishedAt: null,
  exitCode: null,
  interrupted: false,
  lines: 2,
  turns: 1,
  ignored: 0,
  postedEvents: 4,
  lastSequence: 3,
  detail: null,
} as const;

function wireSession() {
  const { terminalAvailable, ...record } = session;
  return { ...record, terminal_available: terminalAvailable };
}

test("control client accepts only credential-free loopback HTTP URLs", () => {
  expect(normalizeLocalAgentControlUrl("http://127.0.0.1:4500/")).toBe("http://127.0.0.1:4500");
  expect(normalizeLocalAgentControlUrl("http://localhost:4500")).toBe("http://localhost:4500");
  expect(normalizeLocalAgentControlUrl("http://[::1]:4500")).toBe("http://[::1]:4500");

  for (const value of [
    "https://localhost:4500",
    "http://192.168.1.20:4500",
    "http://example.test:4500",
    "http://user:password@localhost:4500",
    "http://localhost:4500/control?token=secret",
    "not a URL",
  ]) {
    expect(() => normalizeLocalAgentControlUrl(value)).toThrow();
  }
});

test("control bootstrap reads and scrubs a one-use token fragment", () => {
  expect(localAgentControlBootstrapFromLocation(
    "?sample=dev-session&control=http%3A%2F%2F127.0.0.1%3A4500",
    "#control-token=secret-value&panel=agents",
  )).toEqual({
    controlUrl: "http://127.0.0.1:4500",
    token: "secret-value",
  });
  expect(scrubLocalAgentControlTokenFragment({
    pathname: "/",
    search: "?sample=dev-session&control=http%3A%2F%2F127.0.0.1%3A4500",
    hash: "#control-token=secret-value&panel=agents",
  })).toBe("/?sample=dev-session&control=http%3A%2F%2F127.0.0.1%3A4500#panel=agents");
  expect(scrubLocalAgentControlTokenFragment({ pathname: "/", search: "", hash: "#control-token=only" })).toBe("/");
});

test("control client authenticates protected routes and parses the complete contract", async () => {
  const seen: Array<{ url: string; method: string; auth: string | null; body: unknown }> = [];
  const fetcher = (async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = String(input);
    const headers = new Headers(init?.headers);
    seen.push({
      url,
      method: init?.method ?? "GET",
      auth: headers.get("authorization"),
      body: init?.body ? JSON.parse(String(init.body)) as unknown : null,
    });
    if (url.endsWith("/health")) return Response.json({ ok: true, active_sessions: 1, persistence: "durable" });
    if (url.endsWith("/tools")) return Response.json({ tools: [{
      id: "codex-review",
      label: "Codex review",
      description: "Review locally",
      kind: "codex",
      mode: "pty",
      input: { kind: "prompt", label: "Task", placeholder: "Review", required: true, max_length: 200 },
    }] });
    if (url.includes("/terminal?after=")) return Response.json({
      frames: [{ sequence: 1, timestamp: 30, data: "ready$ " }],
      next_after: 1,
      gap: false,
      dropped_frames: 0,
      dropped_bytes: 0,
      status: "running",
      cols: 100,
      rows: 30,
      total_bytes: 7,
    });
    if (url.endsWith("/sessions/session-1/input")) return Response.json({ accepted: true, session_id: "session-1" }, { status: 202 });
    if (url.endsWith("/sessions/session-1/resize")) return Response.json({ accepted: true, session_id: "session-1", cols: 120, rows: 40 }, { status: 202 });
    if (url.endsWith("/receipts")) return Response.json({ receipts: [{
      sequence: 1,
      timestamp: 20,
      action: "start",
      outcome: "accepted",
      sessionId: "session-1",
      toolId: "codex-review",
      detail: "started allowlisted tool codex-review",
    }] });
    if (url.endsWith("/sessions/session-1/stop")) return Response.json({ accepted: true, session_id: "session-1" }, { status: 202 });
    if (url.endsWith("/sessions/session-1")) return Response.json({ session: wireSession() });
    if (url.endsWith("/sessions") && init?.method === "POST") {
      return Response.json({ accepted: true, session_id: "session-1" }, { status: 202 });
    }
    if (url.endsWith("/sessions")) return Response.json({ sessions: [wireSession()] });
    return new Response("not found", { status: 404 });
  });
  const client = createLocalAgentControlClient({
    baseUrl: "http://127.0.0.1:4500",
    token: "control-secret",
    fetcher,
  });

  expect(await client.health()).toEqual({ ok: true, activeSessions: 1, persistence: "durable" });
  expect((await client.tools())[0]).toMatchObject({ id: "codex-review", mode: "pty", input: { maxLength: 200 } });
  expect((await client.sessions())[0]).toEqual(session);
  expect(await client.session("session-1")).toEqual(session);
  expect((await client.receipts())[0]).toMatchObject({ action: "start", outcome: "accepted" });
  expect(await client.start({ toolId: "codex-review", sessionId: "session-1", input: { prompt: "Review schema" } }))
    .toEqual({ accepted: true, sessionId: "session-1" });
  expect(await client.stop("session-1")).toEqual({ accepted: true, sessionId: "session-1" });
  expect(await client.terminal("session-1", 0)).toMatchObject({
    frames: [{ sequence: 1, data: "ready$ " }],
    nextAfter: 1,
    status: "running",
    cols: 100,
    rows: 30,
  });
  expect(await client.writeTerminal("session-1", "echo private\r")).toEqual({ accepted: true, sessionId: "session-1" });
  expect(await client.resizeTerminal("session-1", 120, 40)).toEqual({ accepted: true, sessionId: "session-1", cols: 120, rows: 40 });

  expect(seen[0]).toMatchObject({ method: "GET", auth: null });
  expect(seen.slice(1).every((request) => request.auth === "Bearer control-secret")).toBe(true);
  expect(seen.find((request) => request.method === "POST" && request.url.endsWith("/sessions"))?.body).toEqual({
    tool_id: "codex-review",
    session_id: "session-1",
    input: { prompt: "Review schema" },
  });
  expect(seen.find((request) => request.url.endsWith("/sessions/session-1/input"))?.body).toEqual({ data: "echo private\r" });
  expect(seen.find((request) => request.url.endsWith("/sessions/session-1/resize"))?.body).toEqual({ cols: 120, rows: 40 });
});

test("control client maps authorization and policy failures without leaking credentials", async () => {
  const responses = [
    new Response("unauthorized token=sentinel-secret", { status: 401 }),
    new Response("tool input rejected password=hunter2", { status: 400 }),
    new Response("session not found", { status: 404 }),
  ];
  const client = createLocalAgentControlClient({
    baseUrl: "http://localhost:4500",
    token: "sentinel-secret",
    fetcher: async () => responses.shift()!,
  });

  for (const [operation, code] of [
    [() => client.tools(), "unauthorized"],
    [() => client.start({ toolId: "codex-review" }), "policy"],
    [() => client.session("missing"), "not_found"],
  ] as const) {
    try {
      await operation();
      throw new Error("expected operation to fail");
    } catch (error) {
      expect(error).toBeInstanceOf(LocalAgentControlClientError);
      expect((error as LocalAgentControlClientError).code).toBe(code);
      expect(String(error)).not.toContain("sentinel-secret");
      expect(String(error)).not.toContain("hunter2");
    }
  }
});

test("control client rejects oversized and malformed success payloads", async () => {
  const oversized = createLocalAgentControlClient({
    baseUrl: "http://localhost:4500",
    token: "secret",
    maxResponseBytes: 64,
    fetcher: async () => new Response(JSON.stringify({ sessions: ["x".repeat(100)] })),
  });
  await expect(oversized.sessions()).rejects.toMatchObject({ code: "response_too_large" });

  const malformed = createLocalAgentControlClient({
    baseUrl: "http://localhost:4500",
    token: "secret",
    fetcher: async () => Response.json({ sessions: [{ id: "unsafe/id" }] }),
  });
  await expect(malformed.sessions()).rejects.toMatchObject({ code: "invalid_response" });

  const unavailable = createLocalAgentControlClient({
    baseUrl: "http://localhost:4500",
    token: "secret",
    fetcher: async () => { throw new Error("fetch failed for token=secret"); },
  });
  await expect(unavailable.health()).rejects.toMatchObject({
    code: "unavailable",
    message: "local control server unavailable",
  });
});

test("control client normalizes cancellation while reading a response body", async () => {
  const controller = new AbortController();
  const client = createLocalAgentControlClient({
    baseUrl: "http://localhost:4500",
    token: "secret",
    fetcher: async (_input, init) => new Response(new ReadableStream<Uint8Array>({
      start(streamController) {
        init?.signal?.addEventListener("abort", () => {
          streamController.error(new DOMException("aborted", "AbortError"));
        });
      },
    })),
  });

  const pending = client.health(controller.signal);
  controller.abort();
  await expect(pending).rejects.toMatchObject({
    code: "cancelled",
    message: "local control request cancelled",
  });
});

test("control client rejects malformed terminal frames and invalid commands", async () => {
  const requests: string[] = [];
  const client = createLocalAgentControlClient({
    baseUrl: "http://localhost:4500",
    token: "secret",
    fetcher: async (input) => {
      requests.push(String(input));
      return Response.json({
        frames: [{ sequence: 0, timestamp: -1, data: 42 }],
        next_after: 0,
        gap: false,
        dropped_frames: 0,
        dropped_bytes: 0,
        status: "running",
        cols: 100,
        rows: 30,
        total_bytes: 0,
      });
    },
  });

  await expect(client.terminal("session-1", 0)).rejects.toMatchObject({ code: "invalid_response" });
  await expect(client.terminal("session-1", -1)).rejects.toMatchObject({ code: "policy" });
  await expect(client.writeTerminal("session-1", "x".repeat(20_000))).rejects.toMatchObject({ code: "policy" });
  await expect(client.resizeTerminal("session-1", 2, 999)).rejects.toMatchObject({ code: "policy" });
  expect(requests).toHaveLength(1);
});
