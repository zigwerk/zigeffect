import { redactLocalDevText } from "../localDevRedaction";

export const PROJECT_DEVELOPMENT_SCHEMA = "zigeffect.project-development.v1" as const;
const PROJECT_SCHEMA = "zigeffect.project.v1";
const STATUS_SCHEMA = "zigeffect.project-status.v1";
const HANDOFF_SCHEMA = "zigeffect.agent-handoff.v1";
const MAX_ITEMS = 4096;

export type ProjectConnectionState = "static" | "live" | "recovered" | "disconnected";
export type ProjectRecoveryState = "clean" | "recovered" | "interrupted" | "stale";
export type ProjectApprovalState = "not_required" | "pending" | "approved" | "rejected";

export type ProjectComponentModel = {
  id: string; kind: string; path: string; dependsOn: string[]; capabilities: string[];
};
export type ProjectCommandModel = {
  id: string; argv: string[]; command: string; component: string | null;
};
export type ProjectAcceptanceModel = {
  id: string; requirement: string; command: string; expectation: string; status: string;
};
export type ProjectEvidenceModel = {
  id: string; requirement: string; acceptanceCheck: string | null; component: string;
  kind: string; artifact: string; eventIds: string[]; summary: string; sessionId: string | null;
};
export type ProjectRequirementModel = {
  id: string; summary: string; component: string; status: string;
  checks: ProjectAcceptanceModel[]; evidence: ProjectEvidenceModel[];
};
export type ProjectTaskModel = {
  id: string; requirement: string; component: string; summary: string; status: string; sessionId: string | null;
};
export type ProjectNextActionModel = {
  id: string; requirement: string; component: string; summary: string; command: string | null; sessionId: string | null;
};
export type ProjectArtifactModel = {
  id: string; path: string; kind: string; requirement: string | null; acceptanceCheck: string | null; sessionId: string | null;
};
export type ApplicationFactModel = {
  eventId: string; kind: string; label: string; status: string; detail: string; component: string | null;
  serviceKey: string; artifactId: string; domainEntityRef: string; dataSubjectRef: string;
  schemaRef: string; causeEventId: string | null;
};
export type ProjectSessionModel = {
  id: string; provider: string; status: string; connection: ProjectConnectionState;
  recovery: ProjectRecoveryState; approval: ProjectApprovalState; taskIds: string[];
  evidenceIds: string[]; artifactIds: string[]; summary: string;
};
export type ProjectDevelopmentModel = {
  schema: typeof PROJECT_DEVELOPMENT_SCHEMA; sequence: number; project: string; version: string; kind: string;
  connection: ProjectConnectionState; recovery: ProjectRecoveryState; approval: ProjectApprovalState;
  currentSession: string | null; baselineSession: string | null; components: ProjectComponentModel[];
  dependencies: Array<{ from: string; to: string }>; commands: ProjectCommandModel[];
  requirements: ProjectRequirementModel[]; checks: ProjectAcceptanceModel[]; tasks: ProjectTaskModel[];
  evidence: ProjectEvidenceModel[]; nextActions: ProjectNextActionModel[]; artifacts: ProjectArtifactModel[];
  applicationFacts: ApplicationFactModel[]; sessions: ProjectSessionModel[]; blockers: string[];
};
export type ProjectDevelopmentFrame = Record<string, unknown> & {
  schema: typeof PROJECT_DEVELOPMENT_SCHEMA; sequence: number;
};

type UnknownRecord = Record<string, unknown>;
const applicationKinds: Record<string, string> = {
  "app.config.load": "config_load",
  "app.schema.decode": "schema_decode",
  "app.command.execute": "command_execution",
  "app.request.handle": "request_handling",
  "app.sql.transaction": "sql_transaction",
  "app.external.call": "external_call",
  "app.artifact.produce": "artifact_production",
  "app.component.dependency": "component_dependency",
  "app.acceptance.evaluate": "acceptance_evaluation",
};

function object(value: unknown, label: string): UnknownRecord {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error(`${label} must be an object`);
  return value as UnknownRecord;
}
function optionalObject(value: unknown, label: string): UnknownRecord | null {
  return value === undefined || value === null ? null : object(value, label);
}
function array(value: unknown, label: string, required = false): unknown[] {
  if (value === undefined && !required) return [];
  if (!Array.isArray(value)) throw new Error(`${label} must be an array`);
  if (value.length > MAX_ITEMS) throw new Error(`${label} exceeds ${MAX_ITEMS} items`);
  return value;
}
function text(value: unknown, label: string, allowEmpty = false): string {
  if (typeof value !== "string" || (!allowEmpty && value.length === 0)) throw new Error(`${label} must be a non-empty string`);
  if (value.length > 4096) throw new Error(`${label} is too long`);
  return redactLocalDevText(value);
}
function optionalText(value: unknown, label: string): string | null {
  return value === undefined || value === null ? null : text(value, label);
}
function stringList(value: unknown, label: string): string[] {
  return array(value, label).map((entry, index) => text(entry, `${label}[${index}]`));
}
function enumeration<T extends string>(value: unknown, label: string, values: readonly T[], fallback?: T): T {
  if (value === undefined && fallback !== undefined) return fallback;
  const parsed = text(value, label) as T;
  if (!values.includes(parsed)) throw new Error(`${label} is invalid`);
  return parsed;
}
function sequence(value: unknown): number {
  if (!Number.isSafeInteger(value) || (value as number) < 0) throw new Error("sequence must be a non-negative safe integer");
  return value as number;
}
function eventId(value: unknown, label: string): string {
  if (!Number.isSafeInteger(value) || (value as number) < 0) throw new Error(`${label} must be a non-negative safe integer`);
  return String(value);
}
function unique<T extends { id: string }>(items: T[], label: string): T[] {
  const ids = new Set<string>();
  for (const item of items) {
    if (ids.has(item.id)) throw new Error(`duplicate ${label} id: ${item.id}`);
    ids.add(item.id);
  }
  return items;
}
function mergeUnique<T extends { id: string }>(left: T[], right: T[], label: string): T[] {
  const values = new Map(left.map((item) => [item.id, item]));
  for (const item of right) values.set(item.id, item);
  return unique([...values.values()], label);
}

function parseComponents(value: unknown): ProjectComponentModel[] {
  return unique(array(value, "manifest.components", true).map((entry, index) => {
    const item = object(entry, `component[${index}]`);
    return {
      id: text(item.id, `component[${index}].id`),
      kind: text(item.kind, `component[${index}].kind`),
      path: text(item.path, `component[${index}].path`),
      dependsOn: stringList(item.depends_on, `component[${index}].depends_on`),
      capabilities: stringList(item.capabilities, `component[${index}].capabilities`),
    };
  }), "component");
}
function parseCommands(value: unknown): ProjectCommandModel[] {
  return unique(array(value, "manifest.commands").map((entry, index) => {
    const item = object(entry, `command[${index}]`);
    const argv = stringList(item.argv, `command[${index}].argv`);
    if (argv.length === 0) throw new Error(`command[${index}].argv must not be empty`);
    return {
      id: text(item.id, `command[${index}].id`), argv, command: argv.join(" "),
      component: optionalText(item.component, `command[${index}].component`),
    };
  }), "command");
}
function parseChecks(value: unknown): ProjectAcceptanceModel[] {
  return unique(array(value, "manifest.acceptance_checks").map((entry, index) => {
    const item = object(entry, `acceptance_check[${index}]`);
    return {
      id: text(item.id, `acceptance_check[${index}].id`),
      requirement: text(item.requirement, `acceptance_check[${index}].requirement`),
      command: text(item.command, `acceptance_check[${index}].command`),
      expectation: text(item.expectation, `acceptance_check[${index}].expectation`),
      status: text(item.status ?? "pending", `acceptance_check[${index}].status`),
    };
  }), "acceptance check");
}
function parseTasks(value: unknown, sessionId: string | null): ProjectTaskModel[] {
  return unique(array(value, "tasks").map((entry, index) => {
    const item = object(entry, `task[${index}]`);
    return {
      id: text(item.id, `task[${index}].id`), requirement: text(item.requirement, `task[${index}].requirement`),
      component: text(item.component, `task[${index}].component`), summary: text(item.summary, `task[${index}].summary`),
      status: text(item.status ?? "planned", `task[${index}].status`), sessionId,
    };
  }), "task");
}
function parseEvidence(value: unknown, sessionId: string | null): ProjectEvidenceModel[] {
  return unique(array(value, "evidence").map((entry, index) => {
    const item = object(entry, `evidence[${index}]`);
    return {
      id: text(item.id, `evidence[${index}].id`), requirement: text(item.requirement, `evidence[${index}].requirement`),
      acceptanceCheck: optionalText(item.acceptance_check, `evidence[${index}].acceptance_check`),
      component: text(item.component, `evidence[${index}].component`), kind: text(item.kind, `evidence[${index}].kind`),
      artifact: text(item.artifact ?? "", `evidence[${index}].artifact`, true),
      eventIds: array(item.causal_event_ids, `evidence[${index}].causal_event_ids`).map(
        (id, idIndex) => eventId(id, `evidence[${index}].causal_event_ids[${idIndex}]`),
      ),
      summary: text(item.summary, `evidence[${index}].summary`), sessionId,
    };
  }), "evidence");
}
function parseActions(value: unknown, sessionId: string | null): ProjectNextActionModel[] {
  return unique(array(value, "next_actions").map((entry, index) => {
    const item = object(entry, `next_action[${index}]`);
    return {
      id: text(item.id, `next_action[${index}].id`), requirement: text(item.requirement, `next_action[${index}].requirement`),
      component: text(item.component, `next_action[${index}].component`), summary: text(item.summary, `next_action[${index}].summary`),
      command: optionalText(item.command, `next_action[${index}].command`), sessionId,
    };
  }), "next action");
}
function parseSessions(value: unknown): ProjectSessionModel[] {
  return unique(array(value, "sessions").map((entry, index) => {
    const item = object(entry, `session[${index}]`);
    return {
      id: text(item.id, `session[${index}].id`), provider: text(item.provider, `session[${index}].provider`),
      status: text(item.status, `session[${index}].status`),
      connection: enumeration(item.connection, `session[${index}].connection`, ["static", "live", "recovered", "disconnected"], "static"),
      recovery: enumeration(item.recovery, `session[${index}].recovery`, ["clean", "recovered", "interrupted", "stale"], "clean"),
      approval: enumeration(item.approval, `session[${index}].approval`, ["not_required", "pending", "approved", "rejected"], "not_required"),
      taskIds: stringList(item.task_ids, `session[${index}].task_ids`),
      evidenceIds: stringList(item.evidence_ids, `session[${index}].evidence_ids`),
      artifactIds: stringList(item.artifact_ids, `session[${index}].artifact_ids`),
      summary: text(item.summary ?? "", `session[${index}].summary`, true),
    };
  }), "session");
}
function parseApplicationFacts(value: unknown, componentIds: Set<string>): ApplicationFactModel[] {
  const facts: ApplicationFactModel[] = [];
  for (const [index, entry] of array(value, "events").entries()) {
    const item = object(entry, `event[${index}]`);
    if (item.kind !== "span_recorded" || typeof item.label !== "string" || !(item.label in applicationKinds)) continue;
    const serviceKey = text(item.service_key ?? "", `event[${index}].service_key`, true);
    const entity = text(item.domain_entity_ref ?? "", `event[${index}].domain_entity_ref`, true);
    const component = componentIds.has(serviceKey) ? serviceKey : componentIds.has(entity) ? entity : null;
    facts.push({
      eventId: eventId(item.id, `event[${index}].id`), kind: applicationKinds[item.label]!,
      label: text(item.label, `event[${index}].label`), status: text(item.status ?? "unknown", `event[${index}].status`),
      detail: text(item.redacted_detail ?? "", `event[${index}].redacted_detail`, true), component, serviceKey,
      artifactId: text(item.artifact_id ?? "", `event[${index}].artifact_id`, true), domainEntityRef: entity,
      dataSubjectRef: text(item.data_subject_ref ?? "", `event[${index}].data_subject_ref`, true),
      schemaRef: text(item.schema_ref ?? "", `event[${index}].schema_ref`, true),
      causeEventId: item.cause_event_id === undefined || item.cause_event_id === null
        ? null : eventId(item.cause_event_id, `event[${index}].cause_event_id`),
    });
  }
  return facts;
}

export function deriveProjectDevelopmentModel(input: unknown): ProjectDevelopmentModel {
  const root = object(input, "project development frame");
  if (root.schema !== PROJECT_DEVELOPMENT_SCHEMA) throw new Error("unsupported project development schema");
  const manifest = object(root.manifest, "manifest");
  if (manifest.schema !== PROJECT_SCHEMA) throw new Error("unsupported project manifest schema");
  const components = parseComponents(manifest.components);
  const commands = parseCommands(manifest.commands);
  const componentIds = new Set(components.map((component) => component.id));
  const commandIds = new Set(commands.map((command) => command.id));
  for (const component of components) {
    for (const dependency of component.dependsOn) {
      if (!componentIds.has(dependency)) throw new Error(`component ${component.id} depends on unknown component ${dependency}`);
    }
  }
  for (const command of commands) {
    if (command.component && !componentIds.has(command.component)) throw new Error(`command ${command.id} references unknown component ${command.component}`);
  }
  const rawRequirements = unique(array(manifest.requirements, "manifest.requirements").map((entry, index) => {
    const item = object(entry, `requirement[${index}]`);
    return {
      id: text(item.id, `requirement[${index}].id`), summary: text(item.summary, `requirement[${index}].summary`),
      component: text(item.component, `requirement[${index}].component`), status: text(item.status ?? "planned", `requirement[${index}].status`),
    };
  }), "requirement");
  const requirementIds = new Set(rawRequirements.map((requirement) => requirement.id));
  for (const requirement of rawRequirements) {
    if (!componentIds.has(requirement.component)) throw new Error(`requirement ${requirement.id} references unknown component ${requirement.component}`);
  }
  const checks = parseChecks(manifest.acceptance_checks);
  const checkIds = new Set(checks.map((check) => check.id));
  for (const check of checks) {
    if (!requirementIds.has(check.requirement)) throw new Error(`acceptance check ${check.id} references unknown requirement ${check.requirement}`);
    if (!commandIds.has(check.command)) throw new Error(`acceptance check ${check.id} references unknown command ${check.command}`);
  }

  const currentSession = optionalText(root.current_session, "current_session");
  const status = optionalObject(root.status, "status");
  if (status && status.schema !== STATUS_SCHEMA) throw new Error("unsupported project status schema");
  const handoff = optionalObject(root.handoff, "handoff");
  if (handoff && handoff.schema !== HANDOFF_SCHEMA) throw new Error("unsupported agent handoff schema");
  const handoffSession = handoff ? text(handoff.session, "handoff.session") : null;
  if (handoff && text(handoff.project, "handoff.project") !== text(manifest.name, "manifest.name")) {
    throw new Error("handoff project does not match manifest");
  }
  const statusSession = currentSession ?? handoffSession;
  const tasks = mergeUnique(status ? parseTasks(status.tasks, statusSession) : [], handoff ? parseTasks(handoff.tasks, handoffSession) : [], "task");
  const evidence = mergeUnique(status ? parseEvidence(status.evidence, statusSession) : [], handoff ? parseEvidence(handoff.evidence, handoffSession) : [], "evidence");
  const nextActions = mergeUnique(status ? parseActions(status.next_actions, statusSession) : [], handoff ? parseActions(handoff.next_actions, handoffSession) : [], "next action");
  for (const item of [...tasks, ...evidence, ...nextActions]) {
    if (!requirementIds.has(item.requirement)) throw new Error(`${item.id} references unknown requirement ${item.requirement}`);
    if (!componentIds.has(item.component)) throw new Error(`${item.id} references unknown component ${item.component}`);
  }
  for (const item of evidence) {
    if (item.acceptanceCheck && !checkIds.has(item.acceptanceCheck)) throw new Error(`${item.id} references unknown acceptance check ${item.acceptanceCheck}`);
  }
  for (const action of nextActions) {
    if (action.command && !commandIds.has(action.command)) throw new Error(`${action.id} references unknown command ${action.command}`);
  }

  let sessions = parseSessions(root.sessions);
  if (handoff && handoffSession && !sessions.some((session) => session.id === handoffSession)) {
    sessions = [...sessions, {
      id: handoffSession, provider: text(handoff.provider, "handoff.provider"), status: "handoff",
      connection: "static", recovery: "clean", approval: "not_required",
      taskIds: tasks.filter((task) => task.sessionId === handoffSession).map((task) => task.id),
      evidenceIds: evidence.filter((item) => item.sessionId === handoffSession).map((item) => item.id),
      artifactIds: evidence.filter((item) => item.sessionId === handoffSession && item.artifact).map((item) => item.artifact),
      summary: text(handoff.summary, "handoff.summary"),
    }];
  }
  const taskIds = new Set(tasks.map((task) => task.id));
  const evidenceIds = new Set(evidence.map((item) => item.id));
  for (const session of sessions) {
    for (const id of session.taskIds) if (!taskIds.has(id)) throw new Error(`session ${session.id} references unknown task ${id}`);
    for (const id of session.evidenceIds) if (!evidenceIds.has(id)) throw new Error(`session ${session.id} references unknown evidence ${id}`);
  }
  const artifacts = unique(evidence.filter((item) => item.artifact.length > 0).map((item) => ({
    id: item.artifact, path: item.artifact, kind: item.kind, requirement: item.requirement,
    acceptanceCheck: item.acceptanceCheck, sessionId: item.sessionId,
  })), "artifact");
  const requirements: ProjectRequirementModel[] = rawRequirements.map((requirement) => ({
    ...requirement,
    checks: checks.filter((check) => check.requirement === requirement.id),
    evidence: evidence.filter((item) => item.requirement === requirement.id),
  }));
  return {
    schema: PROJECT_DEVELOPMENT_SCHEMA, sequence: sequence(root.sequence), project: text(manifest.name, "manifest.name"),
    version: text(manifest.version, "manifest.version"), kind: text(manifest.kind, "manifest.kind"),
    connection: enumeration(root.connection, "connection", ["static", "live", "recovered", "disconnected"], "static"),
    recovery: enumeration(root.recovery_state, "recovery_state", ["clean", "recovered", "interrupted", "stale"], "clean"),
    approval: enumeration(root.approval_state, "approval_state", ["not_required", "pending", "approved", "rejected"], "not_required"),
    currentSession, baselineSession: optionalText(root.baseline_session, "baseline_session"), components,
    dependencies: components.flatMap((component) => component.dependsOn.map((dependency) => ({ from: component.id, to: dependency }))),
    commands, requirements, checks, tasks, evidence, nextActions, artifacts,
    applicationFacts: parseApplicationFacts(root.events, componentIds), sessions,
    blockers: handoff ? stringList(handoff.blockers, "handoff.blockers") : [],
  };
}

export function parseProjectDevelopmentFrameMessage(data: string): ProjectDevelopmentFrame | null {
  try {
    const parsed = JSON.parse(data) as unknown;
    deriveProjectDevelopmentModel(parsed);
    return parsed as ProjectDevelopmentFrame;
  } catch {
    return null;
  }
}

export function focusProjectDevelopment(
  model: ProjectDevelopmentModel,
  focus: { component?: string | null; session?: string | null },
) {
  const component = focus.component ?? null;
  const session = focus.session ? model.sessions.find((item) => item.id === focus.session) : null;
  if (component && !model.components.some((item) => item.id === component)) throw new Error(`unknown component ${component}`);
  if (focus.session && !session) throw new Error(`unknown session ${focus.session}`);
  const sessionTasks = session ? new Set(session.taskIds) : null;
  const sessionEvidence = session ? new Set(session.evidenceIds) : null;
  const requirements = model.requirements.filter((item) => !component || item.component === component);
  const requirementIds = new Set(requirements.map((item) => item.id));
  const tasks = model.tasks.filter((item) => requirementIds.has(item.requirement) && (!sessionTasks || sessionTasks.has(item.id)));
  const evidence = model.evidence.filter((item) => requirementIds.has(item.requirement) && (!sessionEvidence || sessionEvidence.has(item.id)));
  const evidencePaths = new Set(evidence.map((item) => item.artifact).filter(Boolean));
  return {
    components: model.components.filter((item) => !component || item.id === component || item.dependsOn.includes(component) || model.dependencies.some((edge) => edge.from === component && edge.to === item.id)),
    commands: model.commands.filter((item) => !component || item.component === null || item.component === component),
    requirements, checks: model.checks.filter((item) => requirementIds.has(item.requirement)), tasks, evidence,
    nextActions: model.nextActions.filter((item) => requirementIds.has(item.requirement) && (!session || item.sessionId === session.id)),
    artifacts: model.artifacts.filter((item) => evidencePaths.has(item.path)),
    applicationFacts: model.applicationFacts.filter((item) => !component || item.component === component || item.serviceKey === component || item.domainEntityRef === component),
  };
}

export function compareProjectSessions(model: ProjectDevelopmentModel, baselineId: string, currentId: string) {
  const baseline = model.sessions.find((session) => session.id === baselineId);
  const current = model.sessions.find((session) => session.id === currentId);
  if (!baseline || !current) throw new Error("unknown comparison session");
  const added = (before: string[], after: string[]) => {
    const values = new Set(before);
    return after.filter((value) => !values.has(value)).length;
  };
  return {
    baseline: baseline.id, current: current.id, tasksAdded: added(baseline.taskIds, current.taskIds),
    evidenceAdded: added(baseline.evidenceIds, current.evidenceIds), artifactsAdded: added(baseline.artifactIds, current.artifactIds),
    approvalChanged: baseline.approval !== current.approval, recoveryChanged: baseline.recovery !== current.recovery,
  };
}
