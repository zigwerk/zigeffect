// Track F — live-attach for the causal workbench.
//
// The static workbench loads a one-shot artifact snapshot (workbenchBridge).
// Live-attach instead consumes a STREAM of causal-event frames emitted by the
// engine's live bridge (CausalHubBackend → wire; see
// public/sample-live-dashboard-stream.json) and accumulates them into the SAME
// artifact model every existing view (timeline, graph, findings, …) already
// renders — so live mode reuses the whole UI rather than adding a parallel one.
//
// HONEST BOUNDARY: the real transport (`webSocketLiveSource`) needs the
// engine-side live-attach collector endpoint, which is not yet built. Everything
// here is transport-agnostic and unit-tested through `LiveSource`; the socket
// itself is exercised only against a running collector (manual / flagged). The
// message framing (`parseFrameMessage`) is pure and fully tested.

import { createSignal, onCleanup } from "solid-js";
import type { UnknownRecord } from "./causalArtifact";

// ── Live wire format — one frame per causal-event delta ───────────────────────
export type LiveFrame = {
  sequence: number;
  event_id: number;
  event_kind: string;
  status: string;
  label?: string;
  lane?: string | null;
  parent_id?: number | null;
  finding_kind?: string | null;
  dashboard_priority?: string | null;
};

export type LiveStreamMeta = {
  schema?: string;
  schemaVersion?: number | string;
  taxonomyVersion?: string;
  /** Ring-buffer window; <= 0 / undefined keeps every frame. */
  maxFrames?: number;
};

const DEFAULT_SCHEMA = "zigeffect.causal.live-dashboard-stream.v1";

// ── Transport abstraction ─────────────────────────────────────────────────────
export type LiveSubscriber = {
  onFrame: (frame: LiveFrame) => void;
  onError?: (error: unknown) => void;
  onClose?: () => void;
};

export type LiveUnsubscribe = () => void;

export type LiveSource = {
  subscribe: (subscriber: LiveSubscriber) => LiveUnsubscribe;
};

// ── Frame → workbench event record ────────────────────────────────────────────
// Maps the live wire fields onto the canonical artifact event keys that
// `deriveWorkbenchModel`/`normalizeEvent` consume, preserving the live-only
// annotations (sequence, lane, finding_kind, dashboard_priority) on the record.
export function frameToEventRecord(frame: LiveFrame): UnknownRecord {
  return {
    id: frame.event_id,
    kind: frame.event_kind,
    status: frame.status,
    label: frame.label ?? "",
    parent_id: frame.parent_id ?? null,
    sequence: frame.sequence,
    lane: frame.lane ?? null,
    finding_kind: frame.finding_kind ?? null,
    dashboard_priority: frame.dashboard_priority ?? null,
  };
}

export function isLiveFrame(value: unknown): value is LiveFrame {
  if (typeof value !== "object" || value === null) {
    return false;
  }
  const record = value as Record<string, unknown>;
  return (
    typeof record.sequence === "number" &&
    typeof record.event_id === "number" &&
    typeof record.event_kind === "string" &&
    typeof record.status === "string"
  );
}

export function parseFrameMessage(data: string): LiveFrame | null {
  try {
    const parsed = JSON.parse(data) as unknown;
    return isLiveFrame(parsed) ? parsed : null;
  } catch {
    return null;
  }
}

/** Pull `frames` out of a full live-stream document (the sample fixture shape). */
export function framesFromStreamDocument(raw: unknown): LiveFrame[] {
  if (typeof raw !== "object" || raw === null) {
    return [];
  }
  const frames = (raw as Record<string, unknown>).frames;
  if (!Array.isArray(frames)) {
    return [];
  }
  return frames.filter(isLiveFrame);
}

// ── Accumulating buffer ───────────────────────────────────────────────────────
export class LiveCausalBuffer {
  private readonly byId = new Map<number, LiveFrame>();
  private readonly insertionOrder: number[] = [];
  private droppedCount = 0;

  constructor(private readonly meta: LiveStreamMeta = {}) {}

  /** Ingest one frame. A repeated `event_id` updates in place (status
   * transitions, e.g. pending → ready) without growing the window. */
  ingest(frame: LiveFrame): void {
    const known = this.byId.has(frame.event_id);
    this.byId.set(frame.event_id, frame);
    if (!known) {
      this.insertionOrder.push(frame.event_id);
      this.evictIfNeeded();
    }
  }

  ingestMany(frames: readonly LiveFrame[]): void {
    for (const frame of frames) {
      this.ingest(frame);
    }
  }

  private evictIfNeeded(): void {
    const max = this.meta.maxFrames ?? 0;
    if (max <= 0) {
      return;
    }
    while (this.insertionOrder.length > max) {
      const evicted = this.insertionOrder.shift();
      if (evicted !== undefined) {
        this.byId.delete(evicted);
        this.droppedCount += 1;
      }
    }
  }

  get size(): number {
    return this.byId.size;
  }

  get dropped(): number {
    return this.droppedCount;
  }

  /** Frames in causal (sequence) order. */
  frames(): LiveFrame[] {
    return [...this.byId.values()].sort((left, right) => left.sequence - right.sequence);
  }

  artifact(): UnknownRecord {
    return {
      schema: this.meta.schema ?? DEFAULT_SCHEMA,
      schema_version: this.meta.schemaVersion ?? 1,
      event_taxonomy_version: this.meta.taxonomyVersion ?? "live",
      events: this.frames().map(frameToEventRecord),
    };
  }

  artifactJson(): string {
    return JSON.stringify(this.artifact());
  }
}

// ── Mock source (tests / offline demo) ────────────────────────────────────────
export function mockLiveSource(
  frames: readonly LiveFrame[],
  options: { async?: boolean } = {},
): LiveSource {
  return {
    subscribe(subscriber) {
      let cancelled = false;
      if (options.async) {
        void (async () => {
          for (const frame of frames) {
            await Promise.resolve();
            if (cancelled) {
              return;
            }
            subscriber.onFrame(frame);
          }
          if (!cancelled) {
            subscriber.onClose?.();
          }
        })();
      } else {
        for (const frame of frames) {
          if (cancelled) {
            break;
          }
          subscriber.onFrame(frame);
        }
        if (!cancelled) {
          subscriber.onClose?.();
        }
      }
      return () => {
        cancelled = true;
      };
    },
  };
}

// ── WebSocket source (real transport — flagged) ───────────────────────────────
export type SocketListener = (event: unknown) => void;
export type WebSocketLike = {
  addEventListener: (type: string, listener: SocketListener) => void;
  close: () => void;
};
export type WebSocketFactory = (url: string) => WebSocketLike;

function defaultWebSocketFactory(url: string): WebSocketLike {
  return new WebSocket(url) as unknown as WebSocketLike;
}

function socketMessageData(event: unknown): string {
  if (typeof event === "object" && event !== null) {
    const data = (event as Record<string, unknown>).data;
    if (typeof data === "string") {
      return data;
    }
  }
  return "";
}

export function webSocketLiveSource(
  url: string,
  factory: WebSocketFactory = defaultWebSocketFactory,
): LiveSource {
  return {
    subscribe(subscriber) {
      const socket = factory(url);
      socket.addEventListener("message", (event) => {
        const frame = parseFrameMessage(socketMessageData(event));
        if (frame) {
          subscriber.onFrame(frame);
        }
      });
      socket.addEventListener("error", (event) => subscriber.onError?.(event));
      socket.addEventListener("close", () => subscriber.onClose?.());
      return () => socket.close();
    },
  };
}

// ── SolidJS reactive integration ──────────────────────────────────────────────
export type LiveArtifactHandle = {
  artifactJson: () => string;
  frameCount: () => number;
  dropped: () => number;
  connected: () => boolean;
};

/** Subscribe to `source` and expose a reactive, accumulating artifact the
 * existing workbench views can render. Must be called within a Solid owner
 * (component body or `createRoot`) so the subscription is cleaned up. */
export function createLiveArtifact(source: LiveSource, meta: LiveStreamMeta = {}): LiveArtifactHandle {
  const buffer = new LiveCausalBuffer(meta);
  const [artifactJson, setArtifactJson] = createSignal(buffer.artifactJson());
  const [frameCount, setFrameCount] = createSignal(0);
  const [dropped, setDropped] = createSignal(0);
  const [connected, setConnected] = createSignal(true);

  const unsubscribe = source.subscribe({
    onFrame: (frame) => {
      buffer.ingest(frame);
      setArtifactJson(buffer.artifactJson());
      setFrameCount(buffer.size);
      setDropped(buffer.dropped);
    },
    onError: () => setConnected(false),
    onClose: () => setConnected(false),
  });

  onCleanup(unsubscribe);

  return { artifactJson, frameCount, dropped, connected };
}

/** Extract a live-attach websocket URL from a `?live=<url>` query string. */
export function liveUrlFromSearch(search: string): string | null {
  const params = new URLSearchParams(search);
  const url = params.get("live");
  return url && url.length > 0 ? url : null;
}
