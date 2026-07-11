import { For, Show, createMemo, createSignal } from "solid-js";
import type { CausalEvent } from "../causalArtifact";
import type { Lens } from "../theme";
import type { TraceFindingMark } from "../trace/traceModel";
import { Overlay } from "./Overlay";

export type AuxView = "diff" | "chain" | "metadata" | "queries" | "safety" | "tests";

type PaletteItem = { id: string; label: string; hint?: string; run: () => void };

// ⌘K palette: jump by event id, jump to a finding, switch lens/theme, or open the
// auxiliary views (semantic diff, governance chain, metadata, query catalogue) that
// were dissolved out of the old tab bar.
export function CommandPalette(props: {
  events: CausalEvent[];
  findingMarks: TraceFindingMark[];
  hasDiff: boolean;
  hasChain: boolean;
  onClose: () => void;
  onSelectEvent: (id: string) => void;
  onOpenAux: (view: AuxView) => void;
  onSetLens: (lens: Lens) => void;
  onToggleTheme: () => void;
}) {
  const [query, setQuery] = createSignal("");
  const [active, setActive] = createSignal(0);

  const baseItems = createMemo<PaletteItem[]>(() => {
    const items: PaletteItem[] = [
      { id: "lens-exec", label: "Switch to Execution lens", hint: "⌘1", run: () => props.onSetLens("execution") },
      { id: "lens-collab", label: "Switch to Collaboration lens", hint: "⌘2", run: () => props.onSetLens("collaboration") },
      { id: "theme", label: "Toggle dark / light theme", run: () => props.onToggleTheme() },
      { id: "safety", label: "Open agent safety evidence", run: () => props.onOpenAux("safety") },
      { id: "tests", label: "Open requirement-linked test evidence", run: () => props.onOpenAux("tests") },
      { id: "metadata", label: "Open metadata", run: () => props.onOpenAux("metadata") },
      { id: "queries", label: "Open query catalogue", run: () => props.onOpenAux("queries") },
    ];
    if (props.hasDiff) {
      items.push({ id: "diff", label: "Open semantic diff", run: () => props.onOpenAux("diff") });
    }
    if (props.hasChain) {
      items.push({ id: "chain", label: "Open governance chain", run: () => props.onOpenAux("chain") });
    }
    for (const mark of props.findingMarks) {
      items.push({
        id: `finding-${mark.index}`,
        label: `Jump to finding #${mark.index} — ${mark.title}`,
        hint: `#${mark.eventId}`,
        run: () => props.onSelectEvent(mark.eventId),
      });
    }
    return items;
  });

  const filtered = createMemo<PaletteItem[]>(() => {
    const q = query().trim().toLowerCase();
    const items: PaletteItem[] = [];
    if (q) {
      const match = props.events.find((event) => event.idText.toLowerCase() === q || `#${event.idText}`.toLowerCase() === q);
      if (match) {
        items.push({ id: `jump-${match.idText}`, label: `Go to event #${match.idText} — ${match.kind}`, hint: "enter", run: () => props.onSelectEvent(match.idText) });
      }
    }
    const all = [...items, ...baseItems()];
    return q ? all.filter((item) => item.label.toLowerCase().includes(q)) : all;
  });

  const run = (item: PaletteItem | undefined) => {
    if (item) {
      item.run();
      props.onClose();
    }
  };

  const onKeyDown = (event: KeyboardEvent) => {
    if (event.key === "Escape") {
      props.onClose();
    } else if (event.key === "ArrowDown") {
      event.preventDefault();
      setActive((value) => Math.min(value + 1, filtered().length - 1));
    } else if (event.key === "ArrowUp") {
      event.preventDefault();
      setActive((value) => Math.max(value - 1, 0));
    } else if (event.key === "Enter") {
      event.preventDefault();
      run(filtered()[active()]);
    }
  };

  return (
    <Overlay onClose={props.onClose}>
      <div class="palette" onKeyDown={onKeyDown}>
        <input
          class="palette-input"
          placeholder="Jump to event id, finding, or command…"
          value={query()}
          onInput={(event) => {
            setQuery(event.currentTarget.value);
            setActive(0);
          }}
          ref={(element) => queueMicrotask(() => element.focus())}
        />
        <div class="palette-list">
          <For each={filtered()} fallback={<div class="empty-state compact">No matches</div>}>
            {(item, index) => (
              <button
                type="button"
                classList={{ "palette-item": true, active: index() === active() }}
                onMouseEnter={() => setActive(index())}
                onClick={() => run(item)}
              >
                <span>{item.label}</span>
                <Show when={item.hint}>
                  <span class="pi-hint">{item.hint}</span>
                </Show>
              </button>
            )}
          </For>
        </div>
      </div>
    </Overlay>
  );
}
