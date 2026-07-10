import { createSignal, type Accessor } from "solid-js";
import {
  LocalAgentControlClientError,
  type LocalAgentControlClient,
  type LocalAgentControlSession,
} from "../localAgentControlClient";

export type LocalAgentTerminalConnection = "idle" | "polling" | "error" | "closed";

export type LocalAgentTerminalSchedule = (
  run: () => void | Promise<void>,
  delayMs: number,
) => () => void;

export type LocalAgentTerminalOptions = {
  onData: (data: string) => void;
  pollMs?: number;
  resizeDebounceMs?: number;
  schedule?: LocalAgentTerminalSchedule;
};

export type LocalAgentTerminal = {
  connection: Accessor<LocalAgentTerminalConnection>;
  status: Accessor<LocalAgentControlSession["status"]>;
  cursor: Accessor<number>;
  gap: Accessor<boolean>;
  droppedFrames: Accessor<number>;
  droppedBytes: Accessor<number>;
  totalBytes: Accessor<number>;
  cols: Accessor<number>;
  rows: Accessor<number>;
  error: Accessor<LocalAgentControlClientError | null>;
  start: () => Promise<void>;
  refresh: () => Promise<void>;
  write: (data: string) => Promise<boolean>;
  resize: (cols: number, rows: number) => boolean;
  dispose: () => void;
};

const DEFAULT_POLL_MS = 100;
const DEFAULT_RESIZE_DEBOUNCE_MS = 100;
const MIN_COLS = 20;
const MAX_COLS = 500;
const MIN_ROWS = 5;
const MAX_ROWS = 200;

export function createLocalAgentTerminal(
  client: LocalAgentControlClient,
  sessionId: string,
  options: LocalAgentTerminalOptions,
): LocalAgentTerminal {
  const pollMs = positiveSafeInteger(options.pollMs ?? DEFAULT_POLL_MS, "pollMs");
  const resizeDebounceMs = positiveSafeInteger(
    options.resizeDebounceMs ?? DEFAULT_RESIZE_DEBOUNCE_MS,
    "resizeDebounceMs",
  );
  const schedule = options.schedule ?? browserSchedule;
  const [connection, setConnection] = createSignal<LocalAgentTerminalConnection>("idle");
  const [status, setStatus] = createSignal<LocalAgentControlSession["status"]>("running");
  const [cursor, setCursor] = createSignal(0);
  const [gap, setGap] = createSignal(false);
  const [droppedFrames, setDroppedFrames] = createSignal(0);
  const [droppedBytes, setDroppedBytes] = createSignal(0);
  const [totalBytes, setTotalBytes] = createSignal(0);
  const [cols, setCols] = createSignal(100);
  const [rows, setRows] = createSignal(30);
  const [error, setError] = createSignal<LocalAgentControlClientError | null>(null);

  let generation = 0;
  let polling = false;
  let readController: AbortController | null = null;
  let writeController: AbortController | null = null;
  let refreshFlight: Promise<void> | null = null;
  let inputTail: Promise<unknown> = Promise.resolve();
  let cancelPoll: (() => void) | null = null;
  let cancelResize: (() => void) | null = null;
  let pendingResize: { cols: number; rows: number } | null = null;

  async function start(): Promise<void> {
    if (connection() === "closed") return;
    polling = true;
    await refresh();
    scheduleNextPoll();
  }

  function refresh(): Promise<void> {
    if (connection() === "closed") return Promise.resolve();
    if (refreshFlight) return refreshFlight;
    const currentGeneration = generation;
    const controller = new AbortController();
    readController = controller;
    setConnection("polling");
    const promise = client.terminal(sessionId, cursor(), controller.signal)
      .then((next) => {
        if (!isCurrent(currentGeneration)) return;
        for (const frame of next.frames) options.onData(frame.data);
        setCursor(next.nextAfter);
        setGap((value) => value || next.gap);
        setDroppedFrames(next.droppedFrames);
        setDroppedBytes(next.droppedBytes);
        setTotalBytes(next.totalBytes);
        setCols(next.cols);
        setRows(next.rows);
        setStatus(next.status);
        setError(null);
        setConnection("idle");
        if (!isActive(next.status)) polling = false;
      })
      .catch((caught) => {
        if (!isCurrent(currentGeneration)) return;
        const failure = controlError(caught);
        if (failure.code === "cancelled") return;
        polling = false;
        setError(failure);
        setConnection("error");
      })
      .finally(() => {
        if (readController === controller) readController = null;
        if (refreshFlight === promise) refreshFlight = null;
      });
    refreshFlight = promise;
    return promise;
  }

  function scheduleNextPoll(): void {
    cancelPoll?.();
    cancelPoll = null;
    if (!polling || connection() === "closed" || !isActive(status())) return;
    cancelPoll = schedule(async () => {
      cancelPoll = null;
      await refresh();
      scheduleNextPoll();
    }, pollMs);
  }

  function write(data: string): Promise<boolean> {
    if (connection() === "closed" || !isActive(status())) return Promise.resolve(false);
    const currentGeneration = generation;
    const task = inputTail.then(async () => {
      if (!isCurrent(currentGeneration)) return false;
      const controller = new AbortController();
      writeController = controller;
      try {
        await client.writeTerminal(sessionId, data, controller.signal);
        return isCurrent(currentGeneration);
      } catch (caught) {
        if (!isCurrent(currentGeneration)) return false;
        const failure = controlError(caught);
        if (failure.code !== "cancelled") {
          setError(failure);
          setConnection("error");
        }
        return false;
      } finally {
        if (writeController === controller) writeController = null;
      }
    });
    inputTail = task.catch(() => undefined);
    return task;
  }

  function resize(nextCols: number, nextRows: number): boolean {
    if (
      connection() === "closed" || !isActive(status()) ||
      !dimension(nextCols, MIN_COLS, MAX_COLS) ||
      !dimension(nextRows, MIN_ROWS, MAX_ROWS)
    ) return false;
    pendingResize = { cols: nextCols, rows: nextRows };
    cancelResize?.();
    cancelResize = schedule(async () => {
      cancelResize = null;
      const next = pendingResize;
      pendingResize = null;
      if (!next || connection() === "closed" || !isActive(status())) return;
      try {
        const accepted = await client.resizeTerminal(sessionId, next.cols, next.rows);
        if (connection() === "closed") return;
        setCols(accepted.cols);
        setRows(accepted.rows);
      } catch (caught) {
        if (connection() === "closed") return;
        const failure = controlError(caught);
        if (failure.code !== "cancelled") setError(failure);
      }
    }, resizeDebounceMs);
    return true;
  }

  function dispose(): void {
    if (connection() === "closed") return;
    generation += 1;
    polling = false;
    cancelPoll?.();
    cancelResize?.();
    cancelPoll = null;
    cancelResize = null;
    pendingResize = null;
    readController?.abort();
    writeController?.abort();
    readController = null;
    writeController = null;
    setConnection("closed");
  }

  function isCurrent(currentGeneration: number): boolean {
    return generation === currentGeneration && connection() !== "closed";
  }

  return {
    connection,
    status,
    cursor,
    gap,
    droppedFrames,
    droppedBytes,
    totalBytes,
    cols,
    rows,
    error,
    start,
    refresh,
    write,
    resize,
    dispose,
  };
}

function browserSchedule(run: () => void | Promise<void>, delayMs: number): () => void {
  const timer = setTimeout(() => { void run(); }, delayMs);
  return () => clearTimeout(timer);
}

function isActive(status: LocalAgentControlSession["status"]): boolean {
  return status === "starting" || status === "running";
}

function controlError(caught: unknown): LocalAgentControlClientError {
  return caught instanceof LocalAgentControlClientError
    ? caught
    : new LocalAgentControlClientError("unavailable", "local terminal operation failed");
}

function positiveSafeInteger(value: number, label: string): number {
  if (!Number.isSafeInteger(value) || value <= 0) throw new RangeError(`${label} must be a positive safe integer`);
  return value;
}

function dimension(value: number, minimum: number, maximum: number): boolean {
  return Number.isSafeInteger(value) && value >= minimum && value <= maximum;
}
