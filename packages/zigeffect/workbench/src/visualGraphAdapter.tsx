import { Show } from "solid-js";
import { Graph, createGraphData, createGraphLayout } from "@dschz/solid-g6";
import type { VisualGraphModel, VisualGraphNodeTone } from "./causalArtifact";

export const visualGraphAdapterMetadata = {
  solid: "@dschz/solid-g6",
  engine: "@antv/g6",
  directEngineApi: "not-required",
} as const;

export function VisualGraphCanvas(props: { model: VisualGraphModel }) {
  return (
    <Show when={props.model} keyed>
      {(model) => (
        <Graph
          data={solidG6Data(model)}
          layout={solidG6Layout(model)}
          behaviors={["drag-canvas", "zoom-canvas"]}
          style={{ width: "100%", height: "100%" }}
        />
      )}
    </Show>
  );
}

export function solidG6Data(model: VisualGraphModel) {
  return createGraphData({
    nodes: model.nodes.map((node) => ({
      id: node.id,
      data: {
        label: node.label,
        detail: node.detail,
        kind: node.kind,
        status: node.status,
        lane: node.lane,
        group: node.group,
        tone: node.tone,
        priority: node.priority,
        fill: toneFill(node.tone),
        stroke: toneStroke(node.tone),
      },
    })),
    edges: model.edges.map((edge) => ({
      id: edge.id,
      source: edge.source,
      target: edge.target,
      data: {
        label: edge.label,
        detail: edge.detail,
        kind: edge.kind,
        tone: edge.tone,
        stroke: toneStroke(edge.tone),
      },
    })),
  });
}

export function solidG6Layout(model: VisualGraphModel) {
  if (model.layoutMode === "force") {
    return createGraphLayout<Record<string, unknown>>({
      type: "force",
      preventOverlap: true,
    });
  }

  if (model.layoutMode === "radial") {
    return createGraphLayout<Record<string, unknown>>({
      type: "radial",
      unitRadius: model.perspective === "ownership" ? 120 : 90,
    });
  }

  return createGraphLayout<Record<string, unknown>>({
    type: "dagre",
    rankdir: "LR",
  });
}

function toneFill(tone: VisualGraphNodeTone): string {
  if (tone === "failure") return "#fff1db";
  if (tone === "warning") return "#fff7df";
  return "#eff9f3";
}

function toneStroke(tone: VisualGraphNodeTone): string {
  if (tone === "failure") return "#b45309";
  if (tone === "warning") return "#c08403";
  return "#40835b";
}
