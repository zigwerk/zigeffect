import type {
  LocalDevAgentKind,
  LocalDevAgentModel,
  LocalDevAgentStatus,
  LocalDevArtifactModel,
  LocalDevCheckModel,
  LocalDevCheckStatus,
  LocalDevSessionModel,
  LocalDevTransportModel,
} from "./causalArtifact";

export type LocalDevSessionEventKind =
  | "agent_status"
  | "check_result"
  | "artifact_link"
  | "transport_status"
  | "next_action"
  | "guardrail"
  | "warning";

export type LocalDevSessionEvent = {
  sequence: number;
  kind: LocalDevSessionEventKind;
  agent_id?: string;
  agent_kind?: LocalDevAgentKind;
  agent_label?: string;
  status?: LocalDevAgentStatus | LocalDevCheckStatus | string;
  protocol?: LocalDevTransportModel["protocol"];
  url?: string;
  session_id?: string;
  frame_count?: number;
  fallback?: string;
  task?: string;
  label?: string;
  command?: string;
  detail?: string;
  artifact_path?: string;
  key?: string;
  path?: string;
  value?: string;
};

type UnknownRecord = Record<string, unknown>;

const eventKinds = new Set<LocalDevSessionEventKind>([
  "agent_status",
  "check_result",
  "artifact_link",
  "transport_status",
  "next_action",
  "guardrail",
  "warning",
]);

export function parseLocalDevSessionEventMessage(data: string): LocalDevSessionEvent | null {
  try {
    return normalizeLocalDevSessionEvent(unwrapLocalDevTransportFrame(JSON.parse(data) as unknown));
  } catch {
    return null;
  }
}

export function localDevSessionEventsFromJsonl(text: string): LocalDevSessionEvent[] {
  return text
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line.length > 0)
    .map(parseLocalDevSessionEventMessage)
    .filter((event): event is LocalDevSessionEvent => event !== null)
    .sort((left, right) => left.sequence - right.sequence);
}

export function redactLocalDevSessionText(value: string): string {
  return redactLocalDevText(value);
}

export function applyLocalDevSessionEvents(
  base: LocalDevSessionModel,
  events: readonly LocalDevSessionEvent[],
): LocalDevSessionModel {
  const session: LocalDevSessionModel = {
    ...base,
    agents: [...base.agents],
    checks: [...base.checks],
    commands: [...base.commands],
    artifacts: [...base.artifacts],
    transports: [...base.transports],
    nextActions: [...base.nextActions],
    guardrails: [...base.guardrails],
    warnings: [...base.warnings],
  };

  for (const event of [...events].sort((left, right) => left.sequence - right.sequence)) {
    applyLocalDevSessionEvent(session, event);
  }

  return session;
}

function normalizeLocalDevSessionEvent(value: unknown): LocalDevSessionEvent | null {
  if (!isRecord(value)) {
    return null;
  }
  const sequence = safeSequence(value.sequence);
  const kind = localDevSessionEventKind(value.kind);
  if (sequence === null || kind === null) {
    return null;
  }

  const event: LocalDevSessionEvent = { sequence, kind };
  setText(event, "agent_id", value.agent_id);
  event.agent_kind = localDevAgentKind(value.agent_kind);
  setText(event, "agent_label", value.agent_label);
  if (kind === "check_result") {
    event.status = localDevCheckStatus(value.status);
  } else if (kind === "transport_status") {
    event.status = localDevTransportStatus(value.status);
  } else {
    event.status = localDevAgentStatus(value.status);
  }
  event.protocol = localDevTransportProtocol(value.protocol);
  setText(event, "url", value.url);
  setText(event, "session_id", value.session_id);
  const frameCount = safeSequence(value.frame_count);
  if (frameCount !== null) {
    event.frame_count = frameCount;
  }
  setText(event, "fallback", value.fallback);
  setText(event, "task", value.task);
  setText(event, "label", value.label);
  setText(event, "command", value.command);
  setText(event, "detail", value.detail);
  setText(event, "artifact_path", value.artifact_path);
  setText(event, "key", value.key);
  setText(event, "path", value.path);
  setText(event, "value", value.value);

  if (kind === "agent_status" && !event.agent_id) {
    return null;
  }
  if (kind === "check_result" && !event.label) {
    return null;
  }
  if (kind === "artifact_link" && (!event.key || !event.path)) {
    return null;
  }
  if (kind === "transport_status" && !event.protocol) {
    return null;
  }
  if ((kind === "next_action" || kind === "guardrail" || kind === "warning") && !event.value) {
    return null;
  }
  return event;
}

function applyLocalDevSessionEvent(session: LocalDevSessionModel, event: LocalDevSessionEvent): void {
  switch (event.kind) {
    case "agent_status":
      upsertAgent(session.agents, agentFromEvent(event));
      break;
    case "check_result":
      upsertCheck(session.checks, checkFromEvent(event));
      break;
    case "artifact_link":
      upsertArtifact(session.artifacts, artifactFromEvent(event));
      break;
    case "transport_status":
      upsertTransport(session.transports, transportFromEvent(event));
      break;
    case "next_action":
      appendUnique(session.nextActions, event.value ?? "");
      break;
    case "guardrail":
      appendUnique(session.guardrails, event.value ?? "");
      break;
    case "warning":
      appendUnique(session.warnings, event.value ?? "");
      break;
  }
}

function agentFromEvent(event: LocalDevSessionEvent): LocalDevAgentModel {
  return {
    id: event.agent_id ?? "local-agent",
    label: event.agent_label ?? agentLabel(event.agent_kind ?? "other"),
    kind: event.agent_kind ?? "other",
    status: localDevAgentStatus(event.status),
    currentTask: event.task ?? null,
    lastEventId: null,
    artifactPath: event.artifact_path ?? null,
  };
}

function checkFromEvent(event: LocalDevSessionEvent): LocalDevCheckModel {
  return {
    label: event.label ?? "unnamed check",
    command: event.command ?? null,
    status: localDevCheckStatus(event.status),
    detail: event.detail ?? "",
    artifactPath: event.artifact_path ?? null,
  };
}

function artifactFromEvent(event: LocalDevSessionEvent): LocalDevArtifactModel {
  const key = event.key ?? "artifact";
  const path = event.path ?? "";
  return {
    key,
    label: labelFromKey(key),
    path,
    kind: artifactKind(path),
    workbenchCommand: path.endsWith(".json") ? `zig build causal-workbench -- ${path}` : null,
  };
}

function transportFromEvent(event: LocalDevSessionEvent): LocalDevTransportModel {
  return {
    protocol: event.protocol ?? "other",
    status: localDevTransportStatus(event.status),
    url: event.url ?? null,
    sessionId: event.session_id ?? null,
    frameCount: event.frame_count ?? 0,
    fallback: event.fallback ?? null,
    detail: event.detail ?? "",
  };
}

function upsertAgent(agents: LocalDevAgentModel[], agent: LocalDevAgentModel): void {
  const index = agents.findIndex((candidate) => candidate.id === agent.id);
  if (index === -1) {
    agents.push(agent);
  } else {
    agents[index] = { ...agents[index], ...agent };
  }
}

function upsertCheck(checks: LocalDevCheckModel[], check: LocalDevCheckModel): void {
  const index = checks.findIndex((candidate) => candidate.label === check.label);
  if (index === -1) {
    checks.push(check);
  } else {
    checks[index] = { ...checks[index], ...check };
  }
}

function upsertArtifact(artifacts: LocalDevArtifactModel[], artifact: LocalDevArtifactModel): void {
  const index = artifacts.findIndex((candidate) => candidate.key === artifact.key);
  if (index === -1) {
    artifacts.push(artifact);
  } else {
    artifacts[index] = artifact;
  }
}

function upsertTransport(transports: LocalDevTransportModel[], transport: LocalDevTransportModel): void {
  const index = transports.findIndex((candidate) =>
    candidate.protocol === transport.protocol &&
    candidate.sessionId === transport.sessionId &&
    candidate.url === transport.url
  );
  if (index === -1) {
    transports.push(transport);
  } else {
    transports[index] = { ...transports[index], ...transport };
  }
}

function appendUnique(values: string[], value: string): void {
  if (value.length > 0 && !values.includes(value)) {
    values.push(value);
  }
}

function setText<T extends keyof LocalDevSessionEvent>(
  event: LocalDevSessionEvent,
  key: T,
  value: unknown,
): void {
  const text = textValue(value);
  if (text.length > 0) {
    event[key] = redactLocalDevText(text) as LocalDevSessionEvent[T];
  }
}

function safeSequence(value: unknown): number | null {
  if (typeof value === "number" && Number.isSafeInteger(value) && value >= 0) {
    return value;
  }
  if (typeof value === "string" && value.trim().length > 0) {
    const parsed = Number(value);
    return Number.isSafeInteger(parsed) && parsed >= 0 ? parsed : null;
  }
  return null;
}

function localDevSessionEventKind(value: unknown): LocalDevSessionEventKind | null {
  const kind = textValue(value) as LocalDevSessionEventKind;
  return eventKinds.has(kind) ? kind : null;
}

function localDevAgentKind(value: unknown): LocalDevAgentKind {
  const kind = textValue(value);
  if (kind === "codex" || kind === "claude-code" || kind === "zigeffect" || kind === "human") {
    return kind;
  }
  return "other";
}

function localDevAgentStatus(value: unknown): LocalDevAgentStatus {
  const status = textValue(value);
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

function localDevCheckStatus(value: unknown): LocalDevCheckStatus {
  const status = textValue(value);
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

function localDevTransportProtocol(value: unknown): LocalDevTransportModel["protocol"] | undefined {
  const protocol = textValue(value);
  if (protocol === "webtransport" || protocol === "websocket" || protocol === "http") {
    return protocol;
  }
  if (protocol.length > 0) {
    return "other";
  }
  return undefined;
}

function localDevTransportStatus(value: unknown): string {
  const status = textValue(value);
  return status.length > 0 ? redactLocalDevText(status) : "unknown";
}

function artifactKind(path: string): LocalDevArtifactModel["kind"] {
  if (path.endsWith(".json")) return "json";
  if (path.endsWith(".jsonl") || path.endsWith(".ndjson")) return "jsonl";
  if (path.endsWith(".md")) return "markdown";
  if (path.endsWith(".txt") || path.endsWith(".log")) return "text";
  return "other";
}

function labelFromKey(key: string): string {
  return key
    .split("_")
    .filter((part) => part.length > 0)
    .map((part) => `${part.charAt(0).toUpperCase()}${part.slice(1)}`)
    .join(" ");
}

function agentLabel(kind: LocalDevAgentKind): string {
  switch (kind) {
    case "codex": return "Codex";
    case "claude-code": return "Claude Code";
    case "zigeffect": return "zigeffect tools";
    case "human": return "Human";
    case "other": return "Local agent";
  }
}

function unwrapLocalDevTransportFrame(value: unknown): unknown {
  if (!isRecord(value)) {
    return value;
  }
  if (textValue(value.schema) !== "zigeffect.webtransport.local-dev-frame.v1") {
    return value;
  }
  if (typeof value.payload === "string") {
    try {
      return JSON.parse(value.payload) as unknown;
    } catch {
      return null;
    }
  }
  return isRecord(value.payload) ? value.payload : null;
}

function redactLocalDevText(value: string): string {
  return value
    .replace(/\b([a-z][a-z0-9+.-]*:\/\/)[^/?#\s:@]+:[^/?#\s@]+@/gi, "$1<redacted>@")
    .replace(/\b(authorization|proxy-authorization)\s*:\s*(bearer|basic)\s+[^;\s,]+/gi, "$1: $2 <redacted>")
    .replace(/\bcookie\s*:\s*[^,\n\r]+/gi, "Cookie: <redacted>")
    .replace(
      /\b(api[_-]?key|x-api-key|token|password|secret|session(?:_id)?|sid)\b\s*[:=]\s*("[^"]*"|'[^']*'|[^;\s,]+)/gi,
      "$1=<redacted>",
    );
}

function textValue(value: unknown): string {
  if (typeof value === "string") {
    return value.length > 0 ? value : "";
  }
  if (typeof value === "number" && Number.isFinite(value)) {
    return String(value);
  }
  if (typeof value === "boolean") {
    return String(value);
  }
  return "";
}

function isRecord(value: unknown): value is UnknownRecord {
  return typeof value === "object" && value !== null;
}
