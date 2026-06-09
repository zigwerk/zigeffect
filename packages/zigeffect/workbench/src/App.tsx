import { For, Match, Show, Switch, createMemo, createResource, createSignal } from "solid-js";
import {
  type CausalEvent,
  type QueryCommand,
  deriveWorkbenchModel,
  filterEvents,
  parseArtifactJson,
  queryCommandsForEvent,
} from "./causalArtifact";
import { loadPayload, type WorkbenchSession } from "./workbenchBridge";

type Tab = "timeline" | "findings" | "graph" | "queries" | "metadata";

const tabs: Array<{ id: Tab; label: string }> = [
  { id: "timeline", label: "Timeline" },
  { id: "findings", label: "Findings" },
  { id: "graph", label: "Graph" },
  { id: "queries", label: "Queries" },
  { id: "metadata", label: "Metadata" },
];

export function App() {
  const [payload] = createResource(loadPayload);
  const [activeTab, setActiveTab] = createSignal<Tab>("timeline");
  const [selectedId, setSelectedId] = createSignal<string | null>(null);
  const [search, setSearch] = createSignal("");
  const [kind, setKind] = createSignal("all");
  const [status, setStatus] = createSignal("all");
  const [copiedCommand, setCopiedCommand] = createSignal<string | null>(null);

  const parsed = createMemo(() => {
    const loaded = payload();
    if (!loaded) {
      return null;
    }

    try {
      return {
        model: deriveWorkbenchModel(parseArtifactJson(loaded.artifactJson), {
          artifactPath: loaded.session?.artifact_path ?? "sample-artifact.json",
        }),
        session: loaded.session,
        error: null,
      };
    } catch (error) {
      return {
        model: null,
        session: loaded.session,
        error: error instanceof Error ? error.message : "failed to parse artifact",
      };
    }
  });

  const model = createMemo(() => parsed()?.model ?? null);
  const visibleEvents = createMemo(() => {
    const current = model();
    if (!current) {
      return [];
    }
    return filterEvents(current.events, {
      text: search(),
      kind: kind() === "all" ? undefined : kind(),
      status: status() === "all" ? undefined : status(),
    });
  });
  const selectedEvent = createMemo(() => {
    const events = model()?.events ?? [];
    const selected = selectedId();
    return events.find((event) => event.idText === selected) ?? visibleEvents()[0] ?? events[0] ?? null;
  });
  const selectedCommands = createMemo(() => {
    const current = model();
    const event = selectedEvent();
    if (!current || !event) {
      return [];
    }
    return queryCommandsForEvent(event, current.artifactPath);
  });

  async function copyCommand(command: string) {
    if (navigator.clipboard) {
      await navigator.clipboard.writeText(command);
      setCopiedCommand(command);
      window.setTimeout(() => setCopiedCommand(null), 1200);
    }
  }

  return (
    <main class="workbench-shell">
      <Show when={payload.loading}>
        <div class="loading-state">Loading causal artifact</div>
      </Show>

      <Show when={parsed()?.error}>
        <div class="error-state">{parsed()?.error}</div>
      </Show>

      <Show when={model()}>
        {(current) => (
          <>
            <header class="topbar">
              <div class="title-block">
                <span class="eyebrow">zigeffect causal workbench</span>
                <h1>{current().artifactPath}</h1>
              </div>
              <div class="metric-strip">
                <Metric label="schema" value={current().schema} />
                <Metric label="schema version" value={current().schemaVersion} />
                <Metric label="taxonomy" value={current().taxonomyVersion} />
                <Metric label="events" value={String(current().events.length)} />
                <Metric label="findings" value={String(current().findings.length)} tone={current().findings.length ? "warn" : "ok"} />
                <Metric label="mode" value="read-only" tone="ok" />
              </div>
            </header>

            <section class="layout-grid">
              <aside class="left-rail">
                <nav class="tab-list" aria-label="Workbench views">
                  <For each={tabs}>
                    {(tab) => (
                      <button
                        type="button"
                        classList={{ active: activeTab() === tab.id }}
                        onClick={() => setActiveTab(tab.id)}
                      >
                        {tab.label}
                      </button>
                    )}
                  </For>
                </nav>

                <label class="filter-control">
                  <span>Search</span>
                  <input
                    value={search()}
                    onInput={(event) => setSearch(event.currentTarget.value)}
                    placeholder="event, kind, label"
                  />
                </label>

                <label class="filter-control">
                  <span>Kind</span>
                  <select value={kind()} onChange={(event) => setKind(event.currentTarget.value)}>
                    <option value="all">All kinds</option>
                    <For each={current().kinds}>
                      {(value) => <option value={value}>{value}</option>}
                    </For>
                  </select>
                </label>

                <label class="filter-control">
                  <span>Status</span>
                  <select value={status()} onChange={(event) => setStatus(event.currentTarget.value)}>
                    <option value="all">All statuses</option>
                    <For each={current().statuses}>
                      {(value) => <option value={value}>{value}</option>}
                    </For>
                  </select>
                </label>

                <div class="safety-panel">
                  <span>read-only local artifact viewer</span>
                  <span>no source edits</span>
                  <span>no registry edits</span>
                  <span>no policy decisions</span>
                </div>
              </aside>

              <section class="main-pane">
                <Switch>
                  <Match when={activeTab() === "timeline"}>
                    <Timeline events={visibleEvents()} selected={selectedEvent()} onSelect={setSelectedId} />
                  </Match>
                  <Match when={activeTab() === "findings"}>
                    <Findings events={current().events} findings={current().findings} onSelect={setSelectedId} />
                  </Match>
                  <Match when={activeTab() === "graph"}>
                    <Graph events={current().events} onSelect={setSelectedId} />
                  </Match>
                  <Match when={activeTab() === "queries"}>
                    <Queries
                      artifactPath={current().artifactPath}
                      selected={selectedEvent()}
                      commands={selectedCommands()}
                      copiedCommand={copiedCommand()}
                      onCopy={copyCommand}
                    />
                  </Match>
                  <Match when={activeTab() === "metadata"}>
                    <Metadata model={current()} session={parsed()?.session ?? null} />
                  </Match>
                </Switch>
              </section>

              <aside class="inspector">
                <Inspector
                  event={selectedEvent()}
                  commands={selectedCommands()}
                  copiedCommand={copiedCommand()}
                  onCopy={copyCommand}
                />
              </aside>
            </section>
          </>
        )}
      </Show>
    </main>
  );
}

function Metric(props: { label: string; value: string; tone?: "ok" | "warn" }) {
  return (
    <div classList={{ metric: true, ok: props.tone === "ok", warn: props.tone === "warn" }}>
      <span>{props.label}</span>
      <strong>{props.value}</strong>
    </div>
  );
}

function Timeline(props: {
  events: CausalEvent[];
  selected: CausalEvent | null;
  onSelect: (id: string) => void;
}) {
  return (
    <div class="view-stack">
      <div class="view-heading">
        <h2>Timeline</h2>
        <span>{props.events.length} events</span>
      </div>
      <div class="event-list">
        <For each={props.events} fallback={<EmptyState label="No events match" />}>
          {(event) => (
            <button
              type="button"
              classList={{ "event-row": true, selected: props.selected?.idText === event.idText }}
              onClick={() => props.onSelect(event.idText)}
            >
              <span class="event-id">#{event.idText}</span>
              <span class="event-main">
                <strong>{event.kind}</strong>
                <span>{event.label || event.typeName || "unlabeled"}</span>
              </span>
              <Badge value={event.status} />
              <SmallMeta event={event} />
            </button>
          )}
        </For>
      </div>
    </div>
  );
}

function Findings(props: {
  events: CausalEvent[];
  findings: ReturnType<typeof deriveWorkbenchModel>["findings"];
  onSelect: (id: string) => void;
}) {
  return (
    <div class="view-stack">
      <div class="view-heading">
        <h2>Findings</h2>
        <span>{props.findings.length} active</span>
      </div>
      <div class="finding-list">
        <For each={props.findings} fallback={<EmptyState label="No findings" />}>
          {(finding) => (
            <button type="button" class="finding-row" onClick={() => props.onSelect(finding.eventId)}>
              <span>{finding.kind}</span>
              <strong>{finding.title}</strong>
              <p>{finding.summary}</p>
              <small>event #{finding.eventId}</small>
            </button>
          )}
        </For>
      </div>
    </div>
  );
}

function Graph(props: { events: CausalEvent[]; onSelect: (id: string) => void }) {
  const scopes = createMemo(() => groupedValues(props.events, "scopeId"));
  const fibers = createMemo(() => groupedValues(props.events, "fiberId"));

  return (
    <div class="view-stack">
      <div class="view-heading">
        <h2>Graph</h2>
        <span>{props.events.length} linked events</span>
      </div>
      <div class="graph-grid">
        <div class="relationship-list">
          <h3>Parent chain</h3>
          <For each={props.events}>
            {(event) => (
              <button type="button" class="relationship-row" onClick={() => props.onSelect(event.idText)}>
                <span>#{event.parentId ?? "root"} -&gt; #{event.idText}</span>
                <strong>{event.kind}</strong>
              </button>
            )}
          </For>
        </div>
        <GroupList title="Scopes" groups={scopes()} onSelect={props.onSelect} />
        <GroupList title="Fibers" groups={fibers()} onSelect={props.onSelect} />
      </div>
    </div>
  );
}

function GroupList(props: {
  title: string;
  groups: Array<{ key: string; events: CausalEvent[] }>;
  onSelect: (id: string) => void;
}) {
  return (
    <div class="relationship-list">
      <h3>{props.title}</h3>
      <For each={props.groups} fallback={<EmptyState label="No grouped events" compact />}>
        {(group) => (
          <div class="group-block">
            <strong>{group.key}</strong>
            <For each={group.events}>
              {(event) => (
                <button type="button" onClick={() => props.onSelect(event.idText)}>
                  #{event.idText} {event.kind}
                </button>
              )}
            </For>
          </div>
        )}
      </For>
    </div>
  );
}

function Queries(props: {
  artifactPath: string;
  selected: CausalEvent | null;
  commands: QueryCommand[];
  copiedCommand: string | null;
  onCopy: (command: string) => void;
}) {
  const snapshot = `zig build causal-query -- --file ${props.artifactPath} snapshot`;
  const commands = createMemo<QueryCommand[]>(() => [
    { label: "Snapshot", command: snapshot },
    ...props.commands,
  ]);

  return (
    <div class="view-stack">
      <div class="view-heading">
        <h2>Queries</h2>
        <span>{props.selected ? `event #${props.selected.idText}` : "artifact"}</span>
      </div>
      <CommandList commands={commands()} copiedCommand={props.copiedCommand} onCopy={props.onCopy} />
    </div>
  );
}

function Metadata(props: { model: ReturnType<typeof deriveWorkbenchModel>; session: WorkbenchSession | null }) {
  const sessionWarnings = () => props.session?.warnings ?? [];

  return (
    <div class="view-stack">
      <div class="view-heading">
        <h2>Metadata</h2>
        <span>{props.model.safeToShare}</span>
      </div>
      <dl class="metadata-grid">
        <Meta label="artifact" value={props.model.artifactPath} />
        <Meta label="schema" value={props.model.schema} />
        <Meta label="schema version" value={props.model.schemaVersion} />
        <Meta label="taxonomy version" value={props.model.taxonomyVersion} />
        <Meta label="events" value={String(props.model.events.length)} />
        <Meta label="findings" value={String(props.model.findings.length)} />
        <Meta label="read only" value={String(props.session?.read_only ?? true)} />
        <Meta label="bytes" value={String(props.session?.artifact_bytes ?? "unknown")} />
      </dl>
      <div class="warning-list">
        <For each={[...props.model.warnings, ...sessionWarnings()]} fallback={<EmptyState label="No metadata warnings" compact />}>
          {(warning) => <span>{warning}</span>}
        </For>
      </div>
    </div>
  );
}

function Inspector(props: {
  event: CausalEvent | null;
  commands: QueryCommand[];
  copiedCommand: string | null;
  onCopy: (command: string) => void;
}) {
  return (
    <Show when={props.event} fallback={<EmptyState label="No event selected" />}>
      {(event) => (
        <div class="inspector-stack">
          <div>
            <span class="eyebrow">event #{event().idText}</span>
            <h2>{event().kind}</h2>
          </div>
          <Badge value={event().status} />
          <dl class="inspector-grid">
            <Meta label="label" value={event().label || "unlabeled"} />
            <Meta label="type" value={event().typeName || "unknown"} />
            <Meta label="run" value={event().runId ?? "none"} />
            <Meta label="scope" value={event().scopeId ?? "none"} />
            <Meta label="fiber" value={event().fiberId ?? "none"} />
            <Meta label="parent" value={event().parentId ?? "none"} />
          </dl>
          <div class="detail-block">
            <span>redacted detail</span>
            <p>{event().redactedDetail || "empty"}</p>
          </div>
          <CommandList commands={props.commands} copiedCommand={props.copiedCommand} onCopy={props.onCopy} compact />
        </div>
      )}
    </Show>
  );
}

function CommandList(props: {
  commands: QueryCommand[];
  copiedCommand: string | null;
  onCopy: (command: string) => void;
  compact?: boolean;
}) {
  return (
    <div classList={{ "command-list": true, compact: props.compact }}>
      <For each={props.commands}>
        {(item) => (
          <div class="command-row">
            <span>{item.label}</span>
            <code>{item.command}</code>
            <button type="button" onClick={() => props.onCopy(item.command)}>
              {props.copiedCommand === item.command ? "Copied" : "Copy"}
            </button>
          </div>
        )}
      </For>
    </div>
  );
}

function SmallMeta(props: { event: CausalEvent }) {
  return (
    <span class="small-meta">
      <span>run {props.event.runId ?? "-"}</span>
      <span>scope {props.event.scopeId ?? "-"}</span>
      <span>fiber {props.event.fiberId ?? "-"}</span>
    </span>
  );
}

function Badge(props: { value: string }) {
  return <span class={`badge status-${props.value.replaceAll("_", "-")}`}>{props.value}</span>;
}

function Meta(props: { label: string; value: string }) {
  return (
    <>
      <dt>{props.label}</dt>
      <dd>{props.value}</dd>
    </>
  );
}

function EmptyState(props: { label: string; compact?: boolean }) {
  return <div classList={{ "empty-state": true, compact: props.compact }}>{props.label}</div>;
}

function groupedValues(events: CausalEvent[], key: "scopeId" | "fiberId") {
  const groups = new Map<string, CausalEvent[]>();
  for (const event of events) {
    const value = event[key];
    if (!value) {
      continue;
    }
    const existing = groups.get(value) ?? [];
    existing.push(event);
    groups.set(value, existing);
  }
  return Array.from(groups, ([groupKey, groupEvents]) => ({
    key: groupKey,
    events: groupEvents,
  }));
}
