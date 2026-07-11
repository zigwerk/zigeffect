import type {
  CausalEvent,
  CausalFinding,
  GraphLane,
  GraphLaneKind,
  VisualGraphNodeTone,
} from "../causalArtifact";

// Pure derivation layered on top of the existing `derive*` functions. It turns the
// flat, id-ordered event stream into the geometry a swimlane trace needs: a dense
// sequence index per event (the single source of truth for row position so SVG
// overlays never measure the DOM), one lane column per run/scope/fiber/resource/retry
// group, and the cross-row spans (scope bands, resource tenures, fiber rails) plus
// the shared finding-severity marks. No Solid, no DOM, no wire-format changes.

export type TraceSeverity = "fail" | "warn";

const FINDING_SEVERITY: Record<CausalFinding["kind"], TraceSeverity> = {
  retry_budget_exhausted: "fail",
  finalizer_failure: "fail",
  assertion_failure: "fail",
  service_requirement_without_provider: "warn",
  fiber_pending_after_scope_close: "warn",
  resource_acquired_without_finalization: "warn",
};

/** The single source of truth for "how loud is this finding" across trace, DAG, band. */
export function findingSeverity(kind: CausalFinding["kind"]): TraceSeverity {
  return FINDING_SEVERITY[kind] ?? "warn";
}

export type TraceFindingMark = {
  eventId: string;
  kind: CausalFinding["kind"];
  severity: TraceSeverity;
  title: string;
  index: number;
};

export type TraceLaneColumn = {
  key: string;
  kind: GraphLaneKind;
  label: string;
  status: GraphLane["status"];
  index: number;
};

export type TraceRow = {
  event: CausalEvent;
  seqIndex: number;
  laneIndex: number;
  tone: VisualGraphNodeTone;
  finding: TraceFindingMark | null;
};

export type TraceScopeBand = {
  scopeId: string;
  laneIndex: number;
  startIndex: number;
  endIndex: number | null;
  label: string;
  tone: VisualGraphNodeTone;
};

export type TraceResourceTenure = {
  key: string;
  scopeId: string | null;
  laneIndex: number;
  acquireIndex: number;
  finalizeIndex: number | null;
  leaked: boolean;
  label: string;
};

export type TraceFiberRail = {
  fiberId: string;
  laneIndex: number;
  startIndex: number;
  endIndex: number | null;
  pendingAtScopeClose: boolean;
  label: string;
};

export type TraceModel = {
  rows: TraceRow[];
  laneColumns: TraceLaneColumn[];
  scopeBands: TraceScopeBand[];
  resourceTenures: TraceResourceTenure[];
  fiberRails: TraceFiberRail[];
  findingMarks: TraceFindingMark[];
  seqIndexById: Map<string, number>;
  laneCount: number;
};

const warnStatuses = new Set(["missing", "exhausted", "pending", "running"]);
const fiberLifecycleKinds = new Set([
  "fiber_forked",
  "fiber_started",
  "fiber_joined",
  "fiber_interrupted",
]);
const fiberTerminalKinds = new Set(["fiber_joined", "fiber_interrupted"]);

function laneId(kind: GraphLaneKind, key: string): string {
  return `${kind}::${key}`;
}

function resourceKeyFor(event: CausalEvent): string {
  const name = event.typeName || event.label || "resource";
  return `${event.scopeId ?? "scope-unknown"}:${name}`;
}

function primaryLane(event: CausalEvent): { kind: GraphLaneKind; key: string } | null {
  if (event.kind === "schedule_decision") {
    return { kind: "retry", key: event.runId ?? "run-unknown" };
  }
  if (event.kind === "resource_acquired" || event.kind === "resource_finalized") {
    return { kind: "resource", key: resourceKeyFor(event) };
  }
  if (event.fiberId) {
    return { kind: "fiber", key: event.fiberId };
  }
  if (event.scopeId) {
    return { kind: "scope", key: event.scopeId };
  }
  if (event.runId) {
    return { kind: "run", key: event.runId };
  }
  return null;
}

function toneForLane(status: GraphLane["status"]): VisualGraphNodeTone {
  if (status === "failure") return "failure";
  if (status === "warning") return "warning";
  return "ok";
}

function rowTone(event: CausalEvent, hasFinding: boolean): VisualGraphNodeTone {
  if (event.status === "failure") return "failure";
  if (hasFinding || warnStatuses.has(event.status)) return "warning";
  return "ok";
}

export function deriveTraceModel(
  events: CausalEvent[],
  lanes: GraphLane[],
  findings: CausalFinding[],
): TraceModel {
  const seqIndexById = new Map<string, number>();
  events.forEach((event, index) => seqIndexById.set(event.idText, index));

  const laneColumns: TraceLaneColumn[] = lanes.map((lane, index) => ({
    key: lane.key,
    kind: lane.kind,
    label: lane.label,
    status: lane.status,
    index,
  }));
  const laneIndexById = new Map<string, number>();
  laneColumns.forEach((column) => laneIndexById.set(laneId(column.kind, column.key), column.index));

  const fallbackLaneIndex = laneColumns.length > 0 ? 0 : -1;
  const laneIndexFor = (event: CausalEvent): number => {
    const lane = primaryLane(event);
    if (!lane) {
      return fallbackLaneIndex;
    }
    return laneIndexById.get(laneId(lane.kind, lane.key)) ?? fallbackLaneIndex;
  };

  const findingMarks: TraceFindingMark[] = findings.map((finding, index) => ({
    eventId: finding.eventId,
    kind: finding.kind,
    severity: findingSeverity(finding.kind),
    title: finding.title,
    index: index + 1,
  }));
  const markByEvent = new Map<string, TraceFindingMark>();
  for (const mark of findingMarks) {
    if (!markByEvent.has(mark.eventId)) {
      markByEvent.set(mark.eventId, mark);
    }
  }

  const rows: TraceRow[] = events.map((event, index) => {
    const finding = markByEvent.get(event.idText) ?? null;
    return {
      event,
      seqIndex: index,
      laneIndex: laneIndexFor(event),
      tone: rowTone(event, finding !== null),
      finding,
    };
  });

  const laneStatusById = new Map<string, GraphLane["status"]>();
  for (const column of laneColumns) {
    laneStatusById.set(laneId(column.kind, column.key), column.status);
  }

  const scopeBands = deriveScopeBands(events, seqIndexById, laneIndexById, laneStatusById);
  const scopeBandById = new Map(scopeBands.map((band) => [band.scopeId, band]));

  return {
    rows,
    laneColumns,
    scopeBands,
    resourceTenures: deriveResourceTenures(events, seqIndexById, laneIndexById, markByEvent),
    fiberRails: deriveFiberRails(events, seqIndexById, laneIndexById, scopeBandById),
    findingMarks,
    seqIndexById,
    laneCount: laneColumns.length,
  };
}

function deriveScopeBands(
  events: CausalEvent[],
  seqIndexById: Map<string, number>,
  laneIndexById: Map<string, number>,
  laneStatusById: Map<string, GraphLane["status"]>,
): TraceScopeBand[] {
  const bands = new Map<string, TraceScopeBand>();

  for (const event of events) {
    if (event.kind !== "scope_opened" && event.kind !== "scope_closed") {
      continue;
    }
    const scopeId = event.scopeId;
    if (!scopeId) {
      continue;
    }
    const at = seqIndexById.get(event.idText) ?? 0;
    const key = laneId("scope", scopeId);
    let band = bands.get(scopeId);
    if (!band) {
      band = {
        scopeId,
        laneIndex: laneIndexById.get(key) ?? 0,
        startIndex: at,
        endIndex: null,
        label: event.label || `scope ${scopeId}`,
        tone: toneForLane(laneStatusById.get(key) ?? "ok"),
      };
      bands.set(scopeId, band);
    }
    if (event.kind === "scope_opened") {
      band.startIndex = Math.min(band.startIndex, at);
      if (event.label) {
        band.label = event.label;
      }
    } else {
      band.endIndex = at;
    }
  }

  return Array.from(bands.values());
}

function deriveResourceTenures(
  events: CausalEvent[],
  seqIndexById: Map<string, number>,
  laneIndexById: Map<string, number>,
  markByEvent: Map<string, TraceFindingMark>,
): TraceResourceTenure[] {
  const finalizers = events
    .map((event, index) => ({ event, index }))
    .filter((entry) => entry.event.kind === "resource_finalized");
  const usedFinalizers = new Set<number>();
  const tenures: TraceResourceTenure[] = [];

  for (const event of events) {
    if (event.kind !== "resource_acquired") {
      continue;
    }
    const acquireIndex = seqIndexById.get(event.idText) ?? 0;
    const match = finalizers.find((entry) =>
      !usedFinalizers.has(entry.index) &&
      entry.event.scopeId === event.scopeId &&
      entry.event.typeName === event.typeName &&
      entry.index >= acquireIndex,
    );
    if (match) {
      usedFinalizers.add(match.index);
    }
    const mark = markByEvent.get(event.idText);
    const leaked = mark?.kind === "resource_acquired_without_finalization";
    const key = resourceKeyFor(event);
    tenures.push({
      key,
      scopeId: event.scopeId,
      laneIndex: laneIndexById.get(laneId("resource", key)) ?? 0,
      acquireIndex,
      finalizeIndex: match ? match.index : null,
      leaked,
      label: event.typeName || event.label || "resource",
    });
  }

  return tenures;
}

function deriveFiberRails(
  events: CausalEvent[],
  seqIndexById: Map<string, number>,
  laneIndexById: Map<string, number>,
  scopeBandById: Map<string, TraceScopeBand>,
): TraceFiberRail[] {
  const rails = new Map<string, {
    fiberId: string;
    startIndex: number;
    endIndex: number | null;
    owningScopeId: string | null;
    label: string;
  }>();

  for (const event of events) {
    if (!fiberLifecycleKinds.has(event.kind)) {
      continue;
    }
    const fiberId = event.fiberId;
    if (!fiberId) {
      continue;
    }
    const at = seqIndexById.get(event.idText) ?? 0;
    let rail = rails.get(fiberId);
    if (!rail) {
      rail = {
        fiberId,
        startIndex: at,
        endIndex: null,
        owningScopeId: event.scopeId,
        label: event.label || `fiber ${fiberId}`,
      };
      rails.set(fiberId, rail);
    }
    rail.startIndex = Math.min(rail.startIndex, at);
    if (event.scopeId && !rail.owningScopeId) {
      rail.owningScopeId = event.scopeId;
    }
    if (fiberTerminalKinds.has(event.kind)) {
      rail.endIndex = rail.endIndex === null ? at : Math.max(rail.endIndex, at);
    }
  }

  return Array.from(rails.values()).map((rail) => {
    const scopeBand = rail.owningScopeId ? scopeBandById.get(rail.owningScopeId) : undefined;
    const scopeEnd = scopeBand?.endIndex ?? null;
    const pendingAtScopeClose = scopeEnd !== null &&
      (rail.endIndex === null || rail.endIndex > scopeEnd);
    return {
      fiberId: rail.fiberId,
      laneIndex: laneIndexById.get(laneId("fiber", rail.fiberId)) ?? 0,
      startIndex: rail.startIndex,
      endIndex: rail.endIndex,
      pendingAtScopeClose,
      label: rail.label,
    };
  });
}

/**
 * Best causal-event jump target for a collaboration entity (agent/check/turn).
 * Resolution order: lastEventId -> eventId -> null. Only returns an id that is a real
 * event in the loaded artifact, so an "Evidence" jump never points at nothing; a null
 * result is an honest "no causal evidence" outcome the UI renders as such.
 */
export function resolveEvidenceEventId(
  candidate: { lastEventId?: string | null; eventId?: string | null },
  validEventIds: Set<string>,
): string | null {
  const ordered = [candidate.lastEventId, candidate.eventId];
  for (const id of ordered) {
    if (typeof id === "string" && id.length > 0 && validEventIds.has(id)) {
      return id;
    }
  }
  return null;
}
