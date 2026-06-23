// Live-attach collector — engine NDJSON → workbench LiveFrame mapping.
//
// The engine serializes each CausalEvent to an NDJSON line via
// `formatCausalJsonLine` (schema `zigeffect.causal.event.v1`):
//   {"schema":"…","id":1,"kind":"run_started","run_id":1,"parent_id":null,
//    "fiber_id":null,"scope_id":null,…,"label":"…","status":"…",…}
// The collector maps each line to the wire `LiveFrame` the workbench frontend
// consumes (one frame per WebSocket message). The `LiveFrame` type is imported
// (type-only — no runtime dependency on the frontend's solid-js module) so the
// mapping is compile-time guaranteed to match the frontend contract.

import type { LiveFrame } from "../liveAttach";

export type { LiveFrame };

type CausalEventRecord = Record<string, unknown>;

function numberOrNull(value: unknown): number | null {
  return typeof value === "number" ? value : null;
}

/** Lane the event belongs to, most-specific first (fiber → scope → run). */
function deriveLane(event: CausalEventRecord): string | null {
  if (typeof event.fiber_id === "number") return `fiber:${event.fiber_id}`;
  if (typeof event.scope_id === "number") return `scope:${event.scope_id}`;
  if (typeof event.run_id === "number") return `run:${event.run_id}`;
  return null;
}

/** Dashboard priority derived from the event's status/kind. */
function derivePriority(event: CausalEventRecord): string {
  const status = typeof event.status === "string" ? event.status.toLowerCase() : "";
  const kind = typeof event.kind === "string" ? event.kind.toLowerCase() : "";
  if (
    status.includes("fail") ||
    status.includes("error") ||
    kind.includes("failed") ||
    kind.includes("interrupt")
  ) {
    return "critical";
  }
  if (kind.includes("suspend") || kind.includes("retry") || status.includes("pending")) {
    return "watch";
  }
  return "normal";
}

/**
 * Map one engine NDJSON CausalEvent line to a `LiveFrame` with the given
 * sequence number. Returns null for blank lines, non-JSON, non-objects, or
 * records missing the required `id`/`kind` (so a malformed line never breaks the
 * stream).
 */
export function causalLineToFrame(line: string, sequence: number): LiveFrame | null {
  const trimmed = line.trim();
  if (trimmed.length === 0) return null;

  let parsed: unknown;
  try {
    parsed = JSON.parse(trimmed);
  } catch {
    return null;
  }
  if (typeof parsed !== "object" || parsed === null) return null;

  const event = parsed as CausalEventRecord;
  if (typeof event.id !== "number" || typeof event.kind !== "string") return null;

  return {
    sequence,
    event_id: event.id,
    event_kind: event.kind,
    status: typeof event.status === "string" && event.status.length > 0 ? event.status : "unknown",
    label: typeof event.label === "string" ? event.label : "",
    lane: deriveLane(event),
    parent_id: numberOrNull(event.parent_id),
    finding_kind: null,
    dashboard_priority: derivePriority(event),
  };
}
