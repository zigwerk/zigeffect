// Track F — live-attach for the causal workbench.
//
// The static workbench loads a one-shot artifact snapshot (workbenchBridge).
// Live-attach instead consumes a STREAM of causal-event frames emitted by the
// engine's live bridge (CausalHubBackend → wire; see
// public/sample-live-dashboard-stream.json) and accumulates them into the SAME
// artifact model every existing view (timeline, graph, findings, …) already
// renders — so live mode reuses the whole UI rather than adding a parallel one.
//
// HONEST BOUNDARY: the collector endpoint now exists under `src/collector/`,
// maps engine NDJSON into LiveFrame WebSocket messages, and has browser-level
// proof. The remaining gap is a real long-lived host process that wires the
// local command polling harness to the engine-side policy bridge.

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

export type LiveCommandRequest = {
  kind: string;
  reason?: string;
  redacted_detail?: string;
  run_id?: number;
  scope_id?: number;
  fiber_id?: number;
  schedule_id?: number;
  resource_id?: number;
};

export type LiveCommandFrame = {
  sequence: number;
  command_id: string;
  command_kind: string;
  status: "received" | "rejected" | "forwarded";
  reason?: string;
  redacted_detail?: string;
  run_id?: number | null;
  scope_id?: number | null;
  fiber_id?: number | null;
  schedule_id?: number | null;
  resource_id?: number | null;
};

export type LiveCommandInboxResponse = {
  commands: LiveCommandFrame[];
  next_after: number;
};

export type LiveCommandPollingOptions = {
  startAfter?: number;
  maxPolls?: number;
};

export type LiveCommandPollingResult = {
  polls: number;
  commands: number;
  next_after: number;
};

export type LiveCommandBatchHandler = (inbox: LiveCommandInboxResponse) => void | Promise<void>;

export type LiveCommandDaemonOptions = {
  startAfter?: number;
  maxCycles?: number;
  maxPollsPerCycle?: number;
  shouldStop?: () => boolean | Promise<boolean>;
  delay?: (cycle: LiveCommandPollingResult) => void | Promise<void>;
  onLifecycle?: (event: LiveCommandDaemonLifecycleEvent) => void | Promise<void>;
  continueOnError?: boolean;
};

export type LiveCommandDaemonResult = {
  cycles: number;
  polls: number;
  commands: number;
  errors: number;
  next_after: number;
  stopped: boolean;
};

export type LiveCommandEngineBatchResult = {
  processed: number;
  applied: number;
  rejected: number;
  needs_human_review: number;
  frames?: LiveFrame[];
};

export type LiveCommandEngineBridge = {
  applyBatch: (inbox: LiveCommandInboxResponse) => LiveCommandEngineBatchResult | Promise<LiveCommandEngineBatchResult>;
  emitFrame?: (frame: LiveFrame) => void | Promise<void>;
};

export type HttpLiveEngineCommandBridgeOptions = {
  applyUrl: string;
  framesUrl?: string;
  fetcher?: LiveCommandFetcher;
};

export type LiveEngineCommandDaemonResult = LiveCommandDaemonResult & {
  processed: number;
  applied: number;
  rejected: number;
  needs_human_review: number;
  emitted_frames: number;
};

export type LiveEngineHost = {
  handleApplyRequest: (request: Request) => Promise<Response>;
  runCommandDaemon: (
    url: string,
    options?: LiveCommandDaemonOptions,
    fetcher?: LiveCommandFetcher,
  ) => Promise<LiveEngineCommandDaemonResult>;
};

export type LiveCommandDaemonLifecycleEvent =
  | { kind: "started"; next_after: number }
  | ({ kind: "cycle"; cycle: number } & LiveCommandPollingResult)
  | { kind: "error"; cycle: number; error: unknown; next_after: number }
  | ({ kind: "stopped" } & LiveCommandDaemonResult);

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

export function isLiveCommandFrame(value: unknown): value is LiveCommandFrame {
  if (typeof value !== "object" || value === null) {
    return false;
  }
  const record = value as Record<string, unknown>;
  return (
    typeof record.sequence === "number" &&
    typeof record.command_id === "string" &&
    typeof record.command_kind === "string" &&
    (record.status === "received" || record.status === "rejected" || record.status === "forwarded")
  );
}

export function parseCommandMessage(data: string): LiveCommandFrame | null {
  try {
    const parsed = JSON.parse(data) as unknown;
    return isLiveCommandFrame(parsed) ? parsed : null;
  } catch {
    return null;
  }
}

function isSafeCursor(value: unknown): value is number {
  return typeof value === "number" && Number.isSafeInteger(value) && value >= 0;
}

export function isLiveCommandInboxResponse(value: unknown): value is LiveCommandInboxResponse {
  if (typeof value !== "object" || value === null) {
    return false;
  }
  const record = value as Record<string, unknown>;
  if (!isSafeCursor(record.next_after) || !Array.isArray(record.commands)) {
    return false;
  }
  let maxSequence = 0;
  for (const command of record.commands) {
    if (!isLiveCommandFrame(command)) {
      return false;
    }
    maxSequence = Math.max(maxSequence, command.sequence);
  }
  return record.next_after >= maxSequence;
}

export function isLiveCommandEngineBatchResult(value: unknown): value is LiveCommandEngineBatchResult {
  if (typeof value !== "object" || value === null) {
    return false;
  }
  const record = value as Record<string, unknown>;
  if (
    !isSafeCursor(record.processed) ||
    !isSafeCursor(record.applied) ||
    !isSafeCursor(record.rejected) ||
    !isSafeCursor(record.needs_human_review)
  ) {
    return false;
  }
  if (record.frames === undefined) {
    return true;
  }
  return Array.isArray(record.frames) && record.frames.every(isLiveFrame);
}

export type LiveCommandFetcher = (url: string, init?: RequestInit) => Promise<Response>;

export const liveEngineCommandApplyHeaders = {
  "content-type": "application/json",
  "cache-control": "no-store",
  "x-content-type-options": "nosniff",
} as const;

function liveEngineCommandJsonResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: liveEngineCommandApplyHeaders,
  });
}

export async function serveLiveEngineCommandApplyRequest(
  request: Request,
  bridge: LiveCommandEngineBridge,
): Promise<Response> {
  if (request.method.toUpperCase() !== "POST") {
    return liveEngineCommandJsonResponse(405, { error: "method_not_allowed" });
  }

  let parsed: unknown;
  try {
    parsed = await request.json();
  } catch {
    return liveEngineCommandJsonResponse(400, { error: "invalid_json" });
  }

  if (!isLiveCommandInboxResponse(parsed)) {
    return liveEngineCommandJsonResponse(400, { error: "invalid_live_command_inbox" });
  }

  const result = await bridge.applyBatch(parsed);
  if (!isLiveCommandEngineBatchResult(result)) {
    return liveEngineCommandJsonResponse(502, { error: "invalid_live_engine_batch_result" });
  }

  return liveEngineCommandJsonResponse(200, result);
}

export async function sendLiveCommand(
  url: string,
  command: LiveCommandRequest,
  fetcher: LiveCommandFetcher = fetch,
): Promise<LiveCommandFrame> {
  const response = await fetcher(url, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(command),
  });
  if (!response.ok) {
    throw new Error(`live command rejected: ${response.status}`);
  }
  const parsed = (await response.json()) as unknown;
  if (!isLiveCommandFrame(parsed)) {
    throw new Error("live command endpoint returned an invalid command frame");
  }
  return parsed;
}

export async function fetchLiveCommands(
  url: string,
  afterSequence: number,
  fetcher: LiveCommandFetcher = fetch,
): Promise<LiveCommandInboxResponse> {
  if (!Number.isSafeInteger(afterSequence) || afterSequence < 0) {
    throw new Error("live command inbox cursor must be a non-negative safe integer");
  }
  const endpoint = new URL(url);
  endpoint.searchParams.set("after", String(afterSequence));
  const response = await fetcher(endpoint.toString());
  if (!response.ok) {
    throw new Error(`live command inbox rejected: ${response.status}`);
  }
  const parsed = (await response.json()) as unknown;
  if (!isLiveCommandInboxResponse(parsed)) {
    throw new Error("live command inbox returned an invalid response");
  }
  return parsed;
}

export async function runLiveCommandPollingLoop(
  url: string,
  handler: LiveCommandBatchHandler,
  options: LiveCommandPollingOptions = {},
  fetcher: LiveCommandFetcher = fetch,
): Promise<LiveCommandPollingResult> {
  const maxPolls = options.maxPolls ?? 1;
  if (!Number.isSafeInteger(maxPolls) || maxPolls < 0) {
    throw new Error("live command polling maxPolls must be a non-negative safe integer");
  }
  let cursor = options.startAfter ?? 0;
  let polls = 0;
  let commands = 0;
  while (polls < maxPolls) {
    const inbox = await fetchLiveCommands(url, cursor, fetcher);
    polls += 1;
    commands += inbox.commands.length;
    await handler(inbox);
    cursor = inbox.next_after;
    if (inbox.commands.length === 0) {
      break;
    }
  }
  return { polls, commands, next_after: cursor };
}

export async function runLiveCommandDaemon(
  url: string,
  handler: LiveCommandBatchHandler,
  options: LiveCommandDaemonOptions = {},
  fetcher: LiveCommandFetcher = fetch,
): Promise<LiveCommandDaemonResult> {
  const maxCycles = options.maxCycles ?? 1;
  const maxPollsPerCycle = options.maxPollsPerCycle ?? 1;
  if (!Number.isSafeInteger(maxCycles) || maxCycles < 0) {
    throw new Error("live command daemon maxCycles must be a non-negative safe integer");
  }
  if (!Number.isSafeInteger(maxPollsPerCycle) || maxPollsPerCycle < 0) {
    throw new Error("live command daemon maxPollsPerCycle must be a non-negative safe integer");
  }

  let cursor = options.startAfter ?? 0;
  let cycles = 0;
  let polls = 0;
  let commands = 0;
  let errors = 0;
  let stopped = false;
  const emitLifecycle = async (event: LiveCommandDaemonLifecycleEvent) => {
    if (options.onLifecycle) {
      await options.onLifecycle(event);
    }
  };

  await emitLifecycle({ kind: "started", next_after: cursor });

  while (cycles < maxCycles) {
    if (options.shouldStop && (await options.shouldStop())) {
      stopped = true;
      break;
    }

    let cycle: LiveCommandPollingResult;
    try {
      cycle = await runLiveCommandPollingLoop(
        url,
        handler,
        { startAfter: cursor, maxPolls: maxPollsPerCycle },
        fetcher,
      );
    } catch (error) {
      errors += 1;
      await emitLifecycle({ kind: "error", cycle: cycles + 1, error, next_after: cursor });
      if (!options.continueOnError) {
        throw error;
      }
      cycles += 1;
      continue;
    }

    cycles += 1;
    polls += cycle.polls;
    commands += cycle.commands;
    cursor = cycle.next_after;
    await emitLifecycle({ kind: "cycle", cycle: cycles, ...cycle });

    if (options.shouldStop && (await options.shouldStop())) {
      stopped = true;
      break;
    }
    if (cycle.commands === 0) {
      break;
    }
    if (cycles < maxCycles && options.delay) {
      await options.delay(cycle);
    }
  }

  const result = { cycles, polls, commands, errors, next_after: cursor, stopped };
  await emitLifecycle({ kind: "stopped", ...result });
  return result;
}

export async function runLiveEngineCommandDaemon(
  url: string,
  bridge: LiveCommandEngineBridge,
  options: LiveCommandDaemonOptions = {},
  fetcher: LiveCommandFetcher = fetch,
): Promise<LiveEngineCommandDaemonResult> {
  const engine = {
    processed: 0,
    applied: 0,
    rejected: 0,
    needs_human_review: 0,
    emitted_frames: 0,
  };

  const daemon = await runLiveCommandDaemon(
    url,
    async (inbox) => {
      if (inbox.commands.length === 0) {
        return;
      }
      const batch = await bridge.applyBatch(inbox);
      engine.processed += batch.processed;
      engine.applied += batch.applied;
      engine.rejected += batch.rejected;
      engine.needs_human_review += batch.needs_human_review;
      if (bridge.emitFrame) {
        for (const nextFrame of batch.frames ?? []) {
          await bridge.emitFrame(nextFrame);
          engine.emitted_frames += 1;
        }
      }
    },
    options,
    fetcher,
  );

  return { ...daemon, ...engine };
}

export function createLiveEngineHost(bridge: LiveCommandEngineBridge): LiveEngineHost {
  return {
    handleApplyRequest: (request) => serveLiveEngineCommandApplyRequest(request, bridge),
    runCommandDaemon: (url, options = {}, fetcher = fetch) => runLiveEngineCommandDaemon(url, bridge, options, fetcher),
  };
}

export function createHttpLiveEngineCommandBridge(options: HttpLiveEngineCommandBridgeOptions): LiveCommandEngineBridge {
  const fetcher = options.fetcher ?? fetch;

  const bridge: LiveCommandEngineBridge = {
    applyBatch: async (inbox) => {
      const response = await fetcher(options.applyUrl, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(inbox),
      });
      if (!response.ok) {
        throw new Error(`live engine command bridge rejected: ${response.status}`);
      }
      const parsed = (await response.json()) as unknown;
      if (!isLiveCommandEngineBatchResult(parsed)) {
        throw new Error("live engine command bridge returned an invalid batch result");
      }
      return parsed;
    },
  };

  if (options.framesUrl) {
    bridge.emitFrame = async (frame) => {
      const response = await fetcher(options.framesUrl!, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(frame),
      });
      if (!response.ok) {
        throw new Error(`live engine frame ingest rejected: ${response.status}`);
      }
    };
  }

  return bridge;
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
