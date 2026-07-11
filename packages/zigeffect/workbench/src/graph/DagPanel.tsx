import { For, Show } from "solid-js";
import type {
  VisualGraphLayoutMode,
  VisualGraphModel,
  VisualGraphPerspective,
} from "../causalArtifact";
import { Segmented } from "../ui/Segmented";
import { EmptyState } from "../primitives";
import { CausalDag } from "./CausalDag";
import { StatechartStudio } from "../statechart/StatechartStudio";
import type { StatechartDefinitionArtifact } from "../statechart/statechartModel";
import type { StudioModel } from "../statechart/studioModel";

const perspectives: Array<{ value: VisualGraphPerspective; label: string }> = [
  { value: "cause", label: "Cause" },
  { value: "topology", label: "Topology" },
  { value: "ownership", label: "Ownership" },
  { value: "lineage", label: "Lineage" },
];

const layouts: Array<{ value: VisualGraphLayoutMode; label: string }> = [
  { value: "dagre", label: "Dagre" },
  { value: "force", label: "Force" },
  { value: "radial", label: "Radial" },
];

export type GraphSurfaceMode = "causal" | "statechart" | "actors" | "studio";

const graphModes: Array<{ value: GraphSurfaceMode; label: string }> = [
  { value: "causal", label: "Causal" },
  { value: "statechart", label: "Statechart" },
  { value: "actors", label: "Actors" },
  { value: "studio", label: "Studio" },
];

const legendTones: Array<{ tone: string; label: string }> = [
  { tone: "ok", label: "ok" },
  { tone: "warning", label: "warning" },
  { tone: "failure", label: "failure" },
];

// The single G6 causal DAG, presented as a self-contained pane. It is the same canvas
// in both lenses (companion in execution, evidence minimap in collaboration), kept in
// sync with the rest of the app through selectedId + onSelect.
export function DagPanel(props: {
  model: VisualGraphModel | null;
  layoutMode: VisualGraphLayoutMode;
  perspective: VisualGraphPerspective;
  selectedId: string | null;
  onLayoutMode: (mode: VisualGraphLayoutMode) => void;
  onPerspective: (perspective: VisualGraphPerspective) => void;
  onSelect: (eventId: string) => void;
  mode?: GraphSurfaceMode;
  onMode?: (mode: GraphSurfaceMode) => void;
  replay?: { position: number; total: number; onPosition: (position: number) => void } | null;
  statechartControls?: {
    definitions: Array<{ value: string; label: string }>;
    definition: string;
    onDefinition: (value: string) => void;
    instances: Array<{ value: string; label: string }>;
    instance: string;
    onInstance: (value: string) => void;
    oracle: string;
    oracleOk: boolean;
    diff: string;
  } | null;
  studio?: { model: StudioModel; definition: StatechartDefinitionArtifact | null; onCopy?: (value: string) => void } | null;
  compact?: boolean;
}) {
  const mode = () => props.mode ?? "causal";
  const title = () => mode() === "causal" ? "Causal graph" : mode() === "statechart" ? "Statechart logic" : mode() === "actors" ? "Actor system" : "Statechart Studio";
  const selectedNode = () => props.model?.nodes.find((node) => node.eventId === props.selectedId) ?? null;
  return (
    <section class="stage-pane">
      <div class="pane-head">
        <div class="pane-title">
          <h2>{title()}</h2>
          <Show when={props.model}>
            {(model) => <span class="pane-sub">{model().nodes.length} nodes · {model().edges.length} edges</span>}
          </Show>
        </div>
        <Show when={!props.compact}>
          <div class="pane-tools">
            <Show when={(mode() === "statechart" || mode() === "actors" || mode() === "studio") && props.statechartControls}>
              {(controls) => (
                <div class="statechart-selectors">
                  <label>
                    <span>Definition</span>
                    <select aria-label="Statechart definition" value={controls().definition} onChange={(event) => controls().onDefinition(event.currentTarget.value)}>
                      <For each={controls().definitions}>{(option) => <option value={option.value}>{option.label}</option>}</For>
                    </select>
                  </label>
                  <label>
                    <span>Instance</span>
                    <select aria-label="Statechart instance" value={controls().instance} onChange={(event) => controls().onInstance(event.currentTarget.value)}>
                      <Show when={controls().instances.length > 0} fallback={<option value="">No instances</option>}>
                        <For each={controls().instances}>{(option) => <option value={option.value}>{option.label}</option>}</For>
                      </Show>
                    </select>
                  </label>
                  <span classList={{ "oracle-badge": true, ok: controls().oracleOk, failure: !controls().oracleOk }} title={controls().diff}>{controls().oracle}</span>
                  <span class="definition-diff" title="Definition version diff">{controls().diff}</span>
                </div>
              )}
            </Show>
            <Show when={props.onMode}>
              <Segmented
                ariaLabel="Graph surface mode"
                compact
                options={graphModes}
                value={mode()}
                onChange={(next) => props.onMode?.(next)}
              />
            </Show>
            <Show when={mode() === "causal"}>
              <Segmented
                ariaLabel="Causal graph perspective"
                compact
                options={perspectives}
                value={props.perspective}
                onChange={props.onPerspective}
              />
            </Show>
            <Show when={mode() !== "studio"}>
              <Segmented
                ariaLabel="Causal graph layout"
                compact
                options={layouts}
                value={props.layoutMode}
                onChange={props.onLayoutMode}
              />
            </Show>
          </div>
        </Show>
      </div>

      <div class="dag">
        <Show when={mode() === "studio" && props.studio}>
          {(studio) => <StatechartStudio model={studio().model} definition={studio().definition} onCopy={studio().onCopy} />}
        </Show>
        <Show when={mode() !== "studio"}>
        <Show when={mode() === "statechart" && props.replay && props.replay.total > 0}>
          <label class="statechart-replay">
            <span>Replay {props.replay!.position + 1}/{props.replay!.total}</span>
            <input
              aria-label="Statechart replay position"
              type="range"
              min="0"
              max={Math.max(0, props.replay!.total - 1)}
              value={props.replay!.position}
              onInput={(event) => props.replay!.onPosition(Number(event.currentTarget.value))}
            />
          </label>
        </Show>
        <Show when={props.model} fallback={<EmptyState label={`No ${mode()} graph for this artifact`} />}>
          {(model) => (
            <>
              <CausalDag
                model={model()}
                layoutMode={props.layoutMode}
                selectedId={props.selectedId}
                onSelect={props.onSelect}
                ariaLabel={`${title()} visualization`}
              />
              <div class="dag-legend">
                <For each={legendTones}>
                  {(entry) => (
                    <span class="legend-item">
                      <span class={`legend-dot ${entry.tone}`} />
                      {entry.label}
                    </span>
                  )}
                </For>
              </div>
              <Show when={selectedNode()}>
                {(node) => (
                  <div class="graph-selection" aria-live="polite">
                    <strong>{node().label}</strong>
                    <span>{node().detail}</span>
                    <Show when={node().sourceLocation}>
                      {(source) => (
                        <button
                          type="button"
                          class="source-location"
                          title="Copy source location"
                          onClick={() => navigator.clipboard?.writeText(source())}
                        >{source()}</button>
                      )}
                    </Show>
                  </div>
                )}
              </Show>
            </>
          )}
        </Show>
        </Show>
      </div>
    </section>
  );
}
