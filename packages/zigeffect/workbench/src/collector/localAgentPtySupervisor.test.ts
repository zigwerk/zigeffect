import { expect, test } from "bun:test";
import type { LocalDevSessionEvent } from "../localDevSessionFeed";
import type { LocalAgentProcessTool } from "./localAgentProcessSupervisor";
import {
  bunLocalAgentPtyRunner,
  startLocalAgentPtySupervisor,
  type LocalAgentPtyHandle,
  type LocalAgentPtyRunner,
  type LocalAgentPtyRunnerOptions,
} from "./localAgentPtySupervisor";
import { createLocalAgentSessionRegistry } from "./localAgentSessionRegistry";

function tool(overrides: Partial<LocalAgentProcessTool> = {}): LocalAgentProcessTool {
  return {
    id: "interactive",
    kind: "zigeffect",
    label: "Interactive tool",
    command: ["/bin/sh"],
    cwd: "/workspace",
    task: "Inspect locally",
    checkLabel: "Interactive check",
    ...overrides,
  };
}

function deferred<T>() {
  let resolve!: (value: T) => void;
  let reject!: (error: unknown) => void;
  const promise = new Promise<T>((accept, decline) => {
    resolve = accept;
    reject = decline;
  });
  return { promise, resolve, reject };
}

function fakePty() {
  const exit = deferred<number>();
  let runnerOptions: LocalAgentPtyRunnerOptions | null = null;
  const writes: string[] = [];
  const resizes: Array<[number, number]> = [];
  let kills = 0;
  let closes = 0;
  const handle: LocalAgentPtyHandle = {
    exited: exit.promise,
    write(data) { writes.push(data); return new TextEncoder().encode(data).byteLength; },
    resize(cols, rows) { resizes.push([cols, rows]); },
    kill() { kills += 1; },
    close() { closes += 1; },
  };
  const runner: LocalAgentPtyRunner = {
    async start(_tool, options) {
      runnerOptions = options;
      return handle;
    },
  };
  return {
    runner,
    exit,
    writes,
    resizes,
    options: () => runnerOptions!,
    kills: () => kills,
    closes: () => closes,
  };
}

function eventSink(events: LocalDevSessionEvent[]): typeof fetch {
  return (async (_input: RequestInfo | URL, init?: RequestInit) => {
    events.push(JSON.parse(String(init?.body)) as LocalDevSessionEvent);
    return Response.json({ ingested: 1 });
  }) as unknown as typeof fetch;
}

test("PTY supervisor persists lifecycle, redacts split output, writes input, and resizes", async () => {
  const pty = fakePty();
  const events: LocalDevSessionEvent[] = [];
  const registry = createLocalAgentSessionRegistry({ now: () => 10 });
  const supervisor = await startLocalAgentPtySupervisor(tool(), {
    sessionId: "pty-session",
    registry,
    runner: pty.runner,
    agentEventsUrl: "http://collector.test/agent-events",
    fetcher: eventSink(events),
    now: () => 10,
    secretLiterals: ["literal-secret"],
  });

  expect(registry.get("pty-session")).toMatchObject({ status: "running" });
  pty.options().onData(new TextEncoder().encode("token=sentinel-"));
  await Promise.resolve();
  pty.options().onData(new TextEncoder().encode("secret literal-"));
  await Promise.resolve();
  pty.options().onData(new TextEncoder().encode("secret\r\nready$ "));
  await Promise.resolve();

  expect(supervisor.write("echo private-input\r")).toBe(true);
  expect(supervisor.resize(120, 40)).toBe(true);
  expect(pty.writes).toEqual(["echo private-input\r"]);
  expect(pty.resizes).toEqual([[120, 40]]);
  const output = supervisor.read(0);
  expect(output.frames.length).toBeGreaterThan(0);
  const joinedOutput = output.frames.map((frame) => frame.data).join("");
  expect(joinedOutput).toContain("ready$ ");
  expect(joinedOutput).not.toContain("literal-secret");
  expect(JSON.stringify(output)).not.toContain("sentinel-secret");
  expect(JSON.stringify(output)).not.toContain("literal-secret");

  pty.exit.resolve(0);
  const summary = await supervisor.completion;
  expect(summary).toMatchObject({ status: "done", exitCode: 0, interrupted: false, cols: 120, rows: 40 });
  expect(registry.get("pty-session")).toMatchObject({ status: "done", exitCode: 0, interrupted: false });
  expect(pty.kills()).toBe(0);
  expect(pty.closes()).toBe(1);
  expect(events.map((event) => `${event.kind}:${event.status ?? ""}`)).toEqual([
    "agent_status:running",
    "check_result:pass",
    "agent_status:done",
  ]);
  expect(JSON.stringify(events)).not.toContain("private-input");
});

test("PTY output ring reports honest cursor gaps and retained byte drops", async () => {
  const pty = fakePty();
  const supervisor = await startLocalAgentPtySupervisor(tool(), {
    sessionId: "ring-session",
    registry: createLocalAgentSessionRegistry(),
    runner: pty.runner,
    agentEventsUrl: "http://collector.test/agent-events",
    fetcher: eventSink([]),
    maxFrames: 2,
    maxRetainedBytes: 20,
  });
  for (const value of ["first\n", "second\n", "third\n"]) {
    pty.options().onData(new TextEncoder().encode(value));
    await Promise.resolve();
  }

  expect(supervisor.read(0)).toMatchObject({
    gap: true,
    droppedFrames: 1,
    frames: [{ sequence: 2 }, { sequence: 3 }],
    nextAfter: 3,
  });
  expect(supervisor.read(2)).toMatchObject({ gap: false, frames: [{ sequence: 3 }], nextAfter: 3 });
  pty.exit.resolve(0);
  await supervisor.completion;
});

test("PTY output reports a gap when one coalesced frame exceeds byte retention", async () => {
  const pty = fakePty();
  const supervisor = await startLocalAgentPtySupervisor(tool(), {
    sessionId: "oversized-frame-session",
    registry: createLocalAgentSessionRegistry(),
    runner: pty.runner,
    agentEventsUrl: "http://collector.test/agent-events",
    fetcher: eventSink([]),
    maxFrames: 2,
    maxRetainedBytes: 5,
  });

  pty.options().onData(new TextEncoder().encode("abcdefgh"));
  await Promise.resolve();
  expect(supervisor.read(0)).toMatchObject({
    gap: true,
    droppedFrames: 0,
    droppedBytes: 3,
    frames: [{ sequence: 1, data: "defgh" }],
  });
  expect(supervisor.read(1)).toMatchObject({ gap: false, frames: [] });
  pty.exit.resolve(0);
  await supervisor.completion;
});

test("PTY abort and terminal stream errors kill and close exactly once", async () => {
  const pty = fakePty();
  const abort = new AbortController();
  const supervisor = await startLocalAgentPtySupervisor(tool(), {
    sessionId: "abort-session",
    registry: createLocalAgentSessionRegistry(),
    runner: pty.runner,
    agentEventsUrl: "http://collector.test/agent-events",
    fetcher: eventSink([]),
    signal: abort.signal,
  });

  abort.abort();
  abort.abort();
  pty.options().onTerminalExit(1, "EIO");
  expect(pty.kills()).toBe(1);
  pty.exit.resolve(143);
  expect(await supervisor.completion).toMatchObject({
    status: "interrupted",
    exitCode: 143,
    interrupted: true,
    reason: "abort",
  });
  expect(pty.kills()).toBe(1);
  expect(pty.closes()).toBe(1);
});

test("PTY supervisor enforces output, idle, and runtime limits", async () => {
  for (const limit of ["output", "idle", "runtime"] as const) {
    const pty = fakePty();
    const timers: Array<{ delay: number; run: () => void; cancelled: boolean }> = [];
    const supervisor = await startLocalAgentPtySupervisor(tool(), {
      sessionId: `${limit}-session`,
      registry: createLocalAgentSessionRegistry(),
      runner: pty.runner,
      agentEventsUrl: "http://collector.test/agent-events",
      fetcher: eventSink([]),
      maxTotalOutputBytes: limit === "output" ? 4 : 1024,
      idleTimeoutMs: 20,
      maxRuntimeMs: 50,
      schedule(run, delay) {
        const timer = { delay, run, cancelled: false };
        timers.push(timer);
        return () => { timer.cancelled = true; };
      },
    });

    if (limit === "output") {
      pty.options().onData(new TextEncoder().encode("12345"));
    } else {
      const expectedDelay = limit === "idle" ? 20 : 50;
      const timer = timers.find((item) => item.delay === expectedDelay && !item.cancelled);
      expect(timer).toBeDefined();
      timer?.run();
    }
    expect(pty.kills()).toBe(1);
    pty.exit.resolve(143);
    expect(await supervisor.completion).toMatchObject({
      status: "interrupted",
      reason: limit === "output" ? "output_limit" : `${limit}_timeout`,
    });
    expect(pty.closes()).toBe(1);
  }
});

test("PTY spawn and initial collector failures persist honest terminal state", async () => {
  const spawnRegistry = createLocalAgentSessionRegistry();
  await expect(startLocalAgentPtySupervisor(tool(), {
    sessionId: "spawn-failure",
    registry: spawnRegistry,
    runner: { async start() { throw new Error("spawn token=sentinel-secret"); } },
    agentEventsUrl: "http://collector.test/agent-events",
    fetcher: eventSink([]),
  })).rejects.toThrow("spawn token=<redacted>");
  expect(spawnRegistry.get("spawn-failure")).toMatchObject({ status: "failed" });
  expect(JSON.stringify(spawnRegistry.snapshot())).not.toContain("sentinel-secret");

  const pty = fakePty();
  const collectorRegistry = createLocalAgentSessionRegistry();
  const starting = startLocalAgentPtySupervisor(tool(), {
    sessionId: "collector-failure",
    registry: collectorRegistry,
    runner: pty.runner,
    agentEventsUrl: "http://collector.test/agent-events",
    fetcher: (async () => new Response("rejected", { status: 500 })) as unknown as typeof fetch,
  });
  await Promise.resolve();
  pty.exit.resolve(143);
  await expect(starting).rejects.toThrow("collector delivery failed");
  expect(pty.kills()).toBe(1);
  expect(pty.closes()).toBe(1);
  expect(collectorRegistry.get("collector-failure")).toMatchObject({ status: "interrupted" });
});

test("PTY exit-promise failures persist an interrupted terminal state", async () => {
  const pty = fakePty();
  const registry = createLocalAgentSessionRegistry();
  const supervisor = await startLocalAgentPtySupervisor(tool(), {
    sessionId: "exit-rejection",
    registry,
    runner: pty.runner,
    agentEventsUrl: "http://collector.test/agent-events",
    fetcher: eventSink([]),
    secretLiterals: ["literal-secret"],
  });

  pty.exit.reject(new Error("wait failed literal-secret"));
  await expect(supervisor.completion).rejects.toThrow("wait failed <redacted>");
  expect(registry.get("exit-rejection")).toMatchObject({
    status: "interrupted",
    interrupted: true,
    detail: "PTY wait failed: wait failed <redacted>",
  });
  expect(pty.closes()).toBe(1);
});

test("real Bun PTY reports TTY, accepts input, resizes, and exits", async () => {
  let output = "";
  const handle = await bunLocalAgentPtyRunner.start(tool({ command: ["/bin/sh"], cwd: process.cwd() }), {
    cols: 80,
    rows: 24,
    onData(data) { output += new TextDecoder().decode(data); },
    onTerminalExit() {},
  });
  handle.resize(100, 30);
  handle.write("test -t 0 && printf pty-real-ok; exit\r");
  expect(await handle.exited).toBe(0);
  handle.close();
  expect(output).toContain("pty-real-ok");
});
