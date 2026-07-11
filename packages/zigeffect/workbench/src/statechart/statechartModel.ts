import type { VisualGraphModel } from "../causalArtifact";

type UnknownRecord = Record<string, unknown>;

export type StatechartStateKind =
  | "atomic"
  | "final"
  | "compound"
  | "parallel"
  | "history_shallow"
  | "history_deep";

export type StatechartSourceRef = {
  file: string;
  declaration: string;
  line: number;
  column: number;
};

export type StatechartStateNode = {
  id: string;
  kind: StatechartStateKind;
  parent: string | null;
  initial: string | null;
  description: string;
  entry: string[];
  exit: string[];
  source: StatechartSourceRef;
  invocations?: Array<{ id: string; start: string; stop: string | null; description: string; source: StatechartSourceRef }>;
};

export type StatechartTransition = {
  id: string;
  source: string;
  event: string | null;
  target: string | null;
  kind: "external" | "internal";
  reenter: boolean;
  guard: string | null;
  actions: string[];
  description: string;
  source_ref: StatechartSourceRef;
};

export type StatechartDefinitionArtifact = {
  schema: "zigeffect.statechart.definition.v1" | "zigeffect.statechart.definition.v2";
  schema_version: 1 | 2;
  id: string;
  version: number;
  fingerprint: string;
  initial: string;
  description: string;
  state_type: string;
  event_type: string;
  context_type: string;
  command_type: string;
  states: StatechartStateNode[];
  transitions: StatechartTransition[];
};

export type StatechartInstance = {
  schema: "zigeffect.statechart.snapshot.v1" | "zigeffect.statechart.snapshot.v2";
  definitionFingerprint: string;
  instanceId: string;
  configuration: string[];
  activeAtomicStates: string[];
  status: string;
  revision: string;
  lastEventSequence: string;
  contextRedacted: boolean;
};

export type StatechartExecution = {
  schema: "zigeffect.statechart.execution.v1" | "zigeffect.statechart.execution.v2";
  instanceId: string;
  decisionFingerprint: string;
  outcome: string;
  event: string;
  transitionIds: string[];
  fromConfiguration: string[];
  toConfiguration: string[];
  revision: string;
  actions: Array<{ phase: string; id: string }>;
  guards: Array<{ id: string; transitionId: string; accepted: boolean }>;
  commands: string[];
  commandOutcomes: Array<{ command: string; status: string; detail: string }>;
  internalEvents: string[];
};

export type StatechartDefinitionDiff = {
  fromVersion: number;
  toVersion: number;
  statesAdded: string[];
  statesRemoved: string[];
  transitionsAdded: string[];
  transitionsRemoved: string[];
  transitionsChanged: string[];
};

export type StatechartCoverage = {
  schema: "zigeffect.statechart.coverage.v1" | "zigeffect.statechart.coverage.v2";
  definitionId: string;
  definitionFingerprint: string;
  stateCounts: Record<string, string>;
  transitionCounts: Record<string, string>;
  eventCounts: Record<string, string>;
};

export type StatechartCatalog = {
  definitions: StatechartDefinitionArtifact[];
  instances: StatechartInstance[];
  executions: StatechartExecution[];
  coverage: StatechartCoverage[];
  warnings: string[];
};

export function parseStatechartCatalog(raw: unknown): StatechartCatalog {
  const root = asRecord(raw, "statechart catalog");
  const direct = root.schema === "zigeffect.statechart.definition.v1" || root.schema === "zigeffect.statechart.definition.v2" ? [root] : [];
  const definitionsRaw = direct.length > 0
    ? direct
    : arrayValue(root.statecharts ?? root.statechart_definitions ?? root.definitions, "statecharts", []);
  const definitions = definitionsRaw.map((entry, index) => parseDefinition(entry, index));
  const instances = arrayValue(root.statechart_snapshots ?? root.snapshots, "statechart_snapshots", []).map(parseSnapshot);
  const executions = arrayValue(root.statechart_executions ?? root.executions, "statechart_executions", []).map(parseExecution);
  const coverage = arrayValue(root.statechart_coverage ?? root.statechart_coverages ?? root.coverage, "statechart_coverage", []).map(parseCoverage);
  const warnings: string[] = [];

  const fingerprints = new Set(definitions.map((definition) => definition.fingerprint));
  for (const instance of instances) {
    if (!fingerprints.has(instance.definitionFingerprint)) {
      warnings.push(`instance ${instance.instanceId} references unknown definition fingerprint ${instance.definitionFingerprint}`);
    }
  }
  return { definitions, instances, executions, coverage, warnings };
}

export function deriveStatechartGraphModel(
  definition: StatechartDefinitionArtifact,
  instance?: StatechartInstance,
  coverage?: StatechartCoverage,
  execution?: StatechartExecution,
): VisualGraphModel {
  const active = new Set(instance?.configuration ?? instance?.activeAtomicStates ?? []);
  const commandFailed = execution?.commandOutcomes.some((outcome) => outcome.status === "failed") ?? false;
  const rejectedTransitions = new Set(execution?.guards.filter((guard) => !guard.accepted).map((guard) => guard.transitionId) ?? []);
  const selectedTransitions = new Set(execution?.transitionIds ?? []);
  const nodes = definition.states.map((state) => ({
    id: `state:${state.id}`,
    eventId: `state:${state.id}`,
    label: state.id,
    detail: [stateDetail(state), sourceDetail(state.source), coverage ? `visited:${coverage.stateCounts[state.id] ?? 0}` : ""].filter(Boolean).join(" · "),
    kind: state.kind,
    status: active.has(state.id) ? "active" : "inactive",
    lane: state.parent ?? "root",
    group: "state" as const,
    refs: {
      artifactId: definition.id,
      domainEntityRef: instance ? `statechart-instance:${instance.instanceId}` : null,
      dataSubjectRef: null,
      schemaRef: definition.schema,
    },
    tone: commandFailed && active.has(state.id) ? "failure" as const : active.has(state.id) ? "warning" as const : "ok" as const,
    priority: commandFailed && active.has(state.id) ? "critical" as const : active.has(state.id) ? "watch" as const : "normal" as const,
    sourceLocation: sourceDetail(state.source),
  }));

  const containment = definition.states.flatMap((state) => state.parent ? [{
    id: `contains:${state.parent}:${state.id}`,
    source: `state:${state.parent}`,
    target: `state:${state.id}`,
    label: "contains",
    detail: `${state.id} is nested in ${state.parent}`,
    kind: "contains" as const,
    tone: "ok" as const,
  }] : []);
  const transitions = definition.transitions.flatMap((transition) => transition.target ? [{
    id: `transition:${transition.id}`,
    source: `state:${transition.source}`,
    target: `state:${transition.target}`,
    label: transition.event ?? "always",
    detail: [transitionDetail(transition), coverage ? `count:${coverage.transitionCounts[transition.id] ?? 0}` : ""].filter(Boolean).join(" · "),
    kind: "transition" as const,
    tone: rejectedTransitions.has(transition.id) ? "failure" as const : selectedTransitions.has(transition.id) ? "warning" as const : "ok" as const,
  }] : []);

  const warnings: string[] = [];
  if (instance && instance.definitionFingerprint !== definition.fingerprint) {
    warnings.push(`instance fingerprint ${instance.definitionFingerprint} does not match definition ${definition.fingerprint}`);
  }
  return {
    perspective: "statechart",
    layoutMode: "dagre",
    nodes,
    edges: [...containment, ...transitions],
    legend: [
      { id: "active", label: "active", tone: "warning", detail: "Current active configuration" },
      { id: "defined", label: "defined", tone: "ok", detail: "Defined state" },
    ],
    warnings,
    adapter: { solid: "native-solid-svg", engine: "deterministic-svg", directEngineApi: "implemented" },
  };
}

export function replayInstanceAt(
  catalog: StatechartCatalog,
  instance: StatechartInstance,
  position: number,
): StatechartInstance {
  const trace = catalog.executions.filter((execution) => execution.instanceId === instance.instanceId);
  if (trace.length === 0) return instance;
  const bounded = Math.max(0, Math.min(position, trace.length - 1));
  const execution = trace[bounded]!;
  return {
    ...instance,
    configuration: execution.toConfiguration,
    activeAtomicStates: execution.toConfiguration,
    revision: execution.revision,
    lastEventSequence: execution.revision,
  };
}

export function deriveActorGraphModel(catalog: StatechartCatalog): VisualGraphModel {
  const nodes: VisualGraphModel["nodes"] = [];
  const edges: VisualGraphModel["edges"] = [];
  for (const instance of catalog.instances) {
    const definition = catalog.definitions.find((candidate) => candidate.fingerprint === instance.definitionFingerprint);
    nodes.push({
      id: `actor:${instance.instanceId}`,
      eventId: `actor:${instance.instanceId}`,
      label: `${definition?.id ?? "machine"} #${instance.instanceId}`,
      detail: `${instance.status} · revision ${instance.revision}`,
      kind: "statechart-actor",
      status: instance.status,
      lane: definition?.id ?? "unknown-definition",
      group: "actor",
      refs: {
        artifactId: definition?.id ?? null,
        domainEntityRef: `statechart-instance:${instance.instanceId}`,
        dataSubjectRef: null,
        schemaRef: instance.schema,
      },
      tone: instance.status === "failed" ? "failure" : instance.status === "active" ? "warning" : "ok",
      priority: instance.status === "failed" ? "critical" : instance.status === "active" ? "watch" : "normal",
    });
    for (const state of instance.activeAtomicStates) {
      const stateId = `actor-state:${instance.instanceId}:${state}`;
      nodes.push({
        id: stateId,
        eventId: stateId,
        label: state,
        detail: "active atomic state",
        kind: "active-state",
        status: "active",
        lane: definition?.id ?? "unknown-definition",
        group: "state",
        refs: {
          artifactId: definition?.id ?? null,
          domainEntityRef: `statechart-instance:${instance.instanceId}`,
          dataSubjectRef: null,
          schemaRef: instance.schema,
        },
        tone: "warning",
        priority: "watch",
      });
      edges.push({
        id: `invokes:${instance.instanceId}:${state}`,
        source: `actor:${instance.instanceId}`,
        target: stateId,
        label: "active",
        detail: `actor ${instance.instanceId} owns active state ${state}`,
        kind: "invokes",
        tone: "warning",
      });
    }
  }
  return {
    perspective: "actors",
    layoutMode: "dagre",
    nodes,
    edges,
    legend: [
      { id: "actor", label: "actor", tone: "ok", detail: "Statechart actor instance" },
      { id: "active", label: "active state", tone: "warning", detail: "Current atomic state" },
    ],
    warnings: catalog.warnings,
    adapter: { solid: "native-solid-svg", engine: "deterministic-svg", directEngineApi: "implemented" },
  };
}

function parseDefinition(value: unknown, index: number): StatechartDefinitionArtifact {
  const entry = asRecord(value, `statechart definition ${index}`);
  const schema = statechartSchema(entry, "definition", `statechart definition ${index}`);
  const states = arrayValue(entry.states, "states").map(parseState);
  const transitions = arrayValue(entry.transitions, "transitions").map(parseTransition);
  const definition: StatechartDefinitionArtifact = {
    schema: schema.schema as StatechartDefinitionArtifact["schema"],
    schema_version: schema.version,
    id: requiredString(entry.id, "definition id"),
    version: positiveNumber(entry.version, "definition version"),
    fingerprint: u64String(entry.fingerprint, "definition fingerprint", true),
    initial: requiredString(entry.initial, "definition initial"),
    description: optionalString(entry.description),
    state_type: optionalString(entry.state_type),
    event_type: optionalString(entry.event_type),
    context_type: optionalString(entry.context_type),
    command_type: optionalString(entry.command_type),
    states,
    transitions,
  };
  validateDefinition(definition);
  return definition;
}

function parseState(value: unknown, index: number): StatechartStateNode {
  const entry = asRecord(value, `state ${index}`);
  const kind = requiredString(entry.kind, `state ${index} kind`);
  if (!["atomic", "final", "compound", "parallel", "history_shallow", "history_deep"].includes(kind)) {
    throw new Error(`state ${index} has unsupported kind ${kind}`);
  }
  return {
    id: requiredString(entry.id, `state ${index} id`),
    kind: kind as StatechartStateKind,
    parent: nullableString(entry.parent, `state ${index} parent`),
    initial: nullableString(entry.initial, `state ${index} initial`),
    description: optionalString(entry.description),
    entry: stringArray(entry.entry, `state ${index} entry`),
    exit: stringArray(entry.exit, `state ${index} exit`),
    source: parseSource(entry.source),
    invocations: arrayValue(entry.invoke, `state ${index} invoke`, []).map((value, invocationIndex) => {
      const invocation = asRecord(value, `state ${index} invocation ${invocationIndex}`);
      return {
        id: requiredString(invocation.id, "invocation id"),
        start: requiredString(invocation.start, "invocation start"),
        stop: nullableString(invocation.stop, "invocation stop"),
        description: optionalString(invocation.description),
        source: parseSource(invocation.source),
      };
    }),
  };
}

function parseTransition(value: unknown, index: number): StatechartTransition {
  const entry = asRecord(value, `transition ${index}`);
  const kind = optionalString(entry.kind) || "external";
  if (kind !== "external" && kind !== "internal") throw new Error(`transition ${index} has unsupported kind ${kind}`);
  return {
    id: requiredString(entry.id, `transition ${index} id`),
    source: requiredString(entry.source, `transition ${index} source`),
    event: nullableString(entry.event, `transition ${index} event`),
    target: nullableString(entry.target, `transition ${index} target`),
    kind,
    reenter: entry.reenter === true,
    guard: nullableString(entry.guard, `transition ${index} guard`),
    actions: stringArray(entry.actions, `transition ${index} actions`),
    description: optionalString(entry.description),
    source_ref: parseSource(entry.source_ref),
  };
}

function parseSnapshot(value: unknown, index: number): StatechartInstance {
  const entry = asRecord(value, `statechart snapshot ${index}`);
  const schema = statechartSchema(entry, "snapshot", `statechart snapshot ${index}`);
  const flatState = typeof entry.state === "string" ? [entry.state] : [];
  return {
    schema: schema.schema as StatechartInstance["schema"],
    definitionFingerprint: u64String(entry.definition_fingerprint, "snapshot definition_fingerprint", true),
    instanceId: u64String(entry.instance_id, "snapshot instance_id", true),
    configuration: stringArray(entry.configuration, "snapshot configuration", flatState),
    activeAtomicStates: stringArray(entry.active_atomic_states, "snapshot active_atomic_states", flatState),
    status: requiredString(entry.status, "snapshot status"),
    revision: u64String(entry.revision, "snapshot revision"),
    lastEventSequence: u64String(entry.last_event_sequence, "snapshot last_event_sequence"),
    contextRedacted: entry.context_redacted === true,
  };
}

function parseExecution(value: unknown, index: number): StatechartExecution {
  const entry = asRecord(value, `statechart execution ${index}`);
  const schema = statechartSchema(entry, "execution", `statechart execution ${index}`);
  const transitionIds = stringArray(entry.transition_ids, "execution transition_ids",
    typeof entry.transition_id === "string" && entry.transition_id ? [entry.transition_id] : []);
  const actions = arrayValue(entry.actions, "execution actions", []).map((action, actionIndex) => {
    const item = asRecord(action, `execution action ${actionIndex}`);
    return { phase: requiredString(item.phase, "execution action phase"), id: requiredString(item.id, "execution action id") };
  });
  const guards = arrayValue(entry.guards, "execution guards", []).map((guard, guardIndex) => {
    const item = asRecord(guard, `execution guard ${guardIndex}`);
    return {
      id: requiredString(item.id ?? item.guard_id, "execution guard id"),
      transitionId: requiredString(item.transition_id, "execution guard transition_id"),
      accepted: item.accepted === true,
    };
  });
  const commandOutcomes = arrayValue(entry.command_outcomes, "execution command_outcomes", []).map((outcome, outcomeIndex) => {
    const item = asRecord(outcome, `execution command outcome ${outcomeIndex}`);
    return {
      command: requiredString(item.command, "command outcome command"),
      status: requiredString(item.status, "command outcome status"),
      detail: optionalString(item.detail),
    };
  });
  return {
    schema: schema.schema as StatechartExecution["schema"],
    instanceId: u64String(entry.instance_id, "execution instance_id", true),
    decisionFingerprint: u64String(entry.decision_fingerprint, "execution decision_fingerprint", true),
    outcome: requiredString(entry.outcome, "execution outcome"),
    event: requiredString(entry.event, "execution event"),
    transitionIds,
    fromConfiguration: stringArray(entry.from_configuration, "execution from_configuration",
      typeof entry.from === "string" ? [entry.from] : []),
    toConfiguration: stringArray(entry.to_configuration, "execution to_configuration",
      typeof entry.to === "string" ? [entry.to] : []),
    revision: u64String(entry.revision, "execution revision"),
    actions,
    guards,
    commands: stringArray(entry.commands, "execution commands", []),
    commandOutcomes,
    internalEvents: stringArray(entry.internal_events, "execution internal_events", []),
  };
}

export function diffStatechartDefinitions(
  previous: StatechartDefinitionArtifact,
  next: StatechartDefinitionArtifact,
): StatechartDefinitionDiff {
  const previousStates = new Set(previous.states.map((state) => state.id));
  const nextStates = new Set(next.states.map((state) => state.id));
  const previousTransitions = new Map(previous.transitions.map((transition) => [transition.id, transition]));
  const nextTransitions = new Map(next.transitions.map((transition) => [transition.id, transition]));
  return {
    fromVersion: previous.version,
    toVersion: next.version,
    statesAdded: [...nextStates].filter((id) => !previousStates.has(id)).sort(),
    statesRemoved: [...previousStates].filter((id) => !nextStates.has(id)).sort(),
    transitionsAdded: [...nextTransitions.keys()].filter((id) => !previousTransitions.has(id)).sort(),
    transitionsRemoved: [...previousTransitions.keys()].filter((id) => !nextTransitions.has(id)).sort(),
    transitionsChanged: [...nextTransitions].filter(([id, transition]) => {
      const before = previousTransitions.get(id);
      return before !== undefined && JSON.stringify(before) !== JSON.stringify(transition);
    }).map(([id]) => id).sort(),
  };
}

function parseCoverage(value: unknown, index: number): StatechartCoverage {
  const entry = asRecord(value, `statechart coverage ${index}`);
  const schema = statechartSchema(entry, "coverage", `statechart coverage ${index}`);
  return {
    schema: schema.schema as StatechartCoverage["schema"],
    definitionId: requiredString(entry.definition_id, "coverage definition_id"),
    definitionFingerprint: u64String(entry.definition_fingerprint, "coverage definition_fingerprint", true),
    stateCounts: countMap(entry.states, "coverage states"),
    transitionCounts: countMap(entry.transitions, "coverage transitions"),
    eventCounts: countMap(entry.events, "coverage events"),
  };
}

function countMap(value: unknown, label: string): Record<string, string> {
  const result: Record<string, string> = {};
  for (const [index, raw] of arrayValue(value, label, []).entries()) {
    const entry = asRecord(raw, `${label} ${index}`);
    const id = requiredString(entry.id, `${label} ${index} id`);
    if (id in result) throw new Error(`${label} has duplicate id ${id}`);
    result[id] = u64String(entry.count, `${label} ${index} count`);
  }
  return result;
}

function validateDefinition(definition: StatechartDefinitionArtifact): void {
  const ids = new Set<string>();
  const transitionIds = new Set<string>();
  for (const state of definition.states) {
    if (ids.has(state.id)) throw new Error(`statechart ${definition.id} has duplicate state ${state.id}`);
    ids.add(state.id);
  }
  if (!ids.has(definition.initial)) throw new Error(`statechart ${definition.id} has unknown initial ${definition.initial}`);
  for (const state of definition.states) {
    if (state.parent && !ids.has(state.parent)) throw new Error(`state ${state.id} has unknown parent ${state.parent}`);
    if (state.initial && !ids.has(state.initial)) throw new Error(`state ${state.id} has unknown initial ${state.initial}`);
    const visited = new Set([state.id]);
    let cursor = state.parent;
    while (cursor) {
      if (visited.has(cursor)) throw new Error(`statechart ${definition.id} has a parent cycle at ${cursor}`);
      visited.add(cursor);
      cursor = definition.states.find((candidate) => candidate.id === cursor)?.parent ?? null;
    }
  }
  for (const transition of definition.transitions) {
    if (transitionIds.has(transition.id)) throw new Error(`statechart ${definition.id} has duplicate transition ${transition.id}`);
    transitionIds.add(transition.id);
    if (!ids.has(transition.source)) throw new Error(`transition ${transition.id} has unknown source ${transition.source}`);
    if (transition.target && !ids.has(transition.target)) throw new Error(`transition ${transition.id} has unknown target ${transition.target}`);
  }
}

function stateDetail(state: StatechartStateNode): string {
  const actions = [...state.entry.map((id) => `entry:${id}`), ...state.exit.map((id) => `exit:${id}`), ...(state.invocations ?? []).map((invoke) => `invoke:${invoke.id}`)];
  return [state.kind, state.description, ...actions].filter(Boolean).join(" · ");
}

function sourceDetail(source: StatechartSourceRef): string {
  return source.file ? `${source.file}:${source.line || 1}${source.declaration ? ` (${source.declaration})` : ""}` : "";
}

function transitionDetail(transition: StatechartTransition): string {
  return [transition.id, transition.guard ? `guard:${transition.guard}` : "", ...transition.actions.map((id) => `action:${id}`)]
    .filter(Boolean).join(" · ");
}

function parseSource(value: unknown): StatechartSourceRef {
  const entry = value && typeof value === "object" && !Array.isArray(value) ? value as UnknownRecord : {};
  return {
    file: optionalString(entry.file),
    declaration: optionalString(entry.declaration),
    line: nonNegativeNumber(entry.line, "source line", 0),
    column: nonNegativeNumber(entry.column, "source column", 0),
  };
}

function statechartSchema(entry: UnknownRecord, kind: "definition" | "snapshot" | "execution" | "coverage", label: string): { schema: string; version: 1 | 2 } {
  const version = entry.schema_version;
  if (version !== 1 && version !== 2) throw new Error(`${label} schema_version must be 1 or 2`);
  const expected = `zigeffect.statechart.${kind}.v${version}`;
  if (entry.schema !== expected) throw new Error(`${label} uses unsupported schema ${String(entry.schema ?? "missing")}`);
  return { schema: expected, version };
}

function asRecord(value: unknown, label: string): UnknownRecord {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error(`${label} must be an object`);
  return value as UnknownRecord;
}

function arrayValue(value: unknown, label: string, fallback?: unknown[]): unknown[] {
  if (value === undefined && fallback) return fallback;
  if (!Array.isArray(value)) throw new Error(`${label} must be an array`);
  return value;
}

function stringArray(value: unknown, label: string, fallback: string[] = []): string[] {
  if (value === undefined) return fallback;
  if (!Array.isArray(value) || value.some((item) => typeof item !== "string")) throw new Error(`${label} must be a string array`);
  return value as string[];
}

function requiredString(value: unknown, label: string): string {
  if (typeof value !== "string" || value.length === 0) throw new Error(`${label} must be a non-empty string`);
  return value;
}

function optionalString(value: unknown): string {
  return typeof value === "string" ? value : "";
}

function nullableString(value: unknown, label: string): string | null {
  if (value === undefined || value === null) return null;
  if (typeof value !== "string") throw new Error(`${label} must be a string or null`);
  return value;
}

function positiveNumber(value: unknown, label: string): number {
  if (typeof value !== "number" || !Number.isFinite(value) || value <= 0) throw new Error(`${label} must be positive`);
  return value;
}

function nonNegativeNumber(value: unknown, label: string, fallback?: number): number {
  if (value === undefined && fallback !== undefined) return fallback;
  if (typeof value !== "number" || !Number.isFinite(value) || value < 0) throw new Error(`${label} must be non-negative`);
  return value;
}

function u64String(value: unknown, label: string, positive = false): string {
  let parsed: bigint;
  if (typeof value === "string" && /^(0|[1-9][0-9]*)$/.test(value)) parsed = BigInt(value);
  else if (typeof value === "number" && Number.isSafeInteger(value) && value >= 0) parsed = BigInt(value);
  else throw new Error(`${label} must be a decimal u64 string or safe legacy integer`);
  if (parsed > 18_446_744_073_709_551_615n || (positive && parsed === 0n)) throw new Error(`${label} is outside u64 range`);
  return parsed.toString(10);
}
