import { For, Show, createMemo } from "solid-js";
import type { CausalFinding } from "../causalArtifact";
import { findingSeverity, type TraceFindingMark } from "../trace/traceModel";

// The six failure findings as severity counters above the trace. A counter is also a
// cause-path focus filter: clicking it dims every trace row that is not on the
// cause-path of one of its findings. The finding numbers here are the SAME numbers
// pinned on the trace rows, the DAG, and the inspector — one identity everywhere.

const FINDING_KINDS: Array<{ kind: CausalFinding["kind"]; label: string }> = [
  { kind: "service_requirement_without_provider", label: "Missing provider" },
  { kind: "resource_acquired_without_finalization", label: "Resource leak" },
  { kind: "fiber_pending_after_scope_close", label: "Pending fiber" },
  { kind: "retry_budget_exhausted", label: "Retry exhausted" },
  { kind: "finalizer_failure", label: "Finalizer fail" },
  { kind: "assertion_failure", label: "Assertion fail" },
];

export function FindingsBand(props: {
  findingMarks: TraceFindingMark[];
  activeKind: CausalFinding["kind"] | null;
  onToggle: (kind: CausalFinding["kind"] | null) => void;
}) {
  const counts = createMemo(() => {
    const map = new Map<CausalFinding["kind"], number>();
    for (const mark of props.findingMarks) {
      map.set(mark.kind, (map.get(mark.kind) ?? 0) + 1);
    }
    return map;
  });
  const total = () => props.findingMarks.length;
  const present = createMemo(() => FINDING_KINDS.filter((entry) => (counts().get(entry.kind) ?? 0) > 0));

  return (
    <div classList={{ "findings-band": true, clean: total() === 0 }}>
      <span class="fb-label">{total() === 0 ? "No findings — execution is clean" : `Findings · ${total()}`}</span>
      <For each={present()}>
        {(entry) => {
          const count = () => counts().get(entry.kind) ?? 0;
          const severity = findingSeverity(entry.kind);
          return (
            <button
              type="button"
              classList={{
                "finding-counter": true,
                fail: severity === "fail",
                warn: severity === "warn",
                active: props.activeKind === entry.kind,
              }}
              aria-pressed={props.activeKind === entry.kind}
              onClick={() => props.onToggle(props.activeKind === entry.kind ? null : entry.kind)}
            >
              <span class="fc-count">{count()}</span>
              <span class="fc-label">{entry.label}</span>
            </button>
          );
        }}
      </For>
      <Show when={props.activeKind !== null}>
        <button type="button" class="fb-clear" onClick={() => props.onToggle(null)}>
          Clear focus
        </button>
      </Show>
    </div>
  );
}
