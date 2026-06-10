# zigeffect Causal Workbench Graph Visual Debugging Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the Visual Graph tab into a read-only debugging surface with cause, topology, ownership, and lineage perspectives backed by richer graph model data and browser-verified G6 rendering.

**Architecture:** Keep graph semantics in pure TypeScript derivation inside `causalArtifact.ts`, map that model through the Solid G6 adapter in `visualGraphAdapter.tsx`, and render compact controls/details in `App.tsx`. The branch remains local, read-only, and mutation-authority-free.

**Tech Stack:** Bun test runner, TypeScript, SolidJS, Vite, `@dschz/solid-g6`, `@antv/g6`, Zig causal reporting tools.

---

## File Structure

- Modify `packages/zigeffect/workbench/src/causalArtifact.ts`
  - Add perspective, node group, edge kind, legend, warnings, refs, and detail metadata.
  - Extend `deriveVisualGraphModel` with perspective and selected-event options while keeping current callers compatible.
- Modify `packages/zigeffect/workbench/src/causalArtifact.test.ts`
  - Add focused tests for cause, topology, ownership, lineage, and live stream fallback graph models.
- Modify `packages/zigeffect/workbench/src/workbenchBridge.ts`
  - Add `?sample=visual-graph` route.
- Modify `packages/zigeffect/workbench/src/workbenchBridge.test.ts`
  - Test that the new sample loads.
- Create `packages/zigeffect/workbench/public/sample-visual-graph-debugging.json`
  - Provide a normal `zigeffect.causal.v1` fixture with runtime and app semantic refs.
- Modify `packages/zigeffect/workbench/src/App.tsx`
  - Add perspective state, perspective controls, graph detail panel, legend, warnings, and richer fallback rows.
- Modify `packages/zigeffect/workbench/src/visualGraphAdapter.tsx`
  - Map group, tone, priority, and edge kind into Solid G6 node/edge data and style.
- Modify `packages/zigeffect/workbench/src/styles.css`
  - Add compact perspective controls, detail/legend/warning panels, group/tone row styles, and responsive graph controls.
- Modify documentation:
  - `packages/zigeffect/docs/production-hardening-backlog.md`
  - `packages/zigeffect/docs/live-dashboard-streaming-workbench.md`
  - `packages/zigeffect/docs/roadmap.md`
  - `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
- Modify `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
  - Mark `workbench-graph-visual-debugging` delivered and recommend `codex/zigeffect-causal-human-agent-feedback-loop`.

---

## Task 1: Pure Visual Graph Perspective Model

**Files:**
- Modify: `packages/zigeffect/workbench/src/causalArtifact.ts`
- Modify: `packages/zigeffect/workbench/src/causalArtifact.test.ts`

- [ ] **Step 1: Add failing perspective tests**

Add tests near the existing `deriveVisualGraphModel` tests:

```ts
test("deriveVisualGraphModel defaults to cause perspective with parent edges", () => {
  const workbench = deriveWorkbenchModel(parseArtifactJson(sampleArtifact), {
    artifactPath: "sample-artifact.json",
  });
  const graph = deriveGraphModel(workbench.events, workbench.findings);
  const visual = deriveVisualGraphModel(workbench, graph, {
    layoutMode: "dagre",
    perspective: "cause",
    selectedEventId: "8",
  });

  expect(visual.perspective).toBe("cause");
  expect(visual.nodes.some((node) => node.id === "event:8" && node.priority === "critical")).toBe(true);
  expect(visual.edges.some((edge) => edge.kind === "parent" && edge.source === "event:2" && edge.target === "event:8")).toBe(true);
  expect(visual.legend.some((entry) => entry.label === "Failure")).toBe(true);
});

test("deriveVisualGraphModel creates topology group nodes for runtime lanes", () => {
  const workbench = deriveWorkbenchModel(parseArtifactJson(sampleArtifact), {
    artifactPath: "sample-artifact.json",
  });
  const graph = deriveGraphModel(workbench.events, workbench.findings);
  const visual = deriveVisualGraphModel(workbench, graph, {
    layoutMode: "force",
    perspective: "topology",
  });

  expect(visual.perspective).toBe("topology");
  expect(visual.nodes.some((node) => node.group === "run" && node.id === "run:1")).toBe(true);
  expect(visual.nodes.some((node) => node.group === "scope" && node.id === "scope:1")).toBe(true);
  expect(visual.edges.some((edge) => edge.kind === "owns" && edge.source === "scope:1" && edge.target === "event:2")).toBe(true);
});

test("deriveVisualGraphModel emphasizes ownership and finalizer failures", () => {
  const workbench = deriveWorkbenchModel(parseArtifactJson(sampleArtifact), {
    artifactPath: "sample-artifact.json",
  });
  const graph = deriveGraphModel(workbench.events, workbench.findings);
  const visual = deriveVisualGraphModel(workbench, graph, {
    layoutMode: "radial",
    perspective: "ownership",
  });

  expect(visual.nodes.some((node) => node.group === "resource" && node.tone === "failure")).toBe(true);
  expect(visual.edges.some((edge) => edge.kind === "finalizes" && edge.target === "event:8")).toBe(true);
  expect(visual.warnings.every((warning) => !warning.includes("mutation"))).toBe(true);
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```sh
bun test --timeout 30000 packages/zigeffect/workbench/src/causalArtifact.test.ts
```

Expected: FAIL because `deriveVisualGraphModel` does not accept an options object and `VisualGraphModel` does not expose `perspective`, `legend`, richer ids, groups, edge kinds, or warnings.

- [ ] **Step 3: Add graph model types**

In `causalArtifact.ts`, replace the current visual graph type block with:

```ts
export type VisualGraphLayoutMode = "dagre" | "force" | "radial";

export type VisualGraphPerspective = "cause" | "topology" | "ownership" | "lineage";

export type VisualGraphNodeTone = "ok" | "warning" | "failure";

export type VisualGraphNodePriority = "normal" | "watch" | "critical";

export type VisualGraphNodeGroup =
  | "event"
  | "run"
  | "scope"
  | "fiber"
  | "resource"
  | "retry"
  | "service"
  | "artifact"
  | "data";

export type VisualGraphEdgeKind =
  | "parent"
  | "caused_by"
  | "owns"
  | "finalizes"
  | "requires"
  | "reads"
  | "writes"
  | "transforms"
  | "emits";

export type VisualGraphRefSet = {
  artifactId: string | null;
  domainEntityRef: string | null;
  dataSubjectRef: string | null;
  schemaRef: string | null;
};

export type VisualGraphLegendEntry = {
  id: string;
  label: string;
  tone: VisualGraphNodeTone;
  detail: string;
};

export type VisualGraphNode = {
  id: string;
  eventId: string | null;
  label: string;
  detail: string;
  kind: string;
  status: string;
  lane: string;
  group: VisualGraphNodeGroup;
  refs: VisualGraphRefSet;
  tone: VisualGraphNodeTone;
  priority: VisualGraphNodePriority;
};

export type VisualGraphEdge = {
  id: string;
  source: string;
  target: string;
  label: string;
  detail: string;
  kind: VisualGraphEdgeKind;
  tone: VisualGraphNodeTone;
};

export type VisualGraphModel = {
  perspective: VisualGraphPerspective;
  layoutMode: VisualGraphLayoutMode;
  nodes: VisualGraphNode[];
  edges: VisualGraphEdge[];
  legend: VisualGraphLegendEntry[];
  warnings: string[];
  adapter: {
    solid: "@dschz/solid-g6";
    engine: "@antv/g6";
    directEngineApi: "not-required";
  };
};

export type VisualGraphOptions = {
  layoutMode: VisualGraphLayoutMode;
  perspective?: VisualGraphPerspective;
  selectedEventId?: string | null;
  liveDashboard?: LiveDashboardModel | null;
};
```

- [ ] **Step 4: Implement minimal cause/topology/ownership model**

Change `deriveVisualGraphModel` to accept either the old signature or the new options object:

```ts
export function deriveVisualGraphModel(
  workbench: WorkbenchModel,
  graph: GraphModel,
  optionsOrLayout: VisualGraphOptions | VisualGraphLayoutMode,
  legacyLiveDashboard?: LiveDashboardModel | null,
): VisualGraphModel {
  const options: VisualGraphOptions = typeof optionsOrLayout === "string"
    ? { layoutMode: optionsOrLayout, perspective: "cause", liveDashboard: legacyLiveDashboard }
    : optionsOrLayout;
  const perspective = options.perspective ?? "cause";
  const liveDashboard = options.liveDashboard ?? null;
  const warnings: string[] = [];
  const eventNodes = visualEventNodes(workbench, options.selectedEventId ?? null);
  const parentEdges = visualParentEdges(graph.parentEdges);
  const streamNodes = visualStreamNodes(liveDashboard);
  const streamEdges = visualStreamEdges(liveDashboard, streamNodes);
  const baseNodes = eventNodes.length > 0 ? eventNodes : streamNodes;
  const baseEdges = eventNodes.length > 0 ? parentEdges : streamEdges;
  const perspectiveGraph = applyVisualGraphPerspective(perspective, workbench, graph, baseNodes, baseEdges, warnings);

  return {
    perspective,
    layoutMode: options.layoutMode,
    nodes: perspectiveGraph.nodes,
    edges: perspectiveGraph.edges,
    legend: visualGraphLegend(),
    warnings,
    adapter: {
      solid: "@dschz/solid-g6",
      engine: "@antv/g6",
      directEngineApi: "not-required",
    },
  };
}
```

Add helpers in the same file:

```ts
function visualGraphLegend(): VisualGraphLegendEntry[] {
  return [
    { id: "ok", label: "OK", tone: "ok", detail: "No finding or failure evidence" },
    { id: "warning", label: "Warning", tone: "warning", detail: "Finding, pending, missing, exhausted, or running evidence" },
    { id: "failure", label: "Failure", tone: "failure", detail: "Failure or critical evidence" },
  ];
}

function visualEmptyRefs(): VisualGraphRefSet {
  return {
    artifactId: null,
    domainEntityRef: null,
    dataSubjectRef: null,
    schemaRef: null,
  };
}

function visualRefsForEvent(event: CausalEvent): VisualGraphRefSet {
  return {
    artifactId: event.artifactId || null,
    domainEntityRef: event.domainEntityRef || null,
    dataSubjectRef: event.dataSubjectRef || null,
    schemaRef: event.schemaRef || null,
  };
}
```

Use existing `visualNodeTone`, `visualStreamFrameTone`, and `eventLaneLabel` for tone and lane derivation.

- [ ] **Step 5: Run focused tests**

Run:

```sh
bun test --timeout 30000 packages/zigeffect/workbench/src/causalArtifact.test.ts
```

Expected: PASS for the existing visual graph tests and the new cause/topology/ownership tests.

- [ ] **Step 6: Commit model slice**

Run:

```sh
git add packages/zigeffect/workbench/src/causalArtifact.ts packages/zigeffect/workbench/src/causalArtifact.test.ts
git commit -m "feat(zigeffect): derive graph debugging perspectives"
```

---

## Task 2: Lineage Perspective And Visual Graph Fixture

**Files:**
- Modify: `packages/zigeffect/workbench/src/causalArtifact.ts`
- Modify: `packages/zigeffect/workbench/src/causalArtifact.test.ts`
- Modify: `packages/zigeffect/workbench/src/workbenchBridge.ts`
- Modify: `packages/zigeffect/workbench/src/workbenchBridge.test.ts`
- Create: `packages/zigeffect/workbench/public/sample-visual-graph-debugging.json`

- [ ] **Step 1: Add failing lineage and bridge tests**

Add to `causalArtifact.test.ts`:

```ts
test("deriveVisualGraphModel creates lineage ref nodes from app semantic refs", () => {
  const raw = {
    schema: "zigeffect.causal.v1",
    schema_version: 1,
    event_taxonomy_version: 1,
    events: [
      {
        id: 1,
        kind: "span_recorded",
        label: "load project",
        status: "success",
        artifact_id: "artifact:response:project",
        domain_entity_ref: "project:123",
        data_subject_ref: "tenant:acme",
        schema_ref: "Project.v1",
      },
    ],
  };
  const workbench = deriveWorkbenchModel(raw, { artifactPath: "lineage.json" });
  const graph = deriveGraphModel(workbench.events, workbench.findings);
  const visual = deriveVisualGraphModel(workbench, graph, {
    layoutMode: "radial",
    perspective: "lineage",
  });

  expect(visual.nodes.some((node) => node.group === "data" && node.id === "data-subject:tenant:acme")).toBe(true);
  expect(visual.nodes.some((node) => node.group === "artifact" && node.id === "artifact:artifact:response:project")).toBe(true);
  expect(visual.edges.some((edge) => edge.kind === "reads" || edge.kind === "emits")).toBe(true);
});
```

Add to `workbenchBridge.test.ts`:

```ts
test("loadPayloadFromBridge can load the graph visual debugging development sample", async () => {
  const payload = await loadPayloadFromBridge({
    search: "?sample=visual-graph",
    call: async () => {
      throw new Error("webui bridge should not be used for development samples");
    },
  });

  expect(payload.session.artifact_path).toBe("sample-visual-graph-debugging.json");
  expect(payload.artifactJson).toContain("Project.v1");
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```sh
bun test --timeout 30000 packages/zigeffect/workbench/src/causalArtifact.test.ts packages/zigeffect/workbench/src/workbenchBridge.test.ts
```

Expected: FAIL because lineage ref nodes and `?sample=visual-graph` do not exist yet.

- [ ] **Step 3: Implement lineage graph nodes and edges**

Add lineage helper functions in `causalArtifact.ts`:

```ts
function applyLineagePerspective(nodes: VisualGraphNode[], edges: VisualGraphEdge[], warnings: string[]): {
  nodes: VisualGraphNode[];
  edges: VisualGraphEdge[];
} {
  const nextNodes = [...nodes];
  const nextEdges = [...edges];
  const seen = new Set(nextNodes.map((node) => node.id));

  for (const node of nodes) {
    const refs = [
      { id: node.refs.dataSubjectRef, group: "data" as const, prefix: "data-subject", kind: "data_subject", edge: "reads" as const },
      { id: node.refs.domainEntityRef, group: "data" as const, prefix: "domain-entity", kind: "domain_entity", edge: "writes" as const },
      { id: node.refs.schemaRef, group: "data" as const, prefix: "schema", kind: "schema", edge: "transforms" as const },
      { id: node.refs.artifactId, group: "artifact" as const, prefix: "artifact", kind: "artifact", edge: "emits" as const },
    ];

    for (const ref of refs) {
      if (!ref.id) continue;
      const refNodeId = `${ref.prefix}:${ref.id}`;
      if (!seen.has(refNodeId)) {
        seen.add(refNodeId);
        nextNodes.push({
          id: refNodeId,
          eventId: null,
          label: ref.id,
          detail: ref.kind,
          kind: ref.kind,
          status: "reference",
          lane: "lineage",
          group: ref.group,
          refs: visualEmptyRefs(),
          tone: "ok",
          priority: "normal",
        });
      }
      nextEdges.push({
        id: `${node.id}->${refNodeId}:${ref.edge}`,
        source: node.id,
        target: refNodeId,
        label: ref.edge,
        detail: `${node.label} ${ref.edge} ${ref.id}`,
        kind: ref.edge,
        tone: node.tone,
      });
    }
  }

  if (nextNodes.length === nodes.length) {
    warnings.push("lineage perspective found no app semantic refs in this artifact");
  }

  return { nodes: nextNodes, edges: nextEdges };
}
```

Wire it through `applyVisualGraphPerspective`.

- [ ] **Step 4: Add the graph debugging fixture**

Create `packages/zigeffect/workbench/public/sample-visual-graph-debugging.json`:

```json
{
  "schema": "zigeffect.causal.v1",
  "schema_version": 1,
  "event_taxonomy_version": 1,
  "events": [
    {
      "id": 1,
      "kind": "run_started",
      "run_id": 1,
      "parent_id": null,
      "label": "graph debugging run",
      "type_name": "GraphDebugHarness",
      "status": "ok",
      "redacted_detail": ""
    },
    {
      "id": 2,
      "kind": "scope_opened",
      "run_id": 1,
      "parent_id": 1,
      "scope_id": 7,
      "label": "request scope",
      "status": "opened",
      "redacted_detail": ""
    },
    {
      "id": 3,
      "kind": "service_required",
      "run_id": 1,
      "parent_id": 2,
      "label": "ProjectService",
      "type_name": "ProjectService",
      "status": "missing",
      "redacted_detail": "provider missing"
    },
    {
      "id": 4,
      "kind": "fiber_forked",
      "run_id": 1,
      "parent_id": 2,
      "fiber_id": 42,
      "scope_id": 7,
      "label": "load project fiber",
      "status": "pending",
      "redacted_detail": ""
    },
    {
      "id": 5,
      "kind": "resource_acquired",
      "run_id": 1,
      "parent_id": 2,
      "scope_id": 7,
      "label": "ProjectConnection",
      "type_name": "ProjectConnection",
      "status": "success",
      "redacted_detail": "left open"
    },
    {
      "id": 6,
      "kind": "span_recorded",
      "run_id": 1,
      "parent_id": 4,
      "fiber_id": 42,
      "scope_id": 7,
      "label": "load project",
      "type_name": "zigeffect.app.data_read",
      "status": "success",
      "artifact_id": "artifact:project-response",
      "domain_entity_ref": "project:123",
      "data_subject_ref": "tenant:acme",
      "schema_ref": "Project.v1",
      "redacted_detail": "semantic refs only"
    },
    {
      "id": 7,
      "kind": "schedule_decision",
      "run_id": 1,
      "parent_id": 4,
      "label": "retry ProjectService",
      "type_name": "Schedule.exponential",
      "status": "exhausted",
      "redacted_detail": "retry budget exhausted"
    },
    {
      "id": 8,
      "kind": "resource_finalized",
      "run_id": 1,
      "parent_id": 2,
      "scope_id": 7,
      "label": "ProjectConnection finalizer",
      "type_name": "ProjectConnection",
      "status": "failure",
      "redacted_detail": "CloseFailed"
    }
  ]
}
```

- [ ] **Step 5: Wire the sample route**

In `workbenchBridge.ts`, add:

```ts
const sampleFiles: Record<string, string> = {
  chain: "sample-chain.json",
  live: "sample-live-dashboard-stream.json",
  "visual-graph": "sample-visual-graph-debugging.json",
};
```

If the file currently uses conditional statements instead of a map, preserve the local pattern and add the `visual-graph` branch.

- [ ] **Step 6: Run focused tests**

Run:

```sh
bun test --timeout 30000 packages/zigeffect/workbench/src/causalArtifact.test.ts packages/zigeffect/workbench/src/workbenchBridge.test.ts
```

Expected: PASS.

- [ ] **Step 7: Commit fixture and lineage slice**

Run:

```sh
git add packages/zigeffect/workbench/src/causalArtifact.ts packages/zigeffect/workbench/src/causalArtifact.test.ts packages/zigeffect/workbench/src/workbenchBridge.ts packages/zigeffect/workbench/src/workbenchBridge.test.ts packages/zigeffect/workbench/public/sample-visual-graph-debugging.json
git commit -m "feat(zigeffect): add graph debugging fixture and lineage view"
```

---

## Task 3: Visual Graph UI Controls And Detail Panels

**Files:**
- Modify: `packages/zigeffect/workbench/src/App.tsx`
- Modify: `packages/zigeffect/workbench/src/styles.css`

- [ ] **Step 1: Add perspective state and imports**

In `App.tsx`, import `VisualGraphPerspective` and add:

```ts
const [graphPerspective, setGraphPerspective] = createSignal<VisualGraphPerspective>("cause");
const [selectedGraphNodeId, setSelectedGraphNodeId] = createSignal<string | null>(null);
```

Update `visualGraph`:

```ts
return deriveVisualGraphModel(current, graph, {
  layoutMode: layoutMode(),
  perspective: graphPerspective(),
  selectedEventId: selectedId(),
  liveDashboard: liveDashboard(),
});
```

- [ ] **Step 2: Add graph perspective controls**

Inside `VisualGraphView`, add:

```tsx
const perspectives: Array<{ id: VisualGraphPerspective; label: string }> = [
  { id: "cause", label: "Cause" },
  { id: "topology", label: "Topology" },
  { id: "ownership", label: "Ownership" },
  { id: "lineage", label: "Lineage" },
];
```

Render a second segmented control with `aria-label="Visual graph perspective"`.

- [ ] **Step 3: Add selected graph detail**

Add this component near `VisualGraphFallback`:

```tsx
function VisualGraphDetail(props: {
  model: VisualGraphModel;
  selectedNodeId: string | null;
  selectedEvent: CausalEvent | null;
}) {
  const selectedNode = createMemo(() => (
    props.model.nodes.find((node) => node.id === props.selectedNodeId)
    ?? props.model.nodes.find((node) => node.eventId === props.selectedEvent?.idText)
    ?? null
  ));

  return (
    <section class="visual-detail-panel">
      <div class="lane-section-head">
        <h3>Selection</h3>
        <span>{selectedNode()?.group ?? "none"}</span>
      </div>
      <Show when={selectedNode()} fallback={<EmptyState label="No graph node selected" compact />}>
        {(node) => (
          <div class="visual-detail-body">
            <strong>{node().label}</strong>
            <span>{node().detail}</span>
            <small>{node().kind} / {node().status}</small>
          </div>
        )}
      </Show>
    </section>
  );
}
```

- [ ] **Step 4: Add legend and warnings panels**

Add:

```tsx
function VisualGraphLegend(props: { model: VisualGraphModel }) {
  return (
    <div class="visual-legend-grid">
      <For each={props.model.legend}>
        {(entry) => (
          <span class={`visual-legend-item ${entry.tone}`}>
            <strong>{entry.label}</strong>
            <small>{entry.detail}</small>
          </span>
        )}
      </For>
    </div>
  );
}

function VisualGraphWarnings(props: { warnings: string[] }) {
  return (
    <Show when={props.warnings.length > 0}>
      <section class="warning-panel">
        <div class="lane-section-head">
          <h3>Warnings</h3>
          <span>{props.warnings.length}</span>
        </div>
        <ul>
          <For each={props.warnings}>{(warning) => <li>{warning}</li>}</For>
        </ul>
      </section>
    </Show>
  );
}
```

- [ ] **Step 5: Add CSS for controls and panels**

In `styles.css`, add:

```css
.visual-control-stack {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
  align-items: center;
  justify-content: flex-end;
}

.visual-detail-panel,
.warning-panel {
  border: 1px solid rgba(50, 65, 61, 0.14);
  border-radius: 8px;
  background: #fbfcf8;
  padding: 14px;
}

.visual-detail-body {
  display: grid;
  gap: 6px;
  min-width: 0;
}

.visual-detail-body strong,
.visual-detail-body span,
.visual-detail-body small {
  overflow-wrap: anywhere;
}

.visual-legend-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
  gap: 8px;
}

.visual-legend-item {
  display: grid;
  gap: 3px;
  border: 1px solid rgba(50, 65, 61, 0.14);
  border-radius: 8px;
  padding: 10px;
  background: #fbfcf8;
}
```

- [ ] **Step 6: Run typecheck and build**

Run:

```sh
bun run zigeffect:workbench:typecheck
bun run zigeffect:workbench:build
```

Expected: PASS.

- [ ] **Step 7: Commit UI slice**

Run:

```sh
git add packages/zigeffect/workbench/src/App.tsx packages/zigeffect/workbench/src/styles.css
git commit -m "feat(zigeffect): add visual graph debugging controls"
```

---

## Task 4: Solid G6 Adapter Styling

**Files:**
- Modify: `packages/zigeffect/workbench/src/visualGraphAdapter.tsx`
- Modify: `packages/zigeffect/workbench/src/causalArtifact.test.ts`

- [ ] **Step 1: Add adapter data tests**

Add a focused test that imports `solidG6Data` if the test environment can import TSX modules. If importing TSX is not stable in Bun, add pure helper tests for `deriveVisualGraphModel` fields instead and verify adapter through build and browser.

Preferred test:

```ts
test("visual graph nodes carry group tone and priority for the adapter", () => {
  const workbench = deriveWorkbenchModel(parseArtifactJson(sampleArtifact), {
    artifactPath: "sample-artifact.json",
  });
  const graph = deriveGraphModel(workbench.events, workbench.findings);
  const visual = deriveVisualGraphModel(workbench, graph, {
    layoutMode: "force",
    perspective: "topology",
  });

  expect(visual.nodes.every((node) => node.group.length > 0)).toBe(true);
  expect(visual.edges.every((edge) => edge.kind.length > 0)).toBe(true);
});
```

- [ ] **Step 2: Map richer model fields in the adapter**

In `visualGraphAdapter.tsx`, update `solidG6Data` node mapping:

```ts
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
}
```

Update edge mapping:

```ts
data: {
  label: edge.label,
  detail: edge.detail,
  kind: edge.kind,
  tone: edge.tone,
  stroke: toneStroke(edge.tone),
}
```

Add:

```ts
function toneStroke(tone: VisualGraphNodeTone): string {
  if (tone === "failure") return "#b45309";
  if (tone === "warning") return "#c08403";
  return "#40835b";
}
```

- [ ] **Step 3: Make layouts perspective-aware**

Change `solidG6Layout` to accept the whole model:

```ts
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
```

- [ ] **Step 4: Run focused checks**

Run:

```sh
bun run zigeffect:workbench:test
bun run zigeffect:workbench:typecheck
bun run zigeffect:workbench:build
```

Expected: PASS.

- [ ] **Step 5: Commit adapter slice**

Run:

```sh
git add packages/zigeffect/workbench/src/visualGraphAdapter.tsx packages/zigeffect/workbench/src/causalArtifact.test.ts
git commit -m "feat(zigeffect): style visual graph debugging adapter"
```

---

## Task 5: Documentation And Backlog Handoff

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
- Modify: `packages/zigeffect/docs/live-dashboard-streaming-workbench.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Add failing backlog tests**

In `causal_production_hardening_backlog.zig`, update tests to expect:

```zig
try std.testing.expectEqualStrings(
    "start-human-agent-feedback-loop",
    recommendation,
);
try std.testing.expectEqualStrings(
    "codex/zigeffect-causal-human-agent-feedback-loop",
    recommended_next_branch,
);
try expectBacklogItemStatus("workbench-graph-visual-debugging", "delivered");
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_hardening_backlog.zig
```

Expected: FAIL because the report still recommends graph visual debugging and marks it planned.

- [ ] **Step 3: Update backlog report**

Set:

```zig
pub const recommendation = "start-human-agent-feedback-loop";
pub const recommended_next_branch = "codex/zigeffect-causal-human-agent-feedback-loop";
```

Change the `workbench-graph-visual-debugging` backlog item status to `delivered`, add evidence sources for the workbench graph files, and update `agent_guidance` to point at the delivered Visual Graph perspectives.

- [ ] **Step 4: Update docs**

Update docs with these exact outcomes:

- graph visual debugging delivered;
- Visual Graph supports cause, topology, ownership, and lineage perspectives;
- `?sample=visual-graph` exists;
- browser verification includes desktop/mobile and nonblank G6 canvas evidence;
- next branch is `codex/zigeffect-causal-human-agent-feedback-loop`;
- mutation authority remains `none`.

- [ ] **Step 5: Run report checks**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_production_hardening_backlog.zig
zig build causal-production-hardening-backlog -- --format json
cd ../..
git diff --check
```

Expected: PASS and JSON contains `"recommended_next_branch": "codex/zigeffect-causal-human-agent-feedback-loop"`.

- [ ] **Step 6: Commit docs and backlog slice**

Run:

```sh
git add packages/zigeffect/tools/causal_production_hardening_backlog.zig packages/zigeffect/docs/production-hardening-backlog.md packages/zigeffect/docs/live-dashboard-streaming-workbench.md packages/zigeffect/docs/roadmap.md docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
git commit -m "docs(zigeffect): deliver graph visual debugging handoff"
```

---

## Task 6: Browser Verification And Final Checks

**Files:**
- No source edits expected unless browser verification finds a real defect.

- [ ] **Step 1: Start the workbench dev server**

Run:

```sh
bun run zigeffect:workbench:dev -- --port 5179
```

Expected: Vite reports `Local: http://127.0.0.1:5179/`.

- [ ] **Step 2: Verify desktop graph behavior**

Open:

```text
http://127.0.0.1:5179/?sample=visual-graph
```

Verify:

- buttons include `Cause`, `Topology`, `Ownership`, `Lineage`;
- buttons include `dagre`, `force`, `radial`;
- each perspective reports nonzero nodes;
- each perspective reports nonzero edges except lineage only if the fixture is broken;
- the graph shell contains G6 canvases;
- canvas pixel sampling finds nonblank colored pixels;
- no application exceptions appear in browser console logs.

- [ ] **Step 3: Verify mobile graph behavior**

Set viewport width to 390 and height to 844. Open the same URL and verify:

- no horizontal page overflow;
- perspective and layout controls wrap cleanly;
- fallback node/edge rows are readable;
- graph shell has stable height;
- canvas is nonblank.

- [ ] **Step 4: Run full verification**

Run:

```sh
cd packages/zigeffect
zig build causal-production-hardening-backlog -- --format json
zig build causal-schema-governance -- --format json
zig build examples
zig build test
cd ../..
bun run zigeffect:workbench:test
bun run zigeffect:workbench:typecheck
bun run zigeffect:workbench:build
bun run check
bun run zig:test
git diff --check
```

Expected: all commands exit 0.

- [ ] **Step 5: Final status check**

Run:

```sh
git status --short --branch
git log --oneline --decorate --max-count=12
```

Expected: only pre-existing unrelated dirty files remain unstaged, and the current branch is `codex/zigeffect-causal-workbench-graph-visual-debugging`.

---

## Plan Self-Review

- Spec coverage: Tasks 1-4 cover model, perspectives, fixture, UI, adapter, selection detail, and browser-verifiable canvas rendering. Task 5 covers docs and backlog handoff. Task 6 covers verification.
- Incomplete-marker scan: no incomplete-marker phrases are intentionally present.
- Type consistency: `VisualGraphPerspective`, `VisualGraphNodeGroup`, `VisualGraphEdgeKind`, `VisualGraphOptions`, `VisualGraphModel`, and `?sample=visual-graph` are named consistently across tasks.
