import { For, Show, createEffect, createMemo } from "solid-js";
import type { VisualGraphLayoutMode, VisualGraphModel } from "../causalArtifact";

// Self-rendered SVG causal DAG. Deterministic layered (longest-path) layout for
// dagre/force and a concentric layout for radial. Deliberately NOT auto-scaled to fit the
// pane: an earlier version fit the whole viewBox into the container, which shrank node
// labels to a few illegible pixels on any graph with real vertical extent. Instead the
// SVG renders at a strict 1 user-unit = 1 CSS px, so node size and label text are always
// exactly as designed; graphs bigger than the pane simply scroll (centered when they fit).
// All colors come from CSS tokens so the graph themes for free. Clicking/Enter/Space on a
// node selects the underlying event across the whole app.

const NODE_R = 11;
const COL_GAP = 210;
const ROW_GAP = 78;
const LABEL_CHARS = 18;
const CHAR_W = 6.4;

type Placed = { id: string; eventId: string | null; label: string; tone: string; x: number; y: number };

function truncate(label: string): string {
  return label.length > LABEL_CHARS ? `${label.slice(0, LABEL_CHARS - 1)}…` : label;
}

function layeredPositions(model: VisualGraphModel): Map<string, { x: number; y: number }> {
  const ids = new Set(model.nodes.map((node) => node.id));
  const incoming = new Map<string, string[]>();
  for (const node of model.nodes) {
    incoming.set(node.id, []);
  }
  for (const edge of model.edges) {
    if (ids.has(edge.source) && ids.has(edge.target)) {
      incoming.get(edge.target)?.push(edge.source);
    }
  }
  const depth = new Map<string, number>();
  const visiting = new Set<string>();
  const depthOf = (id: string): number => {
    const cached = depth.get(id);
    if (cached !== undefined) {
      return cached;
    }
    if (visiting.has(id)) {
      return 0;
    }
    visiting.add(id);
    let d = 0;
    for (const parent of incoming.get(id) ?? []) {
      d = Math.max(d, depthOf(parent) + 1);
    }
    visiting.delete(id);
    depth.set(id, d);
    return d;
  };
  for (const node of model.nodes) {
    depthOf(node.id);
  }
  const columns = new Map<number, string[]>();
  for (const node of model.nodes) {
    const d = depth.get(node.id) ?? 0;
    const column = columns.get(d) ?? [];
    column.push(node.id);
    columns.set(d, column);
  }
  const positions = new Map<string, { x: number; y: number }>();
  for (const [d, column] of columns) {
    column.forEach((id, index) => {
      positions.set(id, { x: d * COL_GAP, y: (index - (column.length - 1) / 2) * ROW_GAP });
    });
  }
  return positions;
}

function radialPositions(model: VisualGraphModel): Map<string, { x: number; y: number }> {
  const layered = layeredPositions(model);
  // reuse the depth implicit in layered x to build rings, angle by sibling index
  const byDepth = new Map<number, string[]>();
  for (const node of model.nodes) {
    const d = Math.round((layered.get(node.id)?.x ?? 0) / COL_GAP);
    const ring = byDepth.get(d) ?? [];
    ring.push(node.id);
    byDepth.set(d, ring);
  }
  const positions = new Map<string, { x: number; y: number }>();
  for (const [d, ring] of byDepth) {
    const radius = d * 150;
    ring.forEach((id, index) => {
      if (d === 0) {
        positions.set(id, { x: 0, y: 0 });
        return;
      }
      const angle = (index / ring.length) * Math.PI * 2;
      positions.set(id, { x: Math.cos(angle) * radius, y: Math.sin(angle) * radius });
    });
  }
  return positions;
}

export function CausalDag(props: {
  model: VisualGraphModel;
  layoutMode: VisualGraphLayoutMode;
  selectedId: string | null;
  onSelect: (eventId: string) => void;
}) {
  const placed = createMemo<Placed[]>(() => {
    const positions = props.layoutMode === "radial" ? radialPositions(props.model) : layeredPositions(props.model);
    return props.model.nodes.map((node) => {
      const point = positions.get(node.id) ?? { x: 0, y: 0 };
      return { id: node.id, eventId: node.eventId, label: truncate(node.label), tone: node.tone, x: point.x, y: point.y };
    });
  });

  const byId = createMemo(() => new Map(placed().map((node) => [node.id, node])));

  // Bounding box in the SAME units the layout functions use (px, at 1:1). Sized to fit
  // every node circle and its right-placed label, so nothing clips at the SVG edge.
  const box = createMemo(() => {
    const nodes = placed();
    if (nodes.length === 0) {
      return { minX: 0, minY: 0, width: 100, height: 100 };
    }
    let minX = Infinity;
    let minY = Infinity;
    let maxX = -Infinity;
    let maxY = -Infinity;
    for (const node of nodes) {
      const labelW = node.label.length * CHAR_W + NODE_R * 2;
      minX = Math.min(minX, node.x - NODE_R - 8);
      maxX = Math.max(maxX, node.x + labelW + 8);
      minY = Math.min(minY, node.y - NODE_R - 8);
      maxY = Math.max(maxY, node.y + NODE_R + 8);
    }
    const pad = 24;
    return {
      minX: minX - pad,
      minY: minY - pad,
      width: maxX - minX + pad * 2,
      height: maxY - minY + pad * 2,
    };
  });

  let scrollRef: HTMLDivElement | undefined;

  // Center the graph in the scroll container whenever its content size changes (initial
  // render, layout mode switch, or perspective/node-count change). Plain scrollTop/Left
  // math rather than relying on flex-centering-with-overflow, which leaves the browser's
  // initial scroll position pinned to the top-left of the overflowing content.
  createEffect(() => {
    const { width, height } = box();
    const container = scrollRef;
    if (!container) {
      return;
    }
    queueMicrotask(() => {
      container.scrollLeft = Math.max(0, (width - container.clientWidth) / 2);
      container.scrollTop = Math.max(0, (height - container.clientHeight) / 2);
    });
  });

  return (
    <Show when={placed().length > 0} fallback={<div class="empty-state dag-empty">No causal graph for this artifact</div>}>
      <div class="dag-canvas" ref={scrollRef}>
      <svg
        class="dag-svg"
        viewBox={`${box().minX} ${box().minY} ${box().width} ${box().height}`}
        width={box().width}
        height={box().height}
        role="img"
        aria-label="Causal graph"
      >
        <defs>
          <marker id="dag-arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
            <path class="dag-arrowhead" d="M0,0 L10,5 L0,10 z" />
          </marker>
        </defs>
        <g class="dag-edges">
          <For each={props.model.edges}>
            {(edge) => {
              const source = () => byId().get(edge.source);
              const target = () => byId().get(edge.target);
              return (
                <Show when={source() && target()}>
                  <path class="dag-edge" d={edgePath(source()!, target()!)} marker-end="url(#dag-arrow)" />
                </Show>
              );
            }}
          </For>
        </g>
        <g class="dag-nodes">
          <For each={placed()}>
            {(node) => (
              <g
                classList={{ "dag-node": true, ok: node.tone === "ok", warning: node.tone === "warning", failure: node.tone === "failure", selected: node.eventId !== null && node.eventId === props.selectedId }}
                transform={`translate(${node.x} ${node.y})`}
                onClick={() => node.eventId && props.onSelect(node.eventId)}
                onKeyDown={(event) => {
                  if ((event.key === "Enter" || event.key === " ") && node.eventId) {
                    event.preventDefault();
                    props.onSelect(node.eventId);
                  }
                }}
                role="button"
                tabindex={node.eventId ? 0 : -1}
                aria-label={`Select graph node ${node.label}`}
              >
                <circle class="dag-node-circle" r={NODE_R} />
                <text class="dag-node-label" x={NODE_R + 7} y="4">{node.label}</text>
              </g>
            )}
          </For>
        </g>
      </svg>
      </div>
    </Show>
  );
}

function edgePath(source: { x: number; y: number }, target: { x: number; y: number }): string {
  const x1 = source.x + NODE_R;
  const y1 = source.y;
  const x2 = target.x - NODE_R;
  const y2 = target.y;
  const dx = Math.max((x2 - x1) / 2, 24);
  return `M${x1} ${y1} C${x1 + dx} ${y1}, ${x2 - dx} ${y2}, ${x2} ${y2}`;
}
