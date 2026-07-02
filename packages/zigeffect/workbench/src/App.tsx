import { For, Show, createEffect, createMemo, createResource, createSignal, onCleanup, onMount } from "solid-js";
import {
  type CausalEvent,
  type CausalFinding,
  type VisualGraphLayoutMode,
  type VisualGraphPerspective,
  causePathForEvent,
  deriveGovernanceModel,
  deriveGraphModel,
  deriveLocalDevHealthSummary,
  deriveLocalDevSessionModel,
  deriveSemanticDiffModel,
  deriveVisualGraphModel,
  deriveWorkbenchModel,
  filterEvents,
  parseArtifactJson,
  queryCommandsForEvent,
} from "./causalArtifact";
import { loadPayload, type WorkbenchSession } from "./workbenchBridge";
import { createLiveArtifact, liveUrlFromSearch, webSocketLiveSource } from "./liveAttach";
import { correlateEndpoint, createHubServices, hubUrlFromSearch, hubWebSocketSource } from "./liveServices";
import { parseCorrelation } from "./hub/protocol";
import { ServicesRail } from "./services/ServicesRail";
import { PinnedPanes } from "./services/PinnedPanes";
import { applyThemeToDocument, lens, setLens, theme, toggleLens, toggleTheme, type Lens } from "./theme";
import { deriveTraceModel, type TraceFindingMark, type TraceModel } from "./trace/traceModel";
import { agentHue } from "./primitives";
import { TopBar } from "./ui/TopBar";
import { Segmented } from "./ui/Segmented";
import { FindingsBand } from "./findings/FindingsBand";
import { TraceCanvas } from "./trace/TraceCanvas";
import { DagPanel } from "./graph/DagPanel";
import { CollabBoard } from "./collab/CollabBoard";
import { Inspector } from "./inspector/Inspector";
import { CommandPalette, type AuxView } from "./ui/CommandPalette";
import { AuxOverlay } from "./ui/AuxOverlay";
import { ChainView, DiffView, MetadataView, QueriesView } from "./aux/auxViews";

const auxTitles: Record<AuxView, string> = {
  diff: "Semantic diff",
  chain: "Governance chain",
  metadata: "Metadata",
  queries: "Query catalogue",
};

/** Stable description of the two lenses — the headline navigation axis. */
export function workbenchLensesForArtifact(): Array<{ id: Lens; label: string }> {
  return [
    { id: "execution", label: "Execution" },
    { id: "collaboration", label: "Collaboration" },
  ];
}

/** The auxiliary views the old tab bar dissolved into (reachable via ⌘K / More). */
export function workbenchAuxViews(): AuxView[] {
  return ["diff", "chain", "metadata", "queries"];
}

export function App() {
  const [payload] = createResource(loadPayload);
  const [selectedId, setSelectedId] = createSignal<string | null>(null);
  const [search, setSearch] = createSignal("");
  const [kind, setKind] = createSignal("all");
  const [status, setStatus] = createSignal("all");
  const [copiedCommand, setCopiedCommand] = createSignal<string | null>(null);
  const [layoutMode, setLayoutMode] = createSignal<VisualGraphLayoutMode>("dagre");
  const [graphPerspective, setGraphPerspective] = createSignal<VisualGraphPerspective>("cause");
  const [density, setDensity] = createSignal<"comfortable" | "compact">("comfortable");
  const [findingFocus, setFindingFocus] = createSignal<CausalFinding["kind"] | null>(null);
  const [paletteOpen, setPaletteOpen] = createSignal(false);
  const [auxView, setAuxView] = createSignal<AuxView | null>(null);

  createEffect(() => applyThemeToDocument(theme()));

  // Live-attach: `?live=<ws-url>` streams one engine's frames into the SAME model
  // every view renders. Absent `?live`, this is a no-op and the static snapshot path
  // is used.
  const locationSearch = typeof window === "undefined" ? "" : window.location.search;
  const liveUrl = liveUrlFromSearch(locationSearch);
  const live = liveUrl ? createLiveArtifact(webSocketLiveSource(liveUrl), { maxFrames: 1000 }) : null;
  const liveSession: WorkbenchSession = {
    schema: "zigeffect.causal.workbench-session.v1",
    artifact_path: "live-attach",
    read_only: true,
    warnings: ["live-attach stream"],
  };

  // Hub mode: `?hub=<ws-url>` fans in MANY services. The ServicesRail lists the live
  // roster; focusing a service feeds ITS accumulated artifact into the same pipeline.
  const hubUrl = hubUrlFromSearch(locationSearch);
  // maxFrames matches the hub's per-service retention (5000): a smaller client
  // cap would evict backfilled frames that boundary jump links still target.
  const hubServices = hubUrl ? createHubServices(hubWebSocketSource(hubUrl), { maxFrames: 5000 }) : null;
  const emptyArtifact = JSON.stringify({ schema: "zigeffect.causal.v1", schema_version: 1, event_taxonomy_version: 1, events: [] });

  // Every focus change goes through here: event ids restart per service, so a
  // selection carried across services would silently highlight an unrelated
  // event with the same number.
  const focusService = (serviceKey: string | null) => {
    if (!hubServices) {
      return;
    }
    if (hubServices.focused() !== serviceKey) {
      setSelectedId(null);
    }
    hubServices.focus(serviceKey);
  };

  // Auto-focus the first discovered service so a trace shows the moment one
  // connects — and re-home focus when the focused service leaves the roster
  // (hub GC), so the workspace never presents a dead service's trace as live.
  createEffect(() => {
    if (!hubServices) {
      return;
    }
    const roster = hubServices.services();
    const focus = hubServices.focused();
    const focusAlive = focus !== null && roster.some((service) => service.service_key === focus);
    if (!focusAlive) {
      const first = roster[0];
      focusService(first ? first.service_key : null);
    }
  });

  onMount(() => {
    const onKey = (event: KeyboardEvent) => {
      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") {
        event.preventDefault();
        setPaletteOpen((open) => !open);
      } else if ((event.metaKey || event.ctrlKey) && event.key === "1") {
        event.preventDefault();
        setLens("execution");
      } else if ((event.metaKey || event.ctrlKey) && event.key === "2") {
        event.preventDefault();
        setLens("collaboration");
      } else if (event.key === "Escape") {
        setPaletteOpen(false);
        setAuxView(null);
      }
    };
    window.addEventListener("keydown", onKey);
    onCleanup(() => window.removeEventListener("keydown", onKey));
  });

  const parsed = createMemo(() => {
    let loaded: { artifactJson: string; session: WorkbenchSession | null } | undefined;
    if (hubServices) {
      const focused = hubServices.focused();
      const artifactJson = focused ? hubServices.artifactJson(focused) : emptyArtifact;
      const dropped = focused ? hubServices.droppedFrames(focused) : 0;
      const warnings = focused ? [`hub live · ${focused}`] : ["hub — select a service"];
      if (dropped > 0) {
        warnings.push(`hub evicted ${dropped} earlier frame${dropped === 1 ? "" : "s"} — trace starts mid-run`);
      }
      loaded = {
        artifactJson,
        session: {
          schema: "zigeffect.causal.workbench-session.v1",
          artifact_path: focused ?? "hub",
          read_only: true,
          warnings,
        },
      };
    } else {
      const liveJson = live?.artifactJson();
      loaded = liveJson !== undefined ? { artifactJson: liveJson, session: liveSession } : payload();
    }
    if (!loaded) {
      return null;
    }
    try {
      const artifactPath = loaded.session?.artifact_path ?? "sample-artifact.json";
      const raw = parseArtifactJson(loaded.artifactJson);
      return {
        model: deriveWorkbenchModel(raw, { artifactPath }),
        governance: deriveGovernanceModel(raw, { artifactPath }),
        semanticDiff: deriveSemanticDiffModel(raw, { artifactPath }),
        localDevSession: deriveLocalDevSessionModel(raw, { artifactPath }) ?? live?.localDevSession() ?? null,
        raw,
        session: loaded.session,
        error: null as string | null,
      };
    } catch (error) {
      return {
        model: null,
        governance: null,
        semanticDiff: null,
        localDevSession: null,
        raw: null,
        session: loaded.session,
        error: error instanceof Error ? error.message : "failed to parse artifact",
      };
    }
  });

  const model = createMemo(() => parsed()?.model ?? null);
  const governance = createMemo(() => parsed()?.governance ?? null);
  const semanticDiff = createMemo(() => parsed()?.semanticDiff ?? null);
  const localDevSession = createMemo(() => parsed()?.localDevSession ?? null);
  const health = createMemo(() => {
    const session = localDevSession();
    return session ? deriveLocalDevHealthSummary(session) : null;
  });

  const graphModel = createMemo(() => {
    const current = model();
    return current ? deriveGraphModel(current.events, current.findings) : null;
  });
  const traceModel = createMemo<TraceModel | null>(() => {
    const current = model();
    const graph = graphModel();
    return current && graph ? deriveTraceModel(current.events, graph.lanes, current.findings) : null;
  });
  const visualGraph = createMemo(() => {
    const current = model();
    const graph = graphModel();
    if (!current || !graph) {
      return null;
    }
    return deriveVisualGraphModel(current, graph, {
      layoutMode: layoutMode(),
      perspective: graphPerspective(),
      selectedEventId: selectedId(),
    });
  });

  const validEventIds = createMemo(() => new Set((model()?.events ?? []).map((event) => event.idText)));
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
    return events.find((event) => event.idText === selectedId()) ?? null;
  });
  const causePathEvents = createMemo<CausalEvent[]>(() => {
    const current = model();
    const event = selectedEvent();
    return current && event ? causePathForEvent(current.events, event.idText) : [];
  });
  const causePathIds = createMemo(() => causePathEvents().map((event) => event.idText));
  const selectedFinding = createMemo<TraceFindingMark | null>(() => {
    const trace = traceModel();
    const id = selectedId();
    return trace && id ? trace.findingMarks.find((mark) => mark.eventId === id) ?? null : null;
  });
  const selectedCommands = createMemo(() => {
    const current = model();
    const event = selectedEvent();
    return current && event ? queryCommandsForEvent(event, current.artifactPath) : [];
  });

  // Cross-service correlation (hub mode): when the selected event carries a
  // boundary_id, ask the hub where else that id was observed — the hub indexes
  // ALL services, including ones this client never subscribed to. The source is
  // a fresh object per recompute so the fetch re-runs when the selection moves
  // (even to the same boundary id in another service) and when a new
  // boundary-tagged frame arrives (late other-side occurrences appear).
  const boundaryQuery = createMemo(() => {
    if (!hubUrl || !hubServices) {
      return null;
    }
    hubServices.boundaryActivity();
    hubServices.focused();
    const event = selectedEvent();
    const boundaryId = event?.boundaryId;
    return boundaryId ? { boundaryId } : null;
  });
  const [boundaryOccurrences] = createResource(boundaryQuery, async (query) => {
    const endpoint = hubUrl ? correlateEndpoint(hubUrl, query.boundaryId) : null;
    if (!endpoint) {
      return [];
    }
    try {
      const response = await fetch(endpoint);
      if (!response.ok) {
        return [];
      }
      return parseCorrelation(await response.json());
    } catch {
      return [];
    }
  });

  const dimmedIds = createMemo<Set<string> | null>(() => {
    const current = model();
    if (!current) {
      return null;
    }
    const filterActive = search().trim() !== "" || kind() !== "all" || status() !== "all";
    const focusKind = findingFocus();
    if (!filterActive && !focusKind) {
      return null;
    }
    const visibleSet = filterActive ? new Set(visibleEvents().map((event) => event.idText)) : null;
    let focusSet: Set<string> | null = null;
    if (focusKind) {
      focusSet = new Set<string>();
      for (const finding of current.findings) {
        if (finding.kind === focusKind) {
          for (const event of causePathForEvent(current.events, finding.eventId)) {
            focusSet.add(event.idText);
          }
        }
      }
    }
    const dim = new Set<string>();
    for (const event of current.events) {
      const hiddenByFilter = visibleSet ? !visibleSet.has(event.idText) : false;
      const hiddenByFocus = focusSet ? !focusSet.has(event.idText) : false;
      if (hiddenByFilter || hiddenByFocus) {
        dim.add(event.idText);
      }
    }
    return dim;
  });

  const runMeta = createMemo(() => {
    const current = model();
    if (!current) {
      return [];
    }
    return [
      { label: "schema", value: current.schema },
      { label: "events", value: String(current.events.length) },
      { label: "findings", value: String(current.findings.length) },
      { label: "taxonomy", value: current.taxonomyVersion },
    ];
  });

  async function copyCommand(command: string) {
    if (navigator.clipboard) {
      await navigator.clipboard.writeText(command);
      setCopiedCommand(command);
      window.setTimeout(() => setCopiedCommand(null), 1200);
    }
  }

  return (
    <main class="app">
      <Show when={payload.loading}>
        <div class="loading-state">Loading causal artifact…</div>
      </Show>
      <Show when={parsed()?.error}>
        <div class="error-state">{parsed()?.error}</div>
      </Show>

      {/* NOT keyed: in live/hub mode model() is a fresh object per frame, and a
          keyed Show would tear down + rebuild the whole workspace DOM each time.
          Non-keyed, `current` is an accessor and updates stay fine-grained. */}
      <Show when={model()}>
        {(current) => {
          const trace = () => traceModel();
          return (
            <>
              <TopBar
                artifactPath={current().artifactPath}
                schema={current().schema}
                lens={lens()}
                theme={theme()}
                isLive={liveUrl !== null}
                liveFrameCount={live?.frameCount() ?? 0}
                health={health()}
                search={search()}
                kind={kind()}
                status={status()}
                kinds={current().kinds}
                statuses={current().statuses}
                onSearch={setSearch}
                onKind={setKind}
                onStatus={setStatus}
                onLens={setLens}
                onToggleTheme={toggleTheme}
                onOpenPalette={() => setPaletteOpen(true)}
              />

              <div classList={{ workspace: true, "has-rail": hubServices !== null }}>
                <Show when={hubServices}>
                  {(hub) => (
                    <ServicesRail
                      services={hub().services()}
                      focused={hub().focused()}
                      pinned={hub().pinned()}
                      connected={hub().connected()}
                      onFocus={(serviceKey) => focusService(serviceKey)}
                      onTogglePin={(serviceKey) =>
                        hub().pinned().includes(serviceKey) ? hub().unpin(serviceKey) : hub().pin(serviceKey)
                      }
                      onLayer={(serviceKey, layerName) => {
                        focusService(serviceKey);
                        setSearch(layerName);
                      }}
                    />
                  )}
                </Show>
                <div class="stage-split">
                <Show
                  when={lens() === "execution"}
                  fallback={
                    <section class="stage lens-collaboration">
                      <div class="stage-body">
                        <CollabBoard
                          session={localDevSession()}
                          validEventIds={validEventIds()}
                          copiedCommand={copiedCommand()}
                          onCopy={copyCommand}
                          onSelectEvent={setSelectedId}
                        />
                        <div class="evidence-split">
                          <TracePane
                            title="Execution evidence"
                            eventCount={current().events.length}
                            trace={trace()}
                            selectedId={selectedId()}
                            causePath={causePathIds()}
                            dimmedIds={dimmedIds()}
                            density="compact"
                            showFindings={false}
                            findingMarks={trace()?.findingMarks ?? []}
                            findingFocus={findingFocus()}
                            onToggleFocus={setFindingFocus}
                            onDensity={setDensity}
                            onSelect={setSelectedId}
                          />
                          <DagPanel
                            model={visualGraph()}
                            layoutMode={layoutMode()}
                            perspective={graphPerspective()}
                            selectedId={selectedId()}
                            onLayoutMode={setLayoutMode}
                            onPerspective={setGraphPerspective}
                            onSelect={setSelectedId}
                            compact
                          />
                        </div>
                      </div>
                    </section>
                  }
                >
                  <section class="stage lens-execution">
                    <AgentsRibbon
                      session={localDevSession()}
                      validEventIds={validEventIds()}
                      onSelectEvent={setSelectedId}
                    />
                    <div class="stage-body">
                      <TracePane
                        title="Execution trace"
                        eventCount={current().events.length}
                        trace={trace()}
                        selectedId={selectedId()}
                        causePath={causePathIds()}
                        dimmedIds={dimmedIds()}
                        density={density()}
                        showFindings
                        findingMarks={trace()?.findingMarks ?? []}
                        findingFocus={findingFocus()}
                        onToggleFocus={setFindingFocus}
                        onDensity={setDensity}
                        onSelect={setSelectedId}
                      />
                      <DagPanel
                        model={visualGraph()}
                        layoutMode={layoutMode()}
                        perspective={graphPerspective()}
                        selectedId={selectedId()}
                        onLayoutMode={setLayoutMode}
                        onPerspective={setGraphPerspective}
                        onSelect={setSelectedId}
                      />
                    </div>
                  </section>
                </Show>
                <Show when={hubServices}>
                  {(hub) => (
                    <PinnedPanes
                      pinned={hub().pinned()}
                      services={hub().services()}
                      artifactJson={(serviceKey) => hub().artifactJson(serviceKey)}
                      droppedFrames={(serviceKey) => hub().droppedFrames(serviceKey)}
                      onUnpin={(serviceKey) => hub().unpin(serviceKey)}
                      onPromote={(serviceKey, eventId) => {
                        focusService(serviceKey);
                        if (eventId) {
                          setSelectedId(eventId);
                        }
                      }}
                    />
                  )}
                </Show>
                </div>

                <Inspector
                  event={selectedEvent()}
                  causePath={causePathEvents()}
                  finding={selectedFinding()}
                  commands={selectedCommands()}
                  copiedCommand={copiedCommand()}
                  runMeta={runMeta()}
                  boundary={
                    hubServices
                      ? {
                          // While a refetch is in flight the resource still
                          // returns the PREVIOUS boundary's occurrences — hide
                          // them rather than flash wrong jump links.
                          occurrences: boundaryOccurrences.loading ? [] : boundaryOccurrences() ?? [],
                          onJump: (serviceKey, eventId) => {
                            focusService(serviceKey);
                            setSelectedId(eventId);
                          },
                        }
                      : null
                  }
                  onCopy={copyCommand}
                  onSelect={setSelectedId}
                />
              </div>

              <Show when={paletteOpen()}>
                <CommandPalette
                  events={current().events}
                  findingMarks={trace()?.findingMarks ?? []}
                  hasDiff={semanticDiff() !== null}
                  hasChain={governance() !== null}
                  onClose={() => setPaletteOpen(false)}
                  onSelectEvent={(id) => {
                    setSelectedId(id);
                    setPaletteOpen(false);
                  }}
                  onOpenAux={(view) => {
                    setAuxView(view);
                    setPaletteOpen(false);
                  }}
                  onSetLens={setLens}
                  onToggleTheme={toggleTheme}
                />
              </Show>

              <Show when={auxView()} keyed>
                {(view) => (
                  <AuxOverlay title={auxTitles[view]} onClose={() => setAuxView(null)}>
                    <Show when={view === "diff"}>
                      <DiffView diff={semanticDiff()} onSelectEvent={(id) => { setSelectedId(id); setAuxView(null); }} />
                    </Show>
                    <Show when={view === "chain"}>
                      <ChainView
                        governance={governance()}
                        events={current().events}
                        copiedCommand={copiedCommand()}
                        onCopy={copyCommand}
                        onSelectEvent={(id) => { setSelectedId(id); setAuxView(null); }}
                      />
                    </Show>
                    <Show when={view === "metadata"}>
                      <MetadataView model={current()} session={parsed()?.session ?? null} />
                    </Show>
                    <Show when={view === "queries"}>
                      <QueriesView
                        artifactPath={current().artifactPath}
                        selected={selectedEvent()}
                        commands={selectedCommands()}
                        copiedCommand={copiedCommand()}
                        onCopy={copyCommand}
                      />
                    </Show>
                  </AuxOverlay>
                )}
              </Show>
            </>
          );
        }}
      </Show>
    </main>
  );
}

function TracePane(props: {
  title: string;
  eventCount: number;
  trace: TraceModel | null | undefined;
  selectedId: string | null;
  causePath: string[];
  dimmedIds: Set<string> | null;
  density: "comfortable" | "compact";
  showFindings: boolean;
  findingMarks: TraceFindingMark[];
  findingFocus: CausalFinding["kind"] | null;
  onToggleFocus: (kind: CausalFinding["kind"] | null) => void;
  onDensity: (density: "comfortable" | "compact") => void;
  onSelect: (id: string) => void;
}) {
  return (
    <section class="stage-pane trace-pane">
      <div class="pane-head">
        <div class="pane-title">
          <h2>{props.title}</h2>
          <span class="pane-sub">{props.eventCount} events</span>
        </div>
        <div class="pane-tools">
          <Segmented
            ariaLabel="Trace density"
            compact
            options={[{ value: "comfortable", label: "Comfortable" }, { value: "compact", label: "Compact" }]}
            value={props.density}
            onChange={props.onDensity}
          />
        </div>
      </div>
      <Show when={props.showFindings}>
        <FindingsBand findingMarks={props.findingMarks} activeKind={props.findingFocus} onToggle={props.onToggleFocus} />
      </Show>
      <Show when={props.trace} fallback={<div class="empty-state">No trace</div>}>
        {(trace) => (
          <TraceCanvas
            trace={trace()}
            selectedId={props.selectedId}
            causePath={props.causePath}
            dimmedIds={props.dimmedIds}
            density={props.density}
            onSelect={props.onSelect}
          />
        )}
      </Show>
    </section>
  );
}

function AgentsRibbon(props: {
  session: ReturnType<typeof deriveLocalDevSessionModel>;
  validEventIds: Set<string>;
  onSelectEvent: (id: string) => void;
}) {
  return (
    <Show
      when={props.session}
      fallback={<div class="agents-ribbon"><span class="ribbon-label">No local agent session in this artifact</span></div>}
    >
      {(session) => (
        <div class="agents-ribbon">
          <span class="ribbon-label">Agents</span>
          <For each={session().agents}>
            {(agent) => (
              <button
                type="button"
                class="agent-chip"
                style={`--dot:${agentHue(agent.kind)}`}
                onClick={() => {
                  if (agent.lastEventId && props.validEventIds.has(agent.lastEventId)) {
                    props.onSelectEvent(agent.lastEventId);
                  }
                }}
                title={agent.currentTask ?? agent.label}
              >
                <span class="agent-dot" />
                {agent.label}
              </button>
            )}
          </For>
          <button type="button" class="agent-chip ribbon-grow" onClick={() => toggleLens()} title="Open collaboration lens">
            Collaboration ↗
          </button>
        </div>
      )}
    </Show>
  );
}
