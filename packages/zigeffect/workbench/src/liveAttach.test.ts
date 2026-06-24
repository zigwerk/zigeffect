import { expect, test } from "bun:test";
import { createRoot } from "solid-js";
import { deriveWorkbenchModel } from "./causalArtifact";
import {
  LiveCausalBuffer,
  createLiveEngineHost,
  createHttpLiveEngineCommandBridge,
  createLiveArtifact,
  fetchLiveCommands,
  frameToEventRecord,
  framesFromStreamDocument,
  isLiveCommandEngineBatchResult,
  isLiveCommandInboxResponse,
  isLiveFrame,
  isLiveCommandFrame,
  liveUrlFromSearch,
  mockLiveSource,
  parseCommandMessage,
  parseFrameMessage,
  runLiveCommandPollingLoop,
  runLiveCommandDaemon,
  runLiveEngineCommandDaemon,
  serveLiveEngineCommandApplyRequest,
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

test("runLiveCommandDaemon emits lifecycle evidence", async () => {
  const fetcher = async () =>
    new Response(JSON.stringify({ next_after: 0, commands: [] }), { headers: { "content-type": "application/json" } });
  const events: string[] = [];

  const result = await runLiveCommandDaemon(
    "http://127.0.0.1:4500/commands",
    () => {},
    {
      maxCycles: 1,
      onLifecycle: (event) => {
        events.push(event.kind);
      },
    },
    fetcher,
  );

  expect(result).toEqual({ cycles: 1, polls: 1, commands: 0, errors: 0, next_after: 0, stopped: false });
  expect(events).toEqual(["started", "cycle", "stopped"]);
});

test("runLiveEngineCommandDaemon bridges command batches to engine frames", async () => {
  const batches: LiveCommandInboxResponse[] = [
    {
      next_after: 1,
      commands: [
        {
          sequence: 1,
          command_id: "cmd-1",
          command_kind: "interrupt_fiber",
          status: "received",
          run_id: 1,
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
          command_kind: "unknown_command",
          status: "received",
          reason: "exercise rejection path",
        },
      ],
    },
    { next_after: 2, commands: [] },
  ];
  const urls: string[] = [];
  const appliedKinds: string[] = [];
  const emitted: LiveFrame[] = [];
  const fetcher = async (url: string) => {
    urls.push(url);
    const response = batches.shift() ?? { next_after: 2, commands: [] };
    return new Response(JSON.stringify(response), { headers: { "content-type": "application/json" } });
  };

  const result = await runLiveEngineCommandDaemon(
    "http://127.0.0.1:4500/commands",
    {
      applyBatch: (inbox) => {
        appliedKinds.push(...inbox.commands.map((command) => command.command_kind));
        return {
          processed: inbox.commands.length,
          applied: inbox.commands.filter((command) => command.command_kind === "interrupt_fiber").length,
          rejected: inbox.commands.filter((command) => command.command_kind !== "interrupt_fiber").length,
          needs_human_review: 0,
          frames: inbox.commands.map((command) =>
            frame({
              sequence: command.sequence,
              event_id: 100 + command.sequence,
              event_kind: command.command_kind === "interrupt_fiber" ? "remediation_applied" : "alert_emitted",
              status: command.command_kind === "interrupt_fiber" ? "applied" : "rejected",
              label: command.command_id,
            }),
          ),
        };
      },
      emitFrame: (nextFrame) => {
        emitted.push(nextFrame);
      },
    },
    { maxCycles: 3, maxPollsPerCycle: 1 },
    fetcher,
  );

  expect(urls).toEqual([
    "http://127.0.0.1:4500/commands?after=0",
    "http://127.0.0.1:4500/commands?after=1",
    "http://127.0.0.1:4500/commands?after=2",
  ]);
  expect(appliedKinds).toEqual(["interrupt_fiber", "unknown_command"]);
  expect(emitted.map((nextFrame) => nextFrame.event_id)).toEqual([101, 102]);
  expect(result).toEqual({
    cycles: 3,
    polls: 3,
    commands: 2,
    errors: 0,
    next_after: 2,
    stopped: false,
    processed: 2,
    applied: 1,
    rejected: 1,
    needs_human_review: 0,
    emitted_frames: 2,
  });
});

test("createHttpLiveEngineCommandBridge posts command batches and emitted frames", async () => {
  const requests: Array<{ url: string; method?: string; body: unknown }> = [];
  const returnedFrame = frame({
    sequence: 10,
    event_id: 110,
    event_kind: "remediation_applied",
    status: "applied",
    label: "cmd-10",
  });
  const fetcher = async (url: string, init?: RequestInit) => {
    requests.push({
      url,
      method: init?.method,
      body: init?.body ? JSON.parse(String(init.body)) : null,
    });
    if (url === "http://127.0.0.1:4600/apply-commands") {
      return new Response(
        JSON.stringify({
          processed: 1,
          applied: 1,
          rejected: 0,
          needs_human_review: 0,
          frames: [returnedFrame],
        }),
        { headers: { "content-type": "application/json" } },
      );
    }
    return new Response(JSON.stringify({ ingested: 1 }), { headers: { "content-type": "application/json" } });
  };
  const bridge = createHttpLiveEngineCommandBridge({
    applyUrl: "http://127.0.0.1:4600/apply-commands",
    framesUrl: "http://127.0.0.1:4500/frames",
    fetcher,
  });
  const inbox: LiveCommandInboxResponse = {
    next_after: 10,
    commands: [
      {
        sequence: 10,
        command_id: "cmd-10",
        command_kind: "interrupt_fiber",
        status: "received",
        run_id: 1,
        fiber_id: 9,
      },
    ],
  };

  const result = await bridge.applyBatch(inbox);
  expect(isLiveCommandEngineBatchResult(result)).toBe(true);
  await bridge.emitFrame?.(result.frames![0]!);

  expect(result.processed).toBe(1);
  expect(result.frames?.[0]?.event_id).toBe(110);
  expect(requests).toEqual([
    {
      url: "http://127.0.0.1:4600/apply-commands",
      method: "POST",
      body: inbox,
    },
    {
      url: "http://127.0.0.1:4500/frames",
      method: "POST",
      body: returnedFrame,
    },
  ]);
});

test("serveLiveEngineCommandApplyRequest validates inboxes and formats engine results", async () => {
  const inbox: LiveCommandInboxResponse = {
    next_after: 12,
    commands: [
      {
        sequence: 12,
        command_id: "cmd-12",
        command_kind: "interrupt_fiber",
        status: "received",
        run_id: 1,
        fiber_id: 9,
      },
    ],
  };
  const appliedInboxes: LiveCommandInboxResponse[] = [];
  const response = await serveLiveEngineCommandApplyRequest(
    new Request("http://127.0.0.1:4600/apply-commands", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(inbox),
    }),
    {
      applyBatch: (nextInbox) => {
        appliedInboxes.push(nextInbox);
        return {
          processed: 1,
          applied: 1,
          rejected: 0,
          needs_human_review: 0,
          frames: [
            frame({
              sequence: 13,
              event_id: 113,
              event_kind: "remediation_applied",
              status: "applied",
            }),
          ],
        };
      },
    },
  );

  expect(response.status).toBe(200);
  expect(response.headers.get("content-type")).toContain("application/json");
  expect(response.headers.get("cache-control")).toBe("no-store");
  expect(response.headers.get("x-content-type-options")).toBe("nosniff");
  expect(appliedInboxes).toEqual([inbox]);
  expect(await response.json()).toEqual({
    processed: 1,
    applied: 1,
    rejected: 0,
    needs_human_review: 0,
    frames: [
      {
        sequence: 13,
        event_id: 113,
        event_kind: "remediation_applied",
        status: "applied",
        label: "event 113",
      },
    ],
  });

  const methodRejected = await serveLiveEngineCommandApplyRequest(
    new Request("http://127.0.0.1:4600/apply-commands", { method: "GET" }),
    { applyBatch: () => ({ processed: 0, applied: 0, rejected: 0, needs_human_review: 0 }) },
  );
  expect(methodRejected.status).toBe(405);
  expect(await methodRejected.json()).toEqual({ error: "method_not_allowed" });

  const invalidInbox = await serveLiveEngineCommandApplyRequest(
    new Request("http://127.0.0.1:4600/apply-commands", {
      method: "POST",
      body: JSON.stringify({ commands: [{ sequence: 2 }], next_after: 1 }),
    }),
    { applyBatch: () => ({ processed: 0, applied: 0, rejected: 0, needs_human_review: 0 }) },
  );
  expect(invalidInbox.status).toBe(400);
  expect(await invalidInbox.json()).toEqual({ error: "invalid_live_command_inbox" });
});

test("createLiveEngineHost wires apply requests and collector command daemon", async () => {
  const appliedCommandIds: string[] = [];
  const emittedFrames: number[] = [];
  const host = createLiveEngineHost({
    applyBatch: (inbox) => {
      appliedCommandIds.push(...inbox.commands.map((command) => command.command_id));
      return {
        processed: inbox.commands.length,
        applied: inbox.commands.length,
        rejected: 0,
        needs_human_review: 0,
        frames: inbox.commands.map((command, index) =>
          frame({
            sequence: command.sequence + 100,
            event_id: 200 + index,
            event_kind: "remediation_applied",
            status: "applied",
          }),
        ),
      };
    },
    emitFrame: (nextFrame) => {
      emittedFrames.push(nextFrame.event_id);
    },
  });

  const applyInbox: LiveCommandInboxResponse = {
    next_after: 30,
    commands: [
      {
        sequence: 30,
        command_id: "cmd-apply",
        command_kind: "interrupt_fiber",
        status: "received",
        run_id: 1,
        fiber_id: 9,
      },
    ],
  };
  const applyResponse = await host.handleApplyRequest(
    new Request("http://127.0.0.1:4600/apply-commands", {
      method: "POST",
      body: JSON.stringify(applyInbox),
    }),
  );
  expect(applyResponse.status).toBe(200);
  expect(await applyResponse.json()).toEqual({
    processed: 1,
    applied: 1,
    rejected: 0,
    needs_human_review: 0,
    frames: [
      {
        sequence: 130,
        event_id: 200,
        event_kind: "remediation_applied",
        status: "applied",
        label: "event 200",
      },
    ],
  });

  const fetcher = async (url: string) => {
    const after = new URL(url).searchParams.get("after");
    const body =
      after === "0"
        ? {
            next_after: 31,
            commands: [
              {
                sequence: 31,
                command_id: "cmd-daemon",
                command_kind: "interrupt_fiber",
                status: "received",
                run_id: 1,
                fiber_id: 10,
              },
            ],
          }
        : { next_after: 31, commands: [] };
    return new Response(JSON.stringify(body), { headers: { "content-type": "application/json" } });
  };

  const daemon = await host.runCommandDaemon(
    "http://127.0.0.1:4500/commands",
    { maxCycles: 2, maxPollsPerCycle: 1 },
    fetcher,
  );

  expect(appliedCommandIds).toEqual(["cmd-apply", "cmd-daemon"]);
  expect(emittedFrames).toEqual([200]);
  expect(daemon.processed).toBe(1);
  expect(daemon.applied).toBe(1);
  expect(daemon.emitted_frames).toBe(1);
  expect(daemon.next_after).toBe(31);
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
