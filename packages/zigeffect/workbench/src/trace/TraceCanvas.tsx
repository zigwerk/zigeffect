import { For, Show, createMemo } from "solid-js";
import type { GraphLaneKind } from "../causalArtifact";
import type { TraceModel, TraceRow } from "./traceModel";

// The swimlane execution trace. The vertical axis is LOGICAL SEQUENCE (event id order,
// not wall-clock); columns are run/scope/fiber/resource/retry lanes. Every piece of
// geometry is computed from `rowH * seqIndex` and `laneCol * laneIndex` — never from a
// DOM measurement — so the cross-row spans and the cause-path spine never drift on
// scroll, zoom, or live append. The same two numbers are pushed into CSS custom
// properties so the markup and the absolute overlays stay in lockstep.

const LANE_COL = 22;
const ID_COL = 58;

const laneGlyph: Record<GraphLaneKind, string> = {
  run: "R",
  scope: "S",
  fiber: "F",
  resource: "§",
  retry: "↻",
};

export function TraceCanvas(props: {
  trace: TraceModel;
  selectedId: string | null;
  causePath: string[];
  dimmedIds: Set<string> | null;
  density: "comfortable" | "compact";
  onSelect: (id: string) => void;
}) {
  const rowH = () => (props.density === "compact" ? 22 : 30);
  const laneCount = () => Math.max(props.trace.laneCount, 1);
  const trackW = () => laneCount() * LANE_COL;
  const lastIndex = () => Math.max(props.trace.rows.length - 1, 0);
  const pathSet = createMemo(() => new Set(props.causePath));

  const rootStyle = () =>
    `--row-h:${rowH()}px;--lane-col:${LANE_COL}px;--id-col:${ID_COL}px;--track-w:${trackW()}px;`;

  const laneX = (laneIndex: number) => laneIndex * LANE_COL + LANE_COL / 2;

  const rowById = createMemo(() => new Map(props.trace.rows.map((row) => [row.event.idText, row])));

  const spinePath = createMemo(() => {
    const lookup = rowById();
    return props.causePath
      .map((id) => {
        const seq = props.trace.seqIndexById.get(id);
        const row = lookup.get(id);
        if (seq === undefined || !row) {
          return null;
        }
        return { x: laneX(row.laneIndex), y: (seq + 0.5) * rowH() };
      })
      .filter((point): point is { x: number; y: number } => point !== null);
  });

  return (
    <div class="trace" style={rootStyle()}>
      <div class="trace-lane-header">
        <For each={props.trace.laneColumns}>
          {(column) => (
            <span class="lane-header-cell" data-kind={column.kind} title={column.label}>
              {laneGlyph[column.kind]}
            </span>
          )}
        </For>
        <span class="lane-header-spacer">event</span>
      </div>

      <div class="trace-scroll">
        <Show
          when={props.trace.rows.length > 0}
          fallback={<div class="empty-state trace-empty">No execution events in this artifact</div>}
        >
          <div class="trace-body" style={`height:${props.trace.rows.length * rowH()}px;`}>
            {/* cross-row spans: scope bands, resource tenures, fiber rails */}
            <div class="trace-spans" style={`width:${trackW()}px;`}>
              <For each={props.trace.scopeBands}>
                {(band) => {
                  const end = band.endIndex ?? lastIndex();
                  return (
                    <div
                      classList={{ span: true, scope: true, open: band.endIndex === null }}
                      style={spanStyle(laneX(band.laneIndex), band.startIndex, end, rowH())}
                      title={`scope ${band.label}`}
                    />
                  );
                }}
              </For>
              <For each={props.trace.fiberRails}>
                {(rail) => {
                  const end = rail.endIndex ?? lastIndex();
                  return (
                    <div
                      classList={{ span: true, fiber: true, frayed: rail.pendingAtScopeClose, open: rail.endIndex === null && !rail.pendingAtScopeClose }}
                      style={spanStyle(laneX(rail.laneIndex), rail.startIndex, end, rowH())}
                      title={`fiber ${rail.label}`}
                    />
                  );
                }}
              </For>
              <For each={props.trace.resourceTenures}>
                {(tenure) => {
                  const end = tenure.leaked
                    ? Math.min(tenure.acquireIndex + 1.4, lastIndex() + 0.6)
                    : tenure.finalizeIndex ?? lastIndex();
                  return (
                    <div
                      classList={{ span: true, resource: true, leaked: tenure.leaked }}
                      style={spanStyle(laneX(tenure.laneIndex), tenure.acquireIndex, end, rowH())}
                      title={`resource ${tenure.label}${tenure.leaked ? " (not finalized)" : ""}`}
                    />
                  );
                }}
              </For>
            </div>

            {/* rows */}
            <For each={props.trace.rows}>
              {(row) => (
                <TraceRowView
                  row={row}
                  rowH={rowH()}
                  laneX={laneX(row.laneIndex)}
                  selected={props.selectedId === row.event.idText}
                  onPath={pathSet().has(row.event.idText)}
                  dimmed={props.dimmedIds?.has(row.event.idText) ?? false}
                  onSelect={props.onSelect}
                />
              )}
            </For>

            {/* cause-path spine */}
            <Show when={spinePath().length > 1}>
              <svg class="cause-overlay" width={trackW()} height={props.trace.rows.length * rowH()}>
                <path d={polyline(spinePath())} />
                <For each={spinePath()}>
                  {(point, index) => (
                    <circle cx={point.x} cy={point.y} r={index() === spinePath().length - 1 ? 4.5 : 3.2} classList={{ head: index() === spinePath().length - 1 }} />
                  )}
                </For>
              </svg>
            </Show>
          </div>
        </Show>
      </div>
    </div>
  );
}

function TraceRowView(props: {
  row: TraceRow;
  rowH: number;
  laneX: number;
  selected: boolean;
  onPath: boolean;
  dimmed: boolean;
  onSelect: (id: string) => void;
}) {
  const event = () => props.row.event;
  return (
    <button
      type="button"
      classList={{
        "trace-row": true,
        selected: props.selected,
        "on-path": props.onPath && !props.selected,
        dimmed: props.dimmed && !props.selected,
      }}
      onClick={() => props.onSelect(event().idText)}
    >
      <span class="trace-id">#{event().idText}</span>
      <span class="trace-track">
        <Show
          when={event().kind === "schedule_decision"}
          fallback={
            <span
              classList={{
                "trace-marker": true,
                warning: props.row.tone === "warning",
                failure: props.row.tone === "failure",
                "is-finding": props.row.finding !== null,
              }}
              style={`left:${props.laneX}px;`}
            />
          }
        >
          <span class="retry-pip" style={`left:${props.laneX}px;`} />
        </Show>
      </span>
      <span class="event-summary">
        <span class="event-kind">{event().kind}</span>
        <span class="event-label">{event().label || event().typeName || "—"}</span>
        <Show when={event().status}>
          <span class="event-detail">{event().status}</span>
        </Show>
        <Show when={props.row.finding}>
          {(finding) => <span classList={{ "row-finding": true, fail: finding().severity === "fail", warn: finding().severity === "warn" }}>#{finding().index}</span>}
        </Show>
      </span>
    </button>
  );
}

function spanStyle(x: number, startIndex: number, endIndex: number, rowH: number): string {
  const top = (startIndex + 0.5) * rowH;
  const height = Math.max((endIndex - startIndex) * rowH, 4);
  return `left:${x}px;top:${top}px;height:${height}px;`;
}

function polyline(points: Array<{ x: number; y: number }>): string {
  return points.map((point, index) => `${index === 0 ? "M" : "L"}${point.x} ${point.y}`).join(" ");
}
