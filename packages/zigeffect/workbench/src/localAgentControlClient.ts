import { redactLocalDevSessionText } from "./localDevSessionFeed";

export type LocalAgentControlPersistence = "durable" | "memory" | "unknown";
export type LocalAgentControlErrorCode =
  | "cancelled"
  | "invalid_response"
  | "not_found"
  | "policy"
  | "response_too_large"
  | "unauthorized"
  | "unavailable";

export type LocalAgentControlHealth = {
  ok: true;
  activeSessions: number;
  persistence: LocalAgentControlPersistence;
};

export type LocalAgentControlPrompt = {
  kind: "prompt";
  label: string;
  placeholder: string;
  required: boolean;
  maxLength: number;
};

export type LocalAgentControlToolSummary = {
  id: string;
  label: string;
  description: string;
  kind: "codex" | "claude-code" | "zigeffect" | "human" | "other";
  input: LocalAgentControlPrompt | null;
};

export type LocalAgentControlSession = {
  id: string;
  agentId: string;
  agentKind: LocalAgentControlToolSummary["kind"];
  agentLabel: string;
  command: string;
  cwd: string | null;
  task: string | null;
  status: "starting" | "running" | "done" | "failed" | "interrupted";
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

export type LocalAgentControlReceipt = {
  sequence: number;
  timestamp: number;
  action: "start" | "stop";
  outcome: "accepted" | "rejected";
  sessionId: string | null;
  toolId: string | null;
  detail: string;
};

export type LocalAgentControlDecision = {
  accepted: true;
  sessionId: string;
};

export type LocalAgentControlStart = {
  toolId: string;
  sessionId?: string;
  input?: unknown;
};

export type LocalAgentControlClient = {
  baseUrl: string;
  health: (signal?: AbortSignal) => Promise<LocalAgentControlHealth>;
  tools: (signal?: AbortSignal) => Promise<LocalAgentControlToolSummary[]>;
  sessions: (signal?: AbortSignal) => Promise<LocalAgentControlSession[]>;
  session: (sessionId: string, signal?: AbortSignal) => Promise<LocalAgentControlSession>;
  receipts: (signal?: AbortSignal) => Promise<LocalAgentControlReceipt[]>;
  start: (start: LocalAgentControlStart, signal?: AbortSignal) => Promise<LocalAgentControlDecision>;
  stop: (sessionId: string, signal?: AbortSignal) => Promise<LocalAgentControlDecision>;
};

export type LocalAgentControlBootstrap = {
  controlUrl: string | null;
  token: string | null;
};

export type LocalAgentControlClientOptions = {
  baseUrl: string;
  token: string;
  fetcher?: LocalAgentControlFetch;
  maxResponseBytes?: number;
};

export type LocalAgentControlFetch = (
  input: RequestInfo | URL,
  init?: RequestInit,
) => Promise<Response>;

type UnknownRecord = Record<string, unknown>;

const DEFAULT_MAX_RESPONSE_BYTES = 1024 * 1024;
const MAX_ERROR_DETAIL = 512;
const MAX_TOKEN_LENGTH = 4096;
const identifierPattern = /^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$/;
const agentKinds = new Set(["codex", "claude-code", "zigeffect", "human", "other"]);
const sessionStatuses = new Set(["starting", "running", "done", "failed", "interrupted"]);

export class LocalAgentControlClientError extends Error {
  readonly code: LocalAgentControlErrorCode;
  readonly status: number | null;

  constructor(code: LocalAgentControlErrorCode, message: string, status: number | null = null) {
    super(message);
    this.name = "LocalAgentControlClientError";
    this.code = code;
    this.status = status;
  }
}

export function normalizeLocalAgentControlUrl(value: string): string {
  let url: URL;
  try {
    url = new URL(value);
  } catch {
    throw new LocalAgentControlClientError("policy", "local control URL is invalid");
  }
  const hostname = url.hostname.toLowerCase();
  const loopback = hostname === "localhost" || hostname === "127.0.0.1" || hostname === "::1" || hostname === "[::1]";
  if (url.protocol !== "http:" || !loopback) {
    throw new LocalAgentControlClientError("policy", "local control URL must use loopback HTTP");
  }
  if (url.username || url.password || url.search || url.hash || (url.pathname !== "/" && url.pathname !== "")) {
    throw new LocalAgentControlClientError("policy", "local control URL must not contain credentials, paths, or parameters");
  }
  return url.origin;
}

export function localAgentControlBootstrapFromLocation(
  search: string,
  hash: string,
): LocalAgentControlBootstrap {
  const controlUrl = nonEmpty(new URLSearchParams(search).get("control"));
  const token = nonEmpty(new URLSearchParams(hash.startsWith("#") ? hash.slice(1) : hash).get("control-token"));
  return {
    controlUrl,
    token: token && token.length <= MAX_TOKEN_LENGTH ? token : null,
  };
}

export function scrubLocalAgentControlTokenFragment(location: {
  pathname: string;
  search: string;
  hash: string;
}): string {
  const params = new URLSearchParams(location.hash.startsWith("#") ? location.hash.slice(1) : location.hash);
  params.delete("control-token");
  const hash = params.toString();
  return `${location.pathname}${location.search}${hash ? `#${hash}` : ""}`;
}

export function createLocalAgentControlClient(
  options: LocalAgentControlClientOptions,
): LocalAgentControlClient {
  const baseUrl = normalizeLocalAgentControlUrl(options.baseUrl);
  if (options.token.length === 0 || options.token.length > MAX_TOKEN_LENGTH) {
    throw new LocalAgentControlClientError("policy", "local control token is invalid");
  }
  const fetcher = options.fetcher ?? fetch;
  const maxResponseBytes = positiveSafeInteger(options.maxResponseBytes ?? DEFAULT_MAX_RESPONSE_BYTES, "maxResponseBytes");

  async function request(path: string, init: RequestInit, authenticated: boolean): Promise<unknown> {
    const headers = new Headers(init.headers);
    if (authenticated) headers.set("authorization", `Bearer ${options.token}`);
    if (init.body !== undefined) headers.set("content-type", "application/json");
    let response: Response;
    try {
      response = await fetcher(`${baseUrl}${path}`, { ...init, headers });
    } catch (error) {
      if (init.signal?.aborted || isAbortError(error)) {
        throw new LocalAgentControlClientError("cancelled", "local control request cancelled");
      }
      throw new LocalAgentControlClientError("unavailable", "local control server unavailable");
    }
    let text: string;
    try {
      text = await boundedResponseText(response, maxResponseBytes);
    } catch (error) {
      if (error instanceof LocalAgentControlClientError) throw error;
      if (init.signal?.aborted || isAbortError(error)) {
        throw new LocalAgentControlClientError("cancelled", "local control request cancelled");
      }
      throw new LocalAgentControlClientError("unavailable", "local control response failed", response.status);
    }
    if (!response.ok) throw responseError(response.status, text);
    try {
      return JSON.parse(text) as unknown;
    } catch {
      throw new LocalAgentControlClientError("invalid_response", "local control returned invalid JSON", response.status);
    }
  }

  return {
    baseUrl,
    async health(signal) {
      return parseHealth(await request("/agent-control/health", { method: "GET", signal }, false));
    },
    async tools(signal) {
      return parseTools(await request("/agent-control/tools", { method: "GET", signal }, true));
    },
    async sessions(signal) {
      return parseSessions(await request("/agent-control/sessions", { method: "GET", signal }, true));
    },
    async session(sessionId, signal) {
      requireIdentifier(sessionId, "session id");
      const value = record(await request(`/agent-control/sessions/${encodeURIComponent(sessionId)}`, { method: "GET", signal }, true));
      return parseSession(value?.session);
    },
    async receipts(signal) {
      return parseReceipts(await request("/agent-control/receipts", { method: "GET", signal }, true));
    },
    async start(start, signal) {
      requireIdentifier(start.toolId, "tool id");
      if (start.sessionId !== undefined) requireIdentifier(start.sessionId, "session id");
      const body: Record<string, unknown> = { tool_id: start.toolId };
      if (start.sessionId !== undefined) body.session_id = start.sessionId;
      if (start.input !== undefined) body.input = start.input;
      return parseDecision(await request("/agent-control/sessions", {
        method: "POST",
        body: JSON.stringify(body),
        signal,
      }, true));
    },
    async stop(sessionId, signal) {
      requireIdentifier(sessionId, "session id");
      return parseDecision(await request(`/agent-control/sessions/${encodeURIComponent(sessionId)}/stop`, {
        method: "POST",
        body: "{}",
        signal,
      }, true));
    },
  };
}

async function boundedResponseText(response: Response, maxBytes: number): Promise<string> {
  const declared = response.headers.get("content-length");
  if (declared !== null && Number(declared) > maxBytes) {
    throw new LocalAgentControlClientError("response_too_large", "local control response is too large", response.status);
  }
  const text = await response.text();
  if (new TextEncoder().encode(text).byteLength > maxBytes) {
    throw new LocalAgentControlClientError("response_too_large", "local control response is too large", response.status);
  }
  return text;
}

function responseError(status: number, detail: string): LocalAgentControlClientError {
  if (status === 401) return new LocalAgentControlClientError("unauthorized", "local control authorization required", status);
  if (status === 404) return new LocalAgentControlClientError("not_found", "local control session not found", status);
  const safe = boundedDetail(detail) || `local control request rejected (${status})`;
  return new LocalAgentControlClientError("policy", safe, status);
}

function parseHealth(value: unknown): LocalAgentControlHealth {
  const item = record(value);
  if (!item || item.ok !== true) invalidResponse();
  const persistence = item.persistence === "durable" || item.persistence === "memory" ? item.persistence : "unknown";
  return { ok: true, activeSessions: nonNegativeInteger(item.active_sessions), persistence };
}

function parseTools(value: unknown): LocalAgentControlToolSummary[] {
  const items = record(value)?.tools;
  if (!Array.isArray(items)) invalidResponse();
  return items.map(parseTool);
}

function parseTool(value: unknown): LocalAgentControlToolSummary {
  const item = record(value);
  if (!item || !identifier(item.id) || !string(item.label) || !string(item.description) || !agentKinds.has(String(item.kind))) {
    invalidResponse();
  }
  return {
    id: item.id,
    label: item.label,
    description: item.description,
    kind: item.kind as LocalAgentControlToolSummary["kind"],
    input: parsePrompt(item.input),
  };
}

function parsePrompt(value: unknown): LocalAgentControlPrompt | null {
  if (value === null || value === undefined) return null;
  const item = record(value);
  if (!item || item.kind !== "prompt" || !string(item.label) || !string(item.placeholder) || typeof item.required !== "boolean") {
    invalidResponse();
  }
  return {
    kind: "prompt",
    label: item.label,
    placeholder: item.placeholder,
    required: item.required,
    maxLength: positiveInteger(item.max_length),
  };
}

function parseSessions(value: unknown): LocalAgentControlSession[] {
  const items = record(value)?.sessions;
  if (!Array.isArray(items)) invalidResponse();
  return items.map(parseSession);
}

function parseSession(value: unknown): LocalAgentControlSession {
  const item = record(value);
  if (
    !item || !identifier(item.id) || !string(item.agentId) || !agentKinds.has(String(item.agentKind)) ||
    !string(item.agentLabel) || !string(item.command) || !nullableString(item.cwd) || !nullableString(item.task) ||
    !sessionStatuses.has(String(item.status)) || !nullableInteger(item.finishedAt) || !nullableInteger(item.exitCode) ||
    typeof item.interrupted !== "boolean" || !nullableString(item.detail)
  ) invalidResponse();
  return {
    id: item.id,
    agentId: item.agentId,
    agentKind: item.agentKind as LocalAgentControlSession["agentKind"],
    agentLabel: item.agentLabel,
    command: item.command,
    cwd: item.cwd,
    task: item.task,
    status: item.status as LocalAgentControlSession["status"],
    startedAt: nonNegativeInteger(item.startedAt),
    updatedAt: nonNegativeInteger(item.updatedAt),
    finishedAt: item.finishedAt,
    exitCode: item.exitCode,
    interrupted: item.interrupted,
    lines: nonNegativeInteger(item.lines),
    turns: nonNegativeInteger(item.turns),
    ignored: nonNegativeInteger(item.ignored),
    postedEvents: nonNegativeInteger(item.postedEvents),
    lastSequence: nonNegativeInteger(item.lastSequence),
    detail: item.detail,
  };
}

function parseReceipts(value: unknown): LocalAgentControlReceipt[] {
  const items = record(value)?.receipts;
  if (!Array.isArray(items)) invalidResponse();
  return items.map((value) => {
    const item = record(value);
    if (
      !item || (item.action !== "start" && item.action !== "stop") ||
      (item.outcome !== "accepted" && item.outcome !== "rejected") ||
      !nullableIdentifier(item.sessionId) || !nullableIdentifier(item.toolId) || !string(item.detail)
    ) invalidResponse();
    return {
      sequence: positiveInteger(item.sequence),
      timestamp: nonNegativeInteger(item.timestamp),
      action: item.action,
      outcome: item.outcome,
      sessionId: item.sessionId,
      toolId: item.toolId,
      detail: item.detail,
    };
  });
}

function parseDecision(value: unknown): LocalAgentControlDecision {
  const item = record(value);
  if (!item || item.accepted !== true || !identifier(item.session_id)) invalidResponse();
  return { accepted: true, sessionId: item.session_id };
}

function record(value: unknown): UnknownRecord | null {
  return typeof value === "object" && value !== null && !Array.isArray(value) ? value as UnknownRecord : null;
}

function identifier(value: unknown): value is string {
  return typeof value === "string" && identifierPattern.test(value);
}

function nullableIdentifier(value: unknown): value is string | null {
  return value === null || identifier(value);
}

function string(value: unknown): value is string {
  return typeof value === "string";
}

function nullableString(value: unknown): value is string | null {
  return value === null || typeof value === "string";
}

function nullableInteger(value: unknown): value is number | null {
  return value === null || Number.isSafeInteger(value);
}

function nonNegativeInteger(value: unknown): number {
  if (!Number.isSafeInteger(value) || (value as number) < 0) invalidResponse();
  return value as number;
}

function positiveInteger(value: unknown): number {
  if (!Number.isSafeInteger(value) || (value as number) <= 0) invalidResponse();
  return value as number;
}

function positiveSafeInteger(value: number, label: string): number {
  if (!Number.isSafeInteger(value) || value <= 0) {
    throw new LocalAgentControlClientError("policy", `${label} must be a positive safe integer`);
  }
  return value;
}

function requireIdentifier(value: string, label: string): void {
  if (!identifierPattern.test(value)) throw new LocalAgentControlClientError("policy", `${label} is invalid`);
}

function invalidResponse(): never {
  throw new LocalAgentControlClientError("invalid_response", "local control returned an invalid response");
}

function boundedDetail(value: string): string {
  const redacted = redactLocalDevSessionText(value).trim();
  return redacted.length <= MAX_ERROR_DETAIL ? redacted : `${redacted.slice(0, MAX_ERROR_DETAIL - 15)}... [truncated]`;
}

function nonEmpty(value: string | null): string | null {
  return value && value.length > 0 ? value : null;
}

function isAbortError(value: unknown): boolean {
  return value instanceof DOMException && value.name === "AbortError";
}
