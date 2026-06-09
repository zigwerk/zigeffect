# zigeffect Causal Workbench Graphs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a richer read-only graph investigation surface to the SolidJS causal workbench.

**Architecture:** Keep graph derivation in pure TypeScript model functions under `causalArtifact.ts`, then render the derived graph in `App.tsx`. The UI remains a dense local WebUI tool with no source mutation, no registry edits, and no policy decisions.

**Tech Stack:** Bun, SolidJS, TypeScript, Vite, Zig WebUI launcher already present.

---

## Files

- Modify: `packages/zigeffect/workbench/src/causalArtifact.ts`
  - Add graph model types and pure derivation helpers.
- Modify: `packages/zigeffect/workbench/src/causalArtifact.test.ts`
  - Add red/green tests for graph model, cause paths, lanes, orphan handling,
    and loop tolerance.
- Modify: `packages/zigeffect/workbench/src/App.tsx`
  - Replace the simple Graph tab with a cause path, lane summary, lane cards,
    edge list, and orphan section.
- Modify: `packages/zigeffect/workbench/src/styles.css`
  - Add responsive styling for graph summary, cause path, lane cards, edge
    rows, and orphan rows.
- Modify: `packages/zigeffect/README.md`
  - Mention that the Graph tab now surfaces cause paths and runtime lanes.
- Modify: `docs/superpowers/specs/2026-06-09-zigeffect-causal-workbench-graphs-design.md`
  - Keep design current if implementation details change.

## Task 1: Pure Graph Model

**Files:**
- Modify: `packages/zigeffect/workbench/src/causalArtifact.ts`
- Modify: `packages/zigeffect/workbench/src/causalArtifact.test.ts`

- [x] **Step 1: Write failing tests**

Add tests that assert:

```ts
const model = deriveWorkbenchModel(parseArtifactJson(sampleArtifact), {
  artifactPath: "artifact.json",
});
const graph = deriveGraphModel(model.events, model.findings);

expect(graph.roots.map((event) => event.idText)).toEqual(["1"]);
expect(graph.parentEdges.map((edge) => `${edge.from}->${edge.to}`)).toContain("2->5");
expect(causePathForEvent(model.events, "5").map((event) => event.idText)).toEqual(["1", "2", "5"]);
expect(graph.lanes.some((lane) => lane.kind === "resource" && lane.status === "warning")).toBe(true);
expect(graph.lanes.some((lane) => lane.kind === "retry" && lane.status === "warning")).toBe(true);
```

Add a second test for missing parent ids:

```ts
function minimalEvent(idText: string): CausalEvent {
  return {
    idText,
    numericId: Number(idText),
    kind: "unknown",
    status: "unknown",
    label: "",
    typeName: "",
    redactedDetail: "",
    runId: null,
    parentId: null,
    fiberId: null,
    scopeId: null,
    traceId: null,
    spanId: null,
    raw: { id: Number(idText) },
  };
}

const graph = deriveGraphModel([
  { ...minimalEvent("1"), parentId: null },
  { ...minimalEvent("2"), parentId: "missing" },
], []);

expect(graph.orphans.map((event) => event.idText)).toEqual(["2"]);
expect(causePathForEvent(graph.orphans, "2").map((event) => event.idText)).toEqual(["2"]);
```

Add a loop-tolerance test:

```ts
const events = [
  { ...minimalEvent("1"), parentId: "2" },
  { ...minimalEvent("2"), parentId: "1" },
];

expect(causePathForEvent(events, "1").map((event) => event.idText)).toEqual(["2", "1"]);
```

- [x] **Step 2: Run tests to verify red**

Run:

```sh
bun run zigeffect:workbench:test
```

Expected: fail because `deriveGraphModel`, `causePathForEvent`, and graph
types do not exist.

- [x] **Step 3: Implement minimal graph model**

Add exported types:

```ts
export type GraphEdge = {
  from: string;
  to: string;
  kind: "parent";
  label: string;
};

export type GraphLane = {
  kind: "run" | "scope" | "fiber" | "resource" | "retry";
  key: string;
  label: string;
  status: "ok" | "warning" | "failure";
  events: CausalEvent[];
  findingEventIds: string[];
};

export type GraphModel = {
  roots: CausalEvent[];
  orphans: CausalEvent[];
  parentEdges: GraphEdge[];
  lanes: GraphLane[];
  unhealthyLanes: GraphLane[];
};
```

Implement:

- `deriveGraphModel(events, findings)`;
- `causePathForEvent(events, eventId)`;
- grouping helpers for run, scope, fiber, resource, and retry lanes;
- health helper that marks failure/warning/ok from status and finding event ids.

- [x] **Step 4: Run focused tests to verify green**

Run:

```sh
bun run zigeffect:workbench:test
```

Expected: all workbench tests pass.

- [x] **Step 5: Commit**

```sh
git add packages/zigeffect/workbench/src/causalArtifact.ts packages/zigeffect/workbench/src/causalArtifact.test.ts
git commit -m "feat(zigeffect): derive workbench graph model"
```

## Task 2: Rich Graph Tab UI

**Files:**
- Modify: `packages/zigeffect/workbench/src/App.tsx`
- Modify: `packages/zigeffect/workbench/src/styles.css`

- [x] **Step 1: Write failing UI/model integration test**

Extend the model test, not a DOM test, to assert graph summary fields that the
UI will render:

```ts
expect(graph.parentEdges.length).toBe(8);
expect(graph.unhealthyLanes.length).toBeGreaterThan(0);
```

Run:

```sh
bun run zigeffect:workbench:test
```

Expected: fail until `unhealthyLanes` and edge counts are implemented exactly.

- [x] **Step 2: Render graph summary and cause path**

In `App.tsx`, update `Graph` props to include:

```ts
function Graph(props: {
  events: CausalEvent[];
  findings: ReturnType<typeof deriveWorkbenchModel>["findings"];
  selected: CausalEvent | null;
  onSelect: (id: string) => void;
})
```

Inside `Graph`, derive:

```ts
const graph = createMemo(() => deriveGraphModel(props.events, props.findings));
const path = createMemo(() => props.selected ? causePathForEvent(props.events, props.selected.idText) : []);
```

Render:

- summary metrics for roots, parent edges, runtime lanes, unhealthy lanes, and
  orphans;
- cause path strip with clickable event chips;
- lane cards grouped by lane kind;
- relationship edge list;
- orphan list when present.

- [x] **Step 3: Add responsive styles**

Add CSS classes:

- `.graph-summary`
- `.cause-path`
- `.cause-chip`
- `.lane-board`
- `.lane-section`
- `.lane-card`
- `.lane-card.failure`
- `.lane-card.warning`
- `.lane-events`
- `.orphan-list`

Keep the same palette and 6px radius style already used in the workbench.

- [x] **Step 4: Run focused checks**

Run:

```sh
bun run zigeffect:workbench:test
bun run zigeffect:workbench:typecheck
bun run zigeffect:workbench:build
```

Expected: all pass.

- [x] **Step 5: Browser verify desktop/mobile**

Run:

```sh
bun run zigeffect:workbench:dev -- --port 5178
```

Open `http://127.0.0.1:5178/`, switch to Graph, and verify:

- graph summary is visible;
- cause path updates when selecting event `#5`;
- lane cards render resources/retries/scopes/fibers;
- mobile viewport has no horizontal overflow.

Result: browser verification passed on 2026-06-09. The Graph tab rendered
roots, edges, lanes, unhealthy lanes, and orphan counts; selecting event `#5`
updated the inspector to `fiber_forked` and the cause path to `#1 -> #2 -> #5`;
mobile viewport `390x844` had no document or element horizontal overflow; the
browser console had no errors.

- [x] **Step 6: Commit**

```sh
git add packages/zigeffect/workbench/src/App.tsx packages/zigeffect/workbench/src/styles.css
git commit -m "feat(zigeffect): enrich causal workbench graph tab"
```

## Task 3: Docs And Final Verification

**Files:**
- Modify: `packages/zigeffect/README.md`
- Modify: `docs/superpowers/specs/2026-06-09-zigeffect-causal-workbench-graphs-design.md`
- Modify: `docs/superpowers/plans/2026-06-09-zigeffect-causal-workbench-graphs.md`

- [x] **Step 1: Update README**

Add one sentence near the workbench command:

```md
The Graph tab derives cause paths, parent edges, and runtime lanes for runs,
scopes, fibers, resources, and retries from the selected artifact.
```

- [x] **Step 2: Run full verification**

Run:

```sh
bun run check
bun run zig:test
git diff --check
```

Expected:

- `bun run check` passes;
- `bun run zig:test` passes;
- `git diff --check` exits zero.

Result: all three commands passed on 2026-06-09.

- [x] **Step 3: Commit**

```sh
git add packages/zigeffect/README.md docs/superpowers/specs/2026-06-09-zigeffect-causal-workbench-graphs-design.md docs/superpowers/plans/2026-06-09-zigeffect-causal-workbench-graphs.md
git commit -m "docs(zigeffect): document workbench graph view"
```

## Self-Review

- Spec coverage: the plan covers pure graph derivation, UI rendering, responsive
  behavior, docs, and verification.
- Placeholder scan: no placeholder markers are present.
- Scope check: remediation-chain loading is intentionally out of this plan and
  remains a follow-up slice because it needs multi-artifact chain loading.
