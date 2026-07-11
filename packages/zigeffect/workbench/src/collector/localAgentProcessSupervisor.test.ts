import { expect, test } from "bun:test";
import type { LocalDevSessionEvent } from "../localDevSessionFeed";
import {
  bunLocalAgentProcessRunner,
  runLocalAgentProcessSupervisor,
  type LocalAgentProcessHandle,
  type LocalAgentProcessRunner,
} from "./localAgentProcessSupervisor";

function eventCapture(events: LocalDevSessionEvent[]): typeof fetch {
  return (async (_input: RequestInfo | URL, init?: RequestInit) => {
    expect(init?.method).toBe("POST");
    events.push(JSON.parse(String(init?.body)) as LocalDevSessionEvent);
    return new Response(JSON.stringify({ ingested: 1 }), {
      headers: { "content-type": "application/json" },
    });
  }) as typeof fetch;
}

function streamFromChunks(chunks: readonly string[]): ReadableStream<Uint8Array> {
  const encoder = new TextEncoder();
  return new ReadableStream<Uint8Array>({
    start(controller) {
      for (const chunk of chunks) {
        controller.enqueue(encoder.encode(chunk));
      }
      controller.close();
    },
  });
}

function handle(options: {
  stdout?: readonly string[];
  stderr?: readonly string[];
  exitCode?: number;
  kill?: () => void;
} = {}): LocalAgentProcessHandle {
  return {
    stdout: streamFromChunks(options.stdout ?? []),
    stderr: streamFromChunks(options.stderr ?? []),
    exited: Promise.resolve(options.exitCode ?? 0),
    kill: options.kill ?? (() => {}),
  };
}

test("runLocalAgentProcessSupervisor streams turns between running and terminal receipts", async () => {
  const events: LocalDevSessionEvent[] = [];
  const runner: LocalAgentProcessRunner = {
    async start(tool) {
      expect(tool.command).toEqual(["codex", "exec", "build the schema"]);
      return handle({
        stdout: [
          "assistant: implementing token=sentinel-secret\nignored provider noise\n",
          '{"type":"turn","id":"turn-2","role":"tool","output":"tests pass password=sentinel-secret"}\n',
        ],
      });
    },
  };

  const summary = await runLocalAgentProcessSupervisor(
    {
      id: "codex",
      kind: "codex",
      label: "Codex",
      command: ["codex", "exec", "build the schema"],
      task: "schema milestone secret=sentinel-secret",
      checkLabel: "Codex session",
    },
    {
      agentEventsUrl: "http://collector.test/agent-events",
      fetcher: eventCapture(events),
      runner,
      sequenceStart: 10,
    },
  );

  expect(summary).toEqual({
    sessionId: null,
    status: "done",
    exitCode: 0,
    interrupted: false,
    lines: 3,
    turns: 2,
    ignored: 1,
    postedEvents: 5,
    lastSequence: 16,
  });
  expect(events.map((event) => event.sequence)).toEqual([11, 12, 14, 15, 16]);
  expect(events.map((event) => event.kind)).toEqual([
    "agent_status",
    "agent_turn",
    "agent_turn",
    "check_result",
    "agent_status",
  ]);
  expect(events[0]).toMatchObject({
    agent_id: "codex",
    status: "running",
    task: "schema milestone secret=<redacted>",
  });
  expect(events[3]).toMatchObject({
    label: "Codex session",
    status: "pass",
    detail: "2 transcript turns from 3 lines",
  });
  expect(events[4]).toMatchObject({ agent_id: "codex", status: "done" });
  expect(JSON.stringify(events)).not.toContain("sentinel-secret");
});

test("runLocalAgentProcessSupervisor reports non-zero exits with bounded redacted stderr", async () => {
  const events: LocalDevSessionEvent[] = [];
  const runner: LocalAgentProcessRunner = {
    async start() {
      return handle({
        stderr: ["discard-this-prefix-", "failure password=sentinel-secret"],
        exitCode: 7,
      });
    },
  };

  const summary = await runLocalAgentProcessSupervisor(
    {
      id: "claude",
      kind: "claude-code",
      label: "Claude Code",
      command: ["claude", "-p", "review"],
    },
    {
      agentEventsUrl: "http://collector.test/agent-events",
      fetcher: eventCapture(events),
      runner,
      stderrLimitBytes: 32,
    },
  );

  expect(summary).toMatchObject({
    status: "failed",
    exitCode: 7,
    interrupted: false,
    postedEvents: 3,
  });
  expect(events.map((event) => event.kind)).toEqual(["agent_status", "check_result", "agent_status"]);
  expect(events[1]).toMatchObject({
    status: "fail",
    detail: "exit 7: failure password=<redacted>",
  });
  expect(events[2]).toMatchObject({ status: "failed" });
  expect(JSON.stringify(events)).not.toContain("sentinel-secret");
  expect(JSON.stringify(events)).not.toContain("discard-this-prefix");
});

test("runLocalAgentProcessSupervisor records spawn exceptions without claiming the agent ran", async () => {
  const events: LocalDevSessionEvent[] = [];
  const runner: LocalAgentProcessRunner = {
    async start() {
      throw new Error("spawn denied token=sentinel-secret");
    },
  };

  const summary = await runLocalAgentProcessSupervisor(
    {
      id: "codex",
      kind: "codex",
      label: "Codex",
      command: ["missing-codex"],
    },
    {
      agentEventsUrl: "http://collector.test/agent-events",
      fetcher: eventCapture(events),
      runner,
    },
  );

  expect(summary).toEqual({
    sessionId: null,
    status: "failed",
    exitCode: null,
    interrupted: false,
    lines: 0,
    turns: 0,
    ignored: 0,
    postedEvents: 3,
    lastSequence: 3,
  });
  expect(events.map((event) => event.kind)).toEqual(["warning", "check_result", "agent_status"]);
  expect(events[0]).toMatchObject({
    value: "Codex failed to start: spawn denied token=<redacted>",
  });
  expect(events[1]).toMatchObject({ status: "fail" });
  expect(events[2]).toMatchObject({ status: "failed" });
  expect(JSON.stringify(events)).not.toContain("sentinel-secret");
});

test("runLocalAgentProcessSupervisor kills and reports an aborted child", async () => {
  const events: LocalDevSessionEvent[] = [];
  const abortController = new AbortController();
  const encoder = new TextEncoder();
  let stdoutController: ReadableStreamDefaultController<Uint8Array> | undefined;
  let resolveExit: ((code: number) => void) | undefined;
  let kills = 0;
  const exited = new Promise<number>((resolve) => {
    resolveExit = resolve;
  });
  const runner: LocalAgentProcessRunner = {
    async start() {
      return {
        stdout: new ReadableStream<Uint8Array>({
          start(controller) {
            stdoutController = controller;
            controller.enqueue(encoder.encode("assistant: waiting\n"));
          },
        }),
        stderr: streamFromChunks([]),
        exited,
        kill() {
          kills += 1;
          stdoutController?.close();
          resolveExit?.(143);
        },
      };
    },
  };

  const running = runLocalAgentProcessSupervisor(
    {
      id: "codex",
      kind: "codex",
      label: "Codex",
      command: ["codex", "exec"],
    },
    {
      agentEventsUrl: "http://collector.test/agent-events",
      fetcher: eventCapture(events),
      runner,
      signal: abortController.signal,
    },
  );
  await Bun.sleep(0);
  abortController.abort();
  const summary = await running;

  expect(kills).toBe(1);
  expect(summary).toMatchObject({
    status: "failed",
    exitCode: 143,
    interrupted: true,
    turns: 1,
  });
  expect(events.map((event) => event.kind)).toEqual([
    "agent_status",
    "agent_turn",
    "check_result",
    "agent_status",
  ]);
  expect(events[2]).toMatchObject({ status: "fail", detail: "interrupted by abort signal" });
  expect(events[3]).toMatchObject({ status: "failed" });
});

test("bunLocalAgentProcessRunner rejects commands without an executable", async () => {
  await expect(
    bunLocalAgentProcessRunner.start({
      id: "empty",
      kind: "other",
      label: "empty",
      command: [],
    }),
  ).rejects.toThrow("process empty has no command");
});

test("bunLocalAgentProcessRunner streams a real tagged turn through the supervisor", async () => {
  const events: LocalDevSessionEvent[] = [];
  const summary = await runLocalAgentProcessSupervisor(
    {
      id: "shell",
      kind: "other",
      label: "shell",
      command: ["sh", "-c", 'printf "assistant: streamed token=sentinel-secret\\n"'],
    },
    {
      agentEventsUrl: "http://collector.test/agent-events",
      fetcher: eventCapture(events),
    },
  );

  expect(summary).toMatchObject({ status: "done", exitCode: 0, turns: 1 });
  expect(events.map((event) => event.kind)).toEqual([
    "agent_status",
    "agent_turn",
    "check_result",
    "agent_status",
  ]);
  expect(events[1]).toMatchObject({
    role: "assistant",
    output: "streamed token=<redacted>",
  });
  expect(JSON.stringify(events)).not.toContain("sentinel-secret");
});
