import { expect, test } from "bun:test";
import type { LocalDevSessionEvent } from "../localDevSessionFeed";
import {
  parseLocalAgentTranscriptLine,
  runLocalAgentTranscriptTail,
} from "./localAgentTranscriptTail";

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

test("parseLocalAgentTranscriptLine maps JSON turn records to redacted agent_turn events", () => {
  const event = parseLocalAgentTranscriptLine(
    JSON.stringify({
      type: "turn",
      id: "turn-7",
      role: "assistant",
      status: "completed",
      summary: "edited cli token=sentinel-secret",
      input: "please run password=sentinel-secret",
      output: "done secret=sentinel-secret",
      artifact_path: ".zig-cache/causal-artifacts/turn-7.md",
    }),
    {
      agentId: "codex",
      agentKind: "codex",
      agentLabel: "Codex",
    },
    7,
  );

  expect(event).toMatchObject({
    sequence: 7,
    kind: "agent_turn",
    agent_id: "codex",
    agent_kind: "codex",
    agent_label: "Codex",
    turn_id: "turn-7",
    role: "assistant",
    status: "completed",
    summary: "edited cli token=<redacted>",
    input: "please run password=<redacted>",
    output: "done secret=<redacted>",
    artifact_path: ".zig-cache/causal-artifacts/turn-7.md",
  });
  expect(JSON.stringify(event)).not.toContain("sentinel-secret");
});

test("parseLocalAgentTranscriptLine maps tagged text to turn events", () => {
  const event = parseLocalAgentTranscriptLine(
    "assistant: fixed schema password=sentinel-secret",
    {
      agentId: "claude-code",
      agentKind: "claude-code",
      agentLabel: "Claude Code",
    },
    3,
  );

  expect(event).toMatchObject({
    sequence: 3,
    kind: "agent_turn",
    agent_id: "claude-code",
    role: "assistant",
    status: "completed",
    summary: "fixed schema password=<redacted>",
    output: "fixed schema password=<redacted>",
  });
});

test("runLocalAgentTranscriptTail posts complete turn lines and flushes trailing partials", async () => {
  const events: LocalDevSessionEvent[] = [];
  const stream = streamFromChunks([
    '{"type":"turn","id":"user-1","role":"user","input":"hello token=sentinel',
    '-secret"}\nnot a turn\nassistant: done password=sentinel-secret',
  ]);

  const summary = await runLocalAgentTranscriptTail(stream, {
    agentEventsUrl: "http://collector.test/agent-events",
    agentId: "codex",
    agentKind: "codex",
    agentLabel: "Codex",
    fetcher: eventCapture(events),
    sequenceStart: 10,
  });

  expect(summary).toEqual({
    lines: 3,
    turns: 2,
    ignored: 1,
    posted: 2,
    lastSequence: 13,
  });
  expect(events.map((event) => event.sequence)).toEqual([11, 13]);
  expect(events.map((event) => event.role)).toEqual(["user", "assistant"]);
  expect(JSON.stringify(events)).not.toContain("sentinel-secret");
});
