// Causal hub — multi-service fan-in for the workbench. Many zig services stream
// their causal NDJSON here; the hub groups every event by its engine `service_key`
// (auto-discovery — no registration required), keeps a bounded per-service ring
// buffer, tracks liveness, and multiplexes everything over ONE WebSocket where a
// browser subscribes to whichever services it wants.
//
// This generalizes `collector.ts` (single anonymous stream) — it is the same
// NDJSON → LiveFrame mapping + broadcast, now keyed per service.
//
// RUNTIME BOUNDARY: LOCAL tooling (Bun-native `Bun.serve`), never a Worker handler.
// It centralizes retention so a long-lived service can't grow memory without bound,
// regardless of whether that service used a bounded CausalStore.

import type { Server, ServerWebSocket, WebSocketHandler } from "bun";
import { createHash, timingSafeEqual } from "node:crypto";
import { readFileSync, renameSync, writeFileSync } from "node:fs";
import { causalLineToFrame, type LiveFrame } from "../collector/frame";
import {
  parseHubClientMessage,
  type BoundaryOccurrence,
  type HubMessage,
  type ServiceStatus,
  type ServiceSummary,
} from "./protocol";

export type { BoundaryOccurrence };

/** Frames with an empty engine service_key are grouped under this bucket. */
export const UNNAMED_SERVICE = "(unnamed)";

export type HubOptions = {
  /** Max frames retained per service (oldest dropped past this). */
  maxFramesPerService?: number;
  /** Max distinct services; lines for new keys past this are rejected. */
  maxServices?: number;
  /** Max distinct boundary ids indexed for cross-service correlation. */
  maxBoundaries?: number;
  /** Max bytes accepted by one POST /ingest body (413 past this). */
  maxIngestBytes?: number;
  /** Max bytes for a single NDJSON line; longer lines are rejected. */
  maxLineBytes?: number;
  /** No frame for this long → status "idle". */
  idleAfterMs?: number;
  /** No frame for this long → status "stopped". */
  stoppedAfterMs?: number;
  /** Stopped for this long → the service is garbage-collected entirely. */
  gcAfterMs?: number;
  /** When set, every endpoint except /health requires this token —
   * HTTP via `authorization: Bearer <token>`, WS/browser via `?token=`. */
  token?: string;
  /** Clock, injectable for deterministic tests. */
  now?: () => number;
};

/** Distinct layer_ids retained per service (an adversarial stream can't grow this without bound). */
const MAX_LAYERS_PER_SERVICE = 256;
/** Distinct service keys one client may hold subscription state for. */
const MAX_SUBSCRIPTIONS_PER_CLIENT = 1024;
/** Occurrences retained per boundary id (a buggy emitter reusing one id can't grow it without bound). */
const MAX_OCCURRENCES_PER_BOUNDARY = 32;
/** The workbench runs on a different port; local tooling, so a blanket allow is fine. */
const CORS_HEADERS = { "access-control-allow-origin": "*" } as const;

type ServiceState = {
  serviceKey: string;
  status: ServiceStatus;
  frames: LiveFrame[];
  sequence: number;
  totalFrames: number;
  lastFrameAt: number;
  /** layer_id → layer_name, accumulated as frames arrive. */
  layers: Map<number, string>;
};

type ClientSub = { subscribed: boolean; watermark: number };

export type Hub = {
  fetch: (request: Request, server: Server<undefined>) => Response | Promise<Response> | undefined;
  websocket: WebSocketHandler<undefined>;
  /** Route one NDJSON line to its service (by service_key); returns the tagged frame. */
  ingestLine: (line: string, defaultServiceKey?: string) => { serviceKey: string; frame: LiveFrame } | null;
  /** Ingest an NDJSON body; returns frames routed. */
  ingestBody: (body: string, defaultServiceKey?: string) => number;
  /** Announce a service before its first frame (optional liveness signal).
   * Returns null when the service cap is reached. */
  register: (serviceKey: string) => ServiceSummary | null;
  /** Mark a service stopped (e.g. on shutdown). */
  deregister: (serviceKey: string) => boolean;
  /** Current roster snapshot. */
  roster: () => ServiceSummary[];
  /** Retained frames for one service (test/introspection). */
  serviceFrames: (serviceKey: string) => LiveFrame[];
  serviceKeys: () => string[];
  /** Advance liveness at the given time (called by a timer in the live server). */
  tick: (nowMs: number) => void;
  clientCount: () => number;
  /** Lines dropped so far (unparseable, oversized, or past the service cap). */
  rejectedLineCount: () => number;
  /** Everywhere a boundary id was observed, across all services. */
  correlate: (boundaryId: number) => BoundaryOccurrence[];
  /** Monotonic counter bumped on every state mutation — lets the persistence
   * loop skip writes when nothing changed. */
  stateVersion: () => number;
  /** Serializable state for HUB_PERSIST (frames, sequences, layers, boundaries). */
  snapshotState: () => HubSnapshot;
  /** Restore a snapshot taken by snapshotState. Services come back "stopped"
   * with a fresh liveness clock; sequences CONTINUE from their saved values
   * (a regression would make clients treat the resume as a service restart).
   * Returns false (and restores nothing) on a version mismatch. */
  restoreState: (snapshot: unknown) => boolean;
};

export type HubSnapshot = {
  version: 1;
  services: Array<{
    service_key: string;
    frames: LiveFrame[];
    sequence: number;
    total_frames: number;
    layers: Array<[number, string]>;
  }>;
  boundaries: Array<[number, Array<BoundaryOccurrence & { sequence?: number }>]>;
};

export function createHub(options: HubOptions = {}): Hub {
  const maxFrames = Math.max(1, options.maxFramesPerService ?? 5000);
  const maxServices = Math.max(1, options.maxServices ?? 512);
  const maxBoundaries = Math.max(1, options.maxBoundaries ?? 4096);
  const maxIngestBytes = Math.max(1, options.maxIngestBytes ?? 32 * 1024 * 1024);
  const maxLineBytes = Math.max(1, options.maxLineBytes ?? 1024 * 1024);
  const idleAfterMs = options.idleAfterMs ?? 15_000;
  const stoppedAfterMs = options.stoppedAfterMs ?? 60_000;
  const gcAfterMs = options.gcAfterMs ?? stoppedAfterMs * 2;
  const token = options.token;
  // An empty token is a misconfiguration trap, not a secret: requests without
  // credentials still 401 (auth LOOKS enabled) while `?token=` with an empty
  // value passes. Refuse loudly instead.
  if (token !== undefined && token.length === 0) {
    throw new Error("hub token is set but empty — unset it for open access or provide a real secret");
  }
  const now = options.now ?? (() => Date.now());
  let rejectedLines = 0;
  let stateVersion = 0;

  // Cross-service correlation: boundary_id → everywhere it was observed. Each
  // stored occurrence remembers its frame's hub sequence so correlate() can
  // drop entries whose frame has left the service's ring buffer — a jump link
  // must never point at an event the hub can no longer deliver.
  type StoredBoundaryOccurrence = BoundaryOccurrence & { sequence: number };
  const boundaries = new Map<number, StoredBoundaryOccurrence[]>();

  function indexBoundary(serviceKey: string, frame: LiveFrame): void {
    const boundaryId = frame.boundary_id;
    if (typeof boundaryId !== "number") {
      return;
    }
    let occurrences = boundaries.get(boundaryId);
    if (!occurrences) {
      if (boundaries.size >= maxBoundaries) {
        return; // bounded like everything else in the hub
      }
      occurrences = [];
      boundaries.set(boundaryId, occurrences);
    }
    // A restarted service re-records the same event ids — replace, don't stack.
    const existing = occurrences.findIndex(
      (occurrence) => occurrence.service_key === serviceKey && occurrence.event_id === frame.event_id,
    );
    const occurrence: StoredBoundaryOccurrence = {
      service_key: serviceKey,
      event_id: frame.event_id,
      event_kind: frame.event_kind,
      label: frame.label ?? "",
      sequence: frame.sequence,
    };
    if (existing >= 0) {
      occurrences[existing] = occurrence;
    } else if (occurrences.length < MAX_OCCURRENCES_PER_BOUNDARY) {
      occurrences.push(occurrence);
    }
  }

  // Token gate (H8). Hashing both sides normalizes lengths for timingSafeEqual;
  // /health stays open so probes work without credentials.
  const digest = (value: string) => createHash("sha256").update(value).digest();
  function authorized(request: Request, url: URL): boolean {
    if (token === undefined) {
      return true;
    }
    const header = request.headers.get("authorization");
    const candidate = header?.startsWith("Bearer ") ? header.slice("Bearer ".length) : url.searchParams.get("token");
    return candidate !== null && candidate !== undefined && timingSafeEqual(digest(candidate), digest(token));
  }

  const services = new Map<string, ServiceState>();
  // Per client: serviceKey → { subscribed, watermark }. The watermark (last
  // delivered per-service sequence) persists across unsubscribe so a re-subscribe
  // backfills only the frames missed while away, never replaying old ones.
  const clients = new Map<ServerWebSocket<undefined>, Map<string, ClientSub>>();
  const WS_OPEN = 1;

  function summarize(service: ServiceState): ServiceSummary {
    return {
      service_key: service.serviceKey,
      status: service.status,
      frame_count: service.frames.length,
      total_frames: service.totalFrames,
      layers: [...service.layers.entries()].map(([layer_id, layer_name]) => ({ layer_id, layer_name })),
      last_frame_at: service.lastFrameAt,
    };
  }

  function roster(): ServiceSummary[] {
    return [...services.values()]
      .map(summarize)
      .sort((left, right) => left.service_key.localeCompare(right.service_key));
  }

  function send(client: ServerWebSocket<undefined>, message: HubMessage): void {
    if (client.readyState !== WS_OPEN) {
      return;
    }
    client.send(JSON.stringify(message));
  }

  // Bulk ingest can create many services in one body; coalesce to ONE roster
  // broadcast per batch instead of O(clients × new services) messages.
  let rosterSuppressed = false;
  let rosterDirty = false;

  function broadcastRoster(): void {
    if (rosterSuppressed) {
      rosterDirty = true;
      return;
    }
    const message: HubMessage = { type: "roster", services: roster() };
    for (const client of clients.keys()) {
      send(client, message);
    }
  }

  function broadcastStatus(serviceKey: string, status: ServiceStatus): void {
    const message: HubMessage = { type: "service-status", service_key: serviceKey, status };
    for (const client of clients.keys()) {
      send(client, message);
    }
  }

  function broadcastFrame(serviceKey: string, frame: LiveFrame): void {
    const message: HubMessage = { type: "frame", service_key: serviceKey, frame };
    for (const [client, subscriptions] of clients) {
      const entry = subscriptions.get(serviceKey);
      if (entry?.subscribed) {
        send(client, message);
        entry.watermark = frame.sequence;
      }
    }
  }

  function ensureService(serviceKey: string): { service: ServiceState; created: boolean } | null {
    const existing = services.get(serviceKey);
    if (existing) {
      return { service: existing, created: false };
    }
    // Cap distinct services: a stream inventing a unique service_key per line
    // must not grow the map faster than GC can drain it.
    if (services.size >= maxServices) {
      return null;
    }
    const service: ServiceState = {
      serviceKey,
      status: "running",
      frames: [],
      sequence: 0,
      totalFrames: 0,
      lastFrameAt: 0,
      layers: new Map(),
    };
    services.set(serviceKey, service);
    // A service key can be recreated after GC (a restarted service reuses its key
    // and resets its sequence to 1). Reset any lingering client watermarks so the
    // fresh, low-numbered frames are not suppressed by a stale high-water mark.
    for (const subscriptions of clients.values()) {
      const entry = subscriptions.get(serviceKey);
      if (entry) {
        entry.watermark = 0;
      }
    }
    return { service, created: true };
  }

  function ingestLine(line: string, defaultServiceKey?: string): { serviceKey: string; frame: LiveFrame } | null {
    // Blank lines are stream padding, not data — skip without counting.
    if (line.trim().length === 0) {
      return null;
    }
    if (line.length > maxLineBytes) {
      rejectedLines += 1;
      return null;
    }
    const frame = causalLineToFrame(line, 0);
    if (!frame) {
      rejectedLines += 1;
      return null;
    }
    const rawKey = frame.service_key && frame.service_key.length > 0 ? frame.service_key : (defaultServiceKey ?? "");
    const serviceKey = rawKey.length > 0 ? rawKey : UNNAMED_SERVICE;
    frame.service_key = serviceKey;

    const ensured = ensureService(serviceKey);
    if (!ensured) {
      rejectedLines += 1; // new service past the cap
      return null;
    }
    const { service, created } = ensured;
    frame.sequence = service.sequence + 1;
    service.sequence += 1;

    service.frames.push(frame);
    service.totalFrames += 1;
    if (service.frames.length > maxFrames) {
      service.frames.shift(); // drop oldest — centralized retention ceiling
    }
    // Record the layer; an empty layer_name must not blank a name a previous
    // frame already discovered (layer tags are optional per event).
    if (typeof frame.layer_id === "number" && (service.layers.has(frame.layer_id) || service.layers.size < MAX_LAYERS_PER_SERVICE)) {
      const layerName = frame.layer_name ?? "";
      if (layerName !== "" || !service.layers.has(frame.layer_id)) {
        service.layers.set(frame.layer_id, layerName);
      }
    }
    service.lastFrameAt = now();
    indexBoundary(serviceKey, frame);
    stateVersion += 1;

    const wasRunning = service.status === "running";
    service.status = "running";

    broadcastFrame(serviceKey, frame);
    if (created) {
      broadcastRoster();
    } else if (!wasRunning) {
      broadcastStatus(serviceKey, "running");
    }
    return { serviceKey, frame };
  }

  function ingestBody(body: string, defaultServiceKey?: string): number {
    let count = 0;
    rosterSuppressed = true;
    try {
      for (const line of body.split("\n")) {
        if (ingestLine(line, defaultServiceKey)) {
          count += 1;
        }
      }
    } finally {
      rosterSuppressed = false;
      if (rosterDirty) {
        rosterDirty = false;
        broadcastRoster();
      }
    }
    return count;
  }

  function register(serviceKey: string): ServiceSummary | null {
    const key = serviceKey.length > 0 ? serviceKey : UNNAMED_SERVICE;
    const ensured = ensureService(key);
    if (!ensured) {
      return null;
    }
    const { service, created } = ensured;
    // Registering IS a liveness signal — refresh unconditionally (like a frame
    // does), else a re-registered quiet service keeps its stale lastFrameAt and
    // the next tick flips it straight back to stopped / garbage-collects it.
    service.lastFrameAt = now();
    stateVersion += 1;
    const wasRunning = service.status === "running";
    service.status = "running";
    if (created) {
      broadcastRoster();
    } else if (!wasRunning) {
      broadcastStatus(key, "running");
    }
    return summarize(service);
  }

  function deregister(serviceKey: string): boolean {
    const service = services.get(serviceKey);
    if (!service) {
      return false;
    }
    if (service.status !== "stopped") {
      service.status = "stopped";
      stateVersion += 1;
      broadcastStatus(serviceKey, "stopped");
      broadcastRoster();
    }
    return true;
  }

  function tick(nowMs: number): void {
    let changed = false;
    const expired: string[] = [];
    for (const service of services.values()) {
      if (service.lastFrameAt === 0) {
        continue;
      }
      const idleFor = nowMs - service.lastFrameAt;
      if (service.status !== "stopped") {
        const next: ServiceStatus = idleFor > stoppedAfterMs ? "stopped" : idleFor > idleAfterMs ? "idle" : "running";
        if (next !== service.status) {
          service.status = next;
          broadcastStatus(service.serviceKey, next);
          changed = true;
        }
      }
      // Garbage-collect long-stopped services so `services` (and every roster it
      // broadcasts) can't grow without bound under a churn of short-lived keys.
      if (service.status === "stopped" && idleFor > gcAfterMs) {
        expired.push(service.serviceKey);
      }
    }
    for (const serviceKey of expired) {
      services.delete(serviceKey);
      // Drop clients' watermark-only leftovers for the dead key so service-key
      // churn can't grow their maps without bound. ACTIVE subscriptions are kept
      // (they're capped separately): if the key is recreated, ensureService
      // resets the watermark and the stream resumes for those clients.
      for (const subscriptions of clients.values()) {
        const entry = subscriptions.get(serviceKey);
        if (entry && !entry.subscribed) {
          subscriptions.delete(serviceKey);
        }
      }
      // A GC'd service's boundary occurrences go with it (its frames are gone).
      for (const [boundaryId, occurrences] of boundaries) {
        const kept = occurrences.filter((occurrence) => occurrence.service_key !== serviceKey);
        if (kept.length === 0) {
          boundaries.delete(boundaryId);
        } else if (kept.length !== occurrences.length) {
          boundaries.set(boundaryId, kept);
        }
      }
      changed = true;
    }
    if (expired.length > 0) {
      stateVersion += 1;
    }
    if (changed) {
      broadcastRoster();
    }
  }

  function backfill(client: ServerWebSocket<undefined>, serviceKey: string, entry: ClientSub): void {
    const service = services.get(serviceKey);
    if (!service) {
      return;
    }
    // Frames between the watermark and the ring-buffer floor were evicted and
    // can never be delivered — say so, instead of letting the client render a
    // trace with a silent hole (dangling parent_ids).
    const floor = service.frames.length > 0 ? (service.frames[0]?.sequence ?? 1) : service.sequence + 1;
    const dropped = floor - 1 - entry.watermark;
    if (dropped > 0) {
      send(client, { type: "gap", service_key: serviceKey, dropped });
    }
    for (const frame of service.frames) {
      if (frame.sequence > entry.watermark) {
        send(client, { type: "frame", service_key: serviceKey, frame });
        entry.watermark = frame.sequence;
      }
    }
  }

  const websocket: WebSocketHandler<undefined> = {
    open(ws) {
      clients.set(ws, new Map());
      send(ws, { type: "roster", services: roster() });
    },
    close(ws) {
      clients.delete(ws);
    },
    message(ws, raw) {
      const text = typeof raw === "string" ? raw : raw.toString();
      const message = parseHubClientMessage(text);
      if (!message) {
        return;
      }
      const subscriptions = clients.get(ws);
      if (!subscriptions) {
        return;
      }
      if (message.type === "subscribe") {
        for (const serviceKey of message.services) {
          let entry = subscriptions.get(serviceKey);
          if (!entry) {
            if (subscriptions.size >= MAX_SUBSCRIPTIONS_PER_CLIENT) {
              continue; // one client can't hold unbounded subscription state
            }
            entry = { subscribed: false, watermark: 0 };
            subscriptions.set(serviceKey, entry);
          }
          if (!entry.subscribed) {
            entry.subscribed = true;
            backfill(ws, serviceKey, entry); // only frames newer than the watermark
          }
        }
      } else {
        for (const serviceKey of message.services) {
          const entry = subscriptions.get(serviceKey);
          if (entry) {
            entry.subscribed = false; // keep the watermark so we don't replay on re-subscribe
          }
        }
      }
    },
  };

  function json(data: unknown, status = 200): Response {
    return new Response(JSON.stringify(data), {
      status,
      headers: { "content-type": "application/json", ...CORS_HEADERS },
    });
  }

  function plain(message: string, status: number): Response {
    return new Response(message, { status, headers: CORS_HEADERS });
  }

  function fetch(request: Request, server: Server<undefined>): Response | Promise<Response> | undefined {
    const url = new URL(request.url);

    // /health stays open (probes carry no credentials); everything else is
    // token-gated when a token is configured.
    if (url.pathname === "/health") {
      return json({
        ok: true,
        services: services.size,
        clients: clients.size,
        rejected_lines: rejectedLines,
        boundaries: boundaries.size,
      });
    }
    if (!authorized(request, url)) {
      return plain("unauthorized", 401);
    }

    if (url.pathname === "/live") {
      if (server.upgrade(request)) {
        return undefined;
      }
      return plain("expected a websocket upgrade", 426);
    }

    if (url.pathname === "/ingest" && request.method === "POST") {
      const declaredBytes = Number(request.headers.get("content-length") ?? 0);
      if (declaredBytes > maxIngestBytes) {
        return plain("ingest body too large", 413);
      }
      const defaultServiceKey = url.searchParams.get("service") ?? undefined;
      return request.text().then((body) => {
        if (body.length > maxIngestBytes) {
          return plain("ingest body too large", 413);
        }
        return json({ ingested: ingestBody(body, defaultServiceKey) });
      });
    }

    if (url.pathname === "/register" && request.method === "POST") {
      return request.json().then(
        (body) => {
          const serviceKey = typeof body === "object" && body !== null ? (body as Record<string, unknown>).service_key : undefined;
          if (typeof serviceKey !== "string" || serviceKey.length === 0) {
            return plain("service_key required", 400);
          }
          const summary = register(serviceKey);
          if (!summary) {
            return plain("service cap reached", 503);
          }
          return json(summary);
        },
        () => plain("invalid body", 400),
      );
    }

    if (url.pathname === "/deregister" && request.method === "POST") {
      return request.json().then(
        (body) => {
          const serviceKey = typeof body === "object" && body !== null ? (body as Record<string, unknown>).service_key : undefined;
          if (typeof serviceKey !== "string" || serviceKey.length === 0) {
            return plain("service_key required", 400);
          }
          return json({ stopped: deregister(serviceKey) });
        },
        () => plain("invalid body", 400),
      );
    }

    if (url.pathname === "/services" && request.method === "GET") {
      return json({ services: roster() });
    }

    if (url.pathname === "/correlate" && request.method === "GET") {
      // Number(null) and Number("") both coerce to 0 — a missing/empty param
      // must be a 400, not a successful query for boundary 0.
      const rawBoundary = url.searchParams.get("boundary");
      const boundaryId = rawBoundary === null || rawBoundary.trim() === "" ? Number.NaN : Number(rawBoundary);
      if (!Number.isSafeInteger(boundaryId) || boundaryId < 0) {
        return plain("boundary query param required", 400);
      }
      return json({ boundary_id: boundaryId, occurrences: correlate(boundaryId) });
    }

    return plain("not found", 404);
  }

  function correlate(boundaryId: number): BoundaryOccurrence[] {
    const occurrences = boundaries.get(boundaryId);
    if (!occurrences) {
      return [];
    }
    // Lazily prune occurrences whose frame was ring-evicted (or whose service
    // is gone) — GC pruning in tick() only covers whole-service death.
    const live = occurrences.filter((occurrence) => {
      const service = services.get(occurrence.service_key);
      if (!service) {
        return false;
      }
      const floor = service.frames[0]?.sequence ?? service.sequence + 1;
      return occurrence.sequence >= floor;
    });
    if (live.length === 0) {
      boundaries.delete(boundaryId);
    } else if (live.length !== occurrences.length) {
      boundaries.set(boundaryId, live);
    }
    return live.map(({ sequence: _sequence, ...occurrence }) => occurrence);
  }

  function snapshotState(): HubSnapshot {
    return {
      version: 1,
      services: [...services.values()].map((service) => ({
        service_key: service.serviceKey,
        frames: service.frames,
        sequence: service.sequence,
        total_frames: service.totalFrames,
        layers: [...service.layers.entries()],
      })),
      boundaries: [...boundaries.entries()],
    };
  }

  function restoreState(snapshot: unknown): boolean {
    if (typeof snapshot !== "object" || snapshot === null) {
      return false;
    }
    const record = snapshot as Record<string, unknown>;
    if (record.version !== 1 || !Array.isArray(record.services) || !Array.isArray(record.boundaries)) {
      return false;
    }
    // Build into locals first — a malformed snapshot (the file is ours, but
    // truncated writes happen) must not leave the hub half-restored.
    const restoredServices = new Map<string, ServiceState>();
    const restoredBoundaries = new Map<number, StoredBoundaryOccurrence[]>();
    try {
      for (const entry of record.services as HubSnapshot["services"]) {
        if (typeof entry?.service_key !== "string" || entry.service_key.length === 0 || !Array.isArray(entry.frames)) {
          return false;
        }
        restoredServices.set(entry.service_key, {
          serviceKey: entry.service_key,
          // An emitter's next frame flips this back to running.
          status: "stopped",
          frames: entry.frames,
          // Sequences must CONTINUE — a regression reads as a service restart
          // to clients, which would wrongly reset their buffers.
          sequence: typeof entry.sequence === "number" ? entry.sequence : entry.frames.length,
          totalFrames: typeof entry.total_frames === "number" ? entry.total_frames : entry.frames.length,
          // Fresh liveness clock: a restored service gets a full stopped→GC
          // window from restart instead of being collected on the first sweep.
          lastFrameAt: now(),
          layers: new Map(entry.layers ?? []),
        });
      }
      for (const [boundaryId, occurrences] of record.boundaries as HubSnapshot["boundaries"]) {
        if (typeof boundaryId !== "number" || !Array.isArray(occurrences)) {
          return false;
        }
        // A missing sequence (older snapshot) must not be prunable-by-default:
        // treat it as newest so correlate() keeps it until its service goes.
        restoredBoundaries.set(
          boundaryId,
          occurrences.map((occurrence) => ({
            ...occurrence,
            sequence: typeof occurrence.sequence === "number" ? occurrence.sequence : Number.MAX_SAFE_INTEGER,
          })),
        );
      }
    } catch {
      return false;
    }
    for (const [key, state] of restoredServices) {
      services.set(key, state);
    }
    for (const [boundaryId, occurrences] of restoredBoundaries) {
      boundaries.set(boundaryId, occurrences);
    }
    stateVersion += 1;
    return true;
  }

  return {
    fetch,
    websocket,
    ingestLine,
    ingestBody,
    register,
    deregister,
    roster,
    serviceFrames: (serviceKey) => services.get(serviceKey)?.frames ?? [],
    serviceKeys: () => [...services.keys()],
    tick,
    clientCount: () => clients.size,
    rejectedLineCount: () => rejectedLines,
    correlate,
    stateVersion: () => stateVersion,
    snapshotState,
    restoreState,
  };
}

// `service-a | service-b | … | bun hub.ts` — serve + route stdin NDJSON by service_key.
// Env: PORT (4600), HUB_HOST (127.0.0.1; 0.0.0.0 accepts remote emitters),
// HUB_TOKEN (token-gate every endpoint but /health), HUB_PERSIST (snapshot path),
// HUB_SERVICE (default service_key for untagged stdin lines).
if (import.meta.main) {
  const port = Number(process.env.PORT ?? 4600);
  const host = process.env.HUB_HOST ?? "127.0.0.1";
  const persistPath = process.env.HUB_PERSIST;
  if (process.env.HUB_TOKEN !== undefined && process.env.HUB_TOKEN.length === 0) {
    // eslint-disable-next-line no-console
    console.error("HUB_TOKEN is set but empty (e.g. an unset shell variable) — refusing to start with a bypassable gate");
    process.exit(1);
  }
  const hub = createHub({ token: process.env.HUB_TOKEN });

  if (persistPath) {
    try {
      const raw = readFileSync(persistPath, "utf8");
      const restored = hub.restoreState(JSON.parse(raw));
      // eslint-disable-next-line no-console
      console.log(restored ? `restored hub state from ${persistPath}` : `ignored incompatible snapshot at ${persistPath}`);
    } catch {
      // First run (no snapshot yet) or unreadable file — start empty, never crash.
    }
  }
  let savedVersion = hub.stateVersion();
  const saveSnapshot = (): void => {
    if (!persistPath || hub.stateVersion() === savedVersion) {
      return;
    }
    const tmp = `${persistPath}.tmp`;
    try {
      writeFileSync(tmp, JSON.stringify(hub.snapshotState()));
      renameSync(tmp, persistPath); // atomic on the same filesystem
      savedVersion = hub.stateVersion();
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error(`hub snapshot write failed: ${String(error)}`);
    }
  };
  for (const signal of ["SIGINT", "SIGTERM"] as const) {
    process.on(signal, () => {
      saveSnapshot();
      process.exit(0);
    });
  }

  const server = Bun.serve({ port, hostname: host, fetch: hub.fetch, websocket: hub.websocket });
  const sweep = setInterval(() => {
    hub.tick(Date.now());
    saveSnapshot();
  }, 5000);
  sweep.unref?.();
  // eslint-disable-next-line no-console
  console.log(
    `zigeffect causal hub on http://${host}:${server.port}  (ws: /live, ingest: POST /ingest?service=, roster: GET /services)`,
  );

  const defaultServiceKey = process.env.HUB_SERVICE ?? undefined;
  const maxPartialLineBytes = 1024 * 1024;
  void (async () => {
    const reader = Bun.stdin.stream().getReader();
    const decoder = new TextDecoder();
    let buffer = "";
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split("\n");
      buffer = lines.pop() ?? "";
      // ingestBody coalesces roster broadcasts across the chunk's lines.
      hub.ingestBody(lines.join("\n"), defaultServiceKey);
      // A newline-free stream must not grow the partial-line buffer forever;
      // flush the oversized fragment through ingestLine, which rejects+counts it.
      if (buffer.length > maxPartialLineBytes) {
        hub.ingestLine(buffer, defaultServiceKey);
        buffer = "";
      }
    }
    if (buffer.trim().length > 0) hub.ingestLine(buffer, defaultServiceKey);
  })();
}
