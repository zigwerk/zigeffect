import { Buffer } from "node:buffer";
import type { LocalDevSessionEvent } from "../localDevSessionFeed";
import { redactLocalDevSessionText } from "../localDevSessionFeed";
import { localAgentChildEnvironment, postLocalAgentEvent } from "./localAgentRuntime";
import type { LocalAgentProcessTool } from "./localAgentProcessSupervisor";
import {
  saveLocalAgentSessionRegistry,
  type LocalAgentSessionRegistry,
  type LocalAgentSessionStore,
} from "./localAgentSessionRegistry";

export type LocalAgentPtyRunnerOptions = {
  cols: number;
  rows: number;
  onData: (data: Uint8Array) => void;
  onTerminalExit: (exitCode: number, signal: string | null) => void;
};

export type LocalAgentPtyHandle = {
  exited: Promise<number>;
  write: (data: string) => number;
  resize: (cols: number, rows: number) => void;
  kill: () => void;
  close: () => void;
};

export type LocalAgentPtyRunner = {
  start: (
    tool: LocalAgentProcessTool,
    options: LocalAgentPtyRunnerOptions,
  ) => Promise<LocalAgentPtyHandle>;
};

export type LocalAgentPtyTerminationReason =
  | "exit"
  | "abort"
  | "idle_timeout"
  | "runtime_timeout"
  | "output_limit"
  | "stream_error";

export type LocalAgentPtyFrame = {
  sequence: number;
  timestamp: number;
  data: string;
};

export type LocalAgentPtyRead = {
  frames: LocalAgentPtyFrame[];
  nextAfter: number;
  gap: boolean;
  droppedFrames: number;
  droppedBytes: number;
  status: "running" | "done" | "failed" | "interrupted";
  cols: number;
  rows: number;
  totalBytes: number;
};

export type LocalAgentPtySummary = {
  sessionId: string;
  status: "done" | "failed" | "interrupted";
  exitCode: number | null;
  interrupted: boolean;
  reason: LocalAgentPtyTerminationReason;
  cols: number;
  rows: number;
  totalBytes: number;
  frames: number;
  droppedFrames: number;
  droppedBytes: number;
  postedEvents: number;
  lastSequence: number;
};

export type LocalAgentPtySupervisor = {
  sessionId: string;
  completion: Promise<LocalAgentPtySummary>;
  write: (data: string) => boolean;
  resize: (cols: number, rows: number) => boolean;
  stop: () => boolean;
  read: (after: number) => LocalAgentPtyRead;
  status: () => LocalAgentPtyRead["status"];
};

export type LocalAgentPtySchedule = (
  run: () => void,
  delayMs: number,
) => () => void;

export type LocalAgentPtySupervisorOptions = {
  sessionId: string;
  registry: LocalAgentSessionRegistry;
  sessionStore?: LocalAgentSessionStore;
  agentEventsUrl: string;
  fetcher?: typeof fetch;
  runner?: LocalAgentPtyRunner;
  signal?: AbortSignal;
  cols?: number;
  rows?: number;
  maxInputBytes?: number;
  maxChunkBytes?: number;
  maxFrames?: number;
  maxRetainedBytes?: number;
  maxTotalOutputBytes?: number;
  idleTimeoutMs?: number;
  maxRuntimeMs?: number;
  secretLiterals?: readonly string[];
  now?: () => number;
  schedule?: LocalAgentPtySchedule;
};

const DEFAULT_COLS = 100;
const DEFAULT_ROWS = 30;
const MIN_COLS = 20;
const MAX_COLS = 500;
const MIN_ROWS = 5;
const MAX_ROWS = 200;
const DEFAULT_MAX_INPUT_BYTES = 16 * 1024;
const DEFAULT_MAX_CHUNK_BYTES = 64 * 1024;
const DEFAULT_MAX_FRAMES = 2048;
const DEFAULT_MAX_RETAINED_BYTES = 2 * 1024 * 1024;
const DEFAULT_MAX_TOTAL_OUTPUT_BYTES = 64 * 1024 * 1024;
const DEFAULT_IDLE_TIMEOUT_MS = 30 * 60 * 1000;
const DEFAULT_MAX_RUNTIME_MS = 4 * 60 * 60 * 1000;

export const bunLocalAgentPtyRunner: LocalAgentPtyRunner = {
  async start(tool, options) {
    const [command, ...args] = tool.command;
    if (!command) throw new Error(`PTY tool ${tool.id} has no command`);
    const child = Bun.spawn([command, ...args], {
      cwd: tool.cwd,
      env: localAgentChildEnvironment(),
      terminal: {
        cols: options.cols,
        rows: options.rows,
        name: "xterm-256color",
        data(_terminal, data) {
          options.onData(data);
        },
        exit(_terminal, exitCode, signal) {
          options.onTerminalExit(exitCode, signal);
        },
      },
    });
    const terminal = child.terminal;
    if (!terminal) {
      child.kill();
      throw new Error("Bun did not attach a terminal");
    }
    return {
      exited: child.exited,
      write(data) { return terminal.write(data); },
      resize(cols, rows) { terminal.resize(cols, rows); },
      kill() { child.kill(); },
      close() {
        if (!terminal.closed) terminal.close();
      },
    };
  },
};

export async function startLocalAgentPtySupervisor(
  tool: LocalAgentProcessTool,
  options: LocalAgentPtySupervisorOptions,
): Promise<LocalAgentPtySupervisor> {
  const colsInitial = dimension(options.cols ?? DEFAULT_COLS, MIN_COLS, MAX_COLS, "PTY columns");
  const rowsInitial = dimension(options.rows ?? DEFAULT_ROWS, MIN_ROWS, MAX_ROWS, "PTY rows");
  const maxInputBytes = positiveSafeInteger(options.maxInputBytes ?? DEFAULT_MAX_INPUT_BYTES, "maxInputBytes");
  const maxChunkBytes = positiveSafeInteger(options.maxChunkBytes ?? DEFAULT_MAX_CHUNK_BYTES, "maxChunkBytes");
  const maxFrames = positiveSafeInteger(options.maxFrames ?? DEFAULT_MAX_FRAMES, "maxFrames");
  const maxRetainedBytes = positiveSafeInteger(options.maxRetainedBytes ?? DEFAULT_MAX_RETAINED_BYTES, "maxRetainedBytes");
  const maxTotalOutputBytes = positiveSafeInteger(options.maxTotalOutputBytes ?? DEFAULT_MAX_TOTAL_OUTPUT_BYTES, "maxTotalOutputBytes");
  const idleTimeoutMs = positiveSafeInteger(options.idleTimeoutMs ?? DEFAULT_IDLE_TIMEOUT_MS, "idleTimeoutMs");
  const maxRuntimeMs = positiveSafeInteger(options.maxRuntimeMs ?? DEFAULT_MAX_RUNTIME_MS, "maxRuntimeMs");
  const now = options.now ?? Date.now;
  const schedule = options.schedule ?? timerSchedule;
  const secretLiterals = [...new Set((options.secretLiterals ?? []).filter((value) => value.length > 0))]
    .sort((left, right) => right.length - left.length);
  const runner = options.runner ?? bunLocalAgentPtyRunner;
  const decoder = new TextDecoder();
  const frames: LocalAgentPtyFrame[] = [];
  let outputSequence = 0;
  let eventSequence = 0;
  let postedEvents = 0;
  let retainedBytes = 0;
  let totalBytes = 0;
  let totalFrames = 0;
  let totalLines = 0;
  let droppedFrames = 0;
  let droppedBytes = 0;
  let droppedThroughSequence = 0;
  let pendingOutput = "";
  let redactionCarry = "";
  let flushQueued = false;
  let cols = colsInitial;
  let rows = rowsInitial;
  let state: LocalAgentPtyRead["status"] = "running";
  let terminationReason: LocalAgentPtyTerminationReason | null = null;
  let killRequested = false;
  let killSent = false;
  let terminalClosed = false;
  let cancelIdle: () => void = () => {};
  let cancelRuntime: () => void = () => {};

  options.registry.begin({
    agentId: tool.id,
    agentKind: tool.kind,
    agentLabel: tool.label,
    command: tool.command,
    cwd: tool.cwd,
    task: tool.task,
    mode: "pty",
  }, options.sessionId);
  await persist();

  async function persist(): Promise<void> {
    if (options.sessionStore) {
      await saveLocalAgentSessionRegistry(options.registry, options.sessionStore);
    }
  }

  async function emit(event: Omit<LocalDevSessionEvent, "sequence">): Promise<void> {
    eventSequence += 1;
    await postLocalAgentEvent(
      options.agentEventsUrl,
      { sequence: eventSequence, ...event },
      options.fetcher,
    );
    postedEvents += 1;
  }

  function redact(value: string): string {
    return redactWithLiterals(value, secretLiterals);
  }

  function flushOutput(final = false): void {
    flushQueued = false;
    if (pendingOutput.length === 0 && redactionCarry.length === 0) return;
    const combined = redactionCarry + pendingOutput;
    pendingOutput = "";
    const carryLength = final ? 0 : longestSecretPrefixSuffix(combined, secretLiterals);
    redactionCarry = carryLength === 0 ? "" : combined.slice(-carryLength);
    let data = redact(carryLength === 0 ? combined : combined.slice(0, -carryLength));
    if (data.length === 0) return;
    const fullBytes = Buffer.byteLength(data, "utf8");
    totalLines += countNewlines(data);
    data = boundedUtf8Tail(data, maxRetainedBytes);
    const bytes = Buffer.byteLength(data, "utf8");
    outputSequence += 1;
    totalFrames += 1;
    if (bytes < fullBytes) {
      droppedBytes += fullBytes - bytes;
      droppedThroughSequence = outputSequence;
    }
    frames.push({ sequence: outputSequence, timestamp: timestamp(now), data });
    retainedBytes += bytes;
    while (frames.length > maxFrames || retainedBytes > maxRetainedBytes) {
      const removed = frames.shift();
      if (!removed) break;
      const removedBytes = Buffer.byteLength(removed.data, "utf8");
      retainedBytes -= removedBytes;
      droppedFrames += 1;
      droppedBytes += removedBytes;
      droppedThroughSequence = Math.max(droppedThroughSequence, removed.sequence);
    }
  }

  function queueFlush(): void {
    if (flushQueued) return;
    flushQueued = true;
    queueMicrotask(flushOutput);
  }

  let handle!: LocalAgentPtyHandle;

  function sendKill(): void {
    if (!killRequested || killSent || handle === undefined) return;
    killSent = true;
    try {
      handle.kill();
    } catch {
      // Exit may race the limit or abort request.
    }
  }

  function requestKill(reason: Exclude<LocalAgentPtyTerminationReason, "exit">): boolean {
    if (killRequested) return false;
    killRequested = true;
    terminationReason = reason;
    sendKill();
    return true;
  }

  function resetIdleTimer(): void {
    cancelIdle();
    cancelIdle = schedule(() => { requestKill("idle_timeout"); }, idleTimeoutMs);
  }

  try {
    handle = await runner.start(tool, {
      cols,
      rows,
      onData(data) {
        if (state !== "running") return;
        const bytes = data.byteLength;
        totalBytes += bytes;
        if (bytes > maxChunkBytes || totalBytes > maxTotalOutputBytes) {
          requestKill("output_limit");
          return;
        }
        pendingOutput += decoder.decode(data, { stream: true });
        queueFlush();
        resetIdleTimer();
      },
      onTerminalExit() {},
    });
    sendKill();
  } catch (error) {
    const detail = safeError(error, secretLiterals);
    try {
      await emit({ kind: "warning", value: `${tool.label} failed to start: ${detail}` });
      await emit({
        kind: "check_result",
        label: tool.checkLabel ?? tool.label,
        command: safeCommand(tool.command, secretLiterals),
        status: "fail",
        detail,
      });
      await emit(agentStatus(tool, "failed"));
    } finally {
      options.registry.finish(options.sessionId, terminalRecord("failed", null, false, detail));
      await persist();
    }
    throw new Error(detail);
  }

  try {
    options.registry.markRunning(options.sessionId);
    await persist();
    await emit(agentStatus(tool, "running"));
  } catch (error) {
    requestKill("stream_error");
    await Promise.allSettled([handle.exited]);
    closeTerminal();
    const detail = `collector delivery failed: ${safeError(error, secretLiterals)}`;
    options.registry.finish(options.sessionId, terminalRecord("interrupted", null, true, detail));
    await persist();
    throw new Error(detail);
  }

  const abortSignal = options.signal;
  const abort = () => { requestKill("abort"); };
  abortSignal?.addEventListener("abort", abort, { once: true });
  if (abortSignal?.aborted) abort();
  resetIdleTimer();
  cancelRuntime = schedule(() => { requestKill("runtime_timeout"); }, maxRuntimeMs);

  function closeTerminal(): void {
    if (terminalClosed) return;
    terminalClosed = true;
    try {
      handle.close();
    } catch {
      // Terminal close is best-effort after process settlement.
    }
  }

  function terminalRecord(
    terminalStatus: "done" | "failed" | "interrupted",
    exitCode: number | null,
    interrupted: boolean,
    detail?: string,
  ) {
    return {
      status: terminalStatus,
      exitCode,
      interrupted,
      lines: totalLines,
      turns: 0,
      ignored: 0,
      postedEvents,
      lastSequence: eventSequence,
      detail,
    } as const;
  }

  const completion = (async (): Promise<LocalAgentPtySummary> => {
    let exitCode: number | null = null;
    try {
      try {
        exitCode = await handle.exited;
      } catch (error) {
        pendingOutput += decoder.decode();
        flushOutput(true);
        state = "interrupted";
        terminationReason ??= "stream_error";
        const detail = `PTY wait failed: ${safeError(error, secretLiterals)}`;
        try {
          await emit({ kind: "warning", value: detail });
          await emit({
            kind: "check_result",
            label: tool.checkLabel ?? tool.label,
            command: safeCommand(tool.command, secretLiterals),
            status: "fail",
            detail,
          });
          await emit(agentStatus(tool, "failed"));
        } finally {
          options.registry.finish(options.sessionId, terminalRecord("interrupted", null, true, detail));
          await persist();
        }
        throw new Error(detail);
      }
      pendingOutput += decoder.decode();
      flushOutput(true);
      const reason = terminationReason ?? "exit";
      const interrupted = reason !== "exit";
      const succeeded = exitCode === 0 && !interrupted;
      state = succeeded ? "done" : interrupted ? "interrupted" : "failed";
      const detail = succeeded
        ? `PTY exited with code 0`
        : interrupted
          ? `PTY interrupted: ${reason}`
          : `PTY exited with code ${exitCode}`;
      try {
        await emit({
          kind: "check_result",
          label: tool.checkLabel ?? tool.label,
          command: safeCommand(tool.command, secretLiterals),
          status: succeeded ? "pass" : "fail",
          detail,
        });
        await emit(agentStatus(tool, succeeded ? "done" : "failed"));
      } finally {
        options.registry.finish(options.sessionId, terminalRecord(state, exitCode, interrupted, succeeded ? undefined : detail));
        await persist();
      }
      return {
        sessionId: options.sessionId,
        status: state,
        exitCode,
        interrupted,
        reason,
        cols,
        rows,
        totalBytes,
        frames: totalFrames,
        droppedFrames,
        droppedBytes,
        postedEvents,
        lastSequence: eventSequence,
      };
    } finally {
      cancelIdle();
      cancelRuntime();
      abortSignal?.removeEventListener("abort", abort);
      closeTerminal();
    }
  })();

  function read(after: number): LocalAgentPtyRead {
    const cursor = nonNegativeSafeInteger(after, "terminal cursor");
    const firstSequence = frames[0]?.sequence ?? outputSequence + 1;
    const selected = frames.filter((frame) => frame.sequence > cursor).map((frame) => ({ ...frame }));
    return {
      frames: selected,
      nextAfter: selected.at(-1)?.sequence ?? Math.max(cursor, outputSequence),
      gap: cursor < Math.max(firstSequence - 1, droppedThroughSequence),
      droppedFrames,
      droppedBytes,
      status: state,
      cols,
      rows,
      totalBytes,
    };
  }

  return {
    sessionId: options.sessionId,
    completion,
    write(data) {
      if (state !== "running" || Buffer.byteLength(data, "utf8") > maxInputBytes) return false;
      try {
        const written = handle.write(data);
        resetIdleTimer();
        return written >= 0;
      } catch {
        requestKill("stream_error");
        return false;
      }
    },
    resize(nextCols, nextRows) {
      if (state !== "running") return false;
      try {
        const validCols = dimension(nextCols, MIN_COLS, MAX_COLS, "PTY columns");
        const validRows = dimension(nextRows, MIN_ROWS, MAX_ROWS, "PTY rows");
        handle.resize(validCols, validRows);
        cols = validCols;
        rows = validRows;
        resetIdleTimer();
        return true;
      } catch {
        return false;
      }
    },
    stop() { return requestKill("abort"); },
    read,
    status: () => state,
  };
}

function agentStatus(
  tool: LocalAgentProcessTool,
  status: "running" | "done" | "failed",
): Omit<LocalDevSessionEvent, "sequence"> {
  return {
    kind: "agent_status",
    agent_id: tool.id,
    agent_kind: tool.kind,
    agent_label: tool.label,
    status,
    task: tool.task,
  };
}

function safeCommand(command: readonly string[], secretLiterals: readonly string[]): string {
  return redactWithLiterals(command.join(" "), secretLiterals);
}

function safeError(error: unknown, secretLiterals: readonly string[]): string {
  const detail = error instanceof Error ? error.message : typeof error === "string" ? error : "unknown PTY error";
  return redactWithLiterals(detail, secretLiterals);
}

function redactWithLiterals(value: string, secretLiterals: readonly string[]): string {
  let redacted = redactLocalDevSessionText(value);
  for (const secret of secretLiterals) redacted = redacted.replaceAll(secret, "<redacted>");
  return redacted;
}

function longestSecretPrefixSuffix(value: string, secretLiterals: readonly string[]): number {
  let longest = 0;
  for (const secret of secretLiterals) {
    const maximum = Math.min(secret.length - 1, value.length);
    for (let length = maximum; length > longest; length -= 1) {
      if (value.endsWith(secret.slice(0, length))) {
        longest = length;
        break;
      }
    }
  }
  return longest;
}

function boundedUtf8Tail(value: string, maxBytes: number): string {
  const encoded = new TextEncoder().encode(value);
  if (encoded.byteLength <= maxBytes) return value;
  return new TextDecoder().decode(encoded.slice(encoded.byteLength - maxBytes));
}

function countNewlines(value: string): number {
  let lines = 0;
  for (const char of value) if (char === "\n") lines += 1;
  return lines;
}

function dimension(value: number, minimum: number, maximum: number, label: string): number {
  if (!Number.isSafeInteger(value) || value < minimum || value > maximum) {
    throw new RangeError(`${label} must be from ${minimum} to ${maximum}`);
  }
  return value;
}

function positiveSafeInteger(value: number, label: string): number {
  if (!Number.isSafeInteger(value) || value <= 0) throw new RangeError(`${label} must be a positive safe integer`);
  return value;
}

function nonNegativeSafeInteger(value: number, label: string): number {
  if (!Number.isSafeInteger(value) || value < 0) throw new RangeError(`${label} must be a non-negative safe integer`);
  return value;
}

function timestamp(now: () => number): number {
  return nonNegativeSafeInteger(now(), "PTY timestamp");
}

function timerSchedule(run: () => void, delayMs: number): () => void {
  const timer = setTimeout(run, delayMs);
  return () => clearTimeout(timer);
}
