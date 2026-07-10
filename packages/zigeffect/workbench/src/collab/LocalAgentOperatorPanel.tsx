import CircleAlert from "lucide-solid/icons/circle-alert";
import Database from "lucide-solid/icons/database";
import Play from "lucide-solid/icons/play";
import Plug from "lucide-solid/icons/plug";
import RefreshCw from "lucide-solid/icons/refresh-cw";
import ShieldCheck from "lucide-solid/icons/shield-check";
import Square from "lucide-solid/icons/square";
import Unplug from "lucide-solid/icons/unplug";
import { For, Show, createEffect, createMemo, createSignal, onCleanup, onMount } from "solid-js";
import {
  LocalAgentControlClientError,
  createLocalAgentControlClient,
  type LocalAgentControlBootstrap,
  type LocalAgentControlSession,
} from "../localAgentControlClient";
import { Badge, EmptyState, Metric } from "../primitives";
import { LocalAgentTerminalPanel } from "./LocalAgentTerminalPanel";
import { createLocalAgentOperator } from "./localAgentOperator";

type OperatorMobilePanel = "launch" | "sessions" | "detail" | "terminal";

export function LocalAgentOperatorPanel(props: { bootstrap: LocalAgentControlBootstrap }) {
  let operatorRoot!: HTMLElement;
  let terminalSection: HTMLElement | undefined;
  const operator = createLocalAgentOperator();
  const [endpoint, setEndpoint] = createSignal(props.bootstrap.controlUrl ?? "");
  const [token, setToken] = createSignal(props.bootstrap.token ?? "");
  const [selectedToolId, setSelectedToolId] = createSignal("");
  const [prompt, setPrompt] = createSignal("");
  const [mobilePanel, setMobilePanel] = createSignal<OperatorMobilePanel>("launch");
  const [controlClient, setControlClient] = createSignal<ReturnType<typeof createLocalAgentControlClient> | null>(null);
  const [configError, setConfigError] = createSignal<string | null>(null);
  const selectedTool = createMemo(() => operator.tools().find((tool) => tool.id === selectedToolId()) ?? null);
  const latestReceipt = operator.latestReceipt;
  const connected = createMemo(() => operator.connection() === "connected");
  const terminalSessionId = createMemo(() => {
    const client = controlClient();
    const item = operator.selectedSession();
    return client && item && item.mode === "pty" && item.terminalAvailable ? item.id : null;
  });
  const mobileTabs = createMemo<readonly (readonly [OperatorMobilePanel, string])[]>(() => {
    const tabs: Array<readonly [OperatorMobilePanel, string]> = [
      ["launch", "Run"],
      ["sessions", `Sessions ${operator.sessions().length}`],
      ["detail", "Detail"],
    ];
    if (terminalSessionId()) tabs.push(["terminal", "Terminal"]);
    return tabs;
  });

  createEffect(() => {
    const available = operator.tools();
    if (!available.some((tool) => tool.id === selectedToolId())) {
      setSelectedToolId(available[0]?.id ?? "");
    }
  });

  createEffect(() => {
    if (mobilePanel() === "terminal" && !terminalSessionId()) setMobilePanel("detail");
  });

  onMount(() => {
    if (props.bootstrap.controlUrl && props.bootstrap.token) {
      void connectToRuntime(props.bootstrap.controlUrl, props.bootstrap.token);
    }
  });
  onCleanup(() => operator.dispose());

  async function connectToRuntime(controlUrl = endpoint(), bearer = token()): Promise<void> {
    setConfigError(null);
    try {
      const client = createLocalAgentControlClient({ baseUrl: controlUrl, token: bearer });
      setEndpoint(client.baseUrl);
      setToken("");
      setControlClient(client);
      await operator.connect(client);
      if (operator.connection() === "connected") operator.startPolling();
      else setControlClient(null);
    } catch (caught) {
      setToken("");
      setConfigError(caught instanceof LocalAgentControlClientError ? caught.message : "local control connection failed");
    }
  }

  async function launch(): Promise<void> {
    const decision = await operator.start(selectedToolId(), prompt());
    if (decision) {
      setPrompt("");
      showMobilePanel(selectedTool()?.mode === "pty" ? "terminal" : "detail");
    }
  }

  function disconnect(): void {
    operator.disconnect();
    setControlClient(null);
    setPrompt("");
    setConfigError(null);
  }

  function showMobilePanel(panel: OperatorMobilePanel): void {
    setMobilePanel(panel);
    if (panel !== "terminal" || !window.matchMedia("(max-width: 720px)").matches) return;
    requestAnimationFrame(() => {
      if (!terminalSection) return;
      const rootTop = operatorRoot.getBoundingClientRect().top;
      const terminalTop = terminalSection.getBoundingClientRect().top;
      operatorRoot.scrollTop += terminalTop - rootTop - 8;
    });
  }

  return (
    <section ref={operatorRoot} class="local-operator" aria-label="Local agent control">
      <header class="operator-head">
        <div class="operator-title">
          <span classList={{ "operator-status-dot": true, connected: connected() }} />
          <div>
            <h3>Local runtime</h3>
            <span>{operator.connection()}</span>
          </div>
        </div>
        <Show when={connected()}>
          <div class="operator-head-actions">
            <button
              type="button"
              class="operator-icon-button"
              title="Refresh local sessions"
              aria-label="Refresh local sessions"
              disabled={operator.refreshing()}
              onClick={() => void operator.refresh()}
            >
              <RefreshCw size={15} classList={{ spinning: operator.refreshing() }} />
            </button>
            <button
              type="button"
              class="operator-icon-button"
              title="Disconnect local runtime"
              aria-label="Disconnect local runtime"
              onClick={disconnect}
            >
              <Unplug size={15} />
            </button>
          </div>
        </Show>
      </header>

      <Show
        when={connected()}
        fallback={
          <form
            class="operator-connect"
            onSubmit={(event) => {
              event.preventDefault();
              void connectToRuntime();
            }}
          >
            <label>
              <span>Endpoint</span>
              <input
                type="url"
                inputmode="url"
                autocomplete="url"
                placeholder="http://127.0.0.1:4500"
                value={endpoint()}
                onInput={(event) => setEndpoint(event.currentTarget.value)}
                required
              />
            </label>
            <label>
              <span>Token</span>
              <input
                type="password"
                autocomplete="off"
                value={token()}
                onInput={(event) => setToken(event.currentTarget.value)}
                required
              />
            </label>
            <button type="submit" class="operator-command-button" disabled={!endpoint() || !token() || operator.refreshing()}>
              <Plug size={15} />
              Connect
            </button>
            <Show when={operator.refreshing()}>
              <span class="operator-inline-state">Connecting</span>
            </Show>
            <Show when={configError() ?? operator.error()?.message}>
              {(message) => <span class="operator-inline-state fail">{message()}</span>}
            </Show>
          </form>
        }
      >
        <div class="operator-health">
          <Metric label="runtime" value="loopback" tone="ok" />
          <Metric label="active" value={String(operator.health()?.activeSessions ?? 0)} />
          <Metric label="sessions" value={String(operator.sessions().length)} />
          <Metric label="persistence" value={operator.health()?.persistence ?? "unknown"} tone={operator.health()?.persistence === "durable" ? "ok" : undefined} />
        </div>

        <Show when={operator.error()}>
          {(failure) => (
            <div class="operator-policy-state fail">
              <CircleAlert size={15} />
              <span>{failure().message}</span>
            </div>
          )}
        </Show>

        <div class="operator-mobile-tabs" role="tablist" aria-label="Local operator view">
          <For each={mobileTabs()}>
            {([id, label]) => (
              <button
                type="button"
                role="tab"
                aria-selected={mobilePanel() === id}
                classList={{ active: mobilePanel() === id }}
                onClick={() => showMobilePanel(id)}
              >
                {label}
              </button>
            )}
          </For>
        </div>

        <div class="operator-workspace">
          <section classList={{ "operator-launch": true, "mobile-active": mobilePanel() === "launch" }} aria-label="Launch approved tool">
            <div class="operator-section-head">
              <ShieldCheck size={15} />
              <h4>Approved tools</h4>
              <span>{operator.tools().length}</span>
            </div>
            <Show when={operator.tools().length > 0} fallback={<EmptyState label="No approved tools" compact />}>
              <label class="operator-field">
                <span>Tool</span>
                <select value={selectedToolId()} onChange={(event) => setSelectedToolId(event.currentTarget.value)}>
                  <For each={operator.tools()}>
                    {(tool) => <option value={tool.id}>{tool.label}</option>}
                  </For>
                </select>
              </label>
              <Show when={selectedTool()?.description}>
                <p class="operator-tool-description">{selectedTool()?.description}</p>
              </Show>
              <Show when={selectedTool()?.input}>
                {(input) => (
                  <label class="operator-field operator-prompt">
                    <span>{input().label}</span>
                    <textarea
                      rows="4"
                      maxlength={input().maxLength}
                      placeholder={input().placeholder}
                      value={prompt()}
                      onInput={(event) => setPrompt(event.currentTarget.value)}
                      required={input().required}
                    />
                    <small>{prompt().length} / {input().maxLength}</small>
                  </label>
                )}
              </Show>
              <button
                type="button"
                class="operator-command-button primary"
                disabled={operator.pending() !== null || !selectedToolId() || (selectedTool()?.input?.required === true && !prompt().trim())}
                onClick={() => void launch()}
              >
                <Play size={15} fill="currentColor" />
                Launch
              </button>
            </Show>
          </section>

          <section classList={{ "operator-sessions": true, "mobile-active": mobilePanel() === "sessions" }} aria-label="Local session history">
            <div class="operator-section-head">
              <Database size={15} />
              <h4>Session history</h4>
              <span>{operator.sessions().length}</span>
            </div>
            <div class="operator-session-list">
              <For each={operator.sessions()} fallback={<EmptyState label="No local sessions" compact />}>
                {(item) => (
                  <button
                    type="button"
                    classList={{ "operator-session-row": true, selected: operator.selectedSessionId() === item.id }}
                    aria-pressed={operator.selectedSessionId() === item.id}
                    onClick={() => {
                      showMobilePanel("detail");
                      void operator.selectSession(item.id);
                    }}
                  >
                    <span class="operator-session-agent">{item.agentLabel}</span>
                    <span class="operator-session-task">{item.task ?? item.id}</span>
                    <Badge value={item.status} />
                    <time datetime={new Date(item.updatedAt).toISOString()}>{formatTimestamp(item.updatedAt)}</time>
                  </button>
                )}
              </For>
            </div>
          </section>

          <section classList={{ "operator-detail": true, "mobile-active": mobilePanel() === "detail" }} aria-label="Selected session detail">
            <div class="operator-section-head">
              <h4>Session detail</h4>
              <Show when={operator.selectedSession()}>{(item) => <Badge value={item().status} />}</Show>
            </div>
            <Show when={operator.selectedSession()} fallback={<EmptyState label="Select a local session" compact />}>
              {(item) => (
                <>
                  <div class="operator-detail-title">
                    <div>
                      <strong>{item().agentLabel}</strong>
                      <span>{item().task ?? item().id}</span>
                    </div>
                    <Show when={isActive(item())}>
                      <button
                        type="button"
                        class="operator-icon-button stop"
                        title="Stop local session"
                        aria-label="Stop local session"
                        disabled={operator.pending() !== null}
                        onClick={() => void operator.stop(item().id)}
                      >
                        <Square size={14} fill="currentColor" />
                      </button>
                    </Show>
                  </div>
                  <Show when={item().interrupted}>
                    <div class="operator-policy-state warning">
                      <CircleAlert size={15} />
                      <span>{isRecoveryInterruption(item()) ? "Recovery interruption" : "Interrupted"}</span>
                    </div>
                  </Show>
                  <div class="operator-detail-metrics">
                    <Metric label="turns" value={String(item().turns)} />
                    <Metric label="events" value={String(item().postedEvents)} />
                    <Metric label="lines" value={String(item().lines)} />
                    <Metric label="ignored" value={String(item().ignored)} />
                    <Metric label="sequence" value={String(item().lastSequence)} />
                    <Metric label="exit" value={item().exitCode === null ? "-" : String(item().exitCode)} />
                  </div>
                  <dl class="operator-detail-list">
                    <dt>session</dt><dd>{item().id}</dd>
                    <dt>started</dt><dd>{formatTimestamp(item().startedAt)}</dd>
                    <dt>updated</dt><dd>{formatTimestamp(item().updatedAt)}</dd>
                    <dt>cwd</dt><dd>{item().cwd ?? "-"}</dd>
                  </dl>
                  <Show when={item().detail}>
                    {(detail) => <p class="operator-session-detail">{detail()}</p>}
                  </Show>
                </>
              )}
            </Show>
          </section>

          <Show keyed when={terminalSessionId()}>
            {(sessionId) => (
              <section ref={terminalSection} classList={{ "operator-terminal": true, "mobile-active": mobilePanel() === "terminal" }} aria-label="Selected interactive terminal">
                <LocalAgentTerminalPanel client={controlClient()!} sessionId={sessionId} />
              </section>
            )}
          </Show>
        </div>

        <Show when={latestReceipt()}>
          {(receipt) => (
            <div classList={{ "operator-policy-state": true, accepted: receipt().outcome === "accepted", fail: receipt().outcome === "rejected" }}>
              <ShieldCheck size={15} />
              <strong>{receipt().action} {receipt().outcome}</strong>
              <span>{receipt().detail}</span>
              <time datetime={new Date(receipt().timestamp).toISOString()}>{formatTimestamp(receipt().timestamp)}</time>
            </div>
          )}
        </Show>
      </Show>
    </section>
  );
}

function isActive(session: LocalAgentControlSession): boolean {
  return session.status === "starting" || session.status === "running";
}

function isRecoveryInterruption(session: LocalAgentControlSession): boolean {
  return session.interrupted && session.detail?.includes("registry recovery") === true;
}

function formatTimestamp(timestamp: number): string {
  return new Intl.DateTimeFormat(undefined, {
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  }).format(new Date(timestamp));
}
