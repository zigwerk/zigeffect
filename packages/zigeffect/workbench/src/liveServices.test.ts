import { expect, test } from "bun:test";
import { createRoot } from "solid-js";
import { correlateEndpoint, createHubServices, hubUrlFromSearch, type HubSource, type HubSubscriber } from "./liveServices";
import { parseCorrelation, type HubClientMessage, type ServiceSummary } from "./hub/protocol";
import type { LiveFrame } from "./liveAttach";

function frame(id: number, serviceKey: string): LiveFrame {
  return { sequence: id, event_id: id, event_kind: "run_started", status: "started", service_key: serviceKey, layer_id: null, layer_name: "" };
}

function summary(serviceKey: string): ServiceSummary {
  return { service_key: serviceKey, status: "running", frame_count: 0, total_frames: 0, layers: [], last_frame_at: 0 };
}

function fakeSource() {
  let subscriber: HubSubscriber = { onRoster: () => {}, onFrame: () => {}, onServiceStatus: () => {} };
  const sent: HubClientMessage[] = [];
  const source: HubSource = {
    connect(next) {
      subscriber = next;
      return { send: (message) => sent.push(message), close: () => {} };
    },
  };
  return {
    source,
    sent,
    roster: (services: ServiceSummary[]) => subscriber.onRoster(services),
    frame: (serviceKey: string, live: LiveFrame) => subscriber.onFrame(serviceKey, live),
    status: (serviceKey: string, status: ServiceSummary["status"]) => subscriber.onServiceStatus(serviceKey, status),
    gap: (serviceKey: string, dropped: number) => subscriber.onGap?.(serviceKey, dropped),
  };
}

test("roster from the hub is reactive", () => {
  createRoot((dispose) => {
    const fake = fakeSource();
    const hub = createHubServices(fake.source);
    expect(hub.services()).toEqual([]);
    fake.roster([summary("payments-api"), summary("ledger")]);
    expect(hub.services().map((service) => service.service_key)).toEqual(["payments-api", "ledger"]);
    dispose();
  });
});

test("focusing a service subscribes to it and unsubscribes the previous focus", () => {
  createRoot((dispose) => {
    const fake = fakeSource();
    const hub = createHubServices(fake.source);
    hub.focus("payments-api");
    expect(hub.focused()).toBe("payments-api");
    expect(fake.sent).toContainEqual({ type: "subscribe", services: ["payments-api"] });

    hub.focus("ledger");
    expect(fake.sent).toContainEqual({ type: "unsubscribe", services: ["payments-api"] });
    expect(fake.sent).toContainEqual({ type: "subscribe", services: ["ledger"] });
    dispose();
  });
});

test("each service accumulates its own artifact (per-service buffers, no cross-talk)", () => {
  createRoot((dispose) => {
    const fake = fakeSource();
    const hub = createHubServices(fake.source);
    fake.frame("payments-api", frame(1, "payments-api"));
    fake.frame("payments-api", frame(2, "payments-api"));
    fake.frame("ledger", frame(1, "ledger"));

    expect(JSON.parse(hub.artifactJson("payments-api")).events.length).toBe(2);
    expect(JSON.parse(hub.artifactJson("ledger")).events.length).toBe(1);
    expect(hub.frameCount("payments-api")).toBe(2);
    dispose();
  });
});

test("pinning adds a service to the active subscriptions; unpinning removes it", () => {
  createRoot((dispose) => {
    const fake = fakeSource();
    const hub = createHubServices(fake.source);
    hub.focus("payments-api");
    hub.pin("ledger");
    expect(hub.pinned()).toEqual(["ledger"]);
    expect(fake.sent).toContainEqual({ type: "subscribe", services: ["ledger"] });

    hub.unpin("ledger");
    expect(fake.sent).toContainEqual({ type: "unsubscribe", services: ["ledger"] });
    dispose();
  });
});

test("a service-status message patches the matching roster entry in place", () => {
  createRoot((dispose) => {
    const fake = fakeSource();
    const hub = createHubServices(fake.source);
    fake.roster([summary("payments-api")]);
    fake.status("payments-api", "stopped");
    expect(hub.services().find((service) => service.service_key === "payments-api")?.status).toBe("stopped");
    dispose();
  });
});

test("hubUrlFromSearch extracts the ?hub= url", () => {
  expect(hubUrlFromSearch("?hub=ws://127.0.0.1:4600/live")).toBe("ws://127.0.0.1:4600/live");
  expect(hubUrlFromSearch("?live=ws://x/live")).toBeNull();
  expect(hubUrlFromSearch("")).toBeNull();
});

test("correlateEndpoint derives the hub's HTTP endpoint from the ?hub= WS url, keeping the token", () => {
  expect(correlateEndpoint("ws://127.0.0.1:4600/live", "7")).toBe("http://127.0.0.1:4600/correlate?boundary=7");
  expect(correlateEndpoint("wss://hub.local:4600/live", "7")).toBe("https://hub.local:4600/correlate?boundary=7");
  expect(correlateEndpoint("ws://127.0.0.1:4600/live?token=s3cret", "7")).toBe(
    "http://127.0.0.1:4600/correlate?boundary=7&token=s3cret",
  );
  expect(correlateEndpoint("not a url", "7")).toBeNull();
});

test("parseCorrelation keeps well-formed occurrences and drops junk", () => {
  const body = {
    boundary_id: 7,
    occurrences: [
      { service_key: "ledger", event_id: 2, event_kind: "scope_opened", label: "post entry" },
      { service_key: "bad" }, // missing fields
      "junk",
    ],
  };
  expect(parseCorrelation(body)).toEqual([
    { service_key: "ledger", event_id: 2, event_kind: "scope_opened", label: "post entry" },
  ]);
  expect(parseCorrelation(null)).toEqual([]);
  expect(parseCorrelation({ occurrences: "nope" })).toEqual([]);
});

test("a sequence regression (service restart) resets the buffer instead of blending two runs", () => {
  createRoot((dispose) => {
    const fake = fakeSource();
    const hub = createHubServices(fake.source);
    fake.frame("svc", frame(1, "svc"));
    fake.frame("svc", frame(2, "svc"));
    fake.frame("svc", frame(3, "svc"));
    expect(JSON.parse(hub.artifactJson("svc")).events.length).toBe(3);

    // The hub GC'd + recreated the service: sequence starts over at 1. The dead
    // run's events 2..3 must NOT survive alongside the new run's event 1.
    fake.frame("svc", frame(1, "svc"));
    expect(JSON.parse(hub.artifactJson("svc")).events.length).toBe(1);
    dispose();
  });
});

test("a hub gap clears the pre-hole buffer and reports the dropped count reactively", () => {
  createRoot((dispose) => {
    const fake = fakeSource();
    const hub = createHubServices(fake.source);
    fake.frame("svc", frame(1, "svc"));
    fake.frame("svc", frame(2, "svc"));
    expect(hub.droppedFrames("svc")).toBe(0);

    // Frames 3..7 were evicted by the hub's ring buffer before delivery: what's
    // buffered predates the hole, so it must not merge with what follows.
    fake.gap("svc", 5);
    expect(JSON.parse(hub.artifactJson("svc")).events.length).toBe(0);
    expect(hub.droppedFrames("svc")).toBe(5);

    fake.frame("svc", frame(8, "svc"));
    expect(JSON.parse(hub.artifactJson("svc")).events.length).toBe(1);
    dispose();
  });
});
