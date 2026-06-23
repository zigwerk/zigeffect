import { afterEach, expect, test } from "bun:test";
import type { Server } from "bun";
import { createCollector } from "./collector";
import { parseFrameMessage, type LiveFrame } from "../liveAttach";

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
