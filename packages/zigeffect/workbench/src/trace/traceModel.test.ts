import { expect, test } from "bun:test";
import {
  deriveGraphModel,
  deriveWorkbenchModel,
  type CausalFinding,
} from "../causalArtifact";
import {
  deriveTraceModel,
  findingSeverity,
  resolveEvidenceEventId,
} from "./traceModel";

type RawEvent = Record<string, unknown>;

function artifact(events: RawEvent[]): { events: RawEvent[]; schema: string; schema_version: number; event_taxonomy_version: number } {
  return { schema: "zigeffect.causal.v1", schema_version: 1, event_taxonomy_version: 1, events };
}

function build(events: RawEvent[]) {
  const model = deriveWorkbenchModel(artifact(events), { artifactPath: "test.json" });
  const graph = deriveGraphModel(model.events, model.findings);
  const trace = deriveTraceModel(model.events, graph.lanes, model.findings);
  return { model, graph, trace };
}

test("seqIndexById is monotonic, dense, and follows sorted order", () => {
  const { model, trace } = build([
    { id: 3, kind: "scope_closed", run_id: 1, parent_id: 1, scope_id: 1, status: "closed" },
    { id: 1, kind: "run_started", run_id: 1, status: "" },
    { id: 2, kind: "scope_opened", run_id: 1, parent_id: 1, scope_id: 1, status: "opened" },
  ]);

  // events come out sorted by id; trace indices are the dense positions.
  expect(model.events.map((event) => event.idText)).toEqual(["1", "2", "3"]);
  expect(trace.rows.map((row) => row.seqIndex)).toEqual([0, 1, 2]);
  expect(trace.seqIndexById.get("1")).toBe(0);
  expect(trace.seqIndexById.get("3")).toBe(2);
});

test("seqIndexById stays stable as live frames append at the tail", () => {
  const base = [
    { id: 1, kind: "run_started", run_id: 1, status: "" },
    { id: 2, kind: "scope_opened", run_id: 1, parent_id: 1, scope_id: 1, status: "opened" },
  ];
  const before = build(base);
  const after = build([...base, { id: 3, kind: "scope_closed", run_id: 1, parent_id: 2, scope_id: 1, status: "closed" }]);

  expect(after.trace.seqIndexById.get("1")).toBe(before.trace.seqIndexById.get("1"));
  expect(after.trace.seqIndexById.get("2")).toBe(before.trace.seqIndexById.get("2"));
  expect(after.trace.seqIndexById.get("3")).toBe(2);
});

test("seqIndexById is stable and ordered when numericId is null (string ids)", () => {
  const { trace } = build([
    { id: "evt-b", kind: "scope_opened", run_id: "r", scope_id: "s", status: "opened" },
    { id: "evt-a", kind: "run_started", run_id: "r", status: "" },
  ]);
  // string ids sort lexicographically via compareEvents fallback.
  const ids = trace.rows.map((row) => row.event.idText);
  expect(ids).toEqual(["evt-a", "evt-b"]);
  expect(trace.rows.map((row) => row.seqIndex)).toEqual([0, 1]);
});

test("scope bands pair opened<->closed; an unclosed scope is open-ended", () => {
  const { trace } = build([
    { id: 1, kind: "run_started", run_id: 1, status: "" },
    { id: 2, kind: "scope_opened", run_id: 1, parent_id: 1, scope_id: 1, status: "opened" },
    { id: 3, kind: "scope_closed", run_id: 1, parent_id: 2, scope_id: 1, status: "closed" },
    { id: 4, kind: "scope_opened", run_id: 1, parent_id: 1, scope_id: 2, status: "opened" },
  ]);

  const closed = trace.scopeBands.find((band) => band.scopeId === "1");
  const open = trace.scopeBands.find((band) => band.scopeId === "2");
  expect(closed?.startIndex).toBe(1);
  expect(closed?.endIndex).toBe(2);
  expect(open?.startIndex).toBe(3);
  expect(open?.endIndex).toBeNull();
});

test("resource tenure is leaked exactly when there is no matching finalization", () => {
  const { trace } = build([
    { id: 1, kind: "run_started", run_id: 1, status: "" },
    { id: 2, kind: "scope_opened", run_id: 1, parent_id: 1, scope_id: 1, status: "opened" },
    { id: 3, kind: "resource_acquired", run_id: 1, parent_id: 2, scope_id: 1, type_name: "Db", status: "success" },
    { id: 4, kind: "resource_acquired", run_id: 1, parent_id: 2, scope_id: 1, type_name: "Cache", status: "success" },
    { id: 5, kind: "resource_finalized", run_id: 1, parent_id: 2, scope_id: 1, type_name: "Db", status: "success" },
  ]);

  const db = trace.resourceTenures.find((tenure) => tenure.label.includes("Db"));
  const cache = trace.resourceTenures.find((tenure) => tenure.label.includes("Cache"));
  expect(db?.leaked).toBe(false);
  expect(db?.finalizeIndex).toBe(4);
  expect(cache?.leaked).toBe(true);
  expect(cache?.finalizeIndex).toBeNull();
});

test("fiber rail is pendingAtScopeClose when the fiber outlives its owning scope", () => {
  const { trace } = build([
    { id: 1, kind: "run_started", run_id: 1, status: "" },
    { id: 2, kind: "scope_opened", run_id: 1, parent_id: 1, scope_id: 1, status: "opened" },
    { id: 3, kind: "fiber_forked", run_id: 1, parent_id: 2, scope_id: 1, fiber_id: 42, status: "pending" },
    { id: 4, kind: "scope_closed", run_id: 1, parent_id: 2, scope_id: 1, status: "closed" },
  ]);

  const rail = trace.fiberRails.find((entry) => entry.fiberId === "42");
  expect(rail?.startIndex).toBe(2);
  expect(rail?.endIndex).toBeNull();
  expect(rail?.pendingAtScopeClose).toBe(true);
});

test("a joined fiber inside a closed scope is not pending", () => {
  const { trace } = build([
    { id: 1, kind: "run_started", run_id: 1, status: "" },
    { id: 2, kind: "scope_opened", run_id: 1, parent_id: 1, scope_id: 1, status: "opened" },
    { id: 3, kind: "fiber_forked", run_id: 1, parent_id: 2, scope_id: 1, fiber_id: 7, status: "pending" },
    { id: 4, kind: "fiber_joined", run_id: 1, parent_id: 3, scope_id: 1, fiber_id: 7, status: "success" },
    { id: 5, kind: "scope_closed", run_id: 1, parent_id: 2, scope_id: 1, status: "closed" },
  ]);

  const rail = trace.fiberRails.find((entry) => entry.fiberId === "7");
  expect(rail?.endIndex).toBe(3);
  expect(rail?.pendingAtScopeClose).toBe(false);
});

test("findingSeverity maps every finding kind to exactly one tier", () => {
  const kinds: CausalFinding["kind"][] = [
    "service_requirement_without_provider",
    "resource_acquired_without_finalization",
    "fiber_pending_after_scope_close",
    "retry_budget_exhausted",
    "finalizer_failure",
    "assertion_failure",
  ];
  for (const kind of kinds) {
    expect(["fail", "warn"]).toContain(findingSeverity(kind));
  }
  expect(findingSeverity("retry_budget_exhausted")).toBe("fail");
  expect(findingSeverity("finalizer_failure")).toBe("fail");
  expect(findingSeverity("assertion_failure")).toBe("fail");
  expect(findingSeverity("service_requirement_without_provider")).toBe("warn");
  expect(findingSeverity("fiber_pending_after_scope_close")).toBe("warn");
  expect(findingSeverity("resource_acquired_without_finalization")).toBe("warn");
});

test("findingMarks share one stable index per event across the model", () => {
  const { model, trace } = build([
    { id: 1, kind: "run_started", run_id: 1, status: "" },
    { id: 2, kind: "service_required", run_id: 1, parent_id: 1, label: "Config", type_name: "Config", status: "missing" },
    { id: 3, kind: "schedule_decision", run_id: 1, parent_id: 1, type_name: "Schedule", status: "exhausted" },
  ]);

  expect(trace.findingMarks.length).toBe(model.findings.length);
  // indices are unique and 1-based, and the per-event lookup agrees with the list.
  const indices = trace.findingMarks.map((mark) => mark.index);
  expect(new Set(indices).size).toBe(indices.length);
  for (const mark of trace.findingMarks) {
    const row = trace.rows.find((candidate) => candidate.event.idText === mark.eventId);
    expect(row?.finding?.index).toBe(mark.index);
    expect(row?.finding?.severity).toBe(mark.severity);
  }
});

test("primary lane index points each event at an existing lane column", () => {
  const { trace } = build([
    { id: 1, kind: "run_started", run_id: 1, status: "" },
    { id: 2, kind: "scope_opened", run_id: 1, parent_id: 1, scope_id: 1, status: "opened" },
    { id: 3, kind: "fiber_forked", run_id: 1, parent_id: 2, scope_id: 1, fiber_id: 9, status: "pending" },
    { id: 4, kind: "schedule_decision", run_id: 1, parent_id: 1, type_name: "Schedule", status: "exhausted" },
  ]);

  for (const row of trace.rows) {
    expect(row.laneIndex).toBeGreaterThanOrEqual(0);
    expect(row.laneIndex).toBeLessThan(trace.laneColumns.length);
  }
  // the fiber event resolves to a fiber-kind lane column.
  const fiberRow = trace.rows.find((row) => row.event.kind === "fiber_forked");
  const column = trace.laneColumns[fiberRow!.laneIndex];
  expect(column?.kind).toBe("fiber");
});

test("resolveEvidenceEventId prefers lastEventId, then eventId, else null", () => {
  const valid = new Set(["10", "11", "12"]);
  expect(resolveEvidenceEventId({ lastEventId: "10", eventId: "11" }, valid)).toBe("10");
  expect(resolveEvidenceEventId({ lastEventId: null, eventId: "12" }, valid)).toBe("12");
  // an id that does not exist in the artifact is not a valid jump target.
  expect(resolveEvidenceEventId({ lastEventId: "999", eventId: "11" }, valid)).toBe("11");
  expect(resolveEvidenceEventId({ lastEventId: "999", eventId: null }, valid)).toBeNull();
  expect(resolveEvidenceEventId({}, valid)).toBeNull();
});
