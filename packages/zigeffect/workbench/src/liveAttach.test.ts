import { expect, test } from "bun:test";
import { createRoot } from "solid-js";
import { deriveWorkbenchModel } from "./causalArtifact";
import {
  LiveCausalBuffer,
  createLiveArtifact,
  fetchLiveCommands,
  frameToEventRecord,
  framesFromStreamDocument,
  isLiveCommandInboxResponse,
  isLiveFrame,
  isLiveCommandFrame,
  liveUrlFromSearch,
  mockLiveSource,
  parseCommandMessage,
  parseFrameMessage,
  runLiveCommandPollingLoop,
  runLiveCommandDaemon,
  sendLiveCommand,
  webSocketLiveSource,
  type LiveCommandRequest,
  type LiveCommandFrame,
  type LiveCommandInboxResponse,
  type LiveFrame,
  type WebSocketLike,
} from "./liveAttach";

function frame(partial: Partial<LiveFrame> & Pick<LiveFrame, "sequence" | "event_id">): LiveFrame {
  return {
    event_kind: "fiber_started",
    status: "ready",
    label: `event ${partial.event_id}`,
    ...partial,
  };
}

const sampleFrames: LiveFrame[] = [
  frame({ sequence: 1, event_id: 10, event_kind: "run_started", status: "ready", lane: "run" }),
  frame({ sequence: 2, event_id: 11, event_kind: "fiber_started", status: "pending", lane: "fiber", parent_id: 10 }),
  frame({ sequence: 3, event_id: 12, event_kind: "metric_recorded", status: "ready", lane: "resource", parent_id: 11 }),
];

test("frameToEventRecord maps wire fields onto canonical artifact keys", () => {
  const record = frameToEventRecord(
    frame({ sequence: 4, event_id: 99, event_kind: "fiber_resumed", status: "ready", parent_id: 11, lane: "fiber" }),
  );
  expect(record.id).toBe(99);
  expect(record.kind).toBe("fiber_resumed");
  expect(record.status).toBe("ready");
  expect(record.parent_id).toBe(11);
  expect(record.sequence).toBe(4);
  expect(record.lane).toBe("fiber");
});

test("isLiveFrame / parseFrameMessage accept valid frames and reject junk", () => {
  expect(isLiveFrame(sampleFrames[0])).toBe(true);
  expect(isLiveFrame({ sequence: 1 })).toBe(false);
  expect(parseFrameMessage(JSON.stringify(sampleFrames[0]))?.event_id).toBe(10);
  expect(parseFrameMessage("not json")).toBeNull();
  expect(parseFrameMessage(JSON.stringify({ hello: "world" }))).toBeNull();
});

test("isLiveCommandFrame / parseCommandMessage accept intervention command frames", () => {
  const command: LiveCommandFrame = {
    sequence: 1,
    command_id: "cmd-1",
    command_kind: "interrupt_fiber",
    status: "received",
    reason: "interrupt hung fiber",
    run_id: 1,
    fiber_id: 9,
  };

  expect(isLiveCommandFrame(command)).toBe(true);
  expect(isLiveCommandFrame({ sequence: 1, command_id: "cmd-1" })).toBe(false);
  expect(parseCommandMessage(JSON.stringify(command))?.command_kind).toBe("interrupt_fiber");
  expect(parseCommandMessage("not json")).toBeNull();
});

test("sendLiveCommand posts a bounded intervention request and returns command frame", async () => {
  const request: LiveCommandRequest = {
    kind: "interrupt_fiber",
    reason: "interrupt hung fiber",
    run_id: 1,
    fiber_id: 9,
  };
  const sent: { url?: string; body?: unknown } = {};
  const fetcher = async (url: string, init?: RequestInit) => {
    sent.url = url;
    sent.body = JSON.parse(String(init?.body ?? "{}"));
    return new Response(
      JSON.stringify({
        sequence: 7,
        command_id: "cmd-7",
        command_kind: "interrupt_fiber",
        status: "received",
        reason: "interrupt hung fiber",
        run_id: 1,
        fiber_id: 9,
      }),
      { headers: { "content-type": "application/json" } },
    );
  };

  const frame = await sendLiveCommand("http://127.0.0.1:4500/command", request, fetcher);
  expect(sent.url).toBe("http://127.0.0.1:4500/command");
  expect(sent.body).toEqual(request);
  expect(frame.command_id).toBe("cmd-7");
  expect(frame.command_kind).toBe("interrupt_fiber");
});

test("fetchLiveCommands polls the command inbox by cursor and validates frames", async () => {
  const response: LiveCommandInboxResponse = {
    next_after: 8,
    commands: [
      {
        sequence: 8,
        command_id: "cmd-8",
        command_kind: "fire_timer",
        status: "received",
        run_id: 1,
        schedule_id: 7,
      },
    ],
  };
  const seen: string[] = [];
  const fetcher = async (url: string) => {
    seen.push(url);
    return new Response(JSON.stringify(response), { headers: { "content-type": "application/json" } });
  };

  expect(isLiveCommandInboxResponse(response)).toBe(true);
  const inbox = await fetchLiveCommands("http://127.0.0.1:4500/commands", 7, fetcher);
  expect(seen[0]).toBe("http://127.0.0.1:4500/commands?after=7");
  expect(inbox.next_after).toBe(8);
  expect(inbox.commands[0]?.command_kind).toBe("fire_timer");
});

test("fetchLiveCommands rejects invalid command inbox payloads", async () => {
  const fetcher = async () =>
    new Response(JSON.stringify({ next_after: 9, commands: [{ sequence: 9, command_id: "cmd-9" }] }));

  expect(isLiveCommandInboxResponse({ next_after: 9, commands: [{ sequence: 9, command_id: "cmd-9" }] })).toBe(false);
  await expect(fetchLiveCommands("http://127.0.0.1:4500/commands", 8, fetcher)).rejects.toThrow(
    "live command inbox returned an invalid response",
  );
});

test("runLiveCommandPollingLoop advances cursors and stops on empty batches", async () => {
  const batches: LiveCommandInboxResponse[] = [
    {
      next_after: 1,
      commands: [
        {
          sequence: 1,
          command_id: "cmd-1",
          command_kind: "interrupt_fiber",
          status: "received",
          fiber_id: 9,
        },
      ],
    },
    {
      next_after: 2,
      commands: [
        {
          sequence: 2,
          command_id: "cmd-2",
          command_kind: "fire_timer",
          status: "received",
          schedule_id: 7,
        },
      ],
    },
    { next_after: 2, commands: [] },
  ];
  const urls: string[] = [];
  const seen: string[] = [];
  const fetcher = async (url: string) => {
    urls.push(url);
    const response = batches.shift();
    return new Response(JSON.stringify(response), { headers: { "content-type": "application/json" } });
  };

  const result = await runLiveCommandPollingLoop(
    "http://127.0.0.1:4500/commands",
    (inbox) => {
      seen.push(...inbox.commands.map((command) => command.command_kind));
    },
    { startAfter: 0, maxPolls: 5 },
    fetcher,
  );

  expect(urls).toEqual([
    "http://127.0.0.1:4500/commands?after=0",
    "http://127.0.0.1:4500/commands?after=1",
    "http://127.0.0.1:4500/commands?after=2",
  ]);
  expect(seen).toEqual(["interrupt_fiber", "fire_timer"]);
  expect(result).toEqual({ polls: 3, commands: 2, next_after: 2 });
});

test("runLiveCommandDaemon advances cursors across cycles and stops on signal", async () => {
  const batches: LiveCommandInboxResponse[] = [
    {
      next_after: 1,
      commands: [
        {
          sequence: 1,
          command_id: "cmd-1",
          command_kind: "interrupt_fiber",
          status: "received",
          fiber_id: 9,
        },
      ],
    },
    {
      next_after: 2,
      commands: [
        {
          sequence: 2,
          command_id: "cmd-2",
          command_kind: "fire_timer",
          status: "received",
          schedule_id: 7,
        },
      ],
    },
  ];
  const urls: string[] = [];
  const handled: string[] = [];
  let delays = 0;
  const fetcher = async (url: string) => {
    urls.push(url);
    const response = batches.shift() ?? { next_after: 2, commands: [] };
    return new Response(JSON.stringify(response), { headers: { "content-type": "application/json" } });
  };

  const result = await runLiveCommandDaemon(
    "http://127.0.0.1:4500/commands",
    (inbox) => {
      handled.push(...inbox.commands.map((command) => command.command_kind));
    },
    {
      startAfter: 0,
      maxCycles: 5,
      maxPollsPerCycle: 1,
      shouldStop: () => handled.length >= 2,
      delay: () => {
        delays += 1;
      },
    },
    fetcher,
  );

  expect(urls).toEqual([
    "http://127.0.0.1:4500/commands?after=0",
    "http://127.0.0.1:4500/commands?after=1",
  ]);
  expect(handled).toEqual(["interrupt_fiber", "fire_timer"]);
  expect(delays).toBe(1);
  expect(result).toEqual({ cycles: 2, polls: 2, commands: 2, errors: 0, next_after: 2, stopped: true });
});

test("LiveCausalBuffer accumulates frames in causal (sequence) order", () => {
  const buffer = new LiveCausalBuffer();
  // Ingest out of order — buffer must re-order by sequence.
  buffer.ingest(sampleFrames[2]!);
  buffer.ingest(sampleFrames[0]!);
  buffer.ingest(sampleFrames[1]!);
  expect(buffer.size).toBe(3);
  expect(buffer.frames().map((f) => f.sequence)).toEqual([1, 2, 3]);
});

test("LiveCausalBuffer updates a repeated event_id in place (status transition), no growth", () => {
  const buffer = new LiveCausalBuffer();
  buffer.ingest(frame({ sequence: 1, event_id: 11, status: "pending" }));
  buffer.ingest(frame({ sequence: 1, event_id: 11, status: "ready" })); // same id, later status
  expect(buffer.size).toBe(1);
  expect(buffer.frames()[0]!.status).toBe("ready");
});

test("LiveCausalBuffer enforces a maxFrames ring window, counting drops", () => {
  const buffer = new LiveCausalBuffer({ maxFrames: 2 });
  buffer.ingestMany([
    frame({ sequence: 1, event_id: 1 }),
    frame({ sequence: 2, event_id: 2 }),
    frame({ sequence: 3, event_id: 3 }),
  ]);
  expect(buffer.size).toBe(2);
  expect(buffer.dropped).toBe(1);
  // The OLDEST (event_id 1) was evicted; 2 and 3 survive.
  expect(buffer.frames().map((f) => f.event_id)).toEqual([2, 3]);
});

test("the accumulated artifact feeds the EXISTING deriveWorkbenchModel pipeline", () => {
  const buffer = new LiveCausalBuffer();
  buffer.ingestMany(sampleFrames);
  const model = deriveWorkbenchModel(buffer.artifact(), { artifactPath: "live-attach" });

  expect(model.events).toHaveLength(3);
  expect(model.events.map((event) => event.kind)).toEqual(["run_started", "fiber_started", "metric_recorded"]);
  // A child frame's parent edge survives the round-trip into the workbench model.
  const child = model.events.find((event) => event.kind === "metric_recorded");
  expect(child?.parentId).toBe("11");
  // No structural warnings beyond the expected (schema present, events present).
  expect(model.warnings).not.toContain("artifact events array is missing");
});

test("mockLiveSource (sync) drives a buffer to completion and reports close", () => {
  const buffer = new LiveCausalBuffer();
  let closed = false;
  const unsubscribe = mockLiveSource(sampleFrames).subscribe({
    onFrame: (f) => buffer.ingest(f),
    onClose: () => {
      closed = true;
    },
  });
  expect(buffer.size).toBe(3);
  expect(closed).toBe(true);
  unsubscribe();
});

test("mockLiveSource (async) can be cancelled mid-stream", async () => {
  const buffer = new LiveCausalBuffer();
  const unsubscribe = mockLiveSource(sampleFrames, { async: true }).subscribe({
    onFrame: (f) => buffer.ingest(f),
  });
  unsubscribe(); // cancel before any microtask delivers
  await new Promise((resolve) => setTimeout(resolve, 5));
  expect(buffer.size).toBe(0);
});

test("createLiveArtifact reactively accumulates frames and tracks connection", () => {
  createRoot((dispose) => {
    const live = createLiveArtifact(mockLiveSource(sampleFrames), { taxonomyVersion: "test" });
    // mockLiveSource is synchronous, so by now all frames are ingested + closed.
    expect(live.frameCount()).toBe(3);
    expect(live.connected()).toBe(false); // onClose fired
    const artifact = JSON.parse(live.artifactJson()) as { events: unknown[]; event_taxonomy_version: string };
    expect(artifact.events).toHaveLength(3);
    expect(artifact.event_taxonomy_version).toBe("test");
    dispose();
  });
});

test("webSocketLiveSource parses message frames and ignores non-frame payloads", () => {
  type Listener = (event: unknown) => void;
  const listeners = new Map<string, Listener>();
  const fakeSocket: WebSocketLike = {
    addEventListener: (type, listener) => listeners.set(type, listener),
    close: () => listeners.set("__closed", () => {}),
  };
  const received: number[] = [];
  let closed = false;
  webSocketLiveSource("ws://localhost:0/live", () => fakeSocket).subscribe({
    onFrame: (f) => received.push(f.event_id),
    onClose: () => {
      closed = true;
    },
  });

  listeners.get("message")?.({ data: JSON.stringify(sampleFrames[0]) });
  listeners.get("message")?.({ data: "garbage" }); // ignored, no throw
  listeners.get("message")?.({ data: JSON.stringify({ not: "a frame" }) }); // ignored
  listeners.get("close")?.(undefined);

  expect(received).toEqual([10]);
  expect(closed).toBe(true);
});

test("liveUrlFromSearch reads ?live=<url>", () => {
  expect(liveUrlFromSearch("?live=ws://localhost:9000/causal")).toBe("ws://localhost:9000/causal");
  expect(liveUrlFromSearch("?sample=chain")).toBeNull();
  expect(liveUrlFromSearch("")).toBeNull();
});

test("framesFromStreamDocument extracts frames from the real sample-live-dashboard-stream.json", async () => {
  const path = new URL("../public/sample-live-dashboard-stream.json", import.meta.url);
  const raw = JSON.parse(await Bun.file(path).text()) as unknown;
  const frames = framesFromStreamDocument(raw);
  expect(frames.length).toBeGreaterThan(0);

  // The real wire frames flow through the buffer into the workbench model.
  const buffer = new LiveCausalBuffer();
  buffer.ingestMany(frames);
  const model = deriveWorkbenchModel(buffer.artifact(), { artifactPath: "live-attach" });
  expect(model.events.length).toBe(frames.length);
});
