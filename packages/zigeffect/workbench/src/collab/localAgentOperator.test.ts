import { expect, test } from "bun:test";
import { createRoot } from "solid-js";
import {
  LocalAgentControlClientError,
  type LocalAgentControlClient,
  type LocalAgentControlHealth,
  type LocalAgentControlReceipt,
  type LocalAgentControlSession,
  type LocalAgentControlToolSummary,
} from "../localAgentControlClient";
import { createLocalAgentOperator } from "./localAgentOperator";

const tool: LocalAgentControlToolSummary = {
  id: "codex-review",
  label: "Codex review",
  description: "Review locally",
  kind: "codex",
  input: { kind: "prompt", label: "Task", placeholder: "Review schema", required: true, maxLength: 200 },
};

function session(overrides: Partial<LocalAgentControlSession> = {}): LocalAgentControlSession {
  return {
    id: "session-1",
    agentId: "codex",
    agentKind: "codex",
    agentLabel: "Codex",
    command: "codex exec --json <redacted>",
    cwd: "/workspace",
    task: "Review schema",
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
    ...overrides,
  };
}

function fakeClient(overrides: Partial<LocalAgentControlClient> = {}): LocalAgentControlClient {
  return {
    baseUrl: "http://127.0.0.1:4500",
    async health() { return { ok: true, activeSessions: 1, persistence: "durable" }; },
    async tools() { return [tool]; },
    async sessions() { return [session()]; },
    async session(id) { return session({ id }); },
    async receipts() { return []; },
    async start() { return { accepted: true, sessionId: "session-1" }; },
    async stop(id) { return { accepted: true, sessionId: id }; },
    ...overrides,
  };
}

test("operator connects through a complete snapshot and reads selected detail", async () => {
  const detailIds: string[] = [];
  await createRoot(async (dispose) => {
    const operator = createLocalAgentOperator();
    await operator.connect(fakeClient({
      async session(id) {
        detailIds.push(id);
        return session({ id, detail: "detail route" });
      },
    }));

    expect(operator.connection()).toBe("connected");
    expect(operator.health()).toEqual({ ok: true, activeSessions: 1, persistence: "durable" });
    expect(operator.tools()).toEqual([tool]);
    expect(operator.sessions()).toHaveLength(1);
    expect(operator.selectedSession()).toMatchObject({ id: "session-1", detail: "detail route" });
    expect(detailIds).toEqual(["session-1"]);
    expect(operator.error()).toBeNull();
    operator.dispose();
    dispose();
  });
});

test("operator polling is single-flight and switches to the idle interval", async () => {
  const scheduled: Array<{ delay: number; run: () => void | Promise<void>; cancelled: boolean }> = [];
  let healthCalls = 0;
  let resolveHealth: ((health: LocalAgentControlHealth) => void) | null = null;
  let currentSession = session();
  const client = fakeClient({
    async health() {
      healthCalls += 1;
      if (healthCalls === 1) return { ok: true, activeSessions: 1, persistence: "durable" };
      return new Promise<LocalAgentControlHealth>((resolve) => { resolveHealth = resolve; });
    },
    async sessions() { return [currentSession]; },
    async session() { return currentSession; },
  });

  await createRoot(async (dispose) => {
    const operator = createLocalAgentOperator({
      activePollMs: 100,
      idlePollMs: 500,
      schedule(run, delay) {
        const item = { delay, run, cancelled: false };
        scheduled.push(item);
        return () => { item.cancelled = true; };
      },
    });
    await operator.connect(client);
    operator.startPolling();
    expect(scheduled.at(-1)?.delay).toBe(100);

    currentSession = session({ status: "done", finishedAt: 30, updatedAt: 30 });
    const poll = scheduled.at(-1)!.run();
    const concurrent = operator.refresh();
    expect(healthCalls).toBe(2);
    resolveHealth?.({ ok: true, activeSessions: 0, persistence: "durable" });
    await Promise.all([poll, concurrent]);

    expect(operator.sessions()[0]?.status).toBe("done");
    expect(scheduled.at(-1)?.delay).toBe(500);
    operator.dispose();
    expect(scheduled.at(-1)?.cancelled).toBe(true);
    dispose();
  });
});

test("operator ignores stale reconnect work and serializes start and stop decisions", async () => {
  let resolveOldSessions: ((sessions: LocalAgentControlSession[]) => void) | null = null;
  const oldClient = fakeClient({
    baseUrl: "http://localhost:4501",
    async sessions() {
      return new Promise<LocalAgentControlSession[]>((resolve) => { resolveOldSessions = resolve; });
    },
  });
  let records: LocalAgentControlSession[] = [];
  const receipts: LocalAgentControlReceipt[] = [];
  let starts = 0;
  let stops = 0;
  const currentClient = fakeClient({
    baseUrl: "http://localhost:4502",
    async health() {
      return { ok: true, activeSessions: records.filter((item) => item.status === "running").length, persistence: "memory" };
    },
    async sessions() { return records; },
    async session(id) { return records.find((item) => item.id === id)!; },
    async receipts() { return receipts; },
    async start(start) {
      starts += 1;
      expect(start).toEqual({ toolId: "codex-review", input: { prompt: "Review schema" } });
      records = [session({ id: "new-session" })];
      receipts.push({ sequence: 1, timestamp: 21, action: "start", outcome: "accepted", sessionId: "new-session", toolId: "codex-review", detail: "accepted" });
      return { accepted: true, sessionId: "new-session" };
    },
    async stop(id) {
      stops += 1;
      records = [session({ id, status: "interrupted", interrupted: true, finishedAt: 30, updatedAt: 30, detail: "abort requested" })];
      receipts.push({ sequence: 2, timestamp: 30, action: "stop", outcome: "accepted", sessionId: id, toolId: "codex-review", detail: "abort requested" });
      return { accepted: true, sessionId: id };
    },
  });

  await createRoot(async (dispose) => {
    const operator = createLocalAgentOperator();
    const stale = operator.connect(oldClient);
    await Promise.resolve();
    await operator.connect(currentClient);
    resolveOldSessions?.([session({ id: "stale-session" })]);
    await stale;
    expect(operator.baseUrl()).toBe("http://localhost:4502");
    expect(operator.sessions()).toEqual([]);

    const firstStart = operator.start("codex-review", "Review schema");
    const duplicateStart = operator.start("codex-review", "Review twice");
    expect(await duplicateStart).toBeNull();
    expect(await firstStart).toEqual({ accepted: true, sessionId: "new-session" });
    expect(starts).toBe(1);
    expect(operator.selectedSession()?.id).toBe("new-session");
    expect(operator.latestReceipt()?.action).toBe("start");

    expect(await operator.stop("new-session")).toEqual({ accepted: true, sessionId: "new-session" });
    expect(stops).toBe(1);
    expect(operator.selectedSession()).toMatchObject({ status: "interrupted", interrupted: true });
    expect(operator.latestReceipt()?.action).toBe("stop");
    operator.dispose();
    dispose();
  });
});

test("accepted mutations abort an older poll and publish a fresh snapshot", async () => {
  let records: LocalAgentControlSession[] = [];
  let sessionCalls = 0;
  let staleAborted = false;
  let releaseStale: (() => void) | null = null;
  const client = fakeClient({
    async health() {
      return { ok: true, activeSessions: records.length, persistence: "durable" };
    },
    async sessions(signal) {
      sessionCalls += 1;
      if (sessionCalls === 2) {
        return new Promise<LocalAgentControlSession[]>((resolve, reject) => {
          releaseStale = () => resolve([]);
          signal?.addEventListener("abort", () => {
            staleAborted = true;
            reject(new LocalAgentControlClientError("cancelled", "local control request cancelled"));
          });
        });
      }
      return records;
    },
    async session(id) { return records.find((item) => item.id === id)!; },
    async start() {
      records = [session({ id: "fresh-session" })];
      return { accepted: true, sessionId: "fresh-session" };
    },
  });

  await createRoot(async (dispose) => {
    const operator = createLocalAgentOperator();
    await operator.connect(client);
    const stale = operator.refresh();
    await Promise.resolve();
    const mutation = operator.start("codex-review", "Review schema");
    await Promise.resolve();
    const observedAbort = staleAborted;
    if (!observedAbort) releaseStale?.();
    await Promise.all([stale, mutation]);

    expect(observedAbort).toBe(true);
    expect(sessionCalls).toBe(3);
    expect(operator.selectedSession()).toMatchObject({ id: "fresh-session", status: "running" });
    operator.dispose();
    dispose();
  });
});

test("operator exposes authorization failure and aborts in-flight work on dispose", async () => {
  await createRoot(async (dispose) => {
    const unauthorized = createLocalAgentOperator();
    await unauthorized.connect(fakeClient({
      async tools() {
        throw new LocalAgentControlClientError("unauthorized", "local control authorization required", 401);
      },
    }));
    expect(unauthorized.connection()).toBe("unauthorized");
    expect(unauthorized.error()).toMatchObject({ code: "unauthorized" });

    let aborted = false;
    const pending = createLocalAgentOperator();
    const connecting = pending.connect(fakeClient({
      async health(signal) {
        return new Promise<LocalAgentControlHealth>((_resolve, reject) => {
          signal?.addEventListener("abort", () => {
            aborted = true;
            reject(new LocalAgentControlClientError("cancelled", "local control request cancelled"));
          });
        });
      },
    }));
    await Promise.resolve();
    pending.dispose();
    await connecting;
    expect(aborted).toBe(true);
    expect(pending.connection()).toBe("disconnected");
    dispose();
  });
});
