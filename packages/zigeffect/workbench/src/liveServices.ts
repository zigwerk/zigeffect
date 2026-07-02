import { createSignal, onCleanup } from "solid-js";
import { LiveCausalBuffer, type LiveFrame, type LiveStreamMeta } from "./liveAttach";
import {
  parseHubMessage,
  type HubClientMessage,
  type ServiceStatus,
  type ServiceSummary,
} from "./hub/protocol";

// Frontend multi-service source: consumes the causal hub's multiplexed WebSocket
// and maintains ONE `LiveCausalBuffer` per service. Keeping buffers separate is
// deliberate — each engine numbers its own events/sequence from 1, so a shared
// buffer would collide across services; per-service buffers keep every service's
// trace independent and correct.

// ── Socket abstraction (needs `send`, unlike the single-stream WebSocketLike) ──
export type HubSocketLike = {
  addEventListener: (type: string, listener: (event: unknown) => void) => void;
  send: (data: string) => void;
  close: () => void;
};
export type HubSocketFactory = (url: string) => HubSocketLike;

export type HubSubscriber = {
  onRoster: (services: ServiceSummary[]) => void;
  onFrame: (serviceKey: string, frame: LiveFrame) => void;
  onServiceStatus: (serviceKey: string, status: ServiceStatus) => void;
  /** The hub evicted `dropped` frames it can never deliver (ring-buffer floor). */
  onGap?: (serviceKey: string, dropped: number) => void;
  onError?: (error: unknown) => void;
  onClose?: () => void;
};

export type HubConnection = {
  send: (message: HubClientMessage) => void;
  close: () => void;
};

export type HubSource = {
  connect: (subscriber: HubSubscriber) => HubConnection;
};

function defaultHubSocketFactory(url: string): HubSocketLike {
  return new WebSocket(url) as unknown as HubSocketLike;
}

function socketMessageData(event: unknown): string {
  const data = (event as { data?: unknown }).data;
  return typeof data === "string" ? data : "";
}

/** A hub-backed WebSocket source. Queues client messages sent before the socket opens. */
export function hubWebSocketSource(url: string, factory: HubSocketFactory = defaultHubSocketFactory): HubSource {
  return {
    connect(subscriber) {
      const socket = factory(url);
      let open = false;
      const pending: HubClientMessage[] = [];
      const send = (message: HubClientMessage): void => {
        if (open) {
          socket.send(JSON.stringify(message));
        } else {
          pending.push(message);
        }
      };
      socket.addEventListener("open", () => {
        open = true;
        for (const message of pending) {
          socket.send(JSON.stringify(message));
        }
        pending.length = 0;
      });
      socket.addEventListener("message", (event) => {
        const message = parseHubMessage(socketMessageData(event));
        if (!message) {
          return;
        }
        if (message.type === "roster") {
          subscriber.onRoster(message.services);
        } else if (message.type === "frame") {
          subscriber.onFrame(message.service_key, message.frame);
        } else if (message.type === "service-status") {
          subscriber.onServiceStatus(message.service_key, message.status);
        } else {
          subscriber.onGap?.(message.service_key, message.dropped);
        }
      });
      socket.addEventListener("error", (event) => subscriber.onError?.(event));
      socket.addEventListener("close", () => subscriber.onClose?.());
      return { send, close: () => socket.close() };
    },
  };
}

/** Extract a hub websocket URL from a `?hub=<url>` query string. */
export function hubUrlFromSearch(search: string): string | null {
  const url = new URLSearchParams(search).get("hub");
  return url && url.length > 0 ? url : null;
}

/** Derive the hub's HTTP /correlate endpoint from its `?hub=` WebSocket URL —
 * ws→http (wss→https), any `?token=` carried over (H8 auth uses the query
 * carrier for browser requests). Returns null for an unparseable hub URL. */
export function correlateEndpoint(hubUrl: string, boundaryId: string): string | null {
  try {
    const url = new URL(hubUrl);
    url.protocol = url.protocol === "wss:" ? "https:" : "http:";
    url.pathname = "/correlate";
    const token = url.searchParams.get("token");
    url.search = "";
    url.searchParams.set("boundary", boundaryId);
    if (token) {
      url.searchParams.set("token", token);
    }
    return url.toString();
  } catch {
    return null;
  }
}

// ── Reactive multi-service registry ──────────────────────────────────────────
export type HubServicesHandle = {
  /** Reactive roster (auto-discovered services with status + layers). */
  services: () => ServiceSummary[];
  connected: () => boolean;
  /** The service whose full trace is shown in the main workspace. */
  focused: () => string | null;
  focus: (serviceKey: string | null) => void;
  /** Services pinned into the comparison view (in addition to the focused one). */
  pinned: () => string[];
  pin: (serviceKey: string) => void;
  unpin: (serviceKey: string) => void;
  /** Reactive accumulated artifact JSON for a service (its own buffer). */
  artifactJson: (serviceKey: string) => string;
  frameCount: (serviceKey: string) => number;
  /** Frames the hub evicted before this client could receive them (reactive);
   * > 0 means the visible trace starts mid-run. */
  droppedFrames: (serviceKey: string) => number;
  /** Bumped whenever a subscribed frame carries a boundary_id — a cheap signal
   * for "the correlation index may have new occurrences, refetch". */
  boundaryActivity: () => number;
};

type ServiceBuffer = {
  buffer: LiveCausalBuffer;
  version: () => number;
  bump: () => void;
  /** Highest hub sequence ingested; a regression means the service restarted. */
  lastSequence: number;
  dropped: () => number;
  setDropped: (next: number) => void;
};

export function createHubServices(source: HubSource, meta: LiveStreamMeta = {}): HubServicesHandle {
  const [services, setServices] = createSignal<ServiceSummary[]>([]);
  const [connected, setConnected] = createSignal(true);
  const [focused, setFocused] = createSignal<string | null>(null);
  const [pinned, setPinned] = createSignal<string[]>([]);
  const [boundaryActivity, setBoundaryActivity] = createSignal(0);

  const buffers = new Map<string, ServiceBuffer>();
  const subscribed = new Set<string>();
  let connection: HubConnection | null = null;

  function ensureBuffer(serviceKey: string): ServiceBuffer {
    let entry = buffers.get(serviceKey);
    if (!entry) {
      const [version, setVersion] = createSignal(0);
      const [dropped, setDropped] = createSignal(0);
      const buffer = new LiveCausalBuffer(meta);
      entry = {
        buffer,
        version,
        bump: () => setVersion((value) => value + 1),
        lastSequence: 0,
        dropped,
        setDropped,
      };
      buffers.set(serviceKey, entry);
    }
    return entry;
  }

  connection = source.connect({
    onRoster: (roster) => setServices(roster),
    onFrame: (serviceKey, frame) => {
      const entry = ensureBuffer(serviceKey);
      // A sequence regression means the hub recreated this service (the process
      // restarted): the dead run's frames must not blend into the new run's
      // trace, so start a fresh buffer instead of ingesting a chimera.
      if (frame.sequence <= entry.lastSequence) {
        entry.buffer = new LiveCausalBuffer(meta);
        entry.setDropped(0);
      }
      entry.lastSequence = frame.sequence;
      entry.buffer.ingest(frame);
      entry.bump();
      if (typeof frame.boundary_id === "number") {
        setBoundaryActivity((value) => value + 1);
      }
    },
    onServiceStatus: (serviceKey, status) => {
      setServices((prev) => prev.map((service) => (service.service_key === serviceKey ? { ...service, status } : service)));
    },
    onGap: (serviceKey, dropped) => {
      const entry = ensureBuffer(serviceKey);
      // The hub evicted frames we never received; anything already buffered
      // precedes the hole, so keeping it would render a silently broken graph.
      if (entry.buffer.size > 0) {
        entry.buffer = new LiveCausalBuffer(meta);
      }
      entry.setDropped(entry.dropped() + dropped);
      entry.bump();
    },
    onError: () => setConnected(false),
    onClose: () => setConnected(false),
  });
  onCleanup(() => connection?.close());

  // Reconcile the hub subscriptions with the set of services we're actively
  // rendering (the focused one plus any pinned) — subscribe to the new, drop the gone.
  function reconcile(): void {
    const active = new Set<string>();
    const focus = focused();
    if (focus) {
      active.add(focus);
    }
    for (const key of pinned()) {
      active.add(key);
    }
    const toSubscribe = [...active].filter((key) => !subscribed.has(key));
    const toUnsubscribe = [...subscribed].filter((key) => !active.has(key));
    if (toSubscribe.length > 0) {
      connection?.send({ type: "subscribe", services: toSubscribe });
      for (const key of toSubscribe) {
        subscribed.add(key);
      }
    }
    if (toUnsubscribe.length > 0) {
      connection?.send({ type: "unsubscribe", services: toUnsubscribe });
      for (const key of toUnsubscribe) {
        subscribed.delete(key);
      }
    }
  }

  return {
    services,
    connected,
    focused,
    focus: (serviceKey) => {
      setFocused(serviceKey);
      reconcile();
    },
    pinned,
    pin: (serviceKey) => {
      setPinned((prev) => (prev.includes(serviceKey) ? prev : [...prev, serviceKey]));
      reconcile();
    },
    unpin: (serviceKey) => {
      setPinned((prev) => prev.filter((key) => key !== serviceKey));
      reconcile();
    },
    artifactJson: (serviceKey) => {
      const entry = ensureBuffer(serviceKey);
      entry.version(); // reactive dependency: recompute when this service gets a frame
      return entry.buffer.artifactJson();
    },
    frameCount: (serviceKey) => {
      const entry = ensureBuffer(serviceKey);
      entry.version();
      return entry.buffer.size;
    },
    droppedFrames: (serviceKey) => ensureBuffer(serviceKey).dropped(),
    boundaryActivity,
  };
}
