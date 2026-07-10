import { expect, test } from "bun:test";
import { createRoot } from "solid-js";
import {
  LocalAgentControlClientError,
  type LocalAgentControlClient,
  type LocalAgentTerminalRead,
} from "../localAgentControlClient";
import { createLocalAgentTerminal } from "./localAgentTerminal";

function deferred<T>() {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>((accept) => { resolve = accept; });
  return { promise, resolve };
}

function read(overrides: Partial<LocalAgentTerminalRead> = {}): LocalAgentTerminalRead {
  return {
    frames: [],
    nextAfter: 0,
    gap: false,
    droppedFrames: 0,
    droppedBytes: 0,
    status: "running",
    cols: 100,
    rows: 30,
    totalBytes: 0,
    ...overrides,
  };
}

function terminalClient(overrides: Partial<LocalAgentControlClient> = {}): LocalAgentControlClient {
  const unsupported = async () => { throw new Error("unsupported test route"); };
  return {
    baseUrl: "http://127.0.0.1:4500",
    health: unsupported,
    tools: unsupported,
    sessions: unsupported,
    session: unsupported,
    receipts: unsupported,
    start: unsupported,
    stop: unsupported,
    async terminal() { return read(); },
    async writeTerminal(sessionId) { return { accepted: true, sessionId }; },
    async resizeTerminal(sessionId, cols, rows) { return { accepted: true, sessionId, cols, rows }; },
    ...overrides,
  } as LocalAgentControlClient;
}

test("terminal applies ordered frames, advances its cursor, and reports retention gaps", async () => {
  const output: string[] = [];
  const timers: Array<{ delay: number; run: () => void | Promise<void>; cancelled: boolean }> = [];
  let calls = 0;
  await createRoot(async (dispose) => {
    const terminal = createLocalAgentTerminal(terminalClient({
      async terminal(_sessionId, after) {
        calls += 1;
        expect(after).toBe(0);
        return read({
          frames: [
            { sequence: 1, timestamp: 10, data: "hello " },
            { sequence: 2, timestamp: 11, data: "world" },
          ],
          nextAfter: 2,
          gap: true,
          droppedFrames: 3,
          droppedBytes: 21,
          totalBytes: 32,
        });
      },
    }), "pty-session", {
      onData(data) { output.push(data); },
      pollMs: 25,
      schedule(run, delay) {
        const timer = { delay, run, cancelled: false };
        timers.push(timer);
        return () => { timer.cancelled = true; };
      },
    });

    await terminal.start();
    expect(calls).toBe(1);
    expect(output).toEqual(["hello ", "world"]);
    expect(terminal.cursor()).toBe(2);
    expect(terminal.gap()).toBe(true);
    expect(terminal.droppedFrames()).toBe(3);
    expect(terminal.totalBytes()).toBe(32);
    expect(timers.at(-1)?.delay).toBe(25);
    terminal.dispose();
    expect(timers.at(-1)?.cancelled).toBe(true);
    dispose();
  });
});

test("terminal polling is single-flight and stops after a terminal state", async () => {
  const pending = deferred<LocalAgentTerminalRead>();
  const timers: Array<{ run: () => void | Promise<void> }> = [];
  let calls = 0;
  await createRoot(async (dispose) => {
    const terminal = createLocalAgentTerminal(terminalClient({
      async terminal() {
        calls += 1;
        if (calls === 1) return read();
        return pending.promise;
      },
    }), "pty-session", {
      onData() {},
      schedule(run) { timers.push({ run }); return () => {}; },
    });
    await terminal.start();
    const scheduled = timers.at(-1)!.run();
    const duplicate = terminal.refresh();
    expect(calls).toBe(2);
    pending.resolve(read({ status: "done" }));
    await Promise.all([scheduled, duplicate]);
    expect(terminal.status()).toBe("done");
    expect(await terminal.write("ignored-after-exit")).toBe(false);
    expect(terminal.resize(120, 40)).toBe(false);
    expect(timers).toHaveLength(1);
    dispose();
  });
});

test("terminal serializes private input, coalesces resize, and cancels on dispose", async () => {
  const firstWrite = deferred<{ accepted: true; sessionId: string }>();
  const writes: string[] = [];
  const resizes: Array<[number, number]> = [];
  const timers: Array<{ delay: number; run: () => void | Promise<void>; cancelled: boolean }> = [];
  let aborted = false;
  await createRoot(async (dispose) => {
    const terminal = createLocalAgentTerminal(terminalClient({
      async terminal(_sessionId, _after, signal) {
        return new Promise<LocalAgentTerminalRead>((_resolve, reject) => {
          signal?.addEventListener("abort", () => {
            aborted = true;
            reject(new LocalAgentControlClientError("cancelled", "cancelled"));
          });
        });
      },
      async writeTerminal(sessionId, data) {
        writes.push(data);
        if (writes.length === 1) return firstWrite.promise;
        return { accepted: true, sessionId };
      },
      async resizeTerminal(sessionId, cols, rows) {
        resizes.push([cols, rows]);
        return { accepted: true, sessionId, cols, rows };
      },
    }), "pty-session", {
      onData() {},
      resizeDebounceMs: 15,
      schedule(run, delay) {
        const timer = { delay, run, cancelled: false };
        timers.push(timer);
        return () => { timer.cancelled = true; };
      },
    });

    const one = terminal.write("private-one");
    const two = terminal.write("private-two");
    await Promise.resolve();
    expect(writes).toEqual(["private-one"]);
    firstWrite.resolve({ accepted: true, sessionId: "pty-session" });
    expect(await one).toBe(true);
    expect(await two).toBe(true);
    expect(writes).toEqual(["private-one", "private-two"]);

    terminal.resize(80, 24);
    terminal.resize(132, 44);
    const resizeTimer = timers.findLast((item) => item.delay === 15)!;
    await resizeTimer.run();
    expect(resizes).toEqual([[132, 44]]);

    const polling = terminal.start();
    await Promise.resolve();
    terminal.dispose();
    await polling;
    expect(aborted).toBe(true);
    expect(terminal.connection()).toBe("closed");
    dispose();
  });
});
