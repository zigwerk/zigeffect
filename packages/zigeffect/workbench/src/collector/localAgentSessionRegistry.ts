import { mkdir, readFile, rename, rm } from "node:fs/promises";
import { randomUUID } from "node:crypto";
import { Buffer } from "node:buffer";
import { dirname } from "node:path";
import type { LocalDevAgentKind } from "../causalArtifact";
import { redactLocalDevSessionText } from "../localDevSessionFeed";

export const LOCAL_AGENT_SESSION_SCHEMA = "zigeffect.local-agent-sessions.v1" as const;

export type LocalAgentSessionStatus =
  | "starting"
  | "running"
  | "done"
  | "failed"
  | "interrupted";

export type LocalAgentSessionDescriptor = {
  agentId: string;
  agentKind: LocalDevAgentKind;
  agentLabel: string;
  command: readonly string[];
  cwd?: string;
  task?: string;
};

export type LocalAgentSessionTerminal = {
  status: "done" | "failed" | "interrupted";
  exitCode: number | null;
  interrupted: boolean;
  lines: number;
  turns: number;
  ignored: number;
  postedEvents: number;
  lastSequence: number;
  detail?: string;
};

export type LocalAgentSessionRecord = {
  id: string;
  agentId: string;
  agentKind: LocalDevAgentKind;
  agentLabel: string;
  command: string;
  cwd: string | null;
  task: string | null;
  status: LocalAgentSessionStatus;
  startedAt: number;
  updatedAt: number;
  finishedAt: number | null;
  exitCode: number | null;
  interrupted: boolean;
  lines: number;
  turns: number;
  ignored: number;
  postedEvents: number;
  lastSequence: number;
  detail: string | null;
};

export type LocalAgentSessionSnapshot = {
  schema: typeof LOCAL_AGENT_SESSION_SCHEMA;
  sessions: LocalAgentSessionRecord[];
};

export type LocalAgentSessionRegistryOptions = {
  maxSessions?: number;
  now?: () => number;
};

export type LocalAgentSessionRegistry = {
  begin: (descriptor: LocalAgentSessionDescriptor, requestedId?: string) => LocalAgentSessionRecord;
  markRunning: (sessionId: string) => LocalAgentSessionRecord;
  finish: (sessionId: string, terminal: LocalAgentSessionTerminal) => LocalAgentSessionRecord;
  get: (sessionId: string) => LocalAgentSessionRecord | null;
  list: () => LocalAgentSessionRecord[];
  stateVersion: () => number;
  snapshot: () => LocalAgentSessionSnapshot;
  restore: (snapshot: unknown) => boolean;
};

export type LocalAgentSessionStore = {
  read: () => Promise<string | null>;
  write: (value: string) => Promise<void>;
};

export type LocalAgentSessionRestoreResult = "empty" | "restored" | "invalid";

const DEFAULT_MAX_SESSIONS = 256;
const MAX_RETAINED_TEXT_LENGTH = 4096;
const MAX_SNAPSHOT_BYTES = 8 * 1024 * 1024;
const TRUNCATION_MARKER = "... [truncated]";
const sessionIdPattern = /^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$/;
const terminalStatuses = new Set<LocalAgentSessionStatus>(["done", "failed", "interrupted"]);
const agentKinds = new Set<LocalDevAgentKind>(["codex", "claude-code", "zigeffect", "human", "other"]);

export function createLocalAgentSessionRegistry(
  options: LocalAgentSessionRegistryOptions = {},
): LocalAgentSessionRegistry {
  const maxSessions = positiveSafeInteger(options.maxSessions ?? DEFAULT_MAX_SESSIONS, "maxSessions");
  const clock = options.now ?? Date.now;
  const sessions = new Map<string, LocalAgentSessionRecord>();
  let stateVersion = 0;
  let generatedId = 0;

  function timestamp(): number {
    return nonNegativeSafeInteger(clock(), "registry timestamp");
  }

  function begin(
    descriptor: LocalAgentSessionDescriptor,
    requestedId?: string,
  ): LocalAgentSessionRecord {
    const now = timestamp();
    const id = requestedId ?? generatedSessionId(descriptor.agentId, now, ++generatedId);
    requireSessionId(id);
    if (sessions.has(id)) {
      throw new Error(`session already exists: ${id}`);
    }
    makeRoomForSession();
    const record: LocalAgentSessionRecord = {
      id,
      agentId: redactedText(descriptor.agentId),
      agentKind: descriptor.agentKind,
      agentLabel: redactedText(descriptor.agentLabel),
      command: redactedText(descriptor.command.join(" ")),
      cwd: optionalRedactedText(descriptor.cwd),
      task: optionalRedactedText(descriptor.task),
      status: "starting",
      startedAt: now,
      updatedAt: now,
      finishedAt: null,
      exitCode: null,
      interrupted: false,
      lines: 0,
      turns: 0,
      ignored: 0,
      postedEvents: 0,
      lastSequence: 0,
      detail: null,
    };
    sessions.set(id, record);
    stateVersion += 1;
    return cloneRecord(record);
  }

  function markRunning(sessionId: string): LocalAgentSessionRecord {
    const record = requiredSession(sessionId);
    if (record.status !== "starting") {
      throw new Error(`session ${sessionId} cannot transition from ${record.status} to running`);
    }
    record.status = "running";
    record.updatedAt = timestamp();
    stateVersion += 1;
    return cloneRecord(record);
  }

  function finish(
    sessionId: string,
    terminal: LocalAgentSessionTerminal,
  ): LocalAgentSessionRecord {
    const record = requiredSession(sessionId);
    if (terminalStatuses.has(record.status)) {
      throw new Error(`session ${sessionId} is already terminal`);
    }
    const now = timestamp();
    record.status = terminal.status;
    record.updatedAt = now;
    record.finishedAt = now;
    record.exitCode = nullableExitCode(terminal.exitCode);
    record.interrupted = terminal.interrupted;
    record.lines = nonNegativeSafeInteger(terminal.lines, "lines");
    record.turns = nonNegativeSafeInteger(terminal.turns, "turns");
    record.ignored = nonNegativeSafeInteger(terminal.ignored, "ignored");
    record.postedEvents = nonNegativeSafeInteger(terminal.postedEvents, "postedEvents");
    record.lastSequence = nonNegativeSafeInteger(terminal.lastSequence, "lastSequence");
    record.detail = optionalRedactedText(terminal.detail);
    stateVersion += 1;
    return cloneRecord(record);
  }

  function get(sessionId: string): LocalAgentSessionRecord | null {
    const record = sessions.get(sessionId);
    return record ? cloneRecord(record) : null;
  }

  function list(): LocalAgentSessionRecord[] {
    return [...sessions.values()]
      .sort((left, right) => right.startedAt - left.startedAt || left.id.localeCompare(right.id))
      .map(cloneRecord);
  }

  function snapshot(): LocalAgentSessionSnapshot {
    return {
      schema: LOCAL_AGENT_SESSION_SCHEMA,
      sessions: [...sessions.values()]
        .sort((left, right) => left.startedAt - right.startedAt || left.id.localeCompare(right.id))
        .map(cloneRecord),
    };
  }

  function restore(value: unknown): boolean {
    const restored = parseSnapshot(value, maxSessions);
    if (!restored) return false;
    const now = timestamp();
    for (const record of restored) {
      if (record.status === "starting" || record.status === "running") {
        record.status = "interrupted";
        record.interrupted = true;
        record.updatedAt = now;
        record.finishedAt = now;
        record.detail = "interrupted during registry recovery";
      }
    }
    sessions.clear();
    for (const record of restored) {
      sessions.set(record.id, record);
    }
    stateVersion += 1;
    return true;
  }

  function makeRoomForSession(): void {
    if (sessions.size < maxSessions) return;
    const oldestTerminal = [...sessions.values()]
      .filter((record) => terminalStatuses.has(record.status))
      .sort((left, right) => left.startedAt - right.startedAt || left.id.localeCompare(right.id))[0];
    if (!oldestTerminal) {
      throw new Error("session registry is full with active sessions");
    }
    sessions.delete(oldestTerminal.id);
  }

  function requiredSession(sessionId: string): LocalAgentSessionRecord {
    const record = sessions.get(sessionId);
    if (!record) throw new Error(`session not found: ${sessionId}`);
    return record;
  }

  return {
    begin,
    markRunning,
    finish,
    get,
    list,
    stateVersion: () => stateVersion,
    snapshot,
    restore,
  };
}

export async function saveLocalAgentSessionRegistry(
  registry: LocalAgentSessionRegistry,
  store: LocalAgentSessionStore,
): Promise<void> {
  await store.write(JSON.stringify(registry.snapshot()));
}

export async function restoreLocalAgentSessionRegistry(
  registry: LocalAgentSessionRegistry,
  store: LocalAgentSessionStore,
): Promise<LocalAgentSessionRestoreResult> {
  const text = await store.read();
  if (text === null) return "empty";
  if (Buffer.byteLength(text, "utf8") > MAX_SNAPSHOT_BYTES) return "invalid";
  let parsed: unknown;
  try {
    parsed = JSON.parse(text) as unknown;
  } catch {
    return "invalid";
  }
  return registry.restore(parsed) ? "restored" : "invalid";
}

export function bunLocalAgentSessionStore(path: string): LocalAgentSessionStore {
  return {
    async read() {
      try {
        return await readFile(path, "utf8");
      } catch (error) {
        if (isNodeError(error) && error.code === "ENOENT") return null;
        throw error;
      }
    },
    async write(value) {
      await mkdir(dirname(path), { recursive: true });
      const temporaryPath = `${path}.tmp-${process.pid}-${randomUUID()}`;
      try {
        await Bun.write(temporaryPath, value);
        await rename(temporaryPath, path);
      } finally {
        await rm(temporaryPath, { force: true });
      }
    },
  };
}

function parseSnapshot(value: unknown, maxSessions: number): LocalAgentSessionRecord[] | null {
  if (!isRecord(value) || value.schema !== LOCAL_AGENT_SESSION_SCHEMA || !Array.isArray(value.sessions)) {
    return null;
  }
  if (value.sessions.length > maxSessions) return null;
  const restored: LocalAgentSessionRecord[] = [];
  const ids = new Set<string>();
  for (const item of value.sessions) {
    const record = parseRecord(item);
    if (!record || ids.has(record.id)) return null;
    ids.add(record.id);
    restored.push(record);
  }
  return restored;
}

function parseRecord(value: unknown): LocalAgentSessionRecord | null {
  if (!isRecord(value)) return null;
  const status = sessionStatus(value.status);
  const kind = agentKind(value.agentKind);
  if (
    !status ||
    !kind ||
    typeof value.id !== "string" ||
    !sessionIdPattern.test(value.id) ||
    typeof value.agentId !== "string" ||
    typeof value.agentLabel !== "string" ||
    typeof value.command !== "string" ||
    !nullableString(value.cwd) ||
    !nullableString(value.task) ||
    !nullableString(value.detail) ||
    typeof value.interrupted !== "boolean"
  ) {
    return null;
  }
  const startedAt = safeIntegerValue(value.startedAt);
  const updatedAt = safeIntegerValue(value.updatedAt);
  const finishedAt = nullableSafeIntegerValue(value.finishedAt);
  const exitCode = nullableExitCodeValue(value.exitCode);
  const lines = safeIntegerValue(value.lines);
  const turns = safeIntegerValue(value.turns);
  const ignored = safeIntegerValue(value.ignored);
  const postedEvents = safeIntegerValue(value.postedEvents);
  const lastSequence = safeIntegerValue(value.lastSequence);
  if (
    startedAt === null || updatedAt === null || finishedAt === undefined || exitCode === undefined ||
    lines === null || turns === null || ignored === null || postedEvents === null || lastSequence === null
  ) {
    return null;
  }
  return {
    id: value.id,
    agentId: redactedText(value.agentId),
    agentKind: kind,
    agentLabel: redactedText(value.agentLabel),
    command: redactedText(value.command),
    cwd: typeof value.cwd === "string" ? redactedText(value.cwd) : null,
    task: typeof value.task === "string" ? redactedText(value.task) : null,
    status,
    startedAt,
    updatedAt,
    finishedAt,
    exitCode,
    interrupted: value.interrupted,
    lines,
    turns,
    ignored,
    postedEvents,
    lastSequence,
    detail: typeof value.detail === "string" ? redactedText(value.detail) : null,
  };
}

function cloneRecord(record: LocalAgentSessionRecord): LocalAgentSessionRecord {
  return { ...record };
}

function generatedSessionId(agentId: string, now: number, serial: number): string {
  const safeAgentId = agentId
    .toLowerCase()
    .replace(/[^a-z0-9._-]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 64) || "agent";
  return `${safeAgentId}-${now}-${serial}`;
}

function requireSessionId(value: string): void {
  if (!sessionIdPattern.test(value)) {
    throw new Error("session id must be 1-128 safe identifier characters");
  }
}

function optionalRedactedText(value: string | undefined): string | null {
  return value === undefined || value.length === 0 ? null : redactedText(value);
}

function redactedText(value: string): string {
  const redacted = redactLocalDevSessionText(value);
  if (redacted.length <= MAX_RETAINED_TEXT_LENGTH) return redacted;
  return `${redacted.slice(0, MAX_RETAINED_TEXT_LENGTH - TRUNCATION_MARKER.length)}${TRUNCATION_MARKER}`;
}

function positiveSafeInteger(value: number, label: string): number {
  if (!Number.isSafeInteger(value) || value <= 0) throw new RangeError(`${label} must be a positive safe integer`);
  return value;
}

function nonNegativeSafeInteger(value: number, label: string): number {
  if (!Number.isSafeInteger(value) || value < 0) throw new RangeError(`${label} must be a non-negative safe integer`);
  return value;
}

function nullableExitCode(value: number | null): number | null {
  if (value === null) return null;
  if (!Number.isSafeInteger(value)) throw new RangeError("exitCode must be a safe integer or null");
  return value;
}

function safeIntegerValue(value: unknown): number | null {
  return typeof value === "number" && Number.isSafeInteger(value) && value >= 0 ? value : null;
}

function nullableSafeIntegerValue(value: unknown): number | null | undefined {
  if (value === null) return null;
  return safeIntegerValue(value) ?? undefined;
}

function nullableExitCodeValue(value: unknown): number | null | undefined {
  if (value === null) return null;
  return typeof value === "number" && Number.isSafeInteger(value) ? value : undefined;
}

function nullableString(value: unknown): boolean {
  return value === null || typeof value === "string";
}

function sessionStatus(value: unknown): LocalAgentSessionStatus | null {
  return value === "starting" || value === "running" || value === "done" || value === "failed" || value === "interrupted"
    ? value
    : null;
}

function agentKind(value: unknown): LocalDevAgentKind | null {
  return typeof value === "string" && agentKinds.has(value as LocalDevAgentKind)
    ? value as LocalDevAgentKind
    : null;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isNodeError(value: unknown): value is NodeJS.ErrnoException {
  return value instanceof Error && "code" in value;
}
