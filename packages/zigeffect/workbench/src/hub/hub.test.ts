import { expect, test } from "bun:test";
import type { ServerWebSocket } from "bun";
import { createHub, UNNAMED_SERVICE } from "./hub";
import { parseHubMessage, type HubMessage } from "./protocol";

/** A representative engine NDJSON CausalEvent line (formatCausalJsonLine shape). */
function line(extra: Record<string, unknown>): string {
  return JSON.stringify({
    schema: "zigeffect.causal.event.v1",
    schema_version: 1,
    event_taxonomy_version: 1,
    id: 1,
    kind: "run_started",
    status: "started",
    ...extra,
  });
}

type FakeClient = { readyState: number; sent: string[]; send: (message: string) => void };
function fakeClient(): FakeClient {
  const sent: string[] = [];
  return { readyState: 1, sent, send: (message) => sent.push(message) };
}
function asWs(client: FakeClient): ServerWebSocket<undefined> {
  return client as unknown as ServerWebSocket<undefined>;
}
function messagesOfType<T extends HubMessage["type"]>(client: FakeClient, type: T): Extract<HubMessage, { type: T }>[] {
  return client.sent
    .map((raw) => parseHubMessage(raw))
    .filter((message): message is HubMessage => message !== null)
    .filter((message): message is Extract<HubMessage, { type: T }> => message.type === type);
}

test("services are auto-discovered by service_key with independent per-service sequences", () => {
  const hub = createHub();
  hub.ingestLine(line({ id: 1, service_key: "payments-api" }));
  hub.ingestLine(line({ id: 2, service_key: "ledger" }));
  hub.ingestLine(line({ id: 3, service_key: "payments-api" }));

  expect(hub.serviceKeys().sort()).toEqual(["ledger", "payments-api"]);
  expect(hub.serviceFrames("payments-api").map((frame) => frame.sequence)).toEqual([1, 2]);
  expect(hub.serviceFrames("ledger").map((frame) => frame.sequence)).toEqual([1]);
});

test("per-service ring buffer drops the oldest past the cap; totals still count every frame", () => {
  const hub = createHub({ maxFramesPerService: 3 });
  for (let id = 1; id <= 5; id += 1) {
    hub.ingestLine(line({ id, service_key: "svc" }));
  }
  const frames = hub.serviceFrames("svc");
  expect(frames.map((frame) => frame.event_id)).toEqual([3, 4, 5]); // oldest two dropped

  const summary = hub.roster().find((service) => service.service_key === "svc");
  expect(summary?.frame_count).toBe(3);
  expect(summary?.total_frames).toBe(5);
});

test("layers accumulate per service from layer_id / layer_name", () => {
  const hub = createHub();
  hub.ingestLine(line({ id: 1, service_key: "svc", layer_id: 1, layer_name: "persistence" }));
  hub.ingestLine(line({ id: 2, service_key: "svc", layer_id: 2, layer_name: "integration" }));
  hub.ingestLine(line({ id: 3, service_key: "svc", layer_id: 1, layer_name: "persistence" }));

  const summary = hub.roster().find((service) => service.service_key === "svc");
  expect(summary?.layers).toEqual([
    { layer_id: 1, layer_name: "persistence" },
    { layer_id: 2, layer_name: "integration" },
  ]);
});

test("frames with no service_key fall into the unnamed bucket; a default tags an anonymous stream", () => {
  const hub = createHub();
  hub.ingestLine(line({ id: 1 }));
  expect(hub.serviceKeys()).toContain(UNNAMED_SERVICE);

  const tagged = createHub();
  tagged.ingestLine(line({ id: 1 }), "tagged-service");
  expect(tagged.serviceKeys()).toContain("tagged-service");
});

test("register announces a running service; deregister marks it stopped", () => {
  const hub = createHub();
  const summary = hub.register("payments-api");
  expect(summary?.status).toBe("running");
  expect(hub.serviceKeys()).toContain("payments-api");

  expect(hub.deregister("payments-api")).toBe(true);
  expect(hub.roster().find((service) => service.service_key === "payments-api")?.status).toBe("stopped");
  expect(hub.deregister("ghost")).toBe(false);
});

test("liveness sweep transitions running → idle → stopped on the injected clock", () => {
  let clock = 1000;
  const hub = createHub({ idleAfterMs: 100, stoppedAfterMs: 500, now: () => clock });
  hub.ingestLine(line({ id: 1, service_key: "svc" }));
  const statusOf = () => hub.roster().find((service) => service.service_key === "svc")?.status;
  expect(statusOf()).toBe("running");

  clock = 1050;
  hub.tick(clock);
  expect(statusOf()).toBe("running");

  clock = 1200; // 200ms idle > 100
  hub.tick(clock);
  expect(statusOf()).toBe("idle");

  clock = 1700; // 700ms idle > 500
  hub.tick(clock);
  expect(statusOf()).toBe("stopped");
});

test("the WS multiplex only sends a client frames for services it subscribed to", () => {
  const hub = createHub();
  const client = fakeClient();
  hub.websocket.open?.(asWs(client));

  // on connect the client receives the current roster
  expect(messagesOfType(client, "roster").length).toBe(1);

  hub.websocket.message(asWs(client), JSON.stringify({ type: "subscribe", services: ["payments-api"] }));
  hub.ingestLine(line({ id: 1, service_key: "payments-api", label: "a" }));
  hub.ingestLine(line({ id: 2, service_key: "ledger", label: "b" }));

  const frames = messagesOfType(client, "frame");
  expect(frames.length).toBe(1);
  expect(frames[0]?.service_key).toBe("payments-api");
});

test("subscribing backfills a client with the service's buffered history", () => {
  const hub = createHub();
  hub.ingestLine(line({ id: 1, service_key: "payments-api" }));
  hub.ingestLine(line({ id: 2, service_key: "payments-api" }));

  const client = fakeClient();
  hub.websocket.open?.(asWs(client));
  hub.websocket.message(asWs(client), JSON.stringify({ type: "subscribe", services: ["payments-api"] }));

  const frames = messagesOfType(client, "frame");
  expect(frames.map((message) => message.frame.event_id)).toEqual([1, 2]);
});

test("re-subscribe backfills only frames missed while away, never replays delivered ones", () => {
  const hub = createHub();
  const client = fakeClient();
  hub.websocket.open?.(asWs(client));
  hub.websocket.message(asWs(client), JSON.stringify({ type: "subscribe", services: ["svc"] }));
  hub.ingestLine(line({ id: 1, service_key: "svc" })); // delivered live (seq 1)
  hub.websocket.message(asWs(client), JSON.stringify({ type: "unsubscribe", services: ["svc"] }));
  hub.ingestLine(line({ id: 2, service_key: "svc" })); // missed while unsubscribed (seq 2)
  hub.websocket.message(asWs(client), JSON.stringify({ type: "subscribe", services: ["svc"] }));

  // 1 arrives once (live), 2 arrives once (backfill) — never [1, 1, 2].
  expect(messagesOfType(client, "frame").map((message) => message.frame.event_id)).toEqual([1, 2]);
});

test("long-stopped services are garbage-collected so the roster can't grow without bound", () => {
  let clock = 1000;
  const hub = createHub({ idleAfterMs: 100, stoppedAfterMs: 200, gcAfterMs: 500, now: () => clock });
  hub.ingestLine(line({ id: 1, service_key: "svc" }));
  expect(hub.serviceKeys()).toContain("svc");

  clock = 1300; // 300ms idle > 200 → stopped, but < 500 gc window
  hub.tick(clock);
  expect(hub.roster().find((service) => service.service_key === "svc")?.status).toBe("stopped");
  expect(hub.serviceKeys()).toContain("svc");

  clock = 1600; // 600ms idle > 500 gc window → removed entirely
  hub.tick(clock);
  expect(hub.serviceKeys()).not.toContain("svc");
});

test("unsubscribe stops further frames for a service", () => {
  const hub = createHub();
  const client = fakeClient();
  hub.websocket.open?.(asWs(client));
  hub.websocket.message(asWs(client), JSON.stringify({ type: "subscribe", services: ["svc"] }));
  hub.ingestLine(line({ id: 1, service_key: "svc" }));
  hub.websocket.message(asWs(client), JSON.stringify({ type: "unsubscribe", services: ["svc"] }));
  hub.ingestLine(line({ id: 2, service_key: "svc" }));

  expect(messagesOfType(client, "frame").length).toBe(1);
});

test("re-registering a quiet service refreshes its liveness instead of flapping back to stopped", () => {
  let clock = 1000;
  const hub = createHub({ idleAfterMs: 100, stoppedAfterMs: 500, gcAfterMs: 1000, now: () => clock });
  hub.ingestLine(line({ id: 1, service_key: "svc" }));

  clock = 1700; // 700ms quiet > 500 → stopped
  hub.tick(clock);
  expect(hub.roster().find((service) => service.service_key === "svc")?.status).toBe("stopped");

  // The process restarts and announces itself before its first frame.
  expect(hub.register("svc")?.status).toBe("running");
  clock = 1750;
  hub.tick(clock); // must NOT flip back to stopped off the stale lastFrameAt
  expect(hub.roster().find((service) => service.service_key === "svc")?.status).toBe("running");
  expect(hub.serviceKeys()).toContain("svc");
});

test("backfill announces a gap when the ring buffer evicted frames the client never received", () => {
  const hub = createHub({ maxFramesPerService: 3 });
  const client = fakeClient();
  hub.websocket.open?.(asWs(client));
  hub.websocket.message(asWs(client), JSON.stringify({ type: "subscribe", services: ["svc"] }));
  hub.ingestLine(line({ id: 1, service_key: "svc" })); // delivered live (watermark 1)
  hub.websocket.message(asWs(client), JSON.stringify({ type: "unsubscribe", services: ["svc"] }));
  for (let id = 2; id <= 6; id += 1) {
    hub.ingestLine(line({ id, service_key: "svc" })); // buffer retains seq 4..6
  }
  hub.websocket.message(asWs(client), JSON.stringify({ type: "subscribe", services: ["svc"] }));

  const gaps = messagesOfType(client, "gap");
  expect(gaps).toEqual([{ type: "gap", service_key: "svc", dropped: 2 }]); // seq 2 and 3 are gone
  expect(messagesOfType(client, "frame").map((message) => message.frame.event_id)).toEqual([1, 4, 5, 6]);
});

test("a fresh subscriber to a truncated service is told its trace starts mid-run", () => {
  const hub = createHub({ maxFramesPerService: 3 });
  for (let id = 1; id <= 5; id += 1) {
    hub.ingestLine(line({ id, service_key: "svc" }));
  }
  const client = fakeClient();
  hub.websocket.open?.(asWs(client));
  hub.websocket.message(asWs(client), JSON.stringify({ type: "subscribe", services: ["svc"] }));

  expect(messagesOfType(client, "gap")).toEqual([{ type: "gap", service_key: "svc", dropped: 2 }]);
  expect(messagesOfType(client, "frame").map((message) => message.frame.event_id)).toEqual([3, 4, 5]);
});

test("an empty layer_name does not blank a layer name a previous frame discovered", () => {
  const hub = createHub();
  hub.ingestLine(line({ id: 1, service_key: "svc", layer_id: 1, layer_name: "persistence" }));
  hub.ingestLine(line({ id: 2, service_key: "svc", layer_id: 1 })); // no layer_name on this event

  const summary = hub.roster().find((service) => service.service_key === "svc");
  expect(summary?.layers).toEqual([{ layer_id: 1, layer_name: "persistence" }]);
});

test("unparseable and oversized lines are counted, never silently dropped; blanks aren't counted", () => {
  const hub = createHub({ maxLineBytes: 192 }); // base engine line ≈150 bytes
  expect(hub.ingestLine("not json at all")).toBeNull();
  expect(hub.ingestLine("")).toBeNull();
  expect(hub.ingestLine("   ")).toBeNull();
  expect(hub.ingestLine(line({ id: 1, service_key: "svc", label: "x".repeat(256) }))).toBeNull();
  hub.ingestBody('garbage\n\n{"broken\n' + line({ id: 2, service_key: "svc" }));

  // not-json + oversized + (garbage, {"broken) — blanks excluded.
  expect(hub.rejectedLineCount()).toBe(4);
  expect(hub.serviceFrames("svc").length).toBe(1);
});

test("the service cap rejects new keys instead of growing the map without bound", () => {
  const hub = createHub({ maxServices: 2 });
  hub.ingestLine(line({ id: 1, service_key: "svc-a" }));
  hub.ingestLine(line({ id: 2, service_key: "svc-b" }));
  hub.ingestLine(line({ id: 3, service_key: "svc-c" })); // past the cap
  hub.ingestLine(line({ id: 4, service_key: "svc-a" })); // existing keys still flow

  expect(hub.serviceKeys().sort()).toEqual(["svc-a", "svc-b"]);
  expect(hub.rejectedLineCount()).toBe(1);
  expect(hub.serviceFrames("svc-a").length).toBe(2);
  expect(hub.register("svc-d")).toBeNull();
});

test("bulk ingest coalesces roster broadcasts to one per batch", () => {
  const hub = createHub();
  const client = fakeClient();
  hub.websocket.open?.(asWs(client)); // roster #1 (connect)

  const body = [line({ id: 1, service_key: "svc-a" }), line({ id: 2, service_key: "svc-b" }), line({ id: 3, service_key: "svc-c" })].join("\n");
  hub.ingestBody(body); // three new services → ONE roster broadcast, not three

  expect(messagesOfType(client, "roster").length).toBe(2);
});

test("a client subscribed through a service's GC + restart resumes receiving the new run", () => {
  let clock = 1000;
  const hub = createHub({ idleAfterMs: 100, stoppedAfterMs: 200, gcAfterMs: 500, now: () => clock });
  const client = fakeClient();
  hub.websocket.open?.(asWs(client));
  hub.websocket.message(asWs(client), JSON.stringify({ type: "subscribe", services: ["svc"] }));
  hub.ingestLine(line({ id: 7, service_key: "svc" })); // delivered (seq 1)

  clock = 1600; // past gcAfterMs → service deleted
  hub.tick(clock);
  expect(hub.serviceKeys()).not.toContain("svc");

  hub.ingestLine(line({ id: 1, service_key: "svc" })); // restart: sequence begins at 1 again
  // The still-subscribed client must receive the new run (stale watermark reset).
  expect(messagesOfType(client, "frame").map((message) => message.frame.event_id)).toEqual([7, 1]);
});

test("POST /ingest rejects bodies past the byte cap with 413", async () => {
  const hub = createHub({ maxIngestBytes: 64 });
  const server = {} as unknown as Parameters<typeof hub.fetch>[1];

  const tooBig = await hub.fetch(new Request("http://hub/ingest", { method: "POST", body: "x".repeat(256) }), server);
  expect((tooBig as Response).status).toBe(413);

  const ok = await hub.fetch(new Request("http://hub/ingest", { method: "POST", body: line({ id: 1 }).slice(0, 60) }), server);
  expect((ok as Response).status).toBe(200);
});

test("parseHubMessage rejects malformed roster entries and frames instead of casting them", () => {
  // Roster entry missing layers/counters — a drifted or wrong hub must not crash the UI.
  expect(parseHubMessage(JSON.stringify({ type: "roster", services: [{ service_key: "a" }] }))).toBeNull();
  // Frame without sequence/event_id.
  expect(parseHubMessage(JSON.stringify({ type: "frame", service_key: "a", frame: { hello: 1 } }))).toBeNull();
  // Valid gap parses.
  expect(parseHubMessage(JSON.stringify({ type: "gap", service_key: "a", dropped: 3 }))).toEqual({
    type: "gap",
    service_key: "a",
    dropped: 3,
  });
  // Non-positive gap is meaningless.
  expect(parseHubMessage(JSON.stringify({ type: "gap", service_key: "a", dropped: 0 }))).toBeNull();
});
