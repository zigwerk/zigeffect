import { expect, test } from "bun:test";
import { isLiveFrame } from "../liveAttach";
import { causalLineToFrame } from "./frame";

// A representative engine NDJSON CausalEvent line (formatCausalJsonLine shape).
function engineLine(extra: Record<string, unknown>): string {
  return JSON.stringify({
    schema: "zigeffect.causal.event.v1",
    schema_version: 1,
    event_taxonomy_version: 1,
    id: 1,
    kind: "run_started",
    run_id: 1,
    parent_id: null,
    fiber_id: null,
    scope_id: null,
    label: "",
    type_name: "",
    status: "started",
    redacted_detail: "",
    ...extra,
  });
}

test("causalLineToFrame maps an engine line onto the LiveFrame wire shape", () => {
  const frame = causalLineToFrame(engineLine({ id: 7, kind: "fiber_started", status: "running", label: "worker", parent_id: 3, fiber_id: 5, run_id: 1 }), 9);
  expect(frame).not.toBeNull();
  expect(frame!.sequence).toBe(9);
  expect(frame!.event_id).toBe(7);
  expect(frame!.event_kind).toBe("fiber_started");
  expect(frame!.status).toBe("running");
  expect(frame!.label).toBe("worker");
  expect(frame!.parent_id).toBe(3);
  // Every produced frame must satisfy the FRONTEND's own guard.
  expect(isLiveFrame(frame)).toBe(true);
});

test("lane derivation is most-specific-first: fiber → scope → run", () => {
  expect(causalLineToFrame(engineLine({ fiber_id: 5, scope_id: 2, run_id: 1 }), 1)!.lane).toBe("fiber:5");
  expect(causalLineToFrame(engineLine({ fiber_id: null, scope_id: 2, run_id: 1 }), 1)!.lane).toBe("scope:2");
  expect(causalLineToFrame(engineLine({ fiber_id: null, scope_id: null, run_id: 1 }), 1)!.lane).toBe("run:1");
  expect(causalLineToFrame(engineLine({ fiber_id: null, scope_id: null, run_id: null }), 1)!.lane).toBeNull();
});

test("dashboard priority is derived from status/kind", () => {
  expect(causalLineToFrame(engineLine({ status: "failed" }), 1)!.dashboard_priority).toBe("critical");
  expect(causalLineToFrame(engineLine({ kind: "fiber_interrupted", status: "interrupted" }), 1)!.dashboard_priority).toBe("critical");
  expect(causalLineToFrame(engineLine({ kind: "fiber_suspended", status: "pending" }), 1)!.dashboard_priority).toBe("watch");
  expect(causalLineToFrame(engineLine({ status: "ready" }), 1)!.dashboard_priority).toBe("normal");
});

test("empty status maps to 'unknown' (the frontend requires a string status)", () => {
  const frame = causalLineToFrame(engineLine({ status: "" }), 1);
  expect(frame!.status).toBe("unknown");
  expect(isLiveFrame(frame)).toBe(true);
});

test("malformed / incomplete lines are rejected (never break the stream)", () => {
  expect(causalLineToFrame("", 1)).toBeNull();
  expect(causalLineToFrame("   ", 1)).toBeNull();
  expect(causalLineToFrame("not json", 1)).toBeNull();
  expect(causalLineToFrame("[1,2,3]", 1)).toBeNull(); // array, not an object
  expect(causalLineToFrame(JSON.stringify({ kind: "x" }), 1)).toBeNull(); // missing id
  expect(causalLineToFrame(JSON.stringify({ id: 1 }), 1)).toBeNull(); // missing kind
});

test("non-integer / out-of-range ids are rejected, not silently corrupted", () => {
  expect(causalLineToFrame(JSON.stringify({ id: 1.5, kind: "x" }), 1)).toBeNull(); // fractional
  expect(causalLineToFrame(JSON.stringify({ id: -1, kind: "x" }), 1)).toBeNull(); // negative
  expect(causalLineToFrame(JSON.stringify({ id: 9007199254740993, kind: "x" }), 1)).toBeNull(); // > 2^53, precision-lost
  // A valid id with a fractional parent_id keeps the event but drops the bad edge.
  const frame = causalLineToFrame(JSON.stringify({ id: 1, kind: "x", parent_id: 2.5 }), 1);
  expect(frame).not.toBeNull();
  expect(frame!.parent_id).toBeNull();
});
