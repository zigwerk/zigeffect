import type { LocalDevAgentKind } from "../causalArtifact";
import type { LocalDevSessionEvent } from "../localDevSessionFeed";
import { localAgentChildEnvironment, postLocalAgentEvent } from "./localAgentRuntime";
import type {
  LocalAgentSessionRegistry,
  LocalAgentSessionStore,
  LocalAgentSessionTerminal,
} from "./localAgentSessionRegistry";
import { saveLocalAgentSessionRegistry } from "./localAgentSessionRegistry";
import {
  runLocalAgentTranscriptTail,
  type LocalAgentTranscriptAdapter,
  type LocalAgentTranscriptTailSummary,
} from "./localAgentTranscriptTail";

export type LocalAgentProcessTool = {
  id: string;
  kind: LocalDevAgentKind;
  label: string;
  command: string[];
  cwd?: string;
  task?: string;
  checkLabel?: string;
  transcriptAdapter?: LocalAgentTranscriptAdapter;
};

export type LocalAgentProcessHandle = {
  stdout: ReadableStream<Uint8Array>;
  stderr: ReadableStream<Uint8Array>;
  exited: Promise<number>;
  kill: () => void;
};

export type LocalAgentProcessRunner = {
  start: (tool: LocalAgentProcessTool) => Promise<LocalAgentProcessHandle>;
};

export type LocalAgentProcessSupervisorOptions = {
  agentEventsUrl: string;
  fetcher?: typeof fetch;
  runner?: LocalAgentProcessRunner;
  sequenceStart?: number;
  signal?: AbortSignal;
  stderrLimitBytes?: number;
  registry?: LocalAgentSessionRegistry;
  sessionId?: string;
  sessionStore?: LocalAgentSessionStore;
};

export type LocalAgentProcessSupervisorSummary = {
  sessionId: string | null;
  status: "done" | "failed";
  exitCode: number | null;
  interrupted: boolean;
  lines: number;
  turns: number;
  ignored: number;
  postedEvents: number;
  lastSequence: number;
};

const DEFAULT_STDERR_LIMIT_BYTES = 16 * 1024;

export const bunLocalAgentProcessRunner: LocalAgentProcessRunner = {
  async start(tool) {
    const [command, ...args] = tool.command;
    if (!command) {
      throw new Error(`process ${tool.id} has no command`);
    }

    const process = Bun.spawn([command, ...args], {
      cwd: tool.cwd,
      env: localAgentChildEnvironment(),
      stdin: "ignore",
      stdout: "pipe",
      stderr: "pipe",
    });

    return {
      stdout: process.stdout,
      stderr: process.stderr,
      exited: process.exited,
      kill() {
        process.kill();
      },
    };
  },
};

export async function runLocalAgentProcessSupervisor(
  tool: LocalAgentProcessTool,
  options: LocalAgentProcessSupervisorOptions,
): Promise<LocalAgentProcessSupervisorSummary> {
  let sequence = options.sequenceStart ?? 0;
  let postedEvents = 0;
  if (options.sessionStore && !options.registry) {
    throw new Error("sessionStore requires a session registry");
  }
  const registrySession = options.registry?.begin({
    agentId: tool.id,
    agentKind: tool.kind,
    agentLabel: tool.label,
    command: tool.command,
    cwd: tool.cwd,
    task: tool.task,
  }, options.sessionId);
  const sessionId = registrySession?.id ?? null;

  async function persistSession(): Promise<void> {
    if (options.registry && options.sessionStore) {
      await saveLocalAgentSessionRegistry(options.registry, options.sessionStore);
    }
  }

  async function finishSession(terminal: LocalAgentSessionTerminal): Promise<void> {
    if (sessionId) {
      options.registry?.finish(sessionId, terminal);
      await persistSession();
    }
  }

  await persistSession();

  async function emit(event: Omit<LocalDevSessionEvent, "sequence">): Promise<void> {
    sequence += 1;
    await postLocalAgentEvent(
      options.agentEventsUrl,
      { sequence, ...event },
      options.fetcher,
    );
    postedEvents += 1;
  }

  const runner = options.runner ?? bunLocalAgentProcessRunner;
  let process: LocalAgentProcessHandle;
  try {
    process = await runner.start(tool);
  } catch (error) {
    const detail = errorDetail(error);
    try {
      await emit({
        kind: "warning",
        value: `${tool.label} failed to start: ${detail}`,
      });
      await emit({
        kind: "check_result",
        label: tool.checkLabel ?? tool.label,
        command: commandText(tool.command),
        status: "fail",
        detail,
      });
      await emit(agentStatus(tool, "failed"));
    } finally {
      await finishSession(terminalRecord("failed", null, false, postedEvents, sequence, detail));
    }
    return emptySummary(sessionId, sequence, postedEvents);
  }

  try {
    if (sessionId) {
      options.registry?.markRunning(sessionId);
      await persistSession();
    }
    await emit(agentStatus(tool, "running"));
  } catch (error) {
    await terminateProcess(process);
    const detail = `collector delivery failed: ${errorDetail(error)}`;
    await finishSession(terminalRecord("interrupted", null, true, postedEvents, sequence, detail));
    throw error;
  }

  let interrupted = false;
  let killRequested = false;
  const requestKill = (): void => {
    if (killRequested) return;
    killRequested = true;
    interrupted = true;
    try {
      process.kill();
    } catch {
      // The process may have exited between the abort and kill request.
    }
  };
  const abortSignal = options.signal;
  abortSignal?.addEventListener("abort", requestKill, { once: true });
  if (abortSignal?.aborted) {
    requestKill();
  }

  const transcriptPromise = runLocalAgentTranscriptTail(process.stdout, {
    agentEventsUrl: options.agentEventsUrl,
    agentId: tool.id,
    agentKind: tool.kind,
    agentLabel: tool.label,
    adapter: tool.transcriptAdapter,
    fetcher: options.fetcher,
    sequenceStart: sequence,
  });
  const stderrPromise = readBoundedTextTail(
    process.stderr,
    boundedByteLimit(options.stderrLimitBytes),
  );

  let transcript: LocalAgentTranscriptTailSummary;
  let stderr: string;
  let exitCode: number;
  try {
    [transcript, stderr, exitCode] = await Promise.all([
      transcriptPromise,
      stderrPromise,
      process.exited,
    ]);
  } catch (error) {
    if (!killRequested) {
      try {
        process.kill();
      } catch {
        // Preserve the original stream or collector failure.
      }
    }
    await Promise.allSettled([process.exited, transcriptPromise, stderrPromise]);
    await finishSession(terminalRecord(
      "interrupted",
      null,
      true,
      postedEvents,
      sequence,
      `process supervision failed: ${errorDetail(error)}`,
    ));
    throw error;
  } finally {
    abortSignal?.removeEventListener("abort", requestKill);
  }

  sequence = transcript.lastSequence;
  postedEvents += transcript.posted;
  const succeeded = exitCode === 0 && !interrupted;
  const detail = terminalDetail(exitCode, interrupted, transcript, stderr);
  try {
    await emit({
      kind: "check_result",
      label: tool.checkLabel ?? tool.label,
      command: commandText(tool.command),
      status: succeeded ? "pass" : "fail",
      detail,
    });
    await emit(agentStatus(tool, succeeded ? "done" : "failed"));
  } finally {
    await finishSession({
      status: succeeded ? "done" : interrupted ? "interrupted" : "failed",
      exitCode,
      interrupted,
      lines: transcript.lines,
      turns: transcript.turns,
      ignored: transcript.ignored,
      postedEvents,
      lastSequence: sequence,
      detail: succeeded ? undefined : detail,
    });
  }

  return {
    sessionId,
    status: succeeded ? "done" : "failed",
    exitCode,
    interrupted,
    lines: transcript.lines,
    turns: transcript.turns,
    ignored: transcript.ignored,
    postedEvents,
    lastSequence: sequence,
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

function emptySummary(
  sessionId: string | null,
  lastSequence: number,
  postedEvents: number,
): LocalAgentProcessSupervisorSummary {
  return {
    sessionId,
    status: "failed",
    exitCode: null,
    interrupted: false,
    lines: 0,
    turns: 0,
    ignored: 0,
    postedEvents,
    lastSequence,
  };
}

function terminalRecord(
  status: LocalAgentSessionTerminal["status"],
  exitCode: number | null,
  interrupted: boolean,
  postedEvents: number,
  lastSequence: number,
  detail?: string,
): LocalAgentSessionTerminal {
  return {
    status,
    exitCode,
    interrupted,
    lines: 0,
    turns: 0,
    ignored: 0,
    postedEvents,
    lastSequence,
    detail,
  };
}

async function terminateProcess(process: LocalAgentProcessHandle): Promise<void> {
  try {
    process.kill();
  } catch {
    // A concurrently exiting process may already be gone.
  }
  await Promise.allSettled([process.exited]);
}

function terminalDetail(
  exitCode: number,
  interrupted: boolean,
  transcript: LocalAgentTranscriptTailSummary,
  stderr: string,
): string {
  if (interrupted) {
    return "interrupted by abort signal";
  }
  if (exitCode === 0) {
    return `${transcript.turns} transcript ${plural(transcript.turns, "turn")} from ${transcript.lines} ${plural(transcript.lines, "line")}`;
  }
  const detail = stderr.trim();
  return detail.length > 0 ? `exit ${exitCode}: ${detail}` : `exit ${exitCode}`;
}

function plural(count: number, singular: string): string {
  return count === 1 ? singular : `${singular}s`;
}

function commandText(command: readonly string[]): string {
  return command.join(" ");
}

function errorDetail(error: unknown): string {
  if (error instanceof Error) return error.message;
  if (typeof error === "string") return error;
  return "unknown process start error";
}

function boundedByteLimit(value: number | undefined): number {
  if (value === undefined) return DEFAULT_STDERR_LIMIT_BYTES;
  if (!Number.isSafeInteger(value) || value < 0) {
    throw new RangeError("stderrLimitBytes must be a non-negative safe integer");
  }
  return value;
}

async function readBoundedTextTail(
  stream: ReadableStream<Uint8Array>,
  limit: number,
): Promise<string> {
  const reader = stream.getReader();
  let tail: Uint8Array<ArrayBufferLike> = new Uint8Array(0);
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    tail = appendByteTail(tail, value, limit);
  }
  return new TextDecoder().decode(tail);
}

function appendByteTail(
  current: Uint8Array,
  chunk: Uint8Array,
  limit: number,
): Uint8Array {
  if (limit === 0) return new Uint8Array(0);
  if (chunk.byteLength >= limit) {
    return chunk.slice(chunk.byteLength - limit);
  }
  const retainedCurrentBytes = Math.min(current.byteLength, limit - chunk.byteLength);
  const next = new Uint8Array(retainedCurrentBytes + chunk.byteLength);
  next.set(current.subarray(current.byteLength - retainedCurrentBytes));
  next.set(chunk, retainedCurrentBytes);
  return next;
}
