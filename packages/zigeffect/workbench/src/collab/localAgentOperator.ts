import { createSignal, type Accessor } from "solid-js";
import {
  LocalAgentControlClientError,
  type LocalAgentControlClient,
  type LocalAgentControlDecision,
  type LocalAgentControlHealth,
  type LocalAgentControlReceipt,
  type LocalAgentControlSession,
  type LocalAgentControlToolSummary,
} from "../localAgentControlClient";

export type LocalAgentOperatorConnection =
  | "disconnected"
  | "connecting"
  | "connected"
  | "unauthorized"
  | "error";

export type LocalAgentOperatorPending = "start" | "stop" | null;

export type LocalAgentOperatorSchedule = (
  run: () => void | Promise<void>,
  delayMs: number,
) => () => void;

export type LocalAgentOperatorOptions = {
  activePollMs?: number;
  idlePollMs?: number;
  schedule?: LocalAgentOperatorSchedule;
};

export type LocalAgentOperator = {
  baseUrl: Accessor<string | null>;
  connection: Accessor<LocalAgentOperatorConnection>;
  refreshing: Accessor<boolean>;
  pending: Accessor<LocalAgentOperatorPending>;
  health: Accessor<LocalAgentControlHealth | null>;
  tools: Accessor<LocalAgentControlToolSummary[]>;
  sessions: Accessor<LocalAgentControlSession[]>;
  receipts: Accessor<LocalAgentControlReceipt[]>;
  latestReceipt: Accessor<LocalAgentControlReceipt | null>;
  selectedSessionId: Accessor<string | null>;
  selectedSession: Accessor<LocalAgentControlSession | null>;
  error: Accessor<LocalAgentControlClientError | null>;
  connect: (client: LocalAgentControlClient) => Promise<void>;
  disconnect: () => void;
  refresh: () => Promise<void>;
  startPolling: () => void;
  stopPolling: () => void;
  selectSession: (sessionId: string) => Promise<void>;
  start: (toolId: string, prompt?: string) => Promise<LocalAgentControlDecision | null>;
  stop: (sessionId: string) => Promise<LocalAgentControlDecision | null>;
  dispose: () => void;
};

type RefreshFlight = {
  generation: number;
  promise: Promise<void>;
};

const DEFAULT_ACTIVE_POLL_MS = 1000;
const DEFAULT_IDLE_POLL_MS = 5000;

export function createLocalAgentOperator(
  options: LocalAgentOperatorOptions = {},
): LocalAgentOperator {
  const activePollMs = positiveSafeInteger(options.activePollMs ?? DEFAULT_ACTIVE_POLL_MS, "activePollMs");
  const idlePollMs = positiveSafeInteger(options.idlePollMs ?? DEFAULT_IDLE_POLL_MS, "idlePollMs");
  const schedule = options.schedule ?? browserSchedule;

  const [baseUrl, setBaseUrl] = createSignal<string | null>(null);
  const [connection, setConnection] = createSignal<LocalAgentOperatorConnection>("disconnected");
  const [refreshing, setRefreshing] = createSignal(false);
  const [pending, setPending] = createSignal<LocalAgentOperatorPending>(null);
  const [health, setHealth] = createSignal<LocalAgentControlHealth | null>(null);
  const [tools, setTools] = createSignal<LocalAgentControlToolSummary[]>([]);
  const [sessions, setSessions] = createSignal<LocalAgentControlSession[]>([]);
  const [receipts, setReceipts] = createSignal<LocalAgentControlReceipt[]>([]);
  const [selectedSessionId, setSelectedSessionId] = createSignal<string | null>(null);
  const [selectedSession, setSelectedSession] = createSignal<LocalAgentControlSession | null>(null);
  const [error, setError] = createSignal<LocalAgentControlClientError | null>(null);

  let client: LocalAgentControlClient | null = null;
  let generation = 0;
  let refreshController: AbortController | null = null;
  let detailController: AbortController | null = null;
  let refreshFlight: RefreshFlight | null = null;
  let cancelTimer: (() => void) | null = null;
  let polling = false;

  async function connect(nextClient: LocalAgentControlClient): Promise<void> {
    resetConnectionWork();
    generation += 1;
    client = nextClient;
    setBaseUrl(nextClient.baseUrl);
    setConnection("connecting");
    setRefreshing(false);
    setPending(null);
    setHealth(null);
    setTools([]);
    setSessions([]);
    setReceipts([]);
    setSelectedSessionId(null);
    setSelectedSession(null);
    setError(null);
    await refresh();
  }

  function disconnect(): void {
    generation += 1;
    resetConnectionWork();
    client = null;
    polling = false;
    setBaseUrl(null);
    setConnection("disconnected");
    setRefreshing(false);
    setPending(null);
    setHealth(null);
    setTools([]);
    setSessions([]);
    setReceipts([]);
    setSelectedSessionId(null);
    setSelectedSession(null);
    setError(null);
  }

  function refresh(): Promise<void> {
    const currentClient = client;
    if (!currentClient) return Promise.resolve();
    const currentGeneration = generation;
    if (refreshFlight?.generation === currentGeneration) return refreshFlight.promise;
    const controller = new AbortController();
    refreshController = controller;
    const promise = refreshSnapshot(currentClient, currentGeneration, controller.signal)
      .finally(() => {
        const currentFlight = refreshFlight?.promise === promise;
        if (currentFlight) refreshFlight = null;
        if (refreshController === controller) refreshController = null;
        if (currentFlight && generation === currentGeneration) setRefreshing(false);
      });
    refreshFlight = { generation: currentGeneration, promise };
    return promise;
  }

  function refreshFresh(): Promise<void> {
    refreshController?.abort();
    refreshController = null;
    refreshFlight = null;
    return refresh();
  }

  async function refreshSnapshot(
    currentClient: LocalAgentControlClient,
    currentGeneration: number,
    signal: AbortSignal,
  ): Promise<void> {
    setRefreshing(true);
    try {
      const [nextHealth, nextTools, nextSessions, nextReceipts] = await Promise.all([
        currentClient.health(signal),
        currentClient.tools(signal),
        currentClient.sessions(signal),
        currentClient.receipts(signal),
      ]);
      if (!isCurrent(currentClient, currentGeneration)) return;

      const priorSelection = selectedSessionId();
      const selection = priorSelection && nextSessions.some((item) => item.id === priorSelection)
        ? priorSelection
        : nextSessions[0]?.id ?? null;
      let detail = selection ? nextSessions.find((item) => item.id === selection) ?? null : null;
      if (selection) {
        try {
          detail = await currentClient.session(selection, signal);
        } catch (caught) {
          if (!(caught instanceof LocalAgentControlClientError && caught.code === "not_found")) throw caught;
        }
      }
      if (!isCurrent(currentClient, currentGeneration)) return;

      setHealth(nextHealth);
      setTools(nextTools);
      setSessions(nextSessions);
      setReceipts(nextReceipts);
      setSelectedSessionId(selection);
      setSelectedSession(detail);
      setError(null);
      setConnection("connected");
    } catch (caught) {
      if (!isCurrent(currentClient, currentGeneration)) return;
      const failure = controlError(caught);
      if (failure.code === "cancelled") return;
      setError(failure);
      setConnection(failure.code === "unauthorized" ? "unauthorized" : "error");
    }
  }

  function startPolling(): void {
    polling = true;
    scheduleNextPoll();
  }

  function stopPolling(): void {
    polling = false;
    cancelTimer?.();
    cancelTimer = null;
  }

  function scheduleNextPoll(): void {
    if (!polling || !client || connection() === "disconnected") return;
    cancelTimer?.();
    const active = health()?.activeSessions ?? sessions().filter(isActiveSession).length;
    cancelTimer = schedule(async () => {
      cancelTimer = null;
      await refresh();
      scheduleNextPoll();
    }, active > 0 ? activePollMs : idlePollMs);
  }

  async function selectSession(sessionId: string): Promise<void> {
    const currentClient = client;
    const currentGeneration = generation;
    const fallback = sessions().find((item) => item.id === sessionId);
    if (!currentClient || !fallback) return;
    detailController?.abort();
    const controller = new AbortController();
    detailController = controller;
    setSelectedSessionId(sessionId);
    setSelectedSession(fallback);
    try {
      const detail = await currentClient.session(sessionId, controller.signal);
      if (isCurrent(currentClient, currentGeneration) && selectedSessionId() === sessionId) {
        setSelectedSession(detail);
      }
    } catch (caught) {
      if (!isCurrent(currentClient, currentGeneration)) return;
      const failure = controlError(caught);
      if (failure.code !== "cancelled" && failure.code !== "not_found") setError(failure);
    } finally {
      if (detailController === controller) detailController = null;
    }
  }

  async function start(
    toolId: string,
    prompt?: string,
  ): Promise<LocalAgentControlDecision | null> {
    const currentClient = client;
    if (!currentClient || pending() !== null) return null;
    const tool = tools().find((item) => item.id === toolId);
    if (!tool) {
      setError(new LocalAgentControlClientError("policy", "approved tool is not available"));
      return null;
    }
    let input: unknown;
    if (tool.input) {
      const value = prompt ?? "";
      if (tool.input.required && value.trim().length === 0) {
        setError(new LocalAgentControlClientError("policy", `${tool.input.label} is required`));
        return null;
      }
      if (value.length > tool.input.maxLength) {
        setError(new LocalAgentControlClientError("policy", `${tool.input.label} is too long`));
        return null;
      }
      input = { prompt: value };
    }
    const currentGeneration = generation;
    setPending("start");
    setError(null);
    try {
      const decision = await currentClient.start({ toolId, ...(input === undefined ? {} : { input }) });
      if (!isCurrent(currentClient, currentGeneration)) return null;
      setSelectedSessionId(decision.sessionId);
      await refreshFresh();
      return decision;
    } catch (caught) {
      if (isCurrent(currentClient, currentGeneration)) applyActionError(caught);
      return null;
    } finally {
      if (isCurrent(currentClient, currentGeneration)) setPending(null);
    }
  }

  async function stop(sessionId: string): Promise<LocalAgentControlDecision | null> {
    const currentClient = client;
    if (!currentClient || pending() !== null || !sessions().some((item) => item.id === sessionId && isActiveSession(item))) {
      return null;
    }
    const currentGeneration = generation;
    setPending("stop");
    setError(null);
    try {
      const decision = await currentClient.stop(sessionId);
      if (!isCurrent(currentClient, currentGeneration)) return null;
      setSelectedSessionId(decision.sessionId);
      await refreshFresh();
      return decision;
    } catch (caught) {
      if (isCurrent(currentClient, currentGeneration)) applyActionError(caught);
      return null;
    } finally {
      if (isCurrent(currentClient, currentGeneration)) setPending(null);
    }
  }

  function applyActionError(caught: unknown): void {
    const failure = controlError(caught);
    setError(failure);
    if (failure.code === "unauthorized") setConnection("unauthorized");
  }

  function isCurrent(currentClient: LocalAgentControlClient, currentGeneration: number): boolean {
    return client === currentClient && generation === currentGeneration;
  }

  function resetConnectionWork(): void {
    stopPolling();
    refreshController?.abort();
    detailController?.abort();
    refreshController = null;
    detailController = null;
    refreshFlight = null;
  }

  return {
    baseUrl,
    connection,
    refreshing,
    pending,
    health,
    tools,
    sessions,
    receipts,
    latestReceipt: () => receipts().at(-1) ?? null,
    selectedSessionId,
    selectedSession,
    error,
    connect,
    disconnect,
    refresh,
    startPolling,
    stopPolling,
    selectSession,
    start,
    stop,
    dispose: disconnect,
  };
}

function browserSchedule(run: () => void | Promise<void>, delayMs: number): () => void {
  const timer = setTimeout(() => { void run(); }, delayMs);
  return () => clearTimeout(timer);
}

function isActiveSession(session: LocalAgentControlSession): boolean {
  return session.status === "starting" || session.status === "running";
}

function controlError(caught: unknown): LocalAgentControlClientError {
  return caught instanceof LocalAgentControlClientError
    ? caught
    : new LocalAgentControlClientError("unavailable", "local control operation failed");
}

function positiveSafeInteger(value: number, label: string): number {
  if (!Number.isSafeInteger(value) || value <= 0) throw new RangeError(`${label} must be a positive safe integer`);
  return value;
}
