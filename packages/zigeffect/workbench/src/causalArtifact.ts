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
  artifactId: string;
  domainEntityRef: string;
  dataSubjectRef: string;
  schemaRef: string;
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

export type VisualGraphLayoutMode = "dagre" | "force" | "radial";

export type VisualGraphPerspective = "cause" | "topology" | "ownership" | "lineage";

export type VisualGraphNodeTone = "ok" | "warning" | "failure";

export type VisualGraphNodePriority = "normal" | "watch" | "critical";

export type VisualGraphNodeGroup =
  | "event"
  | "run"
  | "scope"
  | "fiber"
  | "resource"
  | "retry"
  | "service"
  | "artifact"
  | "data";

export type VisualGraphEdgeKind =
  | "parent"
  | "caused_by"
  | "owns"
  | "finalizes"
  | "requires"
  | "reads"
  | "writes"
  | "transforms"
  | "emits";

export type VisualGraphRefSet = {
  artifactId: string | null;
  domainEntityRef: string | null;
  dataSubjectRef: string | null;
  schemaRef: string | null;
};

export type VisualGraphLegendEntry = {
  id: string;
  label: string;
  tone: VisualGraphNodeTone;
  detail: string;
};

export type VisualGraphNode = {
  id: string;
  eventId: string | null;
  label: string;
  detail: string;
  kind: string;
  status: string;
  lane: string;
  group: VisualGraphNodeGroup;
  refs: VisualGraphRefSet;
  tone: VisualGraphNodeTone;
  priority: VisualGraphNodePriority;
};

export type VisualGraphEdge = {
  id: string;
  source: string;
  target: string;
  label: string;
  detail: string;
  kind: VisualGraphEdgeKind;
  tone: VisualGraphNodeTone;
};

export type VisualGraphModel = {
  perspective: VisualGraphPerspective;
  layoutMode: VisualGraphLayoutMode;
  nodes: VisualGraphNode[];
  edges: VisualGraphEdge[];
  legend: VisualGraphLegendEntry[];
  warnings: string[];
  adapter: {
    solid: "@dschz/solid-g6";
    engine: "@antv/g6";
    directEngineApi: "not-required";
  };
};

export type VisualGraphOptions = {
  layoutMode: VisualGraphLayoutMode;
  perspective?: VisualGraphPerspective;
  selectedEventId?: string | null;
};

export type GovernanceArtifactKind =
  | "audit-chain"
  | "remediation-audit"
  | "app-remediation-audit"
  | "app-policy-decision"
  | "app-human-review"
  | "app-patch-proposal"
  | "app-application-readiness"
  | "app-application"
  | "remediation-decision"
  | "patch-proposal"
  | "registry-readiness"
  | "registry-application"
  | "policy-decision";

export type ChainSourceKind =
  | "session"
  | "audit"
  | "decision"
  | "proposal"
  | "before"
  | "after"
  | "compare";

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

export type AppRemediationArtifactKind =
  | "app-remediation-audit"
  | "app-policy-decision"
  | "app-human-review"
  | "app-patch-proposal"
  | "app-application-readiness"
  | "app-application";

export type AppIncidentModel = {
  action: string;
  eventId: string;
  eventKind: string;
  label: string;
  subsystem: string;
  fixCategory: string;
  policyGate: string;
  queryCommands: string[];
};

export type AppGateResultModel = {
  gate: string;
  status: string;
  detail: string;
};

export type AppCitationGroup = {
  label: string;
  values: string[];
};

export type AppReadinessCheckModel = {
  name: string;
  status: string;
  detail: string;
};

export type AppRemediationModel = {
  artifactPath: string;
  schema: string;
  schemaVersion: string;
  kind: AppRemediationArtifactKind;
  mode: string;
  target: string;
  summary: string;
  decision: string;
  applicationStatus: string;
  proposalStatus: string;
  readinessStatus: string;
  approvalStatus: string;
  approved: boolean | null;
  readyForApplication: boolean | null;
  applied: boolean | null;
  mutationAuthority: string | null;
  sourceSteps: ChainSourceStep[];
  incidents: AppIncidentModel[];
  policyGates: string[];
  gateResults: AppGateResultModel[];
  citations: AppCitationGroup[];
  changeEvidence: AppCitationGroup[];
  beforeEvidence: string[];
  afterEvidence: string[];
  checks: AppReadinessCheckModel[];
  eventIds: string[];
  verificationCommands: string[];
  applicationSteps: string[];
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
  app: AppRemediationModel | null;
  warnings: string[];
};

export type LocalDevAgentKind = "codex" | "claude-code" | "zigeffect" | "human" | "other";

export type LocalDevAgentStatus = "idle" | "running" | "reviewing" | "blocked" | "done" | "failed" | "unknown";

export type LocalDevCheckStatus = "pass" | "fail" | "running" | "skipped" | "unknown";

export type LocalDevAgentModel = {
  id: string;
  label: string;
  kind: LocalDevAgentKind;
  status: LocalDevAgentStatus;
  currentTask: string | null;
  lastEventId: string | null;
  artifactPath: string | null;
};

export type LocalDevCheckModel = {
  label: string;
  command: string | null;
  status: LocalDevCheckStatus;
  detail: string;
  artifactPath: string | null;
};

export type LocalDevCommandModel = {
  label: string;
  command: string;
  status: LocalDevCheckStatus;
  exitCode: number | null;
  stdoutSnippet: string;
  stderrSnippet: string;
};

export type LocalDevArtifactModel = {
  key: string;
  label: string;
  path: string;
  kind: "json" | "text" | "markdown" | "other";
  workbenchCommand: string | null;
};

export type LocalDevSessionModel = {
  artifactPath: string;
  schema: string;
  schemaVersion: string;
  mode: string;
  sessionId: string;
  title: string;
  goal: string;
  target: string;
  phase: string;
  status: string;
  agents: LocalDevAgentModel[];
  checks: LocalDevCheckModel[];
  commands: LocalDevCommandModel[];
  artifacts: LocalDevArtifactModel[];
  nextActions: string[];
  guardrails: string[];
  warnings: string[];
};

export type SemanticDiffSummary = {
  resolvedFindings: number;
  introducedFindings: number;
  addedFiberTerminals: number;
  removedFiberTerminals: number;
  addedResourceFinalizations: number;
  removedResourceFinalizations: number;
  addedLineageEdges: number;
  removedLineageEdges: number;
};

export type SemanticDiffFinding = {
  kind: string;
  eventId: string;
  owner: string;
};

export type SemanticDiffFiberTerminal = {
  fiberId: string;
  terminalKind: string;
  status: string;
  eventId: string;
};

export type SemanticDiffResourceFinalization = {
  scopeId: string;
  resourceId: string;
  typeName: string;
  eventId: string;
};

export type SemanticDiffLineageEdge = {
  fromEventId: string;
  toEventId: string;
  edgeKind: string;
};

export type SemanticDiffModel = {
  artifactPath: string;
  schema: string;
  beforeArtifact: string;
  afterArtifact: string;
  summary: SemanticDiffSummary;
  resolvedFindings: SemanticDiffFinding[];
  introducedFindings: SemanticDiffFinding[];
  addedFiberTerminals: SemanticDiffFiberTerminal[];
  removedFiberTerminals: SemanticDiffFiberTerminal[];
  addedResourceFinalizations: SemanticDiffResourceFinalization[];
  removedResourceFinalizations: SemanticDiffResourceFinalization[];
  addedLineageEdges: SemanticDiffLineageEdge[];
  removedLineageEdges: SemanticDiffLineageEdge[];
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
const localDevSessionSchemas = new Set([
  "zigeffect.causal.dev-session.v1",
  "zigeffect.causal.local-dev-session.v1",
]);
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

export function deriveLocalDevSessionModel(raw: unknown, options: WorkbenchOptions): LocalDevSessionModel | null {
  const artifact = isRecord(raw) ? raw : {};
  const schema = textValue(artifact.schema, "");
  if (!localDevSessionSchemas.has(schema)) {
    return null;
  }

  const schemaVersion = textValue(artifact.schema_version, "unknown");
  const warnings = stringList(artifact.warnings);
  if (schemaVersion === "unknown") {
    warnings.unshift("artifact schema_version is missing");
  }

  const mode = textValue(artifact.mode, "local");
  const target = textValue(artifact.target, "unknown");
  const phase = textValue(artifact.phase, "unknown");
  const status = textValue(artifact.status, "unknown");
  const commands = localDevCommands(artifact.commands);
  const artifacts = localDevArtifacts(artifact.artifacts);
  const explicitAgents = localDevAgents(artifact.agents);
  const explicitChecks = localDevChecks(artifact.checks);

  return {
    artifactPath: options.artifactPath,
    schema,
    schemaVersion,
    mode,
    sessionId: textValue(artifact.session_id, options.artifactPath),
    title: textValue(artifact.title, `${target} local development session`),
    goal: textValue(artifact.goal, "Develop zigeffect locally with causal evidence."),
    target,
    phase,
    status,
    agents: explicitAgents.length > 0 ? explicitAgents : fallbackLocalDevAgents(commands, status),
    checks: explicitChecks.length > 0 ? explicitChecks : commands.map(checkFromLocalDevCommand),
    commands,
    artifacts,
    nextActions: stringList(artifact.next_actions),
    guardrails: stringList(artifact.guardrails),
    warnings,
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

export function deriveVisualGraphModel(
  workbench: WorkbenchModel,
  graph: GraphModel,
  optionsOrLayout: VisualGraphOptions | VisualGraphLayoutMode,
): VisualGraphModel {
  const options: VisualGraphOptions = typeof optionsOrLayout === "string"
    ? { layoutMode: optionsOrLayout, perspective: "cause" }
    : optionsOrLayout;
  const perspective = options.perspective ?? "cause";
  const legacyIds = typeof optionsOrLayout === "string";
  const warnings: string[] = [];
  const findingEventIds = new Set(workbench.findings.map((finding) => finding.eventId));
  const eventNodes = workbench.events.map((event) => visualNodeFromEvent(event, findingEventIds, options.selectedEventId ?? null, legacyIds));
  const eventNodeToneById = new Map(eventNodes.map((node) => [node.eventId ?? node.id, node.tone]));
  const eventEdges = graph.parentEdges.map((edge) => visualParentEdge(edge, eventNodeToneById, legacyIds));
  const perspectiveGraph = applyVisualGraphPerspective(perspective, workbench, eventNodes, eventEdges, warnings, legacyIds);

  return {
    perspective,
    layoutMode: options.layoutMode,
    nodes: perspectiveGraph.nodes,
    edges: perspectiveGraph.edges,
    legend: visualGraphLegend(),
    warnings,
    adapter: {
      solid: "@dschz/solid-g6",
      engine: "@antv/g6",
      directEngineApi: "not-required",
    },
  };
}

function visualNodeFromEvent(
  event: CausalEvent,
  findingEventIds: Set<string>,
  selectedEventId: string | null,
  legacyIds: boolean,
): VisualGraphNode {
  const tone = visualNodeTone(event, findingEventIds);
  return {
    id: visualEventNodeId(event.idText, legacyIds),
    eventId: event.idText,
    label: event.label || event.typeName || event.kind,
    detail: event.redactedDetail || event.typeName || event.kind,
    kind: event.kind,
    status: event.status,
    lane: eventLaneLabel(event),
    group: "event",
    refs: visualRefsForEvent(event),
    tone,
    priority: visualPriority(tone, event.idText === selectedEventId),
  };
}

function visualParentEdge(edge: GraphEdge, toneByEventId: Map<string, VisualGraphNodeTone>, legacyIds: boolean): VisualGraphEdge {
  const source = visualEventNodeId(edge.from, legacyIds);
  const target = visualEventNodeId(edge.to, legacyIds);
  return {
    id: `${source}->${target}`,
    source,
    target,
    label: edge.label,
    detail: "parent relationship",
    kind: "parent",
    tone: toneByEventId.get(edge.to) ?? "ok",
  };
}

function applyVisualGraphPerspective(
  perspective: VisualGraphPerspective,
  workbench: WorkbenchModel,
  nodes: VisualGraphNode[],
  edges: VisualGraphEdge[],
  warnings: string[],
  legacyIds: boolean,
): { nodes: VisualGraphNode[]; edges: VisualGraphEdge[] } {
  if (legacyIds || perspective === "cause") {
    return { nodes, edges };
  }

  if (perspective === "topology") {
    return addRuntimeTopology(workbench.events, nodes, edges, ["run", "scope", "fiber", "resource", "retry"]);
  }

  if (perspective === "ownership") {
    return addRuntimeTopology(workbench.events, nodes, edges, ["scope", "fiber", "resource"]);
  }

  return applyLineagePerspective(nodes, edges, warnings);
}

function addRuntimeTopology(
  events: CausalEvent[],
  nodes: VisualGraphNode[],
  edges: VisualGraphEdge[],
  groups: VisualGraphNodeGroup[],
): { nodes: VisualGraphNode[]; edges: VisualGraphEdge[] } {
  const nextNodes = [...nodes];
  const nextEdges = [...edges];
  const seenNodes = new Set(nextNodes.map((node) => node.id));
  const seenEdges = new Set(nextEdges.map((edge) => edge.id));

  for (const event of events) {
    const eventNodeId = visualEventNodeId(event.idText, false);
    for (const group of visualGroupsForEvent(event, groups)) {
      if (!seenNodes.has(group.id)) {
        seenNodes.add(group.id);
        nextNodes.push(group);
      }

      const kind: VisualGraphEdgeKind = group.group === "resource" && event.kind === "resource_finalized" ? "finalizes" : "owns";
      const edgeId = `${group.id}->${eventNodeId}:${kind}`;
      if (!seenEdges.has(edgeId)) {
        seenEdges.add(edgeId);
        nextEdges.push({
          id: edgeId,
          source: group.id,
          target: eventNodeId,
          label: kind,
          detail: `${group.label} ${kind} ${event.label || event.kind}`,
          kind,
          tone: kind === "finalizes" ? visualNodeTone(event, new Set()) : group.tone,
        });
      }
    }
  }

  return { nodes: nextNodes, edges: nextEdges };
}

function applyLineagePerspective(
  nodes: VisualGraphNode[],
  edges: VisualGraphEdge[],
  warnings: string[],
): { nodes: VisualGraphNode[]; edges: VisualGraphEdge[] } {
  const nextNodes = [...nodes];
  const nextEdges = [...edges];
  const seenNodes = new Set(nextNodes.map((node) => node.id));
  const seenEdges = new Set(nextEdges.map((edge) => edge.id));

  for (const node of nodes) {
    const refs: Array<{
      id: string | null;
      group: VisualGraphNodeGroup;
      prefix: string;
      kind: string;
      edge: VisualGraphEdgeKind;
      tone: VisualGraphNodeTone;
    }> = [
      { id: node.refs.dataSubjectRef, group: "data", prefix: "data-subject", kind: "data_subject", edge: "reads", tone: "ok" },
      { id: node.refs.domainEntityRef, group: "data", prefix: "domain-entity", kind: "domain_entity", edge: "writes", tone: "ok" },
      { id: node.refs.schemaRef, group: "data", prefix: "schema", kind: "schema", edge: "transforms", tone: "ok" },
      { id: node.refs.artifactId, group: "artifact", prefix: "artifact", kind: "artifact", edge: "emits", tone: node.tone },
    ];

    for (const ref of refs) {
      if (!ref.id) continue;

      const refNodeId = `${ref.prefix}:${ref.id}`;
      if (!seenNodes.has(refNodeId)) {
        seenNodes.add(refNodeId);
        nextNodes.push({
          id: refNodeId,
          eventId: null,
          label: ref.id,
          detail: ref.kind,
          kind: ref.kind,
          status: "reference",
          lane: "lineage",
          group: ref.group,
          refs: visualEmptyRefs(),
          tone: ref.tone,
          priority: visualPriority(ref.tone, false),
        });
      }

      const edgeId = `${node.id}->${refNodeId}:${ref.edge}`;
      if (!seenEdges.has(edgeId)) {
        seenEdges.add(edgeId);
        nextEdges.push({
          id: edgeId,
          source: node.id,
          target: refNodeId,
          label: ref.edge,
          detail: `${node.label} ${ref.edge} ${ref.id}`,
          kind: ref.edge,
          tone: node.tone,
        });
      }
    }
  }

  if (nextNodes.length === nodes.length) {
    warnings.push("lineage perspective found no app semantic refs in this artifact");
  }

  return { nodes: nextNodes, edges: nextEdges };
}

function visualGroupsForEvent(event: CausalEvent, groups: VisualGraphNodeGroup[]): VisualGraphNode[] {
  const candidates: VisualGraphNode[] = [];
  const emptyRefs = visualEmptyRefs();
  const add = (group: VisualGraphNodeGroup, id: string, label: string, tone: VisualGraphNodeTone = "ok") => {
    if (!groups.includes(group)) return;
    candidates.push({
      id,
      eventId: null,
      label,
      detail: group,
      kind: group,
      status: "group",
      lane: group,
      group,
      refs: emptyRefs,
      tone,
      priority: visualPriority(tone, false),
    });
  };

  if (event.runId) add("run", `run:${event.runId}`, `run ${event.runId}`);
  if (event.scopeId) add("scope", `scope:${event.scopeId}`, `scope ${event.scopeId}`);
  if (event.fiberId) add("fiber", `fiber:${event.fiberId}`, `fiber ${event.fiberId}`);
  if (event.kind === "schedule_decision") add("retry", `retry:${event.label || event.idText}`, event.label || "retry", event.status === "exhausted" ? "warning" : "ok");
  if (event.kind.includes("resource")) {
    const resourceLabel = event.typeName || event.label || `resource ${event.idText}`;
    add("resource", `resource:${resourceLabel}`, resourceLabel, event.status === "failure" ? "failure" : event.status === "success" ? "ok" : "warning");
  }

  return candidates;
}

function visualEventNodeId(eventId: string, legacyIds: boolean): string {
  return legacyIds ? eventId : `event:${eventId}`;
}

function visualPriority(tone: VisualGraphNodeTone, selected: boolean): VisualGraphNodePriority {
  if (tone === "failure" || selected) return "critical";
  if (tone === "warning") return "watch";
  return "normal";
}

function visualGraphLegend(): VisualGraphLegendEntry[] {
  return [
    { id: "ok", label: "OK", tone: "ok", detail: "No finding or failure evidence" },
    { id: "warning", label: "Warning", tone: "warning", detail: "Finding, pending, missing, exhausted, or running evidence" },
    { id: "failure", label: "Failure", tone: "failure", detail: "Failure or critical evidence" },
  ];
}

function visualEmptyRefs(): VisualGraphRefSet {
  return {
    artifactId: null,
    domainEntityRef: null,
    dataSubjectRef: null,
    schemaRef: null,
  };
}

function visualRefsForEvent(event: CausalEvent): VisualGraphRefSet {
  return {
    artifactId: event.artifactId || null,
    domainEntityRef: event.domainEntityRef || null,
    dataSubjectRef: event.dataSubjectRef || null,
    schemaRef: event.schemaRef || null,
  };
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

export function deriveAppRemediationModel(raw: unknown, options: WorkbenchOptions): AppRemediationModel | null {
  const artifact = isRecord(raw) ? raw : {};
  const schema = textValue(artifact.schema, "unknown");
  const kind = governanceKindForSchema(schema);
  if (
    kind !== "app-remediation-audit" &&
    kind !== "app-policy-decision" &&
    kind !== "app-human-review" &&
    kind !== "app-patch-proposal" &&
    kind !== "app-application-readiness" &&
    kind !== "app-application"
  ) {
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
    kind,
    mode: textValue(artifact.mode, "unknown"),
    target: textValue(artifact.target, "unknown"),
    summary: appSummary(kind, artifact),
    decision: textValue(artifact.decision, "unknown"),
    applicationStatus: textValue(artifact.application_status, "unknown"),
    proposalStatus: textValue(artifact.proposal_status, textValue(artifact.review_status, textValue(artifact.readiness_status, "unknown"))),
    readinessStatus: textValue(artifact.readiness_status, "unknown"),
    approvalStatus: textValue(artifact.approval_status, "unknown"),
    approved: booleanValue(artifact.approved),
    readyForApplication: booleanValue(artifact.ready_for_application),
    applied: booleanValue(artifact.applied),
    mutationAuthority: nullableTextValue(artifact.mutation_authority),
    sourceSteps: appSourceSteps(kind, source),
    incidents: appIncidents(artifact.incidents),
    policyGates: stringList(artifact.policy_gates),
    gateResults: appGateResults(artifact.gate_results),
    citations: appCitationGroups(artifact.citations),
    changeEvidence: appChangeEvidenceGroups(artifact.change_evidence),
    beforeEvidence: stringList(artifact.before_evidence),
    afterEvidence: stringList(artifact.after_evidence),
    checks: appReadinessChecks(artifact.checks),
    eventIds: eventIdList(artifact.event_ids),
    verificationCommands: uniqueInOrder([
      ...stringList(artifact.verification_commands),
      ...stringList(artifact.required_verification_commands),
      ...stringList(artifact.reviewed_verification_commands),
      ...stringList(artifact.verified_commands),
    ]),
    applicationSteps: stringList(artifact.application_steps),
    guardrails: uniqueInOrder([
      ...stringList(artifact.claim_guardrails),
      ...stringList(artifact.guardrails),
      ...stringList(artifact.proposal_guardrails),
      ...stringList(artifact.review_guardrails),
      ...stringList(artifact.readiness_guardrails),
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
  const app = deriveAppRemediationModel(raw, options);
  const schemaVersion = textValue(artifact.schema_version, "unknown");
  const target = textValue(artifact.target, "unknown");
  const warnings = chain?.warnings ?? app?.warnings ?? (schemaVersion === "unknown" ? ["artifact schema_version is missing"] : []);
  const incidentCount = numericValue(artifact.incident_count);
  const decision = textValue(artifact.decision, "unknown");
  const proposalStatus = textValue(artifact.proposal_status, "unknown");
  const reviewStatus = textValue(artifact.review_status, "unknown");
  const readinessStatus = textValue(artifact.readiness_status, "unknown");
  const summary = kind === "app-remediation-audit" && incidentCount !== null
    ? `${incidentCount} app incidents for ${target}`
    : kind === "app-policy-decision"
      ? `${decision} app policy decision for ${target}`
    : kind === "app-human-review"
      ? `${reviewStatus} app human review for ${target}`
    : kind === "app-patch-proposal"
      ? `${proposalStatus} app patch proposal for ${target}`
    : kind === "app-application"
      ? `${textValue(artifact.application_status, "unknown")} app application for ${target}`
    : kind === "app-application-readiness"
      ? `${readinessStatus} app application readiness for ${target}`
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
    app,
    warnings,
  };
}

export function deriveSemanticDiffModel(raw: unknown, options: WorkbenchOptions): SemanticDiffModel | null {
  const artifact = isRecord(raw) ? raw : {};
  const source = isRecord(artifact.semantic_diff) ? artifact.semantic_diff : artifact;
  const schema = textValue(source.schema, "");
  const hasSemanticDiff = schema === "zigeffect.causal.semantic-diff.v1" || isRecord(artifact.semantic_diff);
  if (!hasSemanticDiff) {
    return null;
  }

  const warnings: string[] = [];
  if (schema.length === 0) {
    warnings.push("semantic diff schema is missing");
  }
  if (!isRecord(source.summary)) {
    warnings.push("semantic diff summary is missing");
  }

  const summary = isRecord(source.summary) ? source.summary : {};

  return {
    artifactPath: options.artifactPath,
    schema: schema.length > 0 ? schema : "unknown",
    beforeArtifact: textValue(source.before, textValue(source.before_artifact, "unknown")),
    afterArtifact: textValue(source.after, textValue(source.after_artifact, "unknown")),
    summary: {
      resolvedFindings: numericValue(summary.resolved_findings) ?? 0,
      introducedFindings: numericValue(summary.introduced_findings) ?? 0,
      addedFiberTerminals: numericValue(summary.added_fiber_terminals) ?? 0,
      removedFiberTerminals: numericValue(summary.removed_fiber_terminals) ?? 0,
      addedResourceFinalizations: numericValue(summary.added_resource_finalizations) ?? 0,
      removedResourceFinalizations: numericValue(summary.removed_resource_finalizations) ?? 0,
      addedLineageEdges: numericValue(summary.added_lineage_edges) ?? 0,
      removedLineageEdges: numericValue(summary.removed_lineage_edges) ?? 0,
    },
    resolvedFindings: semanticDiffFindings(source.resolved_findings),
    introducedFindings: semanticDiffFindings(source.introduced_findings),
    addedFiberTerminals: semanticDiffFiberTerminals(source.added_fiber_terminals),
    removedFiberTerminals: semanticDiffFiberTerminals(source.removed_fiber_terminals),
    addedResourceFinalizations: semanticDiffResourceFinalizations(source.added_resource_finalizations),
    removedResourceFinalizations: semanticDiffResourceFinalizations(source.removed_resource_finalizations),
    addedLineageEdges: semanticDiffLineageEdges(source.added_lineage_edges),
    removedLineageEdges: semanticDiffLineageEdges(source.removed_lineage_edges),
    warnings,
  };
}

export function semanticDiffSelectableEventIds(diff: SemanticDiffModel): string[] {
  const ids: string[] = [];
  const add = (id: string) => {
    if (isSelectableEventId(id)) {
      ids.push(id);
    }
  };

  for (const entry of diff.resolvedFindings) add(entry.eventId);
  for (const entry of diff.introducedFindings) add(entry.eventId);
  for (const entry of diff.addedFiberTerminals) add(entry.eventId);
  for (const entry of diff.removedFiberTerminals) add(entry.eventId);
  for (const entry of diff.addedResourceFinalizations) add(entry.eventId);
  for (const entry of diff.removedResourceFinalizations) add(entry.eventId);
  for (const entry of diff.addedLineageEdges) {
    add(entry.fromEventId);
    add(entry.toEventId);
  }
  for (const entry of diff.removedLineageEdges) {
    add(entry.fromEventId);
    add(entry.toEventId);
  }

  return uniqueInOrder(ids);
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

function semanticDiffFindings(value: unknown): SemanticDiffFinding[] {
  if (!Array.isArray(value)) {
    return [];
  }
  return value.filter(isRecord).map((entry) => ({
    kind: textValue(entry.kind, "unknown"),
    eventId: idValue(entry.event_id) ?? "unknown",
    owner: textValue(entry.owner, "unknown"),
  }));
}

function semanticDiffFiberTerminals(value: unknown): SemanticDiffFiberTerminal[] {
  if (!Array.isArray(value)) {
    return [];
  }
  return value.filter(isRecord).map((entry) => ({
    fiberId: idValue(entry.fiber_id) ?? "unknown",
    terminalKind: textValue(entry.terminal_kind, textValue(entry.kind, "unknown")),
    status: textValue(entry.status, "unknown"),
    eventId: idValue(entry.event_id) ?? "unknown",
  }));
}

function semanticDiffResourceFinalizations(value: unknown): SemanticDiffResourceFinalization[] {
  if (!Array.isArray(value)) {
    return [];
  }
  return value.filter(isRecord).map((entry) => ({
    scopeId: idValue(entry.scope_id) ?? "unknown",
    resourceId: idValue(entry.resource_id) ?? "unknown",
    typeName: textValue(entry.type_name, "unknown"),
    eventId: idValue(entry.event_id) ?? "unknown",
  }));
}

function semanticDiffLineageEdges(value: unknown): SemanticDiffLineageEdge[] {
  if (!Array.isArray(value)) {
    return [];
  }
  return value.filter(isRecord).map((entry) => ({
    fromEventId: idValue(entry.from_event_id) ?? "unknown",
    toEventId: idValue(entry.to_event_id) ?? "unknown",
    edgeKind: textValue(entry.edge_kind, "unknown"),
  }));
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

function eventLaneLabel(event: CausalEvent): string {
  if (event.fiberId) return `fiber:${event.fiberId}`;
  if (event.scopeId) return `scope:${event.scopeId}`;
  if (event.runId) return `run:${event.runId}`;
  return "event";
}

function visualNodeTone(event: CausalEvent, findingEventIds: Set<string>): VisualGraphNodeTone {
  if (event.status === "failure") {
    return "failure";
  }
  if (findingEventIds.has(event.idText) || graphWarningStatuses.has(event.status)) {
    return "warning";
  }
  return "ok";
}

function governanceKindForSchema(schema: string): GovernanceArtifactKind | null {
  switch (schema) {
    case auditChainSchema:
      return "audit-chain";
    case "zigeffect.causal.remediation-audit.v1":
      return "remediation-audit";
    case "zigeffect.causal.app-remediation-audit.v1":
      return "app-remediation-audit";
    case "zigeffect.causal.app-policy-decision.v1":
      return "app-policy-decision";
    case "zigeffect.causal.app-human-review.v1":
      return "app-human-review";
    case "zigeffect.causal.app-patch-proposal.v1":
      return "app-patch-proposal";
    case "zigeffect.causal.app-application-readiness.v1":
      return "app-application-readiness";
    case "zigeffect.causal.app-application.v1":
      return "app-application";
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

function appSummary(kind: AppRemediationArtifactKind, artifact: UnknownRecord): string {
  const target = textValue(artifact.target, "unknown");
  if (kind === "app-remediation-audit") {
    const incidentCount = numericValue(artifact.incident_count);
    return incidentCount === null ? `app remediation audit for ${target}` : `${incidentCount} app incidents for ${target}`;
  }
  if (kind === "app-policy-decision") {
    return `${textValue(artifact.decision, "unknown")} app policy decision for ${target}`;
  }
  if (kind === "app-human-review") {
    return `${textValue(artifact.review_status, "unknown")} app human review for ${target}`;
  }
  if (kind === "app-application") {
    return `${textValue(artifact.application_status, "unknown")} app application for ${target}`;
  }
  if (kind === "app-application-readiness") {
    return `${textValue(artifact.readiness_status, "unknown")} app application readiness for ${target}`;
  }
  return `${textValue(artifact.proposal_status, "unknown")} app patch proposal for ${target}`;
}

function appSourceSteps(kind: AppRemediationArtifactKind, source: UnknownRecord): ChainSourceStep[] {
  const definitions: Array<[string, string]> = kind === "app-remediation-audit"
    ? [["app_artifact", "App artifact"], ["advice", "Advice"]]
    : kind === "app-policy-decision"
      ? [["app_remediation_audit", "App remediation audit"], ["app_artifact", "App artifact"]]
    : kind === "app-human-review"
      ? [["policy", "App policy decision"], ["app_remediation_audit", "App remediation audit"], ["app_artifact", "App artifact"]]
    : kind === "app-application-readiness"
      ? [["proposal", "App patch proposal"], ["policy", "App policy decision"], ["human_review", "App human review"], ["app_remediation_audit", "App remediation audit"], ["app_artifact", "App artifact"]]
    : kind === "app-application"
      ? [["readiness", "App application readiness"], ["proposal", "App patch proposal"], ["policy", "App policy decision"], ["human_review", "App human review"], ["app_remediation_audit", "App remediation audit"], ["app_artifact", "App artifact"]]
      : [["policy", "App policy decision"], ["human_review", "App human review"], ["app_remediation_audit", "App remediation audit"], ["app_artifact", "App artifact"]];

  return definitions
    .map(([field, label]) => appSourceStep(field, label, source))
    .filter((step): step is ChainSourceStep => step !== null);
}

function appSourceStep(field: string, label: string, source: UnknownRecord): ChainSourceStep | null {
  const path = textValue(source[field], "");
  if (!path) {
    return null;
  }
  return {
    kind: "proposal",
    label,
    path,
    workbenchCommand: workbenchCommandForPath(path),
  };
}

function appIncidents(value: unknown): AppIncidentModel[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return value.filter(isRecord).map((incident) => ({
    action: textValue(incident.action, "unknown"),
    eventId: idValue(incident.event_id) ?? "unknown",
    eventKind: textValue(incident.event_kind, "unknown"),
    label: textValue(incident.label, "unknown"),
    subsystem: textValue(incident.subsystem, "unknown"),
    fixCategory: textValue(incident.fix_category, "unknown"),
    policyGate: textValue(incident.policy_gate, "unknown"),
    queryCommands: stringList(incident.query_commands),
  }));
}

function appGateResults(value: unknown): AppGateResultModel[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return value.filter(isRecord).map((gate) => ({
    gate: textValue(gate.gate, "unknown"),
    status: textValue(gate.status, "unknown"),
    detail: textValue(gate.detail, ""),
  }));
}

function appReadinessChecks(value: unknown): AppReadinessCheckModel[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return value.filter(isRecord).map((check) => ({
    name: textValue(check.name, "unknown"),
    status: textValue(check.status, "unknown"),
    detail: textValue(check.detail, ""),
  }));
}

function appCitationGroups(value: unknown): AppCitationGroup[] {
  const citations = isRecord(value) ? value : {};
  return [
    { label: "Source files", values: stringList(citations.source_files) },
    { label: "Config keys", values: stringList(citations.config_keys) },
    { label: "Migration files", values: stringList(citations.migration_files) },
    { label: "Runbooks", values: stringList(citations.runbooks) },
    { label: "Rollback plans", values: stringList(citations.rollback_plans) },
  ];
}

function appChangeEvidenceGroups(value: unknown): AppCitationGroup[] {
  const evidence = isRecord(value) ? value : {};
  return [
    { label: "Source changes", values: stringList(evidence.source_changes) },
    { label: "Config changes", values: stringList(evidence.config_changes) },
    { label: "Migration changes", values: stringList(evidence.migration_changes) },
    { label: "Operation changes", values: stringList(evidence.operation_changes) },
    { label: "Rollback changes", values: stringList(evidence.rollback_changes) },
  ];
}

function localDevAgents(value: unknown): LocalDevAgentModel[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return value
    .filter(isRecord)
    .map((agent, index) => {
      const kind = localDevAgentKind(agent.kind);
      const label = textValue(agent.label, kind === "other" ? `Agent ${index + 1}` : localDevAgentKindLabel(kind));
      return {
        id: textValue(agent.id, localDevAgentId(kind, index)),
        label,
        kind,
        status: localDevAgentStatus(agent.status),
        currentTask: nullableTextValue(agent.current_task),
        lastEventId: nullableIdValue(agent.last_event_id),
        artifactPath: nullableTextValue(agent.artifact_path),
      };
    });
}

function localDevChecks(value: unknown): LocalDevCheckModel[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return value
    .filter(isRecord)
    .map((check) => ({
      label: textValue(check.label, textValue(check.name, "unnamed check")),
      command: nullableTextValue(check.command),
      status: localDevCheckStatus(check.status),
      detail: textValue(check.detail, ""),
      artifactPath: nullableTextValue(check.artifact_path),
    }));
}

function localDevCommands(value: unknown): LocalDevCommandModel[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return value
    .filter(isRecord)
    .map((command) => ({
      label: textValue(command.name, textValue(command.label, "command")),
      command: localDevCommandText(command),
      status: localDevCheckStatus(command.status),
      exitCode: numericValue(command.exit_code),
      stdoutSnippet: textValue(command.stdout_snippet, ""),
      stderrSnippet: textValue(command.stderr_snippet, ""),
    }));
}

function localDevCommandText(command: UnknownRecord): string {
  const explicit = textValue(command.command, "");
  if (explicit.length > 0) {
    return explicit;
  }

  if (!Array.isArray(command.argv)) {
    return "";
  }

  return command.argv
    .map((item) => textValue(item, ""))
    .filter((item) => item.length > 0)
    .join(" ");
}

function localDevArtifacts(value: unknown): LocalDevArtifactModel[] {
  if (!isRecord(value)) {
    return [];
  }

  return Object.entries(value)
    .map(([key, rawPath]) => {
      const path = textValue(rawPath, "");
      if (path.length === 0) {
        return null;
      }
      return {
        key,
        label: localDevArtifactLabel(key),
        path,
        kind: localDevArtifactKind(path),
        workbenchCommand: workbenchCommandForPath(path),
      } satisfies LocalDevArtifactModel;
    })
    .filter((artifact): artifact is LocalDevArtifactModel => artifact !== null);
}

function fallbackLocalDevAgents(commands: LocalDevCommandModel[], sessionStatus: string): LocalDevAgentModel[] {
  const toolStatus = commands.some((command) => command.status === "fail")
    ? "failed"
    : localDevAgentStatusFromSession(sessionStatus);

  return [
    {
      id: "zigeffect-tools",
      label: "zigeffect tools",
      kind: "zigeffect",
      status: toolStatus,
      currentTask: commands[0]?.label ?? null,
      lastEventId: null,
      artifactPath: null,
    },
  ];
}

function checkFromLocalDevCommand(command: LocalDevCommandModel): LocalDevCheckModel {
  const detail = command.stderrSnippet || command.stdoutSnippet;
  return {
    label: command.label,
    command: command.command.length > 0 ? command.command : null,
    status: command.status,
    detail,
    artifactPath: null,
  };
}

function localDevAgentKind(value: unknown): LocalDevAgentKind {
  const kind = textValue(value, "other");
  if (kind === "codex" || kind === "claude-code" || kind === "zigeffect" || kind === "human") {
    return kind;
  }
  return "other";
}

function localDevAgentStatus(value: unknown): LocalDevAgentStatus {
  const status = textValue(value, "unknown");
  if (
    status === "idle" ||
    status === "running" ||
    status === "reviewing" ||
    status === "blocked" ||
    status === "done" ||
    status === "failed"
  ) {
    return status;
  }
  return "unknown";
}

function localDevAgentStatusFromSession(status: string): LocalDevAgentStatus {
  if (status === "failed" || status === "missing-baseline") {
    return "failed";
  }
  if (status === "audit-ready" || status === "complete") {
    return "done";
  }
  if (status === "blocked") {
    return "blocked";
  }
  return "running";
}

function localDevCheckStatus(value: unknown): LocalDevCheckStatus {
  const status = textValue(value, "unknown");
  if (status === "ok" || status === "pass" || status === "passed" || status === "success") {
    return "pass";
  }
  if (status === "failed" || status === "fail" || status === "failure" || status === "error") {
    return "fail";
  }
  if (status === "running" || status === "pending") {
    return "running";
  }
  if (status === "skipped" || status === "skip") {
    return "skipped";
  }
  return "unknown";
}

function localDevAgentKindLabel(kind: LocalDevAgentKind): string {
  switch (kind) {
    case "codex": return "Codex";
    case "claude-code": return "Claude Code";
    case "zigeffect": return "zigeffect tools";
    case "human": return "Human";
    case "other": return "Agent";
  }
}

function localDevAgentId(kind: LocalDevAgentKind, index: number): string {
  return kind === "other" ? `agent-${index + 1}` : kind;
}

function localDevArtifactLabel(key: string): string {
  return key
    .split("_")
    .filter((part) => part.length > 0)
    .map((part) => `${part.charAt(0).toUpperCase()}${part.slice(1)}`)
    .join(" ");
}

function localDevArtifactKind(path: string): LocalDevArtifactModel["kind"] {
  if (path.endsWith(".json")) {
    return "json";
  }
  if (path.endsWith(".md")) {
    return "markdown";
  }
  if (path.endsWith(".txt") || path.endsWith(".log")) {
    return "text";
  }
  return "other";
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

function isSelectableEventId(value: string): boolean {
  return value.length > 0 && value !== "unknown" && value !== "null";
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
    artifactId: textValue(raw.artifact_id, ""),
    domainEntityRef: textValue(raw.domain_entity_ref, ""),
    dataSubjectRef: textValue(raw.data_subject_ref, ""),
    schemaRef: textValue(raw.schema_ref, ""),
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
