import { For, Show } from "solid-js";
import type {
  VisualGraphLayoutMode,
  VisualGraphModel,
  VisualGraphPerspective,
} from "../causalArtifact";
import { Segmented } from "../ui/Segmented";
import { EmptyState } from "../primitives";
import { CausalDag } from "./CausalDag";

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
  compact?: boolean;
}) {
  return (
    <section class="stage-pane">
      <div class="pane-head">
        <div class="pane-title">
          <h2>Causal graph</h2>
          <Show when={props.model}>
            {(model) => <span class="pane-sub">{model().nodes.length} nodes · {model().edges.length} edges</span>}
          </Show>
        </div>
        <Show when={!props.compact}>
          <div class="pane-tools">
            <Segmented
              ariaLabel="Causal graph perspective"
              compact
              options={perspectives}
              value={props.perspective}
              onChange={props.onPerspective}
            />
            <Segmented
              ariaLabel="Causal graph layout"
              compact
              options={layouts}
              value={props.layoutMode}
              onChange={props.onLayoutMode}
            />
          </div>
        </Show>
      </div>

      <div class="dag">
        <Show when={props.model} fallback={<EmptyState label="No causal graph for this artifact" />}>
          {(model) => (
            <>
              <CausalDag
                model={model()}
                layoutMode={props.layoutMode}
                selectedId={props.selectedId}
                onSelect={props.onSelect}
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
            </>
          )}
        </Show>
      </div>
    </section>
  );
}
