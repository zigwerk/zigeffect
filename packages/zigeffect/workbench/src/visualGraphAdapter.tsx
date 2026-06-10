import { Graph, createGraphData, createGraphLayout } from "@dschz/solid-g6";
import type { VisualGraphLayoutMode, VisualGraphModel, VisualGraphNodeTone } from "./causalArtifact";

export const visualGraphAdapterMetadata = {
  solid: "@dschz/solid-g6",
  engine: "@antv/g6",
  directEngineApi: "not-required",
} as const;

export function VisualGraphCanvas(props: { model: VisualGraphModel }) {
  return (
    <Graph
      data={solidG6Data(props.model)}
      layout={solidG6Layout(props.model.layoutMode)}
      behaviors={["drag-canvas", "zoom-canvas"]}
      style={{ width: "100%", height: "100%" }}
    />
  );
}

export function solidG6Data(model: VisualGraphModel) {
  return createGraphData({
    nodes: model.nodes.map((node) => ({
      id: node.id,
      data: {
        label: node.label,
        kind: node.kind,
        status: node.status,
        lane: node.lane,
        tone: node.tone,
        fill: toneFill(node.tone),
      },
    })),
    edges: model.edges.map((edge) => ({
      id: edge.id,
      source: edge.source,
      target: edge.target,
      data: {
        label: edge.label,
      },
    })),
  });
}

export function solidG6Layout(mode: VisualGraphLayoutMode) {
  if (mode === "force") {
    return createGraphLayout<Record<string, unknown>>({
      type: "force",
      preventOverlap: true,
    });
  }

  if (mode === "radial") {
    return createGraphLayout<Record<string, unknown>>({
      type: "radial",
    });
  }

  return createGraphLayout<Record<string, unknown>>({
    type: "dagre",
  });
}

function toneFill(tone: VisualGraphNodeTone): string {
  if (tone === "failure") return "#fff1db";
  if (tone === "warning") return "#fff7df";
  return "#eff9f3";
}
