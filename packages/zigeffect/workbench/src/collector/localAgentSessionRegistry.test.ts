import { expect, test } from "bun:test";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { LocalDevSessionEvent } from "../localDevSessionFeed";
import {
  bunLocalAgentSessionStore,
  createLocalAgentSessionRegistry,
  restoreLocalAgentSessionRegistry,
  saveLocalAgentSessionRegistry,
  type LocalAgentSessionStore,
} from "./localAgentSessionRegistry";
import {
  runLocalAgentProcessSupervisor,
  type LocalAgentProcessRunner,
} from "./localAgentProcessSupervisor";

function descriptor(id = "codex") {
  return {
    agentId: id,
    agentKind: "codex" as const,
    agentLabel: "Codex token=sentinel-secret",
    command: ["codex", "exec", "password=sentinel-secret"],
    cwd: "/repo/secret=sentinel-secret",
    task: "schema token=sentinel-secret",
  };
}

function terminal(status: "done" | "failed" | "interrupted" = "done") {
  return {
    status,
    exitCode: status === "done" ? 0 : 1,
    interrupted: status === "interrupted",
    lines: 4,
    turns: 3,
    ignored: 1,
    postedEvents: 6,
    lastSequence: 7,
    detail: status === "done" ? undefined : "failure secret=sentinel-secret",
  };
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

test("session registry records redacted lifecycle state and terminal counters", () => {
  let now = 100;
  const registry = createLocalAgentSessionRegistry({ now: () => now });
  const started = registry.begin(descriptor(), "session-1");

  expect(started).toMatchObject({
    id: "session-1",
    status: "starting",
    startedAt: 100,
    updatedAt: 100,
    finishedAt: null,
    command: "codex exec password=<redacted>",
    cwd: "/repo/secret=<redacted>",
    task: "schema token=<redacted>",
  });
  now = 110;
  registry.markRunning("session-1");
  now = 120;
  registry.finish("session-1", terminal("failed"));

  expect(registry.get("session-1")).toMatchObject({
    status: "failed",
    exitCode: 1,
    interrupted: false,
    lines: 4,
    turns: 3,
    ignored: 1,
    postedEvents: 6,
    lastSequence: 7,
    detail: "failure secret=<redacted>",
    updatedAt: 120,
    finishedAt: 120,
  });
  expect(registry.stateVersion()).toBe(3);
  expect(JSON.stringify(registry.snapshot())).not.toContain("sentinel-secret");
});

test("session registry restore is all-or-nothing and interrupts stale active records", () => {
  let sourceNow = 10;
  const source = createLocalAgentSessionRegistry({ now: () => sourceNow });
  source.begin(descriptor("done-agent"), "done-session");
  sourceNow = 20;
  source.finish("done-session", terminal("done"));
  source.begin(descriptor("running-agent"), "running-session");
  source.markRunning("running-session");

  const target = createLocalAgentSessionRegistry({ now: () => 500 });
  expect(target.restore(JSON.parse(JSON.stringify(source.snapshot())))).toBe(true);
  expect(target.get("done-session")?.status).toBe("done");
  expect(target.get("running-session")).toMatchObject({
    status: "interrupted",
    interrupted: true,
    finishedAt: 500,
    updatedAt: 500,
    detail: "interrupted during registry recovery",
  });

  const before = target.snapshot();
  expect(target.restore({ schema: "zigeffect.local-agent-sessions.v2", sessions: [] })).toBe(false);
  expect(target.restore({ schema: "zigeffect.local-agent-sessions.v1", sessions: [{ id: "broken" }] })).toBe(false);
  expect(target.snapshot()).toEqual(before);
});

test("session registry evicts only the oldest terminal record at capacity", () => {
  let now = 1;
  const registry = createLocalAgentSessionRegistry({ maxSessions: 2, now: () => now });
  registry.begin(descriptor("active"), "active");
  registry.markRunning("active");
  now = 2;
  registry.begin(descriptor("old"), "old");
  registry.finish("old", terminal("done"));
  now = 3;
  registry.begin(descriptor("new"), "new");

  expect(registry.get("active")?.status).toBe("running");
  expect(registry.get("old")).toBeNull();
  expect(registry.get("new")?.status).toBe("starting");

  const activeOnly = createLocalAgentSessionRegistry({ maxSessions: 1, now: () => now });
  activeOnly.begin(descriptor("first"), "first");
  expect(() => activeOnly.begin(descriptor("second"), "second")).toThrow("session registry is full");
});

test("session registry bounds retained text fields", () => {
  const registry = createLocalAgentSessionRegistry({ now: () => 1 });
  const record = registry.begin({
    ...descriptor(),
    command: ["codex", "exec", `token=sentinel-secret ${"x".repeat(10_000)}`],
    task: `schema ${"y".repeat(10_000)}`,
  }, "bounded-session");

  expect(record.command.length).toBeLessThanOrEqual(4096);
  expect(record.command).toEndWith("... [truncated]");
  expect(record.task?.length).toBeLessThanOrEqual(4096);
  expect(record.task).toEndWith("... [truncated]");
  expect(JSON.stringify(record)).not.toContain("sentinel-secret");
});

test("session registry storage helpers round-trip and reject corrupt JSON without mutation", async () => {
  let text: string | null = null;
  const store: LocalAgentSessionStore = {
    async read() {
      return text;
    },
    async write(value) {
      text = value;
    },
  };
  const source = createLocalAgentSessionRegistry({ now: () => 10 });
  source.begin(descriptor(), "session-1");
  source.finish("session-1", terminal("done"));
  await saveLocalAgentSessionRegistry(source, store);

  const restored = createLocalAgentSessionRegistry({ now: () => 20 });
  expect(await restoreLocalAgentSessionRegistry(restored, store)).toBe("restored");
  expect(restored.get("session-1")?.status).toBe("done");
  const before = restored.snapshot();
  text = "{not-json";
  expect(await restoreLocalAgentSessionRegistry(restored, store)).toBe("invalid");
  expect(restored.snapshot()).toEqual(before);
  text = null;
  expect(await restoreLocalAgentSessionRegistry(restored, store)).toBe("empty");
});

test("bun session store atomically persists a registry snapshot", async () => {
  const root = await mkdtemp(join(tmpdir(), "zigeffect-agent-sessions-"));
  try {
    const path = join(root, "nested", "sessions.json");
    const store = bunLocalAgentSessionStore(path);
    const source = createLocalAgentSessionRegistry({ now: () => 10 });
    source.begin(descriptor(), "session-1");
    source.finish("session-1", terminal("done"));
    await saveLocalAgentSessionRegistry(source, store);

    expect(await Bun.file(path).exists()).toBe(true);
    expect(await Bun.file(`${path}.tmp`).exists()).toBe(false);
    const restored = createLocalAgentSessionRegistry({ now: () => 20 });
    expect(await restoreLocalAgentSessionRegistry(restored, store)).toBe("restored");
    expect(restored.get("session-1")?.status).toBe("done");
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});

test("process supervisor records successful and spawn-failed sessions", async () => {
  const events: LocalDevSessionEvent[] = [];
  const registry = createLocalAgentSessionRegistry({ now: () => 10 });
  const persistedStatuses: string[] = [];
  const sessionStore: LocalAgentSessionStore = {
    async read() { return null; },
    async write(value) {
      const snapshot = JSON.parse(value) as { sessions: Array<{ status: string }> };
      persistedStatuses.push(snapshot.sessions.at(-1)?.status ?? "missing");
    },
  };
  const successRunner: LocalAgentProcessRunner = {
    async start() {
      return {
        stdout: streamFromText("assistant: done\n"),
        stderr: streamFromText(""),
        exited: Promise.resolve(0),
        kill() {},
      };
    },
  };

  const success = await runLocalAgentProcessSupervisor({
    id: "codex",
    kind: "codex",
    label: "Codex",
    command: ["codex", "exec"],
  }, {
    agentEventsUrl: "http://collector.test/agent-events",
    fetcher: eventCapture(events),
    registry,
    runner: successRunner,
    sessionId: "successful-session",
    sessionStore,
  });

  expect(success.sessionId).toBe("successful-session");
  expect(registry.get("successful-session")).toMatchObject({
    status: "done",
    exitCode: 0,
    turns: 1,
  });
  expect(persistedStatuses).toEqual(["starting", "running", "done"]);

  await runLocalAgentProcessSupervisor({
    id: "claude",
    kind: "claude-code",
    label: "Claude Code",
    command: ["missing-claude", "token=sentinel-secret"],
  }, {
    agentEventsUrl: "http://collector.test/agent-events",
    fetcher: eventCapture(events),
    registry,
    runner: { async start() { throw new Error("spawn secret=sentinel-secret"); } },
    sessionId: "failed-session",
  });

  expect(registry.get("failed-session")).toMatchObject({
    status: "failed",
    exitCode: null,
    detail: "spawn secret=<redacted>",
  });
  expect(JSON.stringify(registry.snapshot())).not.toContain("sentinel-secret");
});

test("process supervisor kills and interrupts the session when initial collector delivery fails", async () => {
  const registry = createLocalAgentSessionRegistry({ now: () => 10 });
  let kills = 0;
  let resolveExit: ((code: number) => void) | undefined;
  const exited = new Promise<number>((resolve) => {
    resolveExit = resolve;
  });
  const runner: LocalAgentProcessRunner = {
    async start() {
      return {
        stdout: streamFromText(""),
        stderr: streamFromText(""),
        exited,
        kill() {
          kills += 1;
          resolveExit?.(143);
        },
      };
    },
  };
  const rejectingFetcher = (async () => new Response("no", { status: 503 })) as unknown as typeof fetch;

  await expect(runLocalAgentProcessSupervisor({
    id: "codex",
    kind: "codex",
    label: "Codex",
    command: ["codex", "exec"],
  }, {
    agentEventsUrl: "http://collector.test/agent-events",
    fetcher: rejectingFetcher,
    registry,
    runner,
    sessionId: "collector-failed-session",
  })).rejects.toThrow("local agent event rejected: 503");

  expect(kills).toBe(1);
  expect(registry.get("collector-failed-session")).toMatchObject({
    status: "interrupted",
    interrupted: true,
    detail: "collector delivery failed: local agent event rejected: 503",
  });
});

test("process supervisor records abort and transcript stream failures as interrupted", async () => {
  const events: LocalDevSessionEvent[] = [];
  const registry = createLocalAgentSessionRegistry({ now: () => 10 });
  const abortController = new AbortController();
  let abortStream: ReadableStreamDefaultController<Uint8Array> | undefined;
  let resolveAbortExit: ((code: number) => void) | undefined;
  const abortExited = new Promise<number>((resolve) => {
    resolveAbortExit = resolve;
  });
  const abortRun = runLocalAgentProcessSupervisor({
    id: "codex",
    kind: "codex",
    label: "Codex",
    command: ["codex", "exec"],
  }, {
    agentEventsUrl: "http://collector.test/agent-events",
    fetcher: eventCapture(events),
    registry,
    runner: {
      async start() {
        return {
          stdout: new ReadableStream<Uint8Array>({ start(controller) { abortStream = controller; } }),
          stderr: streamFromText(""),
          exited: abortExited,
          kill() {
            abortStream?.close();
            resolveAbortExit?.(143);
          },
        };
      },
    },
    sessionId: "aborted-session",
    signal: abortController.signal,
  });
  await Bun.sleep(0);
  abortController.abort();
  await abortRun;
  expect(registry.get("aborted-session")).toMatchObject({
    status: "interrupted",
    interrupted: true,
    exitCode: 143,
  });

  let streamKills = 0;
  let resolveStreamExit: ((code: number) => void) | undefined;
  const streamExited = new Promise<number>((resolve) => {
    resolveStreamExit = resolve;
  });
  await expect(runLocalAgentProcessSupervisor({
    id: "claude",
    kind: "claude-code",
    label: "Claude Code",
    command: ["claude", "-p"],
  }, {
    agentEventsUrl: "http://collector.test/agent-events",
    fetcher: eventCapture(events),
    registry,
    runner: {
      async start() {
        return {
          stdout: new ReadableStream<Uint8Array>({
            start(controller) {
              controller.error(new Error("stream failed secret=sentinel-secret"));
            },
          }),
          stderr: streamFromText(""),
          exited: streamExited,
          kill() {
            streamKills += 1;
            resolveStreamExit?.(1);
          },
        };
      },
    },
    sessionId: "stream-failed-session",
  })).rejects.toThrow("stream failed secret=sentinel-secret");
  expect(streamKills).toBe(1);
  expect(registry.get("stream-failed-session")).toMatchObject({
    status: "interrupted",
    interrupted: true,
    detail: "process supervision failed: stream failed secret=<redacted>",
  });
});
