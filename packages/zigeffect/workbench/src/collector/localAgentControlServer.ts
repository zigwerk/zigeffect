import { createHash, randomUUID, timingSafeEqual } from "node:crypto";
import { Buffer } from "node:buffer";
import type { LocalDevAgentKind } from "../causalArtifact";
import { redactLocalDevSessionText } from "../localDevSessionFeed";
import {
  runLocalAgentProcessSupervisor,
  type LocalAgentProcessRunner,
  type LocalAgentProcessTool,
} from "./localAgentProcessSupervisor";
import {
  saveLocalAgentSessionRegistry,
  type LocalAgentSessionRegistry,
  type LocalAgentSessionStore,
} from "./localAgentSessionRegistry";
import {
  startLocalAgentPtySupervisor,
  type LocalAgentPtyRunner,
  type LocalAgentPtySupervisor,
} from "./localAgentPtySupervisor";

export type LocalAgentControlTool = {
  id: string;
  label: string;
  description?: string;
  kind: LocalDevAgentKind;
  mode?: "batch" | "pty";
  input?: LocalAgentControlPromptInput;
  build: (input: unknown) => LocalAgentProcessTool | Promise<LocalAgentProcessTool>;
};

export type LocalAgentControlPromptInput = {
  kind: "prompt";
  label: string;
  placeholder?: string;
  required?: boolean;
  maxLength?: number;
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

export type LocalAgentControlServerOptions = {
  token: string;
  tools: readonly LocalAgentControlTool[];
  registry: LocalAgentSessionRegistry;
  sessionStore?: LocalAgentSessionStore;
  runner?: LocalAgentProcessRunner;
  agentEventsUrl: string;
  fetcher?: typeof fetch;
  maxBodyBytes?: number;
  maxReceipts?: number;
  now?: () => number;
  receiptSink?: (receipt: LocalAgentControlReceipt) => void | Promise<void>;
  ptyRunner?: LocalAgentPtyRunner;
  ptySecretLiterals?: readonly string[];
  maxPtySessions?: number;
};

export type LocalAgentControlServer = {
  fetch: (request: Request) => Promise<Response>;
  activeSessionIds: () => string[];
  receipts: () => LocalAgentControlReceipt[];
  waitForIdle: () => Promise<void>;
};

type ActiveSession = {
  controller: AbortController;
  completion: Promise<void>;
  toolId: string;
  pty: LocalAgentPtySupervisor | null;
};

type StartRequest = {
  toolId: string;
  sessionId: string;
  input: unknown;
};

const DEFAULT_MAX_BODY_BYTES = 64 * 1024;
const DEFAULT_MAX_RECEIPTS = 512;
const MAX_RECEIPT_DETAIL = 1024;
const DEFAULT_MAX_PROMPT_LENGTH = 16 * 1024;
const MAX_PROMPT_LENGTH = 64 * 1024;
const DEFAULT_MAX_PTY_SESSIONS = 32;
const MAX_TERMINAL_INPUT_BYTES = 16 * 1024;
const MIN_TERMINAL_COLS = 20;
const MAX_TERMINAL_COLS = 500;
const MIN_TERMINAL_ROWS = 5;
const MAX_TERMINAL_ROWS = 200;
const TRUNCATION_MARKER = "... [truncated]";
const identifierPattern = /^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$/;
const CORS_HEADERS = {
  "access-control-allow-origin": "*",
  "access-control-allow-methods": "GET, POST, OPTIONS",
  "access-control-allow-headers": "authorization, content-type",
} as const;

export function createLocalAgentControlServer(
  options: LocalAgentControlServerOptions,
): LocalAgentControlServer {
  if (options.token.length === 0) {
    throw new Error("control token must not be empty");
  }
  const maxBodyBytes = positiveSafeInteger(options.maxBodyBytes ?? DEFAULT_MAX_BODY_BYTES, "maxBodyBytes");
  const maxReceipts = positiveSafeInteger(options.maxReceipts ?? DEFAULT_MAX_RECEIPTS, "maxReceipts");
  const maxPtySessions = positiveSafeInteger(options.maxPtySessions ?? DEFAULT_MAX_PTY_SESSIONS, "maxPtySessions");
  const now = options.now ?? Date.now;
  const tools = new Map<string, LocalAgentControlTool>();
  for (const tool of options.tools) {
    requireIdentifier(tool.id, "control tool id");
    if (tools.has(tool.id)) throw new Error(`duplicate control tool id: ${tool.id}`);
    validateToolInput(tool.input);
    if (tool.mode !== undefined && tool.mode !== "batch" && tool.mode !== "pty") {
      throw new Error(`unsupported control tool mode: ${String(tool.mode)}`);
    }
    tools.set(tool.id, tool);
  }

  const expectedToken = digest(options.token);
  const active = new Map<string, ActiveSession>();
  const terminalSessions = new Map<string, LocalAgentPtySupervisor>();
  const audit: LocalAgentControlReceipt[] = [];
  let receiptSequence = 0;

  async function fetchHandler(request: Request): Promise<Response> {
    const url = new URL(request.url);
    const path = normalizedPath(url.pathname);
    if (request.method === "OPTIONS") return response(null, 204);
    if (path === "/agent-control/health" && request.method === "GET") {
      return json({
        ok: true,
        active_sessions: active.size,
        persistence: options.sessionStore ? "durable" : "memory",
      });
    }
    if (!authorized(request)) return response("unauthorized", 401);

    if (path === "/agent-control/tools" && request.method === "GET") {
      return json({
        tools: [...tools.values()].map((tool) => ({
          id: tool.id,
          label: boundedRedacted(tool.label),
          description: boundedRedacted(tool.description ?? ""),
          kind: tool.kind,
          mode: tool.mode ?? "batch",
          input: safeToolInput(tool.input),
        })),
      });
    }
    if (path === "/agent-control/sessions" && request.method === "GET") {
      return json({ sessions: options.registry.list().map(sessionView) });
    }
    if (path === "/agent-control/sessions" && request.method === "POST") {
      return startSession(request);
    }
    if (path === "/agent-control/receipts" && request.method === "GET") {
      return json({ receipts: receipts() });
    }

    const terminalMatch = /^\/agent-control\/sessions\/([^/]+)\/terminal$/.exec(path);
    if (terminalMatch && request.method === "GET") {
      return readTerminal(safeDecode(terminalMatch[1]!), url.searchParams.get("after"));
    }
    const inputMatch = /^\/agent-control\/sessions\/([^/]+)\/input$/.exec(path);
    if (inputMatch && request.method === "POST") {
      return writeTerminal(safeDecode(inputMatch[1]!), request);
    }
    const resizeMatch = /^\/agent-control\/sessions\/([^/]+)\/resize$/.exec(path);
    if (resizeMatch && request.method === "POST") {
      return resizeTerminal(safeDecode(resizeMatch[1]!), request);
    }

    const stopMatch = /^\/agent-control\/sessions\/([^/]+)\/stop$/.exec(path);
    if (stopMatch && request.method === "POST") {
      return stopSession(safeDecode(stopMatch[1]!));
    }
    const detailMatch = /^\/agent-control\/sessions\/([^/]+)$/.exec(path);
    if (detailMatch && request.method === "GET") {
      const sessionId = safeDecode(detailMatch[1]!);
      if (!sessionId) return response("invalid session id", 400);
      const session = options.registry.get(sessionId);
      return session ? json({ session: sessionView(session) }) : response("session not found", 404);
    }
    return response("not found", 404);
  }

  async function startSession(request: Request): Promise<Response> {
    const body = await boundedJsonBody(request, maxBodyBytes);
    if (body.status !== 200) {
      await recordReceipt("start", "rejected", null, null, body.detail);
      return response(body.detail, body.status);
    }
    const parsed = parseStartRequest(body.value);
    if (!parsed) {
      await recordReceipt("start", "rejected", null, null, "invalid start request");
      return response("invalid start request", 400);
    }
    const tool = tools.get(parsed.toolId);
    if (!tool) {
      await recordReceipt("start", "rejected", parsed.sessionId, parsed.toolId, `tool not allowlisted: ${parsed.toolId}`);
      return response("tool not allowlisted", 403);
    }
    if (active.has(parsed.sessionId) || options.registry.get(parsed.sessionId)) {
      await recordReceipt("start", "rejected", parsed.sessionId, parsed.toolId, "session id already exists");
      return response("session id already exists", 409);
    }
    const inputFailure = validateToolRequestInput(tool.input, parsed.input);
    if (inputFailure) {
      await recordReceipt("start", "rejected", parsed.sessionId, parsed.toolId, inputFailure);
      return response("tool input rejected", 400);
    }

    let processTool: LocalAgentProcessTool;
    try {
      processTool = await tool.build(parsed.input);
      validateProcessTool(processTool, tool);
    } catch (error) {
      await recordReceipt(
        "start",
        "rejected",
        parsed.sessionId,
        parsed.toolId,
        `tool input rejected: ${errorDetail(error)}`,
      );
      return response("tool input rejected", 400);
    }

    if (tool.mode === "pty") {
      return startPtySession(parsed, tool, processTool);
    }

    const controller = new AbortController();
    const run = runLocalAgentProcessSupervisor(processTool, {
      agentEventsUrl: options.agentEventsUrl,
      fetcher: options.fetcher,
      registry: options.registry,
      runner: options.runner,
      sessionId: parsed.sessionId,
      sessionStore: options.sessionStore,
      signal: controller.signal,
    });
    const completion = run
      .then(() => undefined)
      .catch(async (error) => {
        await markBackgroundFailure(parsed.sessionId, error);
      })
      .finally(() => {
        active.delete(parsed.sessionId);
      });
    active.set(parsed.sessionId, { controller, completion, toolId: parsed.toolId, pty: null });
    await Promise.resolve();
    if (!options.registry.get(parsed.sessionId)) {
      controller.abort();
      await completion;
      await recordReceipt("start", "rejected", parsed.sessionId, parsed.toolId, "session registry rejected ownership");
      return response("session registry rejected ownership", 409);
    }
    await recordReceipt("start", "accepted", parsed.sessionId, parsed.toolId, `started allowlisted tool ${parsed.toolId}`);
    return json({ accepted: true, session_id: parsed.sessionId }, 202);
  }

  async function startPtySession(
    parsed: StartRequest,
    tool: LocalAgentControlTool,
    processTool: LocalAgentProcessTool,
  ): Promise<Response> {
    evictTerminalPtySessions(maxPtySessions - 1);
    if (terminalSessions.size >= maxPtySessions) {
      await recordReceipt("start", "rejected", parsed.sessionId, parsed.toolId, "PTY retention is full with active sessions");
      return response("PTY retention is full with active sessions", 409);
    }
    const controller = new AbortController();
    let pty: LocalAgentPtySupervisor;
    try {
      pty = await startLocalAgentPtySupervisor(processTool, {
        sessionId: parsed.sessionId,
        registry: options.registry,
        sessionStore: options.sessionStore,
        agentEventsUrl: options.agentEventsUrl,
        fetcher: options.fetcher,
        runner: options.ptyRunner,
        signal: controller.signal,
        secretLiterals: options.ptySecretLiterals,
        now,
      });
    } catch (error) {
      await recordReceipt("start", "rejected", parsed.sessionId, parsed.toolId, `PTY failed to start: ${errorDetail(error)}`);
      return response("PTY failed to start", 500);
    }
    terminalSessions.set(parsed.sessionId, pty);
    const completion = pty.completion
      .then(() => undefined)
      .catch(async (error) => {
        await markBackgroundFailure(parsed.sessionId, error);
      })
      .finally(() => {
        active.delete(parsed.sessionId);
        evictTerminalPtySessions(maxPtySessions);
      });
    active.set(parsed.sessionId, { controller, completion, toolId: tool.id, pty });
    await recordReceipt("start", "accepted", parsed.sessionId, parsed.toolId, `started allowlisted PTY tool ${parsed.toolId}`);
    return json({ accepted: true, session_id: parsed.sessionId }, 202);
  }

  function readTerminal(sessionId: string | null, rawAfter: string | null): Response {
    if (!sessionId || !identifierPattern.test(sessionId)) return response("invalid session id", 400);
    const after = Number(rawAfter ?? "0");
    if (!Number.isSafeInteger(after) || after < 0) return response("invalid terminal cursor", 400);
    const pty = terminalSessions.get(sessionId);
    if (!pty) return terminalUnavailable(sessionId);
    const output = pty.read(after);
    return json({
      frames: output.frames,
      next_after: output.nextAfter,
      gap: output.gap,
      dropped_frames: output.droppedFrames,
      dropped_bytes: output.droppedBytes,
      status: output.status,
      cols: output.cols,
      rows: output.rows,
      total_bytes: output.totalBytes,
    });
  }

  async function writeTerminal(sessionId: string | null, request: Request): Promise<Response> {
    const body = await boundedJsonBody(request, maxBodyBytes);
    if (body.status !== 200 || !isRecord(body.value) || typeof body.value.data !== "string" || Object.keys(body.value).some((key) => key !== "data")) {
      return response(body.status === 413 ? body.detail : "invalid terminal input", body.status === 413 ? 413 : 400);
    }
    if (Buffer.byteLength(body.value.data, "utf8") > MAX_TERMINAL_INPUT_BYTES) return response("terminal input too large", 413);
    if (!sessionId || !identifierPattern.test(sessionId)) return response("invalid session id", 400);
    const pty = terminalSessions.get(sessionId);
    if (!pty) return terminalUnavailable(sessionId);
    if (pty.status() !== "running") return response("terminal is not active", 409);
    return pty.write(body.value.data)
      ? json({ accepted: true, session_id: sessionId }, 202)
      : response("terminal input rejected", 409);
  }

  async function resizeTerminal(sessionId: string | null, request: Request): Promise<Response> {
    const body = await boundedJsonBody(request, maxBodyBytes);
    if (
      body.status !== 200 || !isRecord(body.value) ||
      !validDimension(body.value.cols, MIN_TERMINAL_COLS, MAX_TERMINAL_COLS) ||
      !validDimension(body.value.rows, MIN_TERMINAL_ROWS, MAX_TERMINAL_ROWS) ||
      Object.keys(body.value).some((key) => key !== "cols" && key !== "rows")
    ) {
      return response(body.status === 413 ? body.detail : "invalid terminal dimensions", body.status === 413 ? 413 : 400);
    }
    if (!sessionId || !identifierPattern.test(sessionId)) return response("invalid session id", 400);
    const pty = terminalSessions.get(sessionId);
    if (!pty) return terminalUnavailable(sessionId);
    if (pty.status() !== "running") return response("terminal is not active", 409);
    return pty.resize(body.value.cols, body.value.rows)
      ? json({ accepted: true, session_id: sessionId, cols: body.value.cols, rows: body.value.rows }, 202)
      : response("terminal resize rejected", 409);
  }

  function terminalUnavailable(sessionId: string): Response {
    return options.registry.get(sessionId)
      ? response("session has no retained terminal", 409)
      : response("session not found", 404);
  }

  function evictTerminalPtySessions(maxRetained: number): void {
    if (terminalSessions.size <= maxRetained) return;
    for (const [sessionId, pty] of terminalSessions) {
      if (terminalSessions.size <= maxRetained) break;
      if (pty.status() !== "running") terminalSessions.delete(sessionId);
    }
  }

  function sessionView<T extends { id: string }>(session: T): T & { terminal_available: boolean } {
    return { ...session, terminal_available: terminalSessions.has(session.id) };
  }

  async function stopSession(sessionId: string | null): Promise<Response> {
    if (!sessionId || !identifierPattern.test(sessionId)) {
      await recordReceipt("stop", "rejected", sessionId, null, "invalid session id");
      return response("invalid session id", 400);
    }
    const owned = active.get(sessionId);
    if (!owned) {
      const existing = options.registry.get(sessionId);
      await recordReceipt("stop", "rejected", sessionId, null, existing ? "session is not active" : "session not found");
      return response(existing ? "session is not active" : "session not found", existing ? 409 : 404);
    }
    owned.controller.abort();
    await recordReceipt("stop", "accepted", sessionId, owned.toolId, "abort requested for active session");
    return json({ accepted: true, session_id: sessionId }, 202);
  }

  async function markBackgroundFailure(sessionId: string, error: unknown): Promise<void> {
    const session = options.registry.get(sessionId);
    if (!session || session.status === "done" || session.status === "failed" || session.status === "interrupted") {
      return;
    }
    options.registry.finish(sessionId, {
      status: "failed",
      exitCode: null,
      interrupted: false,
      lines: session.lines,
      turns: session.turns,
      ignored: session.ignored,
      postedEvents: session.postedEvents,
      lastSequence: session.lastSequence,
      detail: `control supervisor failed: ${errorDetail(error)}`,
    });
    if (options.sessionStore) {
      try {
        await saveLocalAgentSessionRegistry(options.registry, options.sessionStore);
      } catch {
        // The in-memory registry remains honest even if local persistence failed.
      }
    }
  }

  async function recordReceipt(
    action: LocalAgentControlReceipt["action"],
    outcome: LocalAgentControlReceipt["outcome"],
    sessionId: string | null,
    toolId: string | null,
    detail: string,
  ): Promise<void> {
    const receipt: LocalAgentControlReceipt = {
      sequence: ++receiptSequence,
      timestamp: nonNegativeSafeInteger(now(), "receipt timestamp"),
      action,
      outcome,
      sessionId: optionalRedacted(sessionId),
      toolId: optionalRedacted(toolId),
      detail: boundedRedacted(detail),
    };
    audit.push(receipt);
    if (audit.length > maxReceipts) audit.splice(0, audit.length - maxReceipts);
    if (options.receiptSink) {
      try {
        void Promise.resolve(options.receiptSink({ ...receipt })).catch(() => {
          // A mirror is evidence delivery, not execution authority.
        });
      } catch {
        // Synchronous sink failures are isolated for the same reason.
      }
    }
  }

  function authorized(request: Request): boolean {
    const header = request.headers.get("authorization");
    if (!header?.startsWith("Bearer ")) return false;
    return timingSafeEqual(digest(header.slice("Bearer ".length)), expectedToken);
  }

  function activeSessionIds(): string[] {
    return [...active.keys()].sort();
  }

  function receipts(): LocalAgentControlReceipt[] {
    return audit.map((receipt) => ({ ...receipt }));
  }

  async function waitForIdle(): Promise<void> {
    while (active.size > 0) {
      await Promise.allSettled([...active.values()].map((session) => session.completion));
    }
  }

  return { fetch: fetchHandler, activeSessionIds, receipts, waitForIdle };
}

function parseStartRequest(value: unknown): StartRequest | null {
  if (!isRecord(value) || typeof value.tool_id !== "string" || !identifierPattern.test(value.tool_id)) {
    return null;
  }
  const sessionId = value.session_id === undefined ? `session-${randomUUID()}` : value.session_id;
  if (typeof sessionId !== "string" || !identifierPattern.test(sessionId)) return null;
  return { toolId: value.tool_id, sessionId, input: value.input };
}

function validateProcessTool(processTool: LocalAgentProcessTool, catalogTool: LocalAgentControlTool): void {
  if (processTool.kind !== catalogTool.kind) throw new Error("built tool kind does not match catalog kind");
  if (processTool.command.length === 0 || processTool.command.some((part) => typeof part !== "string")) {
    throw new Error("built tool command must contain string arguments");
  }
  if (processTool.id.length === 0 || processTool.label.length === 0) {
    throw new Error("built tool identity must not be empty");
  }
}

function validateToolInput(input: LocalAgentControlPromptInput | undefined): void {
  if (!input) return;
  if (input.kind !== "prompt") throw new Error("unsupported tool input kind");
  if (input.label.trim().length === 0) throw new Error("tool input label must not be empty");
  const maxLength = input.maxLength ?? DEFAULT_MAX_PROMPT_LENGTH;
  positiveSafeInteger(maxLength, "tool input maxLength");
  if (maxLength > MAX_PROMPT_LENGTH) {
    throw new RangeError(`tool input maxLength must not exceed ${MAX_PROMPT_LENGTH}`);
  }
}

function safeToolInput(input: LocalAgentControlPromptInput | undefined): unknown {
  if (!input) return null;
  return {
    kind: "prompt",
    label: boundedRedacted(input.label),
    placeholder: boundedRedacted(input.placeholder ?? ""),
    required: input.required === true,
    max_length: input.maxLength ?? DEFAULT_MAX_PROMPT_LENGTH,
  };
}

function validateToolRequestInput(
  descriptor: LocalAgentControlPromptInput | undefined,
  value: unknown,
): string | null {
  if (!descriptor) return null;
  if (!isRecord(value) || Object.keys(value).some((key) => key !== "prompt")) {
    return "prompt input must contain only prompt";
  }
  const prompt = value.prompt;
  if (typeof prompt !== "string") return "prompt input must be a string";
  if (descriptor.required === true && prompt.trim().length === 0) return "prompt input is required";
  if (prompt.length > (descriptor.maxLength ?? DEFAULT_MAX_PROMPT_LENGTH)) return "prompt input is too long";
  return null;
}

async function boundedJsonBody(
  request: Request,
  maxBytes: number,
): Promise<{ status: 200; value: unknown; detail: "ok" } | { status: 400 | 413; detail: string }> {
  const declared = request.headers.get("content-length");
  if (declared !== null) {
    const bytes = Number(declared);
    if (Number.isFinite(bytes) && bytes > maxBytes) return { status: 413, detail: "request body too large" };
  }
  const text = await request.text();
  if (Buffer.byteLength(text, "utf8") > maxBytes) return { status: 413, detail: "request body too large" };
  try {
    return { status: 200, value: JSON.parse(text) as unknown, detail: "ok" };
  } catch {
    return { status: 400, detail: "invalid JSON body" };
  }
}

function json(value: unknown, status = 200): Response {
  return new Response(JSON.stringify(value), {
    status,
    headers: { ...CORS_HEADERS, "content-type": "application/json" },
  });
}

function response(value: string | null, status: number): Response {
  return new Response(value, { status, headers: CORS_HEADERS });
}

function digest(value: string): Buffer {
  return createHash("sha256").update(value).digest();
}

function normalizedPath(path: string): string {
  return path.length > 1 ? path.replace(/\/+$/, "") : path;
}

function safeDecode(value: string): string | null {
  try {
    return decodeURIComponent(value);
  } catch {
    return null;
  }
}

function optionalRedacted(value: string | null): string | null {
  return value === null ? null : boundedRedacted(value);
}

function boundedRedacted(value: string): string {
  const redacted = redactLocalDevSessionText(value);
  if (redacted.length <= MAX_RECEIPT_DETAIL) return redacted;
  return `${redacted.slice(0, MAX_RECEIPT_DETAIL - TRUNCATION_MARKER.length)}${TRUNCATION_MARKER}`;
}

function errorDetail(error: unknown): string {
  if (error instanceof Error) return error.message;
  if (typeof error === "string") return error;
  return "unknown control error";
}

function requireIdentifier(value: string, label: string): void {
  if (!identifierPattern.test(value)) throw new Error(`${label} must be a safe identifier`);
}

function positiveSafeInteger(value: number, label: string): number {
  if (!Number.isSafeInteger(value) || value <= 0) throw new RangeError(`${label} must be a positive safe integer`);
  return value;
}

function nonNegativeSafeInteger(value: number, label: string): number {
  if (!Number.isSafeInteger(value) || value < 0) throw new RangeError(`${label} must be a non-negative safe integer`);
  return value;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function validDimension(value: unknown, minimum: number, maximum: number): value is number {
  return Number.isSafeInteger(value) && (value as number) >= minimum && (value as number) <= maximum;
}
