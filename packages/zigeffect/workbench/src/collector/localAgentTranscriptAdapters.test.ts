import { expect, test } from "bun:test";
import type { LocalDevSessionEvent } from "../localDevSessionFeed";
import {
  claudeCodeLocalAgentProcessTool,
  claudeCodeTranscriptAdapter,
  codexLocalAgentProcessTool,
  codexTranscriptAdapter,
} from "./localAgentTranscriptAdapters";
import {
  runLocalAgentProcessSupervisor,
  type LocalAgentProcessRunner,
} from "./localAgentProcessSupervisor";
import { runLocalAgentTranscriptTail } from "./localAgentTranscriptTail";

const codexFixtureUrl = new URL("./fixtures/codex-exec-jsonl.jsonl", import.meta.url);
const claudeFixtureUrl = new URL("./fixtures/claude-code-stream-json.jsonl", import.meta.url);

function eventCapture(events: LocalDevSessionEvent[]): typeof fetch {
  return (async (_input: RequestInfo | URL, init?: RequestInit) => {
    expect(init?.method).toBe("POST");
    events.push(JSON.parse(String(init?.body)) as LocalDevSessionEvent);
    return new Response(JSON.stringify({ ingested: 1 }), {
      headers: { "content-type": "application/json" },
    });
  }) as typeof fetch;
}

function streamFromText(text: string): ReadableStream<Uint8Array> {
  const bytes = new TextEncoder().encode(text);
  return new ReadableStream<Uint8Array>({
    start(controller) {
      controller.enqueue(bytes);
      controller.close();
    },
  });
}

function resultEvents(
  result: LocalDevSessionEvent | readonly LocalDevSessionEvent[] | null,
): LocalDevSessionEvent[] {
  if (!result) return [];
  return Array.isArray(result) ? [...result] : [result as LocalDevSessionEvent];
}

test("codexTranscriptAdapter maps public item lifecycle envelopes with stable IDs", async () => {
  const lines = (await Bun.file(codexFixtureUrl).text()).trim().split("\n");
  const events = lines
    .flatMap((line, index) => resultEvents(codexTranscriptAdapter(line, {
      agentId: "codex",
      agentKind: "codex",
      agentLabel: "Codex",
    }, index + 1)));

  expect(events.map((event) => `${event.turn_id}:${event.role}:${event.status}`)).toEqual([
    "codex-command-1:tool:started",
    "codex-command-1:tool:completed",
    "codex-reasoning-1:system:completed",
    "codex-collab-1:tool:completed",
    "codex-message-1:assistant:completed",
  ]);
  expect(events[0]).toMatchObject({
    summary: "bun test",
    input: "bun test",
  });
  expect(events[1]).toMatchObject({
    output: "tests passed token=<redacted>",
  });
  expect(events[3]).toMatchObject({
    summary: "Codex collaboration: spawn_agent",
    input: expect.stringContaining("secret=<redacted>"),
  });
  expect(events[4]).toMatchObject({
    output: "Implemented schema password=<redacted>",
  });
  expect(JSON.stringify(events)).not.toContain("sentinel-secret");
});

test("claudeCodeTranscriptAdapter maps system, tool lifecycle, assistant, and result envelopes", async () => {
  const lines = (await Bun.file(claudeFixtureUrl).text()).trim().split("\n");
  const events = lines
    .flatMap((line, index) => resultEvents(claudeCodeTranscriptAdapter(line, {
      agentId: "claude-code",
      agentKind: "claude-code",
      agentLabel: "Claude Code",
    }, index + 1)));

  expect(events.map((event) => `${event.turn_id}:${event.role}:${event.status}`)).toEqual([
    "claude-init-1:system:completed",
    "claude-tool-1:tool:started",
    "claude-tool-1:tool:completed",
    "claude-message-2:assistant:completed",
    "claude-result-1:assistant:completed",
  ]);
  expect(events[1]).toMatchObject({
    summary: "Bash",
    input: '{"command":"bun test","token":"<redacted>"}',
  });
  expect(events[2]).toMatchObject({
    output: "tests passed password=<redacted>",
  });
  expect(events[4]).toMatchObject({
    summary: "Claude Code result: success",
    output: "Finished local review token=<redacted>",
  });
  expect(JSON.stringify(events)).not.toContain("sentinel-secret");
});

test("claudeCodeTranscriptAdapter preserves parallel tool uses from one assistant message", () => {
  const result = claudeCodeTranscriptAdapter(JSON.stringify({
    type: "assistant",
    uuid: "claude-parallel-1",
    message: {
      id: "claude-message-parallel",
      role: "assistant",
      content: [
        { type: "text", text: "Running two checks" },
        { type: "tool_use", id: "claude-tool-a", name: "Bash", input: { command: "bun test" } },
        { type: "tool_use", id: "claude-tool-b", name: "Read", input: { file_path: "build.zig" } },
      ],
    },
  }), {
    agentId: "claude-code",
    agentKind: "claude-code",
    agentLabel: "Claude Code",
  }, 10);
  const events = resultEvents(result);

  expect(events.map((event) => `${event.sequence}:${event.turn_id}:${event.role}`)).toEqual([
    "10:claude-message-parallel:assistant",
    "11:claude-tool-a:tool",
    "12:claude-tool-b:tool",
  ]);
});

test("codexTranscriptAdapter treats declined commands as failed turns", () => {
  const event = codexTranscriptAdapter(JSON.stringify({
    type: "item.completed",
    item: {
      id: "codex-declined-1",
      type: "command_execution",
      command: "rm -rf build",
      aggregated_output: "declined",
      status: "declined",
    },
  }), {
    agentId: "codex",
    agentKind: "codex",
    agentLabel: "Codex",
  }, 1);

  expect(resultEvents(event)[0]).toMatchObject({ status: "failed" });
});

test("provider adapters ignore malformed, unknown, and Claude partial-delta events", () => {
  const agent = {
    agentId: "local",
    agentKind: "other" as const,
    agentLabel: "Local",
  };
  expect(codexTranscriptAdapter("not-json", agent, 1)).toBeNull();
  expect(codexTranscriptAdapter('{"type":"thread.started","thread_id":"thread-1"}', agent, 2)).toBeNull();
  expect(claudeCodeTranscriptAdapter(
    '{"type":"stream_event","event":{"delta":{"type":"text_delta","text":"partial"}}}',
    agent,
    3,
  )).toBeNull();
  expect(claudeCodeTranscriptAdapter('{"type":"future_event"}', agent, 4)).toBeNull();
});

test("provider adapters bound large process output before normalization", () => {
  const event = codexTranscriptAdapter(JSON.stringify({
    type: "item.completed",
    item: {
      id: "large-command",
      type: "command_execution",
      command: "print output",
      aggregated_output: `token=sentinel-secret ${"x".repeat(10_000)}`,
      exit_code: 0,
      status: "completed",
    },
  }), {
    agentId: "codex",
    agentKind: "codex",
    agentLabel: "Codex",
  }, 1);

  const normalized = resultEvents(event)[0];
  expect(normalized?.output?.length).toBeLessThanOrEqual(4096);
  expect(normalized?.output).toEndWith("... [truncated]");
  expect(JSON.stringify(event)).not.toContain("sentinel-secret");
});

test("provider process-tool builders attach supported public streaming invocations", () => {
  const codex = codexLocalAgentProcessTool({
    id: "codex-review",
    prompt: "review the schema",
    cwd: "/repo",
    extraArgs: ["--ephemeral", "--sandbox", "workspace-write"],
  });
  const claude = claudeCodeLocalAgentProcessTool({
    id: "claude-review",
    prompt: "review the schema",
    cwd: "/repo",
    extraArgs: ["--permission-mode", "acceptEdits"],
  });

  expect(codex).toMatchObject({
    id: "codex-review",
    kind: "codex",
    label: "Codex",
    cwd: "/repo",
    command: [
      "codex",
      "exec",
      "--json",
      "--ephemeral",
      "--sandbox",
      "workspace-write",
      "review the schema",
    ],
  });
  expect(codex.transcriptAdapter).toBe(codexTranscriptAdapter);
  expect(claude).toMatchObject({
    id: "claude-review",
    kind: "claude-code",
    label: "Claude Code",
    cwd: "/repo",
    command: [
      "claude",
      "-p",
      "review the schema",
      "--output-format",
      "stream-json",
      "--verbose",
      "--permission-mode",
      "acceptEdits",
    ],
  });
  expect(claude.transcriptAdapter).toBe(claudeCodeTranscriptAdapter);
});

test("runLocalAgentTranscriptTail applies a native adapter and ignores unsupported fixture lines", async () => {
  const events: LocalDevSessionEvent[] = [];
  const fixture = await Bun.file(codexFixtureUrl).text();
  const summary = await runLocalAgentTranscriptTail(streamFromText(fixture), {
    agentEventsUrl: "http://collector.test/agent-events",
    agentId: "codex",
    agentKind: "codex",
    agentLabel: "Codex",
    adapter: codexTranscriptAdapter,
    fetcher: eventCapture(events),
    sequenceStart: 20,
  });

  expect(summary).toEqual({
    lines: 9,
    turns: 5,
    ignored: 4,
    posted: 5,
    lastSequence: 29,
  });
  expect(events.map((event) => event.sequence)).toEqual([23, 24, 25, 26, 27]);
});

test("runLocalAgentTranscriptTail allocates monotonic sequences for parallel tool uses", async () => {
  const events: LocalDevSessionEvent[] = [];
  const line = JSON.stringify({
    type: "assistant",
    message: {
      id: "parallel-message",
      role: "assistant",
      content: [
        { type: "text", text: "Checking both" },
        { type: "tool_use", id: "parallel-tool-1", name: "Bash", input: { command: "bun test" } },
        { type: "tool_use", id: "parallel-tool-2", name: "Read", input: { file_path: "build.zig" } },
      ],
    },
  });

  const summary = await runLocalAgentTranscriptTail(streamFromText(`${line}\n`), {
    agentEventsUrl: "http://collector.test/agent-events",
    agentId: "claude-code",
    agentKind: "claude-code",
    agentLabel: "Claude Code",
    adapter: claudeCodeTranscriptAdapter,
    fetcher: eventCapture(events),
  });

  expect(summary).toEqual({ lines: 1, turns: 3, ignored: 0, posted: 3, lastSequence: 3 });
  expect(events.map((event) => event.sequence)).toEqual([1, 2, 3]);
});

test("process supervisor forwards a tool-attached native adapter end to end", async () => {
  const events: LocalDevSessionEvent[] = [];
  const fixture = await Bun.file(claudeFixtureUrl).text();
  const runner: LocalAgentProcessRunner = {
    async start() {
      return {
        stdout: streamFromText(fixture),
        stderr: streamFromText(""),
        exited: Promise.resolve(0),
        kill() {},
      };
    },
  };
  const tool = claudeCodeLocalAgentProcessTool({
    id: "claude-code",
    prompt: "review locally",
  });

  const summary = await runLocalAgentProcessSupervisor(tool, {
    agentEventsUrl: "http://collector.test/agent-events",
    fetcher: eventCapture(events),
    runner,
  });

  expect(summary).toMatchObject({
    status: "done",
    lines: 7,
    turns: 5,
    ignored: 2,
    postedEvents: 8,
  });
  expect(events.map((event) => event.kind)).toEqual([
    "agent_status",
    "agent_turn",
    "agent_turn",
    "agent_turn",
    "agent_turn",
    "agent_turn",
    "check_result",
    "agent_status",
  ]);
  expect(JSON.stringify(events)).not.toContain("sentinel-secret");
});
