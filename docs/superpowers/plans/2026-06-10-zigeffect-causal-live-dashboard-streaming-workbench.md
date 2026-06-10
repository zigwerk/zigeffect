# zigeffect Causal Live Dashboard Streaming Workbench Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a record-only live dashboard stream contract and extend the SolidJS/Zig WebUI workbench with Live and Visual Graph tabs backed by the causal graph model.

**Architecture:** Keep the causal artifact model as the source of truth. Add one deterministic Zig contract report for the stream/dashboard milestone, pure TypeScript derivation helpers for stream and visual graph data, a bounded local sample stream, and a Solid G6 adapter boundary that renders read-only graph evidence while falling back to deterministic text evidence if canvas initialization is unavailable.

**Tech Stack:** Zig 0.16 build tools, Bun, TypeScript, SolidJS, Vite, `webui-dev/zig-webui`, `@dschz/solid-g6`, and `@antv/g6`.

---

## Files

- Create: `packages/zigeffect/tools/causal_live_dashboard_streaming_workbench.zig`
  - Record-only report for the stream schema, frame contract, graph adapter boundary, non-goals, and verification commands.
- Modify: `packages/zigeffect/build.zig`
  - Add `causal-live-dashboard-streaming-workbench` build step and tests.
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
  - Register `zigeffect.causal.live-dashboard-stream.v1`.
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
  - Mark `live-dashboard-streaming-workbench` delivered and advance the next recommendation to graph visual debugging.
- Modify: `packages/zigeffect/workbench/src/causalArtifact.ts`
  - Add live dashboard and visual graph model types and derivation helpers.
- Modify: `packages/zigeffect/workbench/src/causalArtifact.test.ts`
  - Add model tests for stream artifacts, snapshot fallback, graph layouts, bounds, source commands, and guardrails.
- Create: `packages/zigeffect/workbench/src/visualGraphAdapter.tsx`
  - Isolate Solid G6 mapping and read-only graph rendering.
- Modify: `packages/zigeffect/workbench/src/App.tsx`
  - Add Live and Visual Graph tabs, layout mode state, and dashboard rendering.
- Modify: `packages/zigeffect/workbench/src/styles.css`
  - Add responsive dashboard and visual graph styling.
- Modify: `packages/zigeffect/workbench/src/workbenchBridge.ts`
  - Add `?sample=live` development sample routing.
- Modify: `packages/zigeffect/workbench/src/workbenchBridge.test.ts`
  - Verify live sample routing.
- Create: `packages/zigeffect/workbench/public/sample-live-dashboard-stream.json`
  - Bounded stream fixture with dagre, force, and radial layout metadata.
- Modify: `package.json`
  - Add `@dschz/solid-g6` and `@antv/g6`.
- Modify: `bun.lock`
  - Bun dependency lock update.
- Create: `packages/zigeffect/docs/live-dashboard-streaming-workbench.md`
  - Operator and agent docs for stream artifacts and the workbench.
- Modify: `packages/zigeffect/docs/schema-governance.md`
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
- Modify: `packages/zigeffect/docs/operations.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `packages/zigeffect/docs/performance-budget.md`
  - Update docs for schema, queue, operations, agent workflow, roadmap, and UI bounds.

## Task 1: Zig Stream Contract Report

**Files:**
- Create: `packages/zigeffect/tools/causal_live_dashboard_streaming_workbench.zig`
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Write failing report tests**

Create `packages/zigeffect/tools/causal_live_dashboard_streaming_workbench.zig` with constants, empty formatting stubs, and tests that describe the contract before the implementation exists:

```zig
const std = @import("std");

pub const live_dashboard_stream_schema = "zigeffect.causal.live-dashboard-stream.v1";
pub const live_dashboard_stream_schema_version: u32 = 1;
pub const live_dashboard_report_schema = "zigeffect.causal.live-dashboard-streaming-workbench.v1";
pub const live_dashboard_report_schema_version: u32 = 1;

test "live dashboard report names schema and hard boundaries" {
    const report = try formatLiveDashboardStreamingWorkbenchText(std.testing.allocator);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, live_dashboard_stream_schema) != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "@dschz/solid-g6") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "production telemetry ingestion") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "mutation authority remains none") != null);
}

test "live dashboard json report is machine readable" {
    const report = try formatLiveDashboardStreamingWorkbenchJson(std.testing.allocator);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.live-dashboard-streaming-workbench.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"stream_schema\": \"zigeffect.causal.live-dashboard-stream.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"solid_adapter\": \"@dschz/solid-g6\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"direct_engine_api\": \"not-required\"") != null);
}
```

- [ ] **Step 2: Run red test**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_live_dashboard_streaming_workbench.zig
```

Expected: FAIL because formatter functions are missing.

- [ ] **Step 3: Implement minimal report**

Add:

```zig
const OutputFormat = enum { text, json };
const generated_by = "causal-live-dashboard-streaming-workbench";
const solid_adapter = "@dschz/solid-g6";
const graph_engine = "@antv/g6";
const direct_engine_api = "not-required";

const frame_fields: []const []const u8 = &.{
    "sequence",
    "event_id",
    "parent_id",
    "event_kind",
    "status",
    "label",
    "lane",
    "finding_kind",
    "dashboard_priority",
};

const layout_modes: []const []const u8 = &.{ "dagre", "force", "radial" };
const non_goals: []const []const u8 = &.{
    "production telemetry ingestion",
    "SSE WebSocket polling or bridge callback transport",
    "Cockroach adapter work",
    "React workbench support",
    "source config registry policy migration deployment rollback alert ticket SIEM page or durable-store mutation",
};
const guardrails: []const []const u8 = &.{
    "read-only dashboard evidence only",
    "mutation authority remains none",
    "stream frames are bounded local evidence",
};
```

Implement text and JSON formatters using the same local JSON helper style as the other tools.

- [ ] **Step 4: Run green test**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_live_dashboard_streaming_workbench.zig
```

Expected: PASS.

- [ ] **Step 5: Add build step**

In `packages/zigeffect/build.zig`, add an executable and test block near the other production-hardening tools:

```zig
const causal_live_dashboard_streaming_workbench_tool = b.addExecutable(.{
    .name = "zigeffect-causal-live-dashboard-streaming-workbench",
    .root_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_live_dashboard_streaming_workbench.zig"),
        .target = target,
        .optimize = optimize,
    }),
});
const run_causal_live_dashboard_streaming_workbench_tool = b.addRunArtifact(causal_live_dashboard_streaming_workbench_tool);
if (b.args) |args| run_causal_live_dashboard_streaming_workbench_tool.addArgs(args);
const causal_live_dashboard_streaming_workbench_step = b.step("causal-live-dashboard-streaming-workbench", "Print causal live dashboard streaming workbench report");
causal_live_dashboard_streaming_workbench_step.dependOn(&run_causal_live_dashboard_streaming_workbench_tool.step);

const causal_live_dashboard_streaming_workbench_tool_tests = b.addTest(.{
    .name = "zigeffect-causal-live-dashboard-streaming-workbench-tests",
    .root_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_live_dashboard_streaming_workbench.zig"),
        .target = target,
        .optimize = optimize,
    }),
});
const run_causal_live_dashboard_streaming_workbench_tool_tests = b.addRunArtifact(causal_live_dashboard_streaming_workbench_tool_tests);
test_step.dependOn(&run_causal_live_dashboard_streaming_workbench_tool_tests.step);
```

- [ ] **Step 6: Verify build step**

Run:

```sh
cd packages/zigeffect
zig build causal-live-dashboard-streaming-workbench
zig build causal-live-dashboard-streaming-workbench -- --format json
```

Expected: both commands print deterministic reports.

- [ ] **Step 7: Commit**

```sh
git add packages/zigeffect/tools/causal_live_dashboard_streaming_workbench.zig packages/zigeffect/build.zig
git commit -m "feat(zigeffect): add live dashboard stream contract"
```

## Task 2: Schema Governance And Backlog Queue

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`

- [ ] **Step 1: Write failing schema/backlog tests**

In `causal_schema_governance.zig`, add expectations for the new schema and bump the count assertion from `43` to `44`:

```zig
try expectSchema(entries, "zigeffect.causal.live-dashboard-stream.v1");
try std.testing.expect(std.mem.indexOf(u8, report, "\"schema_count\": 44") != null);
try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.live-dashboard-stream.v1\"") != null);
```

In `causal_production_hardening_backlog.zig`, update tests to expect:

```zig
try std.testing.expectEqualStrings("start-workbench-graph-visual-debugging", recommendation);
try std.testing.expectEqualStrings("codex/zigeffect-causal-workbench-graph-visual-debugging", recommended_next_branch);
try expectBacklogStatus("live-dashboard-streaming-workbench", "delivered");
```

- [ ] **Step 2: Run red tests**

Run:

```sh
cd packages/zigeffect
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
```

Expected: FAIL until the schema entry and backlog status change.

- [ ] **Step 3: Implement governance entry**

Add schema entry:

```zig
.{
    .schema = "zigeffect.causal.live-dashboard-stream.v1",
    .version = 1,
    .category = "workbench",
    .status = "current",
    .emitted_by = &.{"causal-live-dashboard-streaming-workbench fixture producers"},
    .consumed_by = &.{ "SolidJS workbench", "agents", "future dashboard transports" },
    .compatibility = &.{ "record-only", "bounded-stream" },
    .governance_requirements = &.{ "stream model tests", "workbench sample fixture", "adapter boundary docs" },
},
```

- [ ] **Step 4: Implement backlog advancement**

Change:

```zig
pub const recommendation = "start-workbench-graph-visual-debugging";
pub const recommended_next_branch = "codex/zigeffect-causal-workbench-graph-visual-debugging";
```

Set the `live-dashboard-streaming-workbench` item status to `delivered`, add the new tool/doc evidence sources, and keep `workbench-graph-visual-debugging` planned.

- [ ] **Step 5: Run green tests**

Run:

```sh
cd packages/zigeffect
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
```

Expected: both reports print and include the new schema/status.

- [ ] **Step 6: Commit**

```sh
git add packages/zigeffect/tools/causal_schema_governance.zig packages/zigeffect/tools/causal_production_hardening_backlog.zig
git commit -m "docs(zigeffect): register live dashboard stream schema"
```

## Task 3: Live Dashboard Model

**Files:**
- Modify: `packages/zigeffect/workbench/src/causalArtifact.test.ts`
- Modify: `packages/zigeffect/workbench/src/causalArtifact.ts`

- [ ] **Step 1: Write failing TypeScript tests**

Add imports:

```ts
import {
  deriveLiveDashboardModel,
  deriveVisualGraphModel,
} from "./causalArtifact";
```

Add a `sampleLiveStream` object:

```ts
const sampleLiveStream = {
  schema: "zigeffect.causal.live-dashboard-stream.v1",
  schema_version: 1,
  mode: "local-fixture",
  target: "package-tests",
  mutation_authority: "none",
  source: {
    snapshot: ".zig-cache/causal-artifacts/zigeffect-causal-dogfood.json",
    alert_preview: ".zig-cache/causal-artifacts/alerting-integrations.json",
    compare: ".zig-cache/causal-artifacts/compare.txt",
  },
  stream: {
    window_policy: "drop-oldest",
    max_frames: 4,
    frame_count: 5,
    truncated: true,
    redaction: "artifact-redacted",
  },
  frames: [
    { sequence: 1, event_id: 1, event_kind: "run_started", status: "ok", label: "run", lane: "run:1", parent_id: null, dashboard_priority: "normal" },
    { sequence: 2, event_id: 2, event_kind: "scope_opened", status: "ok", label: "scope", lane: "scope:1", parent_id: 1, dashboard_priority: "normal" },
    { sequence: 3, event_id: 3, event_kind: "service_required", status: "missing", label: "Config", lane: "run:1", parent_id: 2, finding_kind: "service_requirement_without_provider", dashboard_priority: "critical" },
    { sequence: 4, event_id: 4, event_kind: "resource_acquired", status: "success", label: "db", lane: "resource:db", parent_id: 2, dashboard_priority: "watch" },
    { sequence: 5, event_id: 5, event_kind: "fiber_forked", status: "pending", label: "child", lane: "fiber:42", parent_id: 2, finding_kind: "fiber_pending_after_scope_close", dashboard_priority: "watch" },
  ],
  layouts: ["dagre", "force", "radial"],
  guardrails: ["Read-only dashboard evidence only.", "Mutation authority remains none."],
};
```

Add tests:

```ts
test("deriveLiveDashboardModel normalizes bounded stream artifacts", () => {
  const dashboard = deriveLiveDashboardModel(sampleLiveStream, { artifactPath: "live.json" });

  expect(dashboard?.schema).toBe("zigeffect.causal.live-dashboard-stream.v1");
  expect(dashboard?.target).toBe("package-tests");
  expect(dashboard?.mode).toBe("local-fixture");
  expect(dashboard?.mutationAuthority).toBe("none");
  expect(dashboard?.stream.windowPolicy).toBe("drop-oldest");
  expect(dashboard?.stream.maxFrames).toBe(4);
  expect(dashboard?.stream.truncated).toBe(true);
  expect(dashboard?.frames.map((frame) => frame.eventId)).toEqual(["1", "2", "3", "4", "5"]);
  expect(dashboard?.priorityCounts.critical).toBe(1);
  expect(dashboard?.priorityCounts.watch).toBe(2);
  expect(dashboard?.sources.find((source) => source.kind === "snapshot")?.workbenchCommand).toBe(
    "zig build causal-workbench -- .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json",
  );
  expect(dashboard?.sources.find((source) => source.kind === "compare")?.workbenchCommand).toBeNull();
});

test("deriveLiveDashboardModel treats normal causal artifacts as static streams", () => {
  const raw = parseArtifactJson(sampleArtifact);
  const workbench = deriveWorkbenchModel(raw, { artifactPath: "sample-artifact.json" });
  const dashboard = deriveLiveDashboardModel(raw, { artifactPath: "sample-artifact.json" }, workbench);

  expect(dashboard?.schema).toBe("zigeffect.causal.v1");
  expect(dashboard?.mode).toBe("static-snapshot");
  expect(dashboard?.frames.length).toBe(workbench.events.length);
  expect(dashboard?.stream.truncated).toBe(false);
});
```

- [ ] **Step 2: Run red test**

Run:

```sh
bun run zigeffect:workbench:test
```

Expected: FAIL because `deriveLiveDashboardModel` does not exist.

- [ ] **Step 3: Implement model helpers**

Add exported types in `causalArtifact.ts`:

```ts
export type LiveDashboardPriority = "normal" | "watch" | "critical";
export type LiveDashboardSourceStep = {
  kind: string;
  label: string;
  path: string;
  workbenchCommand: string | null;
};
export type LiveStreamFrameModel = {
  sequence: number;
  eventId: string;
  parentId: string | null;
  eventKind: string;
  status: string;
  label: string;
  lane: string;
  findingKind: string | null;
  priority: LiveDashboardPriority;
};
export type LiveDashboardModel = {
  artifactPath: string;
  schema: string;
  schemaVersion: string;
  mode: string;
  target: string;
  mutationAuthority: string | null;
  stream: {
    windowPolicy: string;
    maxFrames: number;
    frameCount: number;
    truncated: boolean;
    redaction: string;
  };
  frames: LiveStreamFrameModel[];
  priorityCounts: Record<LiveDashboardPriority, number>;
  sources: LiveDashboardSourceStep[];
  layouts: VisualGraphLayoutMode[];
  guardrails: string[];
  warnings: string[];
};
```

Implement `deriveLiveDashboardModel` by checking the stream schema first and falling back to `WorkbenchModel.events`.

- [ ] **Step 4: Run green test**

Run:

```sh
bun run zigeffect:workbench:test
bun run zigeffect:workbench:typecheck
```

Expected: all workbench tests pass and TypeScript typecheck passes.

- [ ] **Step 5: Commit**

```sh
git add packages/zigeffect/workbench/src/causalArtifact.ts packages/zigeffect/workbench/src/causalArtifact.test.ts
git commit -m "feat(zigeffect): derive live dashboard stream model"
```

## Task 4: Visual Graph Model And Adapter Boundary

**Files:**
- Modify: `packages/zigeffect/workbench/src/causalArtifact.test.ts`
- Modify: `packages/zigeffect/workbench/src/causalArtifact.ts`
- Create: `packages/zigeffect/workbench/src/visualGraphAdapter.tsx`
- Modify: `package.json`
- Modify: `bun.lock`

- [ ] **Step 1: Install graph dependencies**

Run:

```sh
bun add @dschz/solid-g6 @antv/g6
```

Expected: `package.json` and `bun.lock` update. As of 2026-06-10, `bun pm view` reports `@dschz/solid-g6@0.1.1` and `@antv/g6@5.1.1`.

- [ ] **Step 2: Write failing visual graph model test**

Add:

```ts
test("deriveVisualGraphModel maps causal graph data for read-only layouts", () => {
  const raw = parseArtifactJson(sampleArtifact);
  const workbench = deriveWorkbenchModel(raw, { artifactPath: "sample-artifact.json" });
  const graph = deriveGraphModel(workbench.events, workbench.findings);
  const visual = deriveVisualGraphModel(workbench, graph, "force");

  expect(visual.layoutMode).toBe("force");
  expect(visual.nodes.length).toBe(workbench.events.length);
  expect(visual.edges.length).toBe(graph.parentEdges.length);
  expect(visual.nodes.find((node) => node.id === "3")?.tone).toBe("warning");
  expect(visual.nodes.find((node) => node.id === "8")?.tone).toBe("failure");
  expect(visual.adapter.solid).toBe("@dschz/solid-g6");
  expect(visual.adapter.engine).toBe("@antv/g6");
});
```

- [ ] **Step 3: Run red test**

Run:

```sh
bun run zigeffect:workbench:test
```

Expected: FAIL because `deriveVisualGraphModel` does not exist.

- [ ] **Step 4: Implement visual graph model**

Add:

```ts
export type VisualGraphLayoutMode = "dagre" | "force" | "radial";
export type VisualGraphNodeTone = "ok" | "warning" | "failure";
export type VisualGraphNode = {
  id: string;
  label: string;
  kind: string;
  status: string;
  lane: string;
  tone: VisualGraphNodeTone;
};
export type VisualGraphEdge = {
  id: string;
  source: string;
  target: string;
  label: string;
};
export type VisualGraphModel = {
  layoutMode: VisualGraphLayoutMode;
  nodes: VisualGraphNode[];
  edges: VisualGraphEdge[];
  adapter: {
    solid: "@dschz/solid-g6";
    engine: "@antv/g6";
    directEngineApi: "not-required";
  };
};
```

Implement node tone from status and finding ids. Implement edge ids as `${from}->${to}`.

- [ ] **Step 5: Add adapter component**

Create `visualGraphAdapter.tsx`:

```tsx
import { Graph, createGraphData } from "@dschz/solid-g6";
import type { VisualGraphModel } from "./causalArtifact";

export const visualGraphAdapterMetadata = {
  solid: "@dschz/solid-g6",
  engine: "@antv/g6",
  directEngineApi: "not-required",
} as const;

export function VisualGraphCanvas(props: { model: VisualGraphModel }) {
  const data = () => createGraphData({
    nodes: props.model.nodes.map((node) => ({
      id: node.id,
      data: node,
    })),
    edges: props.model.edges.map((edge) => ({
      source: edge.source,
      target: edge.target,
      data: edge,
    })),
  });

  return (
    <Graph
      data={data()}
      layout={layoutForMode(props.model.layoutMode)}
      style={{ width: "100%", height: "100%" }}
    />
  );
}

function layoutForMode(mode: VisualGraphModel["layoutMode"]) {
  if (mode === "force") return { type: "force", preventOverlap: true };
  if (mode === "radial") return { type: "radial" };
  return { type: "dagre" };
}
```

- [ ] **Step 6: Run green tests**

Run:

```sh
bun run zigeffect:workbench:test
bun run zigeffect:workbench:typecheck
```

Expected: tests and typecheck pass.

- [ ] **Step 7: Commit**

```sh
git add package.json bun.lock packages/zigeffect/workbench/src/causalArtifact.ts packages/zigeffect/workbench/src/causalArtifact.test.ts packages/zigeffect/workbench/src/visualGraphAdapter.tsx
git commit -m "feat(zigeffect): add Solid G6 visual graph adapter boundary"
```

## Task 5: Live Sample Bridge Fixture

**Files:**
- Modify: `packages/zigeffect/workbench/src/workbenchBridge.ts`
- Modify: `packages/zigeffect/workbench/src/workbenchBridge.test.ts`
- Create: `packages/zigeffect/workbench/public/sample-live-dashboard-stream.json`

- [ ] **Step 1: Write failing sample route test**

Add to `workbenchBridge.test.ts`:

```ts
test("loadPayloadFromBridge can load the live dashboard stream development sample", async () => {
  const payload = await loadPayloadFromBridge(
    {},
    async (sampleName) => JSON.stringify({ schema: sampleName }),
    "?sample=live",
  );

  expect(payload.artifactJson).toBe(JSON.stringify({ schema: "sample-live-dashboard-stream.json" }));
  expect(payload.session?.artifact_path).toBe("sample-live-dashboard-stream.json");
});
```

- [ ] **Step 2: Run red test**

Run:

```sh
bun run zigeffect:workbench:test
```

Expected: FAIL because `?sample=live` falls back to `sample-artifact.json`.

- [ ] **Step 3: Add bridge sample route**

In `sampleNameFromSearch`:

```ts
if (sample === "live") return "sample-live-dashboard-stream.json";
```

- [ ] **Step 4: Add sample JSON**

Create `sample-live-dashboard-stream.json` using the schema from the design. Include six frames, JSON source paths for snapshot/access/alerting, one text compare source, layouts `dagre`, `force`, and `radial`, and guardrails that state no production telemetry or mutation authority.

- [ ] **Step 5: Run green test**

Run:

```sh
bun run zigeffect:workbench:test
```

Expected: all workbench tests pass.

- [ ] **Step 6: Commit**

```sh
git add packages/zigeffect/workbench/src/workbenchBridge.ts packages/zigeffect/workbench/src/workbenchBridge.test.ts packages/zigeffect/workbench/public/sample-live-dashboard-stream.json
git commit -m "feat(zigeffect): add live workbench sample stream"
```

## Task 6: Live And Visual Graph UI

**Files:**
- Modify: `packages/zigeffect/workbench/src/App.tsx`
- Modify: `packages/zigeffect/workbench/src/styles.css`

- [ ] **Step 1: Wire model state**

In `App.tsx`, import:

```ts
type LiveDashboardModel,
type LiveStreamFrameModel,
type VisualGraphLayoutMode,
deriveLiveDashboardModel,
deriveVisualGraphModel,
```

Also import:

```ts
import { VisualGraphCanvas } from "./visualGraphAdapter";
```

Add tabs:

```ts
type Tab = "timeline" | "findings" | "live" | "graph" | "visual-graph" | "chain" | "queries" | "metadata";
```

Add layout mode state:

```ts
const [layoutMode, setLayoutMode] = createSignal<VisualGraphLayoutMode>("dagre");
```

Derive:

```ts
const graph = createMemo(() => {
  const current = model();
  return current ? deriveGraphModel(current.events, current.findings) : null;
});
const liveDashboard = createMemo(() => {
  const current = model();
  return parsed()?.raw ? deriveLiveDashboardModel(parsed()!.raw, { artifactPath: current?.artifactPath ?? "sample-artifact.json" }, current ?? undefined) : null;
});
const visualGraph = createMemo(() => {
  const current = model();
  const currentGraph = graph();
  return current && currentGraph ? deriveVisualGraphModel(current, currentGraph, layoutMode()) : null;
});
```

Store `raw` in the `parsed` memo return.

- [ ] **Step 2: Add Live tab renderer**

Add `LiveDashboard` component:

```tsx
function LiveDashboard(props: {
  dashboard: LiveDashboardModel | null;
  copiedCommand: string | null;
  onCopy: (command: string) => void;
  onSelectEvent: (id: string) => void;
}) {
  return (
    <div class="view-stack">
      <div class="view-heading">
        <h2>Live</h2>
        <span>{props.dashboard?.mode ?? "no stream"}</span>
      </div>
      <Show when={props.dashboard} fallback={<EmptyState label="No stream dashboard model" />}>
        {(dashboard) => (
          <>
            <div class="live-summary">
              <Metric label="target" value={dashboard().target} />
              <Metric label="frames" value={String(dashboard().frames.length)} />
              <Metric label="max" value={String(dashboard().stream.maxFrames)} />
              <Metric label="truncated" value={String(dashboard().stream.truncated)} tone={dashboard().stream.truncated ? "warn" : "ok"} />
              <Metric label="authority" value={dashboard().mutationAuthority ?? "none"} tone={dashboard().mutationAuthority === "none" ? "ok" : "warn"} />
            </div>
            <LiveSources sources={dashboard().sources} copiedCommand={props.copiedCommand} onCopy={props.onCopy} />
            <LiveFrameList frames={dashboard().frames} onSelectEvent={props.onSelectEvent} />
            <LiveGuardrails guardrails={dashboard().guardrails} warnings={dashboard().warnings} />
          </>
        )}
      </Show>
    </div>
  );
}
```

- [ ] **Step 3: Add Visual Graph tab renderer**

Add `VisualGraphView` component:

```tsx
function VisualGraphView(props: {
  model: ReturnType<typeof deriveVisualGraphModel> | null;
  layoutMode: VisualGraphLayoutMode;
  onLayoutMode: (mode: VisualGraphLayoutMode) => void;
}) {
  const modes: VisualGraphLayoutMode[] = ["dagre", "force", "radial"];
  return (
    <div class="view-stack">
      <div class="view-heading">
        <h2>Visual Graph</h2>
        <div class="segmented-control">
          <For each={modes}>
            {(mode) => (
              <button type="button" classList={{ active: props.layoutMode === mode }} onClick={() => props.onLayoutMode(mode)}>
                {mode}
              </button>
            )}
          </For>
        </div>
      </div>
      <Show when={props.model} fallback={<EmptyState label="No visual graph model" />}>
        {(model) => (
          <>
            <div class="visual-graph-shell">
              <VisualGraphCanvas model={model()} />
            </div>
            <VisualGraphFallback model={model()} />
          </>
        )}
      </Show>
    </div>
  );
}
```

- [ ] **Step 4: Add styling**

Add CSS classes:

```css
.live-summary {
  display: grid;
  grid-template-columns: repeat(5, minmax(92px, 1fr));
  gap: 8px;
}

.live-frame-list {
  display: grid;
  gap: 8px;
}

.live-frame-row {
  min-height: 54px;
  display: grid;
  grid-template-columns: 58px minmax(0, 1fr) 96px 120px;
  gap: 10px;
  align-items: center;
  padding: 8px 10px;
  border: 1px solid #d6ddd2;
  border-radius: 6px;
  background: #ffffff;
}

.visual-graph-shell {
  min-height: 460px;
  border: 1px solid #d6ddd2;
  border-radius: 6px;
  background: #ffffff;
  overflow: hidden;
}

.segmented-control {
  display: inline-grid;
  grid-auto-flow: column;
  gap: 4px;
}

.segmented-control button.active {
  border-color: #2b7d6b;
  background: #e8f4ee;
  color: #125140;
}
```

Add mobile rules so `.live-summary`, `.live-frame-row`, and `.visual-graph-shell` fit under 760px.

- [ ] **Step 5: Run workbench verification**

Run:

```sh
bun run zigeffect:workbench:test
bun run zigeffect:workbench:typecheck
bun run zigeffect:workbench:build
```

Expected: all pass.

- [ ] **Step 6: Commit**

```sh
git add packages/zigeffect/workbench/src/App.tsx packages/zigeffect/workbench/src/styles.css
git commit -m "feat(zigeffect): render live dashboard and visual graph tabs"
```

## Task 7: Documentation

**Files:**
- Create: `packages/zigeffect/docs/live-dashboard-streaming-workbench.md`
- Modify: `packages/zigeffect/docs/schema-governance.md`
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
- Modify: `packages/zigeffect/docs/operations.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `packages/zigeffect/docs/performance-budget.md`

- [ ] **Step 1: Add live dashboard docs**

Create a doc with sections:

```md
# zigeffect Live Dashboard Streaming Workbench

## Command

cd packages/zigeffect
zig build causal-live-dashboard-streaming-workbench
zig build causal-live-dashboard-streaming-workbench -- --format json

## Stream Schema

The stream artifact schema is `zigeffect.causal.live-dashboard-stream.v1`.
It is record-only and local-fixture safe.

## Workbench

bun run zigeffect:workbench:dev -- --port 5179
open http://127.0.0.1:5179/?sample=live

## Authority

The workbench does not connect to production telemetry, send alerts, open
tickets, edit source, apply policy, update registries, or mutate durable stores.
```

- [ ] **Step 2: Update existing docs**

Add the new command and stream schema to the schema, operations, agent guide,
roadmap, production backlog, and performance budget docs. The backlog docs must
show `live-dashboard-streaming-workbench` delivered and the next branch as
`codex/zigeffect-causal-workbench-graph-visual-debugging`.

- [ ] **Step 3: Verify docs have no stale queue language**

Run:

```sh
rg -n "start-live-dashboard-streaming-workbench|codex/zigeffect-causal-live-dashboard-streaming-workbench|schema_count\": 43|live-dashboard-streaming-workbench` planned" packages/zigeffect/docs docs/superpowers
```

Expected: no stale references outside historical design/plan documents where the old queue is intentionally described.

- [ ] **Step 4: Commit**

```sh
git add packages/zigeffect/docs/live-dashboard-streaming-workbench.md packages/zigeffect/docs/schema-governance.md packages/zigeffect/docs/production-hardening-backlog.md packages/zigeffect/docs/operations.md packages/zigeffect/docs/agent-guide.md packages/zigeffect/docs/roadmap.md packages/zigeffect/docs/performance-budget.md
git commit -m "docs(zigeffect): document live dashboard streaming workbench"
```

## Task 8: Browser Verification

**Files:**
- No planned source edits unless verification finds defects.

- [ ] **Step 1: Start local workbench**

Run:

```sh
bun run zigeffect:workbench:dev -- --port 5179
```

Expected: Vite serves the workbench on `http://127.0.0.1:5179/`.

- [ ] **Step 2: Open live sample**

Use the in-app browser at:

```text
http://127.0.0.1:5179/?sample=live
```

Expected:

- Live tab appears and renders stream summary.
- Visual Graph tab appears.
- Visual graph area is nonblank or fallback evidence is visible.
- Layout buttons switch among dagre, force, and radial.
- There is no horizontal overflow at desktop or mobile viewport.
- Browser console has no app errors.

- [ ] **Step 3: Stop local server**

Stop the Vite process after verification.

- [ ] **Step 4: Commit fixes if needed**

If verification required UI fixes:

```sh
git add packages/zigeffect/workbench/src/App.tsx packages/zigeffect/workbench/src/styles.css packages/zigeffect/workbench/src/visualGraphAdapter.tsx
git commit -m "fix(zigeffect): polish live workbench graph verification"
```

## Task 9: Final Verification

**Files:**
- No planned source edits unless verification finds defects.

- [ ] **Step 1: Run focused suite**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_live_dashboard_streaming_workbench.zig
zig build causal-live-dashboard-streaming-workbench
zig build causal-live-dashboard-streaming-workbench -- --format json
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
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

Expected: all commands pass.

- [ ] **Step 2: Check git status**

Run:

```sh
git status --short
```

Expected: only intentional branch files plus known unrelated pre-existing dirty files are present. Do not stage unrelated files.

- [ ] **Step 3: Commit any final docs/test alignment**

If final verification required small doc or test updates:

```sh
git add <intentional files only>
git commit -m "test(zigeffect): verify live dashboard streaming workbench"
```

## Task 10: Roadmap Handoff

**Files:**
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Update progress ledger**

Add an entry stating that the live dashboard streaming workbench branch delivered the stream schema, local sample, Live tab, Visual Graph tab, Solid G6 boundary, and docs. Set the next branch to:

```text
codex/zigeffect-causal-workbench-graph-visual-debugging
```

- [ ] **Step 2: Commit roadmap handoff**

```sh
git add docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
git commit -m "docs(zigeffect): advance roadmap to visual graph debugging"
```

## Self-Review

Coverage:

- Stream protocol: Tasks 1, 3, 5, and 7.
- Read-only dashboard view: Task 6.
- Bounded live-update fixture: Task 5.
- Solid G6 adapter boundary: Task 4.
- Visual Graph tab backed by causal graph model: Tasks 4 and 6.
- Dagre, force, and radial layout fixture: Tasks 3, 4, 5, and 6.
- SolidJS workbench verification: Tasks 6, 8, and 9.
- Backlog/schema/docs advancement: Tasks 2, 7, and 10.

No placeholders remain. The plan keeps production telemetry, mutation authority,
Cockroach adapter work, and React support out of scope.
