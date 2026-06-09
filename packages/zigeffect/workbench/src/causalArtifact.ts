export type UnknownRecord = Record<string, unknown>;

export type CausalEvent = {
  idText: string;
  numericId: number | null;
  kind: string;
  status: string;
  label: string;
  typeName: string;
  redactedDetail: string;
  runId: string | null;
  parentId: string | null;
  fiberId: string | null;
  scopeId: string | null;
  traceId: string | null;
  spanId: string | null;
  raw: UnknownRecord;
};

export type CausalFinding = {
  kind:
    | "service_requirement_without_provider"
    | "resource_acquired_without_finalization"
    | "fiber_pending_after_scope_close"
    | "retry_budget_exhausted"
    | "finalizer_failure"
    | "assertion_failure";
  eventId: string;
  title: string;
  summary: string;
  event: CausalEvent;
};

export type QueryCommand = {
  label: string;
  command: string;
};

export type GraphEdge = {
  from: string;
  to: string;
  kind: "parent";
  label: string;
};

export type GraphLaneKind = "run" | "scope" | "fiber" | "resource" | "retry";

export type GraphLane = {
  kind: GraphLaneKind;
  key: string;
  label: string;
  status: "ok" | "warning" | "failure";
  events: CausalEvent[];
  findingEventIds: string[];
};

export type GraphModel = {
  roots: CausalEvent[];
  orphans: CausalEvent[];
  parentEdges: GraphEdge[];
  lanes: GraphLane[];
  unhealthyLanes: GraphLane[];
};

export type GovernanceArtifactKind =
  | "audit-chain"
  | "remediation-audit"
  | "app-remediation-audit"
  | "remediation-decision"
  | "patch-proposal"
  | "registry-readiness"
  | "registry-application"
  | "policy-decision";

export type ChainSourceKind = "session" | "audit" | "decision" | "proposal" | "before" | "after" | "compare";

export type ChainSourceStep = {
  kind: ChainSourceKind;
  label: string;
  path: string;
  workbenchCommand: string | null;
};

export type EventClassifications = {
  eventIds: string[];
  disappeared: string[];
  persisting: string[];
  appeared: string[];
  missing: string[];
};

export type RemediationChainModel = {
  artifactPath: string;
  schema: string;
  schemaVersion: string;
  kind: "audit-chain";
  mode: string;
  target: string;
  assessment: string;
  proposalStatus: string;
  approvalStatus: string;
  approved: boolean | null;
  applied: boolean | null;
  findingDelta: string;
  sourceSteps: ChainSourceStep[];
  classifications: EventClassifications;
  verificationCommands: string[];
  guardrails: string[];
  warnings: string[];
};

export type GovernanceModel = {
  artifactPath: string;
  schema: string;
  schemaVersion: string;
  kind: GovernanceArtifactKind;
  target: string;
  summary: string;
  applied: boolean | null;
  mutationAuthority: string | null;
  chain: RemediationChainModel | null;
  warnings: string[];
};

export type WorkbenchModel = {
  artifactPath: string;
  schema: string;
  schemaVersion: string;
  taxonomyVersion: string;
  events: CausalEvent[];
  findings: CausalFinding[];
  kinds: string[];
  statuses: string[];
  warnings: string[];
  safeToShare: "artifact-redacted" | "unknown";
};

export type WorkbenchOptions = {
  artifactPath: string;
};

export type EventFilter = {
  text?: string;
  kind?: string;
  status?: string;
};

const fiberLifecycleKinds = new Set([
  "fiber_forked",
  "fiber_started",
  "fiber_joined",
  "fiber_interrupted",
]);

const pendingFiberStatuses = new Set(["pending", "running"]);
const graphFailureStatuses = new Set(["failure"]);
const graphWarningStatuses = new Set(["missing", "exhausted", "pending", "running"]);
const graphLaneKindOrder: GraphLaneKind[] = ["run", "scope", "fiber", "resource", "retry"];
const auditChainSchema = "zigeffect.causal.audit-chain.v1";
const chainSourceKinds: ChainSourceKind[] = ["session", "audit", "decision", "proposal", "before", "after", "compare"];
const chainSourceLabels: Record<ChainSourceKind, string> = {
  session: "Dev session",
  audit: "Remediation audit",
  decision: "Manual decision",
  proposal: "Patch proposal",
  before: "Before artifact",
  after: "After artifact",
  compare: "Compare report",
};

export function parseArtifactJson(json: string): unknown {
  const parsed = JSON.parse(json) as unknown;
  if (!isRecord(parsed)) {
    throw new Error("causal artifact must be a JSON object");
  }
  return parsed;
}

export function deriveWorkbenchModel(raw: unknown, options: WorkbenchOptions): WorkbenchModel {
  const artifact = isRecord(raw) ? raw : {};
  const warnings: string[] = [];
  const schema = textValue(artifact.schema, "unknown");
  const schemaVersion = textValue(artifact.schema_version, "unknown");
  const taxonomyVersion = textValue(artifact.event_taxonomy_version, "unknown");

  if (schema === "unknown") {
    warnings.push("artifact schema is missing");
  }
  if (schemaVersion === "unknown") {
    warnings.push("artifact schema_version is missing");
  }
  if (taxonomyVersion === "unknown") {
    warnings.push("artifact event_taxonomy_version is missing");
  }

  const rawEvents = Array.isArray(artifact.events) ? artifact.events : [];
  if (!Array.isArray(artifact.events)) {
    warnings.push("artifact events array is missing");
  }

  const events = rawEvents
    .filter(isRecord)
    .map((event, index) => normalizeEvent(event, index))
    .sort(compareEvents);

  return {
    artifactPath: options.artifactPath,
    schema,
    schemaVersion,
    taxonomyVersion,
    events,
    findings: deriveFindings(events),
    kinds: uniqueSorted(events.map((event) => event.kind)),
    statuses: uniqueSorted(events.map((event) => event.status)),
    warnings,
    safeToShare: events.some((event) => event.redactedDetail.length > 0) ? "artifact-redacted" : "unknown",
  };
}

export function filterEvents(events: CausalEvent[], filter: EventFilter): CausalEvent[] {
  const text = filter.text?.trim().toLowerCase() ?? "";
  const kind = filter.kind?.trim();
  const status = filter.status?.trim();

  return events.filter((event) => {
    if (kind && event.kind !== kind) {
      return false;
    }
    if (status && event.status !== status) {
      return false;
    }
    if (!text) {
      return true;
    }
    return searchableEventText(event).includes(text);
  });
}

export function queryCommandsForEvent(event: CausalEvent, artifactPath: string): QueryCommand[] {
  const prefix = `zig build causal-query -- --file ${artifactPath}`;
  const commands: QueryCommand[] = [
    { label: "Cause", command: `${prefix} cause ${event.idText}` },
    { label: "Lineage", command: `${prefix} lineage ${event.idText}` },
  ];

  if (event.scopeId) {
    commands.push({ label: "Resources", command: `${prefix} resources ${event.scopeId}` });
  }

  if (fiberLifecycleKinds.has(event.kind) && pendingFiberStatuses.has(event.status)) {
    commands.push({ label: "Pending fibers", command: `${prefix} fibers ${event.status}` });
  }

  if (event.runId) {
    commands.push({ label: "Requirements", command: `${prefix} requirements ${event.runId}` });
  }

  if (event.kind === "schedule_decision" && event.runId) {
    commands.push({ label: "Retries", command: `${prefix} retries ${event.runId}` });
  }

  return commands;
}

export function deriveGraphModel(events: CausalEvent[], findings: CausalFinding[]): GraphModel {
  const byId = eventMap(events);
  const roots: CausalEvent[] = [];
  const orphans: CausalEvent[] = [];
  const parentEdges: GraphEdge[] = [];

  for (const event of events) {
    if (!event.parentId) {
      roots.push(event);
      continue;
    }

    if (byId.has(event.parentId)) {
      parentEdges.push({
        from: event.parentId,
        to: event.idText,
        kind: "parent",
        label: "parent",
      });
    } else {
      orphans.push(event);
    }
  }

  const findingEventIds = new Set(findings.map((finding) => finding.eventId));
  const lanes = [
    ...groupLaneByEventField("run", "run", events, "runId", findingEventIds),
    ...groupLaneByEventField("scope", "scope", events, "scopeId", findingEventIds),
    ...groupLaneByEventField("fiber", "fiber", events, "fiberId", findingEventIds),
    ...resourceLanes(events, findingEventIds),
    ...retryLanes(events, findingEventIds),
  ].sort(compareGraphLanes);

  return {
    roots,
    orphans,
    parentEdges,
    lanes,
    unhealthyLanes: lanes.filter((lane) => lane.status !== "ok"),
  };
}

export function causePathForEvent(events: CausalEvent[], eventId: string): CausalEvent[] {
  const byId = eventMap(events);
  const path: CausalEvent[] = [];
  const seen = new Set<string>();
  let current = byId.get(eventId) ?? null;

  while (current) {
    path.push(current);
    seen.add(current.idText);

    if (!current.parentId || seen.has(current.parentId)) {
      break;
    }

    current = byId.get(current.parentId) ?? null;
  }

  return path.reverse();
}

export function deriveRemediationChainModel(raw: unknown, options: WorkbenchOptions): RemediationChainModel | null {
  const artifact = isRecord(raw) ? raw : {};
  const schema = textValue(artifact.schema, "unknown");
  if (schema !== auditChainSchema) {
    return null;
  }

  const warnings: string[] = [];
  const schemaVersion = textValue(artifact.schema_version, "unknown");
  if (schemaVersion === "unknown") {
    warnings.push("artifact schema_version is missing");
  }

  const source = isRecord(artifact.source) ? artifact.source : {};
  if (!isRecord(artifact.source)) {
    warnings.push("artifact source object is missing");
  }

  return {
    artifactPath: options.artifactPath,
    schema,
    schemaVersion,
    kind: "audit-chain",
    mode: textValue(artifact.mode, "unknown"),
    target: textValue(artifact.target, "unknown"),
    assessment: textValue(artifact.assessment, "unknown"),
    proposalStatus: textValue(artifact.proposal_status, "unknown"),
    approvalStatus: textValue(artifact.approval_status, "unknown"),
    approved: booleanValue(artifact.approved),
    applied: booleanValue(artifact.applied),
    findingDelta: textValue(artifact.finding_delta, "unknown"),
    sourceSteps: chainSourceSteps(source),
    classifications: {
      eventIds: eventIdList(artifact.event_ids),
      disappeared: eventIdList(artifact.disappeared_event_ids),
      persisting: eventIdList(artifact.persisting_event_ids),
      appeared: eventIdList(artifact.appeared_event_ids),
      missing: eventIdList(artifact.missing_event_ids),
    },
    verificationCommands: stringList(artifact.verification_commands),
    guardrails: uniqueInOrder([
      ...stringList(artifact.claim_guardrails),
      ...stringList(artifact.proposal_guardrails),
      ...stringList(artifact.chain_guardrails),
    ]),
    warnings,
  };
}

export function deriveGovernanceModel(raw: unknown, options: WorkbenchOptions): GovernanceModel | null {
  const artifact = isRecord(raw) ? raw : {};
  const schema = textValue(artifact.schema, "unknown");
  const kind = governanceKindForSchema(schema);
  if (!kind) {
    return null;
  }

  const chain = deriveRemediationChainModel(raw, options);
  const schemaVersion = textValue(artifact.schema_version, "unknown");
  const target = textValue(artifact.target, "unknown");
  const warnings = chain?.warnings ?? (schemaVersion === "unknown" ? ["artifact schema_version is missing"] : []);
  const incidentCount = numericValue(artifact.incident_count);
  const summary = kind === "app-remediation-audit" && incidentCount !== null
    ? `${incidentCount} app incidents for ${target}`
    : chain
      ? `${chain.assessment} audit chain for ${target}`
      : `${kind} for ${target}`;

  return {
    artifactPath: options.artifactPath,
    schema,
    schemaVersion,
    kind,
    target,
    summary,
    applied: booleanValue(artifact.applied),
    mutationAuthority: nullableTextValue(artifact.mutation_authority),
    chain,
    warnings,
  };
}

function deriveFindings(events: CausalEvent[]): CausalFinding[] {
  const findings: CausalFinding[] = [];

  for (const event of events) {
    switch (event.kind) {
      case "resource_acquired":
        if (!hasFinalizedResource(events, event)) {
          findings.push(finding(
            "resource_acquired_without_finalization",
            event,
            "Resource acquired without finalization",
            "An acquired resource has no matching finalization event in this artifact.",
          ));
        }
        break;
      case "scope_closed":
        findings.push(...pendingFiberFindings(events, event));
        break;
      case "resource_finalized":
        if (event.status === "failure") {
          findings.push(finding(
            "finalizer_failure",
            event,
            "Finalizer failure",
            "A resource finalizer failed and remains causal evidence.",
          ));
        }
        break;
      case "schedule_decision":
        if (event.status === "exhausted") {
          findings.push(finding(
            "retry_budget_exhausted",
            event,
            "Retry budget exhausted",
            "A schedule decision exhausted its retry budget.",
          ));
        }
        break;
      case "service_required":
        if (event.status === "missing") {
          findings.push(finding(
            "service_requirement_without_provider",
            event,
            "Missing service provider",
            "A required service was missing from the environment.",
          ));
        }
        break;
      case "assertion_recorded":
        if (event.status === "failure") {
          findings.push(finding(
            "assertion_failure",
            event,
            "Assertion failure",
            "A test or development assertion was recorded as failed.",
          ));
        }
        break;
      default:
        break;
    }
  }

  return findings;
}

function eventMap(events: CausalEvent[]): Map<string, CausalEvent> {
  return new Map(events.map((event) => [event.idText, event]));
}

function groupLaneByEventField(
  kind: GraphLaneKind,
  labelPrefix: string,
  events: CausalEvent[],
  field: "runId" | "scopeId" | "fiberId",
  findingEventIds: Set<string>,
): GraphLane[] {
  const groups = new Map<string, CausalEvent[]>();

  for (const event of events) {
    const key = event[field];
    if (!key) {
      continue;
    }
    const existing = groups.get(key) ?? [];
    existing.push(event);
    groups.set(key, existing);
  }

  return Array.from(groups, ([key, laneEvents]) => graphLane(kind, key, `${labelPrefix} ${key}`, laneEvents, findingEventIds));
}

function resourceLanes(events: CausalEvent[], findingEventIds: Set<string>): GraphLane[] {
  const groups = new Map<string, CausalEvent[]>();

  for (const event of events) {
    if (event.kind !== "resource_acquired" && event.kind !== "resource_finalized") {
      continue;
    }

    const resourceName = event.typeName || event.label || "resource";
    const key = `${event.scopeId ?? "scope-unknown"}:${resourceName}`;
    const existing = groups.get(key) ?? [];
    existing.push(event);
    groups.set(key, existing);
  }

  return Array.from(groups, ([key, laneEvents]) => graphLane("resource", key, key, laneEvents, findingEventIds));
}

function retryLanes(events: CausalEvent[], findingEventIds: Set<string>): GraphLane[] {
  const groups = new Map<string, CausalEvent[]>();

  for (const event of events) {
    if (event.kind !== "schedule_decision") {
      continue;
    }

    const key = event.runId ?? "run-unknown";
    const existing = groups.get(key) ?? [];
    existing.push(event);
    groups.set(key, existing);
  }

  return Array.from(groups, ([key, laneEvents]) => graphLane("retry", key, `retry ${key}`, laneEvents, findingEventIds));
}

function graphLane(
  kind: GraphLaneKind,
  key: string,
  label: string,
  events: CausalEvent[],
  allFindingEventIds: Set<string>,
): GraphLane {
  const findingEventIds = events
    .map((event) => event.idText)
    .filter((eventId) => allFindingEventIds.has(eventId));

  return {
    kind,
    key,
    label,
    status: graphLaneStatus(events, findingEventIds),
    events,
    findingEventIds,
  };
}

function graphLaneStatus(events: CausalEvent[], findingEventIds: string[]): GraphLane["status"] {
  if (events.some((event) => graphFailureStatuses.has(event.status))) {
    return "failure";
  }
  if (
    findingEventIds.length > 0 ||
    events.some((event) => graphWarningStatuses.has(event.status))
  ) {
    return "warning";
  }
  return "ok";
}

function compareGraphLanes(left: GraphLane, right: GraphLane): number {
  const leftKind = graphLaneKindOrder.indexOf(left.kind);
  const rightKind = graphLaneKindOrder.indexOf(right.kind);
  if (leftKind !== rightKind) {
    return leftKind - rightKind;
  }
  return left.key.localeCompare(right.key);
}

function governanceKindForSchema(schema: string): GovernanceArtifactKind | null {
  switch (schema) {
    case auditChainSchema:
      return "audit-chain";
    case "zigeffect.causal.remediation-audit.v1":
      return "remediation-audit";
    case "zigeffect.causal.app-remediation-audit.v1":
      return "app-remediation-audit";
    case "zigeffect.causal.remediation-decision.v1":
      return "remediation-decision";
    case "zigeffect.causal.patch-proposal.v1":
      return "patch-proposal";
    case "zigeffect.causal.registry-application-readiness.v1":
      return "registry-readiness";
    case "zigeffect.causal.registry-application.v1":
      return "registry-application";
    case "zigeffect.causal.policy-decision.v1":
      return "policy-decision";
    default:
      return null;
  }
}

function chainSourceSteps(source: UnknownRecord): ChainSourceStep[] {
  return chainSourceKinds.flatMap((kind) => {
    const path = textValue(source[kind], "");
    if (!path) {
      return [];
    }

    return [{
      kind,
      label: chainSourceLabels[kind],
      path,
      workbenchCommand: workbenchCommandForPath(path),
    }];
  });
}

function workbenchCommandForPath(path: string): string | null {
  return path.endsWith(".json") ? `zig build causal-workbench -- ${path}` : null;
}

function eventIdList(value: unknown): string[] {
  if (!Array.isArray(value)) {
    return [];
  }
  return value
    .map(idValue)
    .filter((id): id is string => id !== null);
}

function stringList(value: unknown): string[] {
  if (!Array.isArray(value)) {
    return [];
  }
  return value
    .map((item) => textValue(item, ""))
    .filter((item) => item.length > 0);
}

function uniqueInOrder(values: string[]): string[] {
  return Array.from(new Set(values));
}

function pendingFiberFindings(events: CausalEvent[], closed: CausalEvent): CausalFinding[] {
  if (!closed.scopeId) {
    return [];
  }

  return events
    .filter((event) => event.scopeId === closed.scopeId)
    .filter((event) => event.fiberId !== null)
    .filter((event) => event.kind === "fiber_forked" || event.kind === "fiber_started")
    .filter((event) => pendingFiberStatuses.has(event.status))
    .filter((event) => !fiberCompletedAfter(events, event.fiberId, closed.numericId))
    .map((event) => finding(
      "fiber_pending_after_scope_close",
      event,
      "Pending fiber after scope close",
      "A scoped fiber was still pending or running when its owning scope closed.",
    ));
}

function hasFinalizedResource(events: CausalEvent[], acquired: CausalEvent): boolean {
  return events.some((event) => (
    event.kind === "resource_finalized" &&
    event.scopeId === acquired.scopeId &&
    event.typeName === acquired.typeName
  ));
}

function fiberCompletedAfter(
  events: CausalEvent[],
  fiberId: string | null,
  closedNumericId: number | null,
): boolean {
  if (!fiberId || closedNumericId === null) {
    return false;
  }

  return events.some((event) => (
    event.numericId !== null &&
    event.numericId >= closedNumericId &&
    event.fiberId === fiberId &&
    (event.kind === "fiber_joined" || event.kind === "fiber_interrupted")
  ));
}

function finding(
  kind: CausalFinding["kind"],
  event: CausalEvent,
  title: string,
  summary: string,
): CausalFinding {
  return {
    kind,
    eventId: event.idText,
    title,
    summary,
    event,
  };
}

function normalizeEvent(raw: UnknownRecord, index: number): CausalEvent {
  const idText = idValue(raw.id) ?? `event-${index + 1}`;

  return {
    idText,
    numericId: numericValue(raw.id),
    kind: textValue(raw.kind, "unknown"),
    status: textValue(raw.status, "unknown"),
    label: textValue(raw.label, ""),
    typeName: textValue(raw.type_name, ""),
    redactedDetail: textValue(raw.redacted_detail, ""),
    runId: nullableIdValue(raw.run_id),
    parentId: nullableIdValue(raw.parent_id),
    fiberId: nullableIdValue(raw.fiber_id),
    scopeId: nullableIdValue(raw.scope_id),
    traceId: nullableIdValue(raw.trace_id),
    spanId: nullableIdValue(raw.span_id),
    raw,
  };
}

function compareEvents(left: CausalEvent, right: CausalEvent): number {
  if (left.numericId !== null && right.numericId !== null) {
    return left.numericId - right.numericId;
  }
  if (left.numericId !== null) {
    return -1;
  }
  if (right.numericId !== null) {
    return 1;
  }
  return left.idText.localeCompare(right.idText);
}

function searchableEventText(event: CausalEvent): string {
  return [
    event.idText,
    event.kind,
    event.status,
    event.label,
    event.typeName,
    event.redactedDetail,
    event.runId,
    event.parentId,
    event.fiberId,
    event.scopeId,
    event.traceId,
    event.spanId,
  ]
    .filter((value): value is string => typeof value === "string")
    .join(" ")
    .toLowerCase();
}

function uniqueSorted(values: string[]): string[] {
  return Array.from(new Set(values.filter((value) => value.length > 0))).sort((left, right) =>
    left.localeCompare(right),
  );
}

function textValue(value: unknown, fallback: string): string {
  if (typeof value === "string") {
    return value.length > 0 ? value : fallback;
  }
  if (typeof value === "number" && Number.isFinite(value)) {
    return String(value);
  }
  if (typeof value === "boolean") {
    return String(value);
  }
  return fallback;
}

function nullableTextValue(value: unknown): string | null {
  const text = textValue(value, "");
  return text.length > 0 ? text : null;
}

function booleanValue(value: unknown): boolean | null {
  return typeof value === "boolean" ? value : null;
}

function idValue(value: unknown): string | null {
  if (typeof value === "string" && value.length > 0) {
    return value;
  }
  if (typeof value === "number" && Number.isFinite(value)) {
    return String(value);
  }
  return null;
}

function nullableIdValue(value: unknown): string | null {
  return idValue(value);
}

function numericValue(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === "string" && value.trim().length > 0) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function isRecord(value: unknown): value is UnknownRecord {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
