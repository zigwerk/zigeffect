import { afterEach, expect, test } from "bun:test";
import type { Server } from "bun";
import { createCollector } from "./collector";
import { parseCommandMessage, parseFrameMessage, type LiveCommandFrame, type LiveFrame } from "../liveAttach";
import { parseLocalDevSessionEventMessage, type LocalDevSessionEvent } from "../localDevSessionFeed";

const engineLine = (extra: Record<string, unknown>): string =>
  JSON.stringify({ id: 1, kind: "run_started", run_id: 1, status: "started", label: "", ...extra });

// ── Pure ingest (no server) ──────────────────────────────────────────────────

test("ingestBody maps NDJSON lines, skips junk, and assigns monotonic sequence", () => {
  const collector = createCollector();
  const seen: LiveFrame[] = [];
  // No clients connected — ingest still maps + returns frames via ingestLine.
  const body = [engineLine({ id: 1 }), "garbage", engineLine({ id: 2 }), ""].join("\n");
  const count = collector.ingestBody(body);
  expect(count).toBe(2); // the two valid lines; junk + blank skipped

  // ingestLine returns the mapped frame and bumps the sequence.
  seen.push(collector.ingestLine(engineLine({ id: 3 }))!);
  seen.push(collector.ingestLine(engineLine({ id: 4 }))!);
  expect(seen.map((f) => f.sequence)).toEqual([3, 4]); // continues after the 2 above
  expect(seen.map((f) => f.event_id)).toEqual([3, 4]);
});

// ── Real WebSocket fan-out ───────────────────────────────────────────────────

let server: Server<undefined> | null = null;
afterEach(() => {
  server?.stop(true);
  server = null;
});

function serve() {
  const collector = createCollector();
  server = Bun.serve({ port: 0, fetch: collector.fetch, websocket: collector.websocket });
  return { collector, port: server.port, origin: `127.0.0.1:${server.port}` };
}

function openClient(origin: string): Promise<WebSocket> {
  const ws = new WebSocket(`ws://${origin}/live`);
  return new Promise((resolve, reject) => {
    ws.addEventListener("open", () => resolve(ws), { once: true });
    ws.addEventListener("error", (e) => reject(e), { once: true });
  });
}

function nextFrame(ws: WebSocket): Promise<LiveFrame> {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error("timed out waiting for a frame")), 2000);
    ws.addEventListener(
      "message",
      (event) => {
        clearTimeout(timer);
        const frame = parseFrameMessage(typeof event.data === "string" ? event.data : "");
        if (frame) resolve(frame);
        else reject(new Error(`unparseable frame: ${String(event.data)}`));
      },
      { once: true },
    );
  });
}

function nextCommand(ws: WebSocket): Promise<LiveCommandFrame> {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error("timed out waiting for a command")), 2000);
    ws.addEventListener(
      "message",
      (event) => {
        clearTimeout(timer);
        const frame = parseCommandMessage(typeof event.data === "string" ? event.data : "");
        if (frame) resolve(frame);
        else reject(new Error(`unparseable command: ${String(event.data)}`));
      },
      { once: true },
    );
  });
}

function nextAgentEvent(ws: WebSocket): Promise<LocalDevSessionEvent> {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error("timed out waiting for an agent event")), 2000);
    ws.addEventListener(
      "message",
      (event) => {
        clearTimeout(timer);
        const frame = parseLocalDevSessionEventMessage(typeof event.data === "string" ? event.data : "");
        if (frame) resolve(frame);
        else reject(new Error(`unparseable agent event: ${String(event.data)}`));
      },
      { once: true },
    );
  });
}

test("a connected client receives an ingested line as ONE mapped LiveFrame message", async () => {
  const { origin } = serve();
  const client = await openClient(origin);
  try {
    const received = nextFrame(client);
    const response = await fetch(`http://${origin}/ingest`, {
      method: "POST",
      body: engineLine({ id: 42, kind: "fiber_started", status: "running", label: "live", fiber_id: 5 }),
    });
    expect(await response.json()).toEqual({ ingested: 1 });

    const frame = await received;
    expect(frame.event_id).toBe(42);
    expect(frame.event_kind).toBe("fiber_started");
    expect(frame.lane).toBe("fiber:5");
    // The exact contract the frontend webSocketLiveSource relies on.
    expect(parseFrameMessage(JSON.stringify(frame))).not.toBeNull();
  } finally {
    client.close();
  }
});

test("every connected client receives the broadcast", async () => {
  const { origin } = serve();
  const a = await openClient(origin);
  const b = await openClient(origin);
  try {
    const gotA = nextFrame(a);
    const gotB = nextFrame(b);
    await fetch(`http://${origin}/ingest`, { method: "POST", body: engineLine({ id: 7 }) });
    expect((await gotA).event_id).toBe(7);
    expect((await gotB).event_id).toBe(7);
  } finally {
    a.close();
    b.close();
  }
});

test("POST /frames broadcasts an already mapped LiveFrame", async () => {
  const { origin } = serve();
  const client = await openClient(origin);
  try {
    const received = nextFrame(client);
    const frame: LiveFrame = {
      sequence: 12,
      event_id: 120,
      event_kind: "remediation_applied",
      status: "applied",
      label: "cmd-12",
      lane: "fiber:9",
      parent_id: 10,
    };
    const response = await fetch(`http://${origin}/frames`, {
      method: "POST",
      body: JSON.stringify(frame),
      headers: { "content-type": "application/json" },
    });
    expect(await response.json()).toEqual({ ingested: 1 });

    const next = await received;
    expect(next.event_id).toBe(120);
    expect(next.event_kind).toBe("remediation_applied");
    expect(next.parent_id).toBe(10);
  } finally {
    client.close();
  }
});

test("POST /command broadcasts a redacted policy-gated command frame", async () => {
  const { origin } = serve();
  const client = await openClient(origin);
  try {
    const received = nextCommand(client);
    const response = await fetch(`http://${origin}/command`, {
      method: "POST",
      body: JSON.stringify({
        kind: "interrupt_fiber",
        reason: "interrupt token=sentinel-secret fiber",
        redacted_detail: "password=sentinel-secret",
        run_id: 1,
        fiber_id: 9,
      }),
    });

    const json = await response.json();
    expect(json.command_kind).toBe("interrupt_fiber");
    const command = await received;
    expect(command.command_kind).toBe("interrupt_fiber");
    expect(command.status).toBe("received");
    expect(command.reason).toContain("<redacted>");
    expect(command.reason).not.toContain("sentinel-secret");
    expect(command.redacted_detail).not.toContain("sentinel-secret");
  } finally {
    client.close();
  }
});

test("POST /command redacts secret-shaped command kind before response and broadcast", async () => {
  const { origin } = serve();
  const client = await openClient(origin);
  try {
    const received = nextCommand(client);
    const response = await fetch(`http://${origin}/command`, {
      method: "POST",
      body: JSON.stringify({
        kind: "rotate_database_root_password token=sentinel-secret",
        reason: "operator sent an unsafe command kind",
      }),
    });

    const json = await response.json();
    expect(json.command_kind).toContain("<redacted>");
    expect(json.command_kind).not.toContain("sentinel-secret");
    const command = await received;
    expect(command.command_kind).toContain("<redacted>");
    expect(command.command_kind).not.toContain("sentinel-secret");

    const all = await (await fetch(`http://${origin}/commands?after=0`)).json();
    expect(JSON.stringify(all)).not.toContain("sentinel-secret");
  } finally {
    client.close();
  }
});

test("POST /agent-feed broadcasts redacted local dev-session events", async () => {
  const { origin } = serve();
  const client = await openClient(origin);
  try {
    const received = nextAgentEvent(client);
    const response = await fetch(`http://${origin}/agent-feed`, {
      method: "POST",
      body: [
        JSON.stringify({
          sequence: 1,
          kind: "agent_status",
          agent_id: "codex",
          agent_kind: "codex",
          agent_label: "Codex",
          status: "running",
          task: "streaming token=sentinel-secret",
        }),
      ].join("\n"),
    });

    expect(await response.json()).toEqual({ ingested: 1 });
    const event = await received;
    expect(event.kind).toBe("agent_status");
    expect(event.agent_id).toBe("codex");
    expect(event.task).toContain("<redacted>");
    expect(JSON.stringify(event)).not.toContain("sentinel-secret");
  } finally {
    client.close();
  }
});

test("GET /commands exposes posted commands for an engine-side tap by sequence", async () => {
  const { origin } = serve();

  const first = await fetch(`http://${origin}/command`, {
    method: "POST",
    body: JSON.stringify({ kind: "interrupt_fiber", reason: "first", run_id: 1, fiber_id: 9 }),
  });
  expect(first.ok).toBe(true);
  const second = await fetch(`http://${origin}/command`, {
    method: "POST",
    body: JSON.stringify({ kind: "fire_timer", reason: "second", run_id: 1, schedule_id: 7 }),
  });
  expect(second.ok).toBe(true);

  const all = await (await fetch(`http://${origin}/commands?after=0`)).json();
  expect(all.next_after).toBe(2);
  expect(all.commands.map((command: LiveCommandFrame) => command.command_kind)).toEqual([
    "interrupt_fiber",
    "fire_timer",
  ]);

  const onlySecond = await (await fetch(`http://${origin}/commands?after=1`)).json();
  expect(onlySecond.next_after).toBe(2);
  expect(onlySecond.commands.map((command: LiveCommandFrame) => command.command_kind)).toEqual(["fire_timer"]);

  const none = await (await fetch(`http://${origin}/commands?after=2`)).json();
  expect(none).toEqual({ commands: [], next_after: 2 });
});

function collectFrames(ws: WebSocket, count: number, timeoutMs = 3000): Promise<LiveFrame[]> {
  return new Promise((resolve, reject) => {
    const frames: LiveFrame[] = [];
    const timer = setTimeout(
      () => reject(new Error(`timed out: got ${frames.length}/${count} frames`)),
      timeoutMs,
    );
    ws.addEventListener("message", (event) => {
      const frame = parseFrameMessage(typeof event.data === "string" ? event.data : "");
      if (frame) frames.push(frame);
      if (frames.length >= count) {
        clearTimeout(timer);
        resolve(frames);
      }
    });
  });
}

test("END-TO-END: REAL engine NDJSON (live_stream_example output) flows through the collector to a client", async () => {
  // sample-engine-stream.ndjson is captured verbatim from `zig build live-stream`
  // — real CausalNdjsonTap output, not a hand-written fixture.
  const samplePath = new URL("./sample-engine-stream.ndjson", import.meta.url);
  const ndjson = await Bun.file(samplePath).text();
  const lineCount = ndjson.split("\n").filter((l) => l.trim().length > 0).length;
  expect(lineCount).toBe(11);

  const { origin } = serve();
  const client = await openClient(origin);
  try {
    const allFrames = collectFrames(client, lineCount);
    const response = await fetch(`http://${origin}/ingest`, { method: "POST", body: ndjson });
    expect(await response.json()).toEqual({ ingested: lineCount });

    const frames = await allFrames;
    expect(frames).toHaveLength(lineCount);
    // The real lifecycle, reconstructed on the client from the engine stream.
    expect(frames[0]!.event_kind).toBe("run_started");
    expect(frames.at(-1)!.event_kind).toBe("run_completed");
    expect(frames.map((f) => f.event_kind)).toContain("fiber_suspended");
    expect(frames.map((f) => f.event_kind)).toContain("fiber_resumed");
    // Sequence is monotonic and the engine's parent edges survive the hop.
    expect(frames.map((f) => f.sequence)).toEqual(Array.from({ length: lineCount }, (_, i) => i + 1));
    const scopeOpened = frames.find((f) => f.event_kind === "scope_opened");
    expect(scopeOpened!.parent_id).toBe(1); // child of run_started (id 1)
    // Every frame passes the frontend's own guard.
    for (const frame of frames) expect(parseFrameMessage(JSON.stringify(frame))).not.toBeNull();
  } finally {
    client.close();
  }
});

test("/health reports the connected client count", async () => {
  const { origin } = serve();
  const client = await openClient(origin);
  try {
    // Give the server a tick to register the open socket.
    await Bun.sleep(20);
    const health = await (await fetch(`http://${origin}/health`)).json();
    expect(health.ok).toBe(true);
    expect(health.clients).toBe(1);
  } finally {
    client.close();
  }
});
