// Causal hub wire protocol — the multiplexed envelope shared by the hub (`hub.ts`)
// and the frontend multi-service source. Services are identified by their engine
// `service_key` (already carried on every causal event), so discovery is automatic:
// the hub never needs a hand-assigned id, and a mixed NDJSON stream self-routes.

import type { LiveFrame } from "../liveAttach";

export type { LiveFrame };

export type ServiceStatus = "running" | "idle" | "stopped";

export type ServiceLayer = { layer_id: number; layer_name: string };

/** One side of a service boundary: where a shared boundary_id was observed.
 * Served by the hub's GET /correlate?boundary= endpoint. */
export type BoundaryOccurrence = {
  service_key: string;
  event_id: number;
  event_kind: string;
  label: string;
};

/** Parse a /correlate response body; malformed entries are dropped, never cast. */
export function parseCorrelation(data: unknown): BoundaryOccurrence[] {
  if (typeof data !== "object" || data === null) {
    return [];
  }
  const record = data as Record<string, unknown>;
  if (!Array.isArray(record.occurrences)) {
    return [];
  }
  return record.occurrences.filter((occurrence): occurrence is BoundaryOccurrence => {
    if (typeof occurrence !== "object" || occurrence === null) {
      return false;
    }
    const entry = occurrence as Record<string, unknown>;
    return (
      typeof entry.service_key === "string" &&
      typeof entry.event_id === "number" &&
      typeof entry.event_kind === "string" &&
      typeof entry.label === "string"
    );
  });
}

export type ServiceSummary = {
  service_key: string;
  status: ServiceStatus;
  /** Frames currently retained in the ring buffer. */
  frame_count: number;
  /** Total frames ever seen, including those dropped by retention. */
  total_frames: number;
  layers: ServiceLayer[];
  /** Epoch ms of the most recent frame, or 0 if none yet. */
  last_frame_at: number;
};

// hub → client
export type HubMessage =
  | { type: "roster"; services: ServiceSummary[] }
  | { type: "frame"; service_key: string; frame: LiveFrame }
  | { type: "service-status"; service_key: string; status: ServiceStatus }
  // Backfill truncation: `dropped` frames between the client's watermark and the
  // ring-buffer floor were evicted and can never be delivered. Sent before the
  // backfill frames so the client can reset/mark its buffer instead of silently
  // rendering a trace with a hole in it.
  | { type: "gap"; service_key: string; dropped: number };

// client → hub
export type HubClientMessage =
  | { type: "subscribe"; services: string[] }
  | { type: "unsubscribe"; services: string[] };

function isServiceStatus(value: unknown): value is ServiceStatus {
  return value === "running" || value === "idle" || value === "stopped";
}

function isServiceLayer(value: unknown): value is ServiceLayer {
  if (typeof value !== "object" || value === null) {
    return false;
  }
  const record = value as Record<string, unknown>;
  return typeof record.layer_id === "number" && typeof record.layer_name === "string";
}

function isServiceSummary(value: unknown): value is ServiceSummary {
  if (typeof value !== "object" || value === null) {
    return false;
  }
  const record = value as Record<string, unknown>;
  return (
    typeof record.service_key === "string" &&
    isServiceStatus(record.status) &&
    typeof record.frame_count === "number" &&
    typeof record.total_frames === "number" &&
    Array.isArray(record.layers) &&
    record.layers.every(isServiceLayer) &&
    typeof record.last_frame_at === "number"
  );
}

// Structural twin of liveAttach's isLiveFrame — duplicated (not imported)
// because liveAttach has a runtime solid-js dependency and this module is
// loaded by the Bun hub process.
function isWireFrame(value: unknown): value is LiveFrame {
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

/** Parse a hub → client message (used by the frontend source); rejects anything
 * malformed — `?hub=` is a user-supplied URL and the hub is a separate process,
 * so a drifted or wrong server must not crash the UI. */
export function parseHubMessage(data: string): HubMessage | null {
  let parsed: unknown;
  try {
    parsed = JSON.parse(data);
  } catch {
    return null;
  }
  if (typeof parsed !== "object" || parsed === null) {
    return null;
  }
  const record = parsed as Record<string, unknown>;
  if (record.type === "roster" && Array.isArray(record.services) && record.services.every(isServiceSummary)) {
    return { type: "roster", services: record.services };
  }
  if (record.type === "frame" && typeof record.service_key === "string" && isWireFrame(record.frame)) {
    return { type: "frame", service_key: record.service_key, frame: record.frame };
  }
  if (record.type === "service-status" && typeof record.service_key === "string" && isServiceStatus(record.status)) {
    return { type: "service-status", service_key: record.service_key, status: record.status };
  }
  if (record.type === "gap" && typeof record.service_key === "string" && typeof record.dropped === "number" && record.dropped > 0) {
    return { type: "gap", service_key: record.service_key, dropped: record.dropped };
  }
  return null;
}

/** Parse a client → hub message (used by the hub); rejects anything malformed. */
export function parseHubClientMessage(data: unknown): HubClientMessage | null {
  let value: unknown = data;
  if (typeof data === "string") {
    try {
      value = JSON.parse(data);
    } catch {
      return null;
    }
  }
  if (typeof value !== "object" || value === null) {
    return null;
  }
  const record = value as Record<string, unknown>;
  if ((record.type === "subscribe" || record.type === "unsubscribe") && Array.isArray(record.services)) {
    const services = record.services.filter((service): service is string => typeof service === "string");
    return { type: record.type, services };
  }
  return null;
}
