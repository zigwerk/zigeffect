import { For, Match, Show, Switch, createMemo, createResource, createSignal } from "solid-js";
import {
  type CausalEvent,
  type AppCitationGroup,
  type AppGateResultModel,
  type AppIncidentModel,
  type AppReadinessCheckModel,
  type AppRemediationModel,
  type GraphEdge,
  type GraphLane,
  type GraphLaneKind,
  type GovernanceModel,
  type QueryCommand,
  type RemediationChainModel,
  type ChainSourceStep,
  causePathForEvent,
  deriveGovernanceModel,
  deriveGraphModel,
  deriveWorkbenchModel,
  filterEvents,
  parseArtifactJson,
  queryCommandsForEvent,
} from "./causalArtifact";
import { loadPayload, type WorkbenchSession } from "./workbenchBridge";

type Tab = "timeline" | "findings" | "graph" | "chain" | "queries" | "metadata";

const tabs: Array<{ id: Tab; label: string }> = [
  { id: "timeline", label: "Timeline" },
  { id: "findings", label: "Findings" },
  { id: "graph", label: "Graph" },
  { id: "chain", label: "Chain" },
  { id: "queries", label: "Queries" },
  { id: "metadata", label: "Metadata" },
];

const laneKinds: GraphLaneKind[] = ["run", "scope", "fiber", "resource", "retry"];

const laneLabels: Record<GraphLaneKind, string> = {
  run: "Runs",
  scope: "Scopes",
  fiber: "Fibers",
  resource: "Resources",
  retry: "Retries",
};

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
      const artifactPath = loaded.session?.artifact_path ?? "sample-artifact.json";
      const raw = parseArtifactJson(loaded.artifactJson);
      return {
        model: deriveWorkbenchModel(raw, { artifactPath }),
        governance: deriveGovernanceModel(raw, { artifactPath }),
        session: loaded.session,
        error: null,
      };
    } catch (error) {
      return {
        model: null,
        governance: null,
        session: loaded.session,
        error: error instanceof Error ? error.message : "failed to parse artifact",
      };
    }
  });

  const model = createMemo(() => parsed()?.model ?? null);
  const governance = createMemo(() => parsed()?.governance ?? null);
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
                    <Graph
                      events={current().events}
                      findings={current().findings}
                      selected={selectedEvent()}
                      onSelect={setSelectedId}
                    />
                  </Match>
                  <Match when={activeTab() === "chain"}>
                    <ChainView
                      governance={governance()}
                      events={current().events}
                      copiedCommand={copiedCommand()}
                      onCopy={copyCommand}
                      onSelectEvent={setSelectedId}
                    />
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

function ChainView(props: {
  governance: GovernanceModel | null;
  events: CausalEvent[];
  copiedCommand: string | null;
  onCopy: (command: string) => void;
  onSelectEvent: (id: string) => void;
}) {
  return (
    <div class="view-stack">
      <div class="view-heading">
        <h2>Chain</h2>
        <span>{props.governance?.kind ?? "no governance artifact"}</span>
      </div>

      <Show when={props.governance} fallback={<EmptyState label="Loaded artifact has no remediation chain" />}>
        {(governance) => (
          <Show
            when={governance().app}
            fallback={(
              <Show when={governance().chain} fallback={<GovernanceSummary governance={governance()} />}>
                {(chain) => (
                  <>
                    <ChainStatus chain={chain()} />
                    <div class="chain-grid">
                      <ChainSources
                        steps={chain().sourceSteps}
                        copiedCommand={props.copiedCommand}
                        onCopy={props.onCopy}
                      />
                      <ChainVerification
                        chain={chain()}
                        copiedCommand={props.copiedCommand}
                        onCopy={props.onCopy}
                      />
                    </div>
                    <ChainClassifications chain={chain()} />
                    <ChainGuardrails chain={chain()} />
                    <div class="warning-list">
                      <For each={[...governance().warnings, ...chain().warnings]} fallback={<EmptyState label="No chain warnings" compact />}>
                        {(warning) => <span>{warning}</span>}
                      </For>
                    </div>
                  </>
                )}
              </Show>
            )}
          >
            {(app) => (
              <AppRemediationView
                app={app()}
                events={props.events}
                copiedCommand={props.copiedCommand}
                onCopy={props.onCopy}
                onSelectEvent={props.onSelectEvent}
              />
            )}
          </Show>
        )}
      </Show>
    </div>
  );
}

function GovernanceSummary(props: { governance: GovernanceModel }) {
  return (
    <>
      <div class="chain-status">
        <Metric label="schema" value={props.governance.schema} />
        <Metric label="kind" value={props.governance.kind} />
        <Metric label="target" value={props.governance.target} />
        <Metric label="applied" value={String(props.governance.applied ?? "unknown")} />
        <Metric label="authority" value={props.governance.mutationAuthority ?? "none"} tone="ok" />
      </div>
      <div class="chain-panel">
        <h3>{props.governance.summary}</h3>
        <EmptyState label="This governance artifact has no audit-chain source graph" compact />
      </div>
    </>
  );
}

function ChainStatus(props: { chain: RemediationChainModel }) {
  return (
    <div class="chain-status">
      <Metric label="target" value={props.chain.target} />
      <Metric label="assessment" value={props.chain.assessment} tone={props.chain.assessment === "regressed" ? "warn" : "ok"} />
      <Metric label="approval" value={props.chain.approvalStatus} />
      <Metric label="applied" value={String(props.chain.applied ?? "unknown")} tone={props.chain.applied ? "warn" : "ok"} />
      <Metric label="delta" value={props.chain.findingDelta} />
    </div>
  );
}

function ChainSources(props: {
  steps: ChainSourceStep[];
  copiedCommand: string | null;
  onCopy: (command: string) => void;
}) {
  return (
    <section class="chain-panel">
      <h3>Source artifacts</h3>
      <div class="chain-source-list">
        <For each={props.steps} fallback={<EmptyState label="No source artifact paths" compact />}>
          {(step) => (
            <ChainSourceRow
              step={step}
              copiedCommand={props.copiedCommand}
              onCopy={props.onCopy}
            />
          )}
        </For>
      </div>
    </section>
  );
}

function ChainSourceRow(props: {
  step: ChainSourceStep;
  copiedCommand: string | null;
  onCopy: (command: string) => void;
}) {
  return (
    <div class="chain-source-row">
      <span>{props.step.label}</span>
      <code>{props.step.path}</code>
      <Show when={props.step.workbenchCommand} fallback={<small>text artifact</small>}>
        {(command) => (
          <button type="button" onClick={() => props.onCopy(command())}>
            {props.copiedCommand === command() ? "Copied" : "Copy"}
          </button>
        )}
      </Show>
    </div>
  );
}

function ChainVerification(props: {
  chain: RemediationChainModel;
  copiedCommand: string | null;
  onCopy: (command: string) => void;
}) {
  const commands = createMemo<QueryCommand[]>(() => props.chain.verificationCommands.map((command, index) => ({
    label: `verify ${index + 1}`,
    command,
  })));

  return (
    <section class="chain-panel">
      <h3>Verification</h3>
      <CommandList
        commands={commands()}
        copiedCommand={props.copiedCommand}
        onCopy={props.onCopy}
        compact
      />
    </section>
  );
}

function ChainClassifications(props: { chain: RemediationChainModel }) {
  const groups = createMemo(() => [
    { label: "disappeared", ids: props.chain.classifications.disappeared },
    { label: "persisting", ids: props.chain.classifications.persisting },
    { label: "appeared", ids: props.chain.classifications.appeared },
    { label: "missing", ids: props.chain.classifications.missing },
  ]);

  return (
    <section class="chain-panel">
      <div class="lane-section-head">
        <h3>Event classification</h3>
        <span>{props.chain.classifications.eventIds.length} cited ids</span>
      </div>
      <div class="chain-classification-grid">
        <For each={groups()}>
          {(group) => (
            <div class="chain-id-list">
              <span>{group.label}</span>
              <For each={group.ids} fallback={<small>none</small>}>
                {(id) => <strong>#{id}</strong>}
              </For>
            </div>
          )}
        </For>
      </div>
    </section>
  );
}

function ChainGuardrails(props: { chain: RemediationChainModel }) {
  return (
    <section class="chain-panel">
      <h3>Guardrails</h3>
      <div class="guardrail-list">
        <For each={props.chain.guardrails} fallback={<EmptyState label="No guardrails recorded" compact />}>
          {(guardrail) => <span>{guardrail}</span>}
        </For>
      </div>
    </section>
  );
}

function AppRemediationView(props: {
  app: AppRemediationModel;
  events: CausalEvent[];
  copiedCommand: string | null;
  onCopy: (command: string) => void;
  onSelectEvent: (id: string) => void;
}) {
  return (
    <>
      <AppRemediationStatus app={props.app} />
      <div class="app-remediation-grid">
        <ChainSources
          steps={props.app.sourceSteps}
          copiedCommand={props.copiedCommand}
          onCopy={props.onCopy}
        />
        <AppPolicyGates gates={props.app.policyGates} results={props.app.gateResults} />
      </div>
      <AppIncidents
        incidents={props.app.incidents}
        events={props.events}
        copiedCommand={props.copiedCommand}
        onCopy={props.onCopy}
        onSelectEvent={props.onSelectEvent}
      />
      <div class="app-remediation-grid">
        <AppCitations citations={props.app.citations} />
        <AppVerification
          commands={props.app.verificationCommands}
          copiedCommand={props.copiedCommand}
          onCopy={props.onCopy}
        />
      </div>
      <Show when={props.app.checks.length || props.app.applicationSteps.length}>
        <div class="app-remediation-grid">
          <AppReadinessChecks checks={props.app.checks} />
          <AppApplicationSteps steps={props.app.applicationSteps} />
        </div>
      </Show>
      <AppGuardrails guardrails={props.app.guardrails} />
      <div class="warning-list">
        <For each={props.app.warnings} fallback={<EmptyState label="No app remediation warnings" compact />}>
          {(warning) => <span>{warning}</span>}
        </For>
      </div>
    </>
  );
}

function AppRemediationStatus(props: { app: AppRemediationModel }) {
  const posture = props.app.kind === "app-application-readiness"
    ? props.app.readinessStatus
    : props.app.kind === "app-patch-proposal"
      ? props.app.proposalStatus
      : props.app.decision;
  return (
    <div class="chain-status app-status">
      <Metric label="target" value={props.app.target} />
      <Metric label="kind" value={props.app.kind} />
      <Metric label="posture" value={posture === "unknown" ? props.app.approvalStatus : posture} />
      <Show when={props.app.readyForApplication !== null}>
        <Metric label="ready" value={String(props.app.readyForApplication)} tone={props.app.readyForApplication ? "ok" : "warn"} />
      </Show>
      <Metric label="approval" value={props.app.approvalStatus} />
      <Metric label="applied" value={String(props.app.applied ?? "unknown")} tone={props.app.applied ? "warn" : "ok"} />
      <Metric label="authority" value={props.app.mutationAuthority ?? "none"} tone={props.app.mutationAuthority === "none" ? "ok" : "warn"} />
    </div>
  );
}

function AppPolicyGates(props: { gates: string[]; results: AppGateResultModel[] }) {
  return (
    <section class="chain-panel">
      <div class="lane-section-head">
        <h3>Policy gates</h3>
        <span>{props.gates.length || props.results.length}</span>
      </div>
      <div class="gate-chip-list">
        <For each={props.gates} fallback={<EmptyState label="No policy gates" compact />}>
          {(gate) => <span class={`gate-chip ${gateToneClass(gate)}`}>{gate}</span>}
        </For>
      </div>
      <div class="gate-result-list">
        <For each={props.results} fallback={<EmptyState label="No gate result details" compact />}>
          {(result) => (
            <div class="gate-result-row">
              <span class={`gate-chip ${gateToneClass(result.status || result.gate)}`}>{result.status}</span>
              <strong>{result.gate}</strong>
              <p>{result.detail || "No detail recorded"}</p>
            </div>
          )}
        </For>
      </div>
    </section>
  );
}

function AppIncidents(props: {
  incidents: AppIncidentModel[];
  events: CausalEvent[];
  copiedCommand: string | null;
  onCopy: (command: string) => void;
  onSelectEvent: (id: string) => void;
}) {
  const eventIds = createMemo(() => new Set(props.events.map((event) => event.idText)));

  return (
    <section class="chain-panel app-remediation-full">
      <div class="lane-section-head">
        <h3>App incidents</h3>
        <span>{props.incidents.length}</span>
      </div>
      <div class="app-incident-list">
        <For each={props.incidents} fallback={<EmptyState label="No app incidents recorded" compact />}>
          {(incident) => (
            <div class="app-incident-row">
              <Show
                when={eventIds().has(incident.eventId)}
                fallback={<span class="app-event-chip">#{incident.eventId}</span>}
              >
                <button type="button" class="app-event-button" onClick={() => props.onSelectEvent(incident.eventId)}>
                  #{incident.eventId}
                </button>
              </Show>
              <div>
                <strong>{incident.action}</strong>
                <span>{incident.label}</span>
              </div>
              <span class={`gate-chip ${gateToneClass(incident.policyGate)}`}>{incident.policyGate}</span>
              <small>{incident.subsystem}</small>
              <small>{incident.fixCategory}</small>
              <CommandList
                commands={incident.queryCommands.map((command, index) => ({
                  label: `query ${index + 1}`,
                  command,
                }))}
                copiedCommand={props.copiedCommand}
                onCopy={props.onCopy}
                compact
              />
            </div>
          )}
        </For>
      </div>
    </section>
  );
}

function AppCitations(props: { citations: AppCitationGroup[] }) {
  return (
    <section class="chain-panel">
      <h3>Citations</h3>
      <div class="citation-grid">
        <For each={props.citations} fallback={<EmptyState label="No citation groups" compact />}>
          {(group) => (
            <div class="citation-group">
              <span>{group.label}</span>
              <For each={group.values} fallback={<small>none</small>}>
                {(value) => <code>{value}</code>}
              </For>
            </div>
          )}
        </For>
      </div>
    </section>
  );
}

function AppVerification(props: {
  commands: string[];
  copiedCommand: string | null;
  onCopy: (command: string) => void;
}) {
  const commands = createMemo<QueryCommand[]>(() => props.commands.map((command, index) => ({
    label: `verify ${index + 1}`,
    command,
  })));

  return (
    <section class="chain-panel">
      <h3>Verification</h3>
      <CommandList commands={commands()} copiedCommand={props.copiedCommand} onCopy={props.onCopy} compact />
    </section>
  );
}

function AppReadinessChecks(props: { checks: AppReadinessCheckModel[] }) {
  return (
    <section class="chain-panel">
      <div class="lane-section-head">
        <h3>Readiness checks</h3>
        <span>{props.checks.length}</span>
      </div>
      <div class="gate-result-list">
        <For each={props.checks} fallback={<EmptyState label="No readiness checks" compact />}>
          {(check) => (
            <div class="gate-result-row">
              <span class={`gate-chip ${gateToneClass(check.status)}`}>{check.status}</span>
              <strong>{check.name}</strong>
              <p>{check.detail || "No detail recorded"}</p>
            </div>
          )}
        </For>
      </div>
    </section>
  );
}

function AppApplicationSteps(props: { steps: string[] }) {
  return (
    <section class="chain-panel">
      <h3>Application steps</h3>
      <div class="guardrail-list">
        <For each={props.steps} fallback={<EmptyState label="No application steps recorded" compact />}>
          {(step) => <span>{step}</span>}
        </For>
      </div>
    </section>
  );
}

function AppGuardrails(props: { guardrails: string[] }) {
  return (
    <section class="chain-panel app-remediation-full">
      <h3>Guardrails</h3>
      <div class="guardrail-list">
        <For each={props.guardrails} fallback={<EmptyState label="No app guardrails recorded" compact />}>
          {(guardrail) => <span>{guardrail}</span>}
        </For>
      </div>
    </section>
  );
}

function gateToneClass(value: string): string {
  if (value.includes("block") || value.includes("reject") || value.includes("unknown")) {
    return "blocked";
  }
  if (value.includes("migration") || value.includes("operational") || value.includes("rollback") || value.includes("human")) {
    return "review";
  }
  return "allow";
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

function Graph(props: {
  events: CausalEvent[];
  findings: ReturnType<typeof deriveWorkbenchModel>["findings"];
  selected: CausalEvent | null;
  onSelect: (id: string) => void;
}) {
  const graph = createMemo(() => deriveGraphModel(props.events, props.findings));
  const causePath = createMemo(() => (
    props.selected ? causePathForEvent(props.events, props.selected.idText) : []
  ));
  const lanesByKind = createMemo(() => laneKinds.map((kind) => ({
    kind,
    label: laneLabels[kind],
    lanes: graph().lanes.filter((lane) => lane.kind === kind),
  })));

  return (
    <div class="view-stack">
      <div class="view-heading">
        <h2>Graph</h2>
        <span>{props.events.length} events</span>
      </div>

      <div class="graph-summary">
        <Metric label="roots" value={String(graph().roots.length)} />
        <Metric label="edges" value={String(graph().parentEdges.length)} />
        <Metric label="lanes" value={String(graph().lanes.length)} />
        <Metric
          label="unhealthy"
          value={String(graph().unhealthyLanes.length)}
          tone={graph().unhealthyLanes.length ? "warn" : "ok"}
        />
        <Metric label="orphans" value={String(graph().orphans.length)} tone={graph().orphans.length ? "warn" : "ok"} />
      </div>

      <CausePath path={causePath()} selected={props.selected} onSelect={props.onSelect} />

      <div class="lane-board">
        <For each={lanesByKind()}>
          {(group) => (
            <LaneSection
              label={group.label}
              lanes={group.lanes}
              selected={props.selected}
              onSelect={props.onSelect}
            />
          )}
        </For>
      </div>

      <div class="graph-grid">
        <EdgeList
          edges={graph().parentEdges}
          events={props.events}
          selected={props.selected}
          onSelect={props.onSelect}
        />
        <OrphanList events={graph().orphans} selected={props.selected} onSelect={props.onSelect} />
      </div>
    </div>
  );
}

function CausePath(props: {
  path: CausalEvent[];
  selected: CausalEvent | null;
  onSelect: (id: string) => void;
}) {
  return (
    <div class="cause-path">
      <div class="cause-path-heading">
        <h3>Cause path</h3>
        <span>{props.selected ? `selected #${props.selected.idText}` : "no selection"}</span>
      </div>
      <div class="cause-path-strip">
        <For each={props.path} fallback={<EmptyState label="No cause path" compact />}>
          {(event) => (
            <button
              type="button"
              classList={{ "cause-chip": true, selected: props.selected?.idText === event.idText }}
              onClick={() => props.onSelect(event.idText)}
            >
              <span>#{event.idText}</span>
              <strong>{event.kind}</strong>
            </button>
          )}
        </For>
      </div>
    </div>
  );
}

function LaneSection(props: {
  label: string;
  lanes: GraphLane[];
  selected: CausalEvent | null;
  onSelect: (id: string) => void;
}) {
  return (
    <section class="lane-section">
      <div class="lane-section-head">
        <h3>{props.label}</h3>
        <span>{props.lanes.length}</span>
      </div>
      <div class="lane-card-list">
        <For each={props.lanes} fallback={<EmptyState label="No lanes" compact />}>
          {(lane) => (
            <LaneCard lane={lane} selected={props.selected} onSelect={props.onSelect} />
          )}
        </For>
      </div>
    </section>
  );
}

function LaneCard(props: {
  lane: GraphLane;
  selected: CausalEvent | null;
  onSelect: (id: string) => void;
}) {
  return (
    <article classList={{
      "lane-card": true,
      failure: props.lane.status === "failure",
      warning: props.lane.status === "warning",
      ok: props.lane.status === "ok",
    }}>
      <div class="lane-card-head">
        <div>
          <span>{props.lane.status}</span>
          <strong>{props.lane.label}</strong>
        </div>
        <small>{props.lane.events.length} events</small>
      </div>
      <Show when={props.lane.findingEventIds.length > 0}>
        <span class="lane-finding-pill">{props.lane.findingEventIds.length} findings</span>
      </Show>
      <div class="lane-events">
        <For each={props.lane.events}>
          {(event) => (
            <button
              type="button"
              classList={{ selected: props.selected?.idText === event.idText }}
              onClick={() => props.onSelect(event.idText)}
            >
              <span>#{event.idText}</span>
              <strong>{event.kind}</strong>
              <small>{event.status}</small>
            </button>
          )}
        </For>
      </div>
    </article>
  );
}

function EdgeList(props: {
  edges: GraphEdge[];
  events: CausalEvent[];
  selected: CausalEvent | null;
  onSelect: (id: string) => void;
}) {
  const eventById = createMemo(() => new Map(props.events.map((event) => [event.idText, event])));

  return (
    <div class="relationship-list">
      <h3>Parent edges</h3>
      <For each={props.edges} fallback={<EmptyState label="No parent edges" compact />}>
        {(edge) => {
          const child = () => eventById().get(edge.to) ?? null;
          return (
            <button
              type="button"
              classList={{ "relationship-row": true, selected: props.selected?.idText === edge.to }}
              onClick={() => props.onSelect(edge.to)}
            >
              <span>#{edge.from} -&gt; #{edge.to}</span>
              <strong>{child()?.kind ?? "unknown"}</strong>
            </button>
          );
        }}
      </For>
    </div>
  );
}

function OrphanList(props: {
  events: CausalEvent[];
  selected: CausalEvent | null;
  onSelect: (id: string) => void;
}) {
  return (
    <div class="orphan-list">
      <h3>Orphans</h3>
      <For each={props.events} fallback={<EmptyState label="No orphaned events" compact />}>
        {(event) => (
          <button
            type="button"
            classList={{ "orphan-row": true, selected: props.selected?.idText === event.idText }}
            onClick={() => props.onSelect(event.idText)}
          >
            <span>missing parent #{event.parentId}</span>
            <strong>#{event.idText} {event.kind}</strong>
          </button>
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
