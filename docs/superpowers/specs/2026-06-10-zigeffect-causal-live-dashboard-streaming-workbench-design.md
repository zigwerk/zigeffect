# zigeffect Causal Live Dashboard Streaming Workbench Design

Date: 2026-06-10

## Purpose

This milestone turns the local causal workbench from a static artifact viewer
into the first read-only dashboard surface for bounded causal streams. It is the
bridge between the agent-readable causal spine and the human control-room view:
agents keep using compact queries, while humans can watch the same evidence as
a stream, inspect findings, and move into visual graph exploration without
editing source, approving remediation, or connecting to production telemetry.

The branch is intentionally artifact-first. "Live" means a deterministic local
stream artifact and bounded in-memory session model, not a socket into a
running production system. That choice keeps the work testable, redacted,
reviewable, and useful to development agents before any production dashboard
host exists.

## Current State

The SolidJS workbench currently loads one bounded payload through
`webui-dev/zig-webui`:

- `tools/causal_workbench.zig` exposes `zigeffect_load_artifact` and
  `zigeffect_load_session`;
- `tools/causal_workbench_session.zig` caps the selected artifact at 4 MiB and
  records `zigeffect.causal.workbench-session.v1`;
- `workbench/src/workbenchBridge.ts` loads bridge payloads or development
  samples;
- `workbench/src/causalArtifact.ts` derives timeline, findings, graph lanes,
  governance chain, app remediation, and query-command models from JSON;
- `workbench/src/App.tsx` renders Timeline, Findings, Graph, Chain, Queries,
  Metadata, and Inspector views.

Production hardening has already produced the contracts this slice depends on:
aggregation bundle provenance, NenDB-only retention posture, artifact access
control, unified causal spine, app semantic tracing, bounded agent queries,
encryption-at-rest policy, and alerting integration previews.

The production backlog says this branch should deliver:

- streaming artifact protocol;
- read-only dashboard view;
- bounded live-update fixture;
- Solid G6 graph adapter boundary;
- Visual Graph tab backed by the causal graph model;
- dagre, force, and radial layout fixture;
- SolidJS workbench verification.

## Use Cases

### zigeffect Development Loop

When `zig build causal-test`, `causal-dev-agent`, or a future local harness
emits causal artifacts, an agent should be able to open a stream-shaped record
and reason about frame order, event ids, findings, truncation, and next queries.
The human view should make the same evidence scan-friendly: current status,
latest frames, active findings, unhealthy lanes, and graph shape.

### CI Failure Inspection

CI already uploads causal artifacts on failure. A future CI artifact bundle can
include a bounded stream artifact showing the sequence of important event and
finding updates. Agents can summarize it, and maintainers can open it locally in
the same workbench.

### App-Facing Runtime Understanding

Applications using zigeffect need a way to understand request traces, background
jobs, data lineage, and semantic app events. This branch should make app-shaped
events work in the same dashboard model without inventing a separate app log
schema.

### Production Readiness Without Production Mutation

Production dashboards eventually need live transport, RBAC enforcement, durable
history, alert routing, and incident workflow. This slice deliberately stops
before that line. It defines the read-only model that those systems can feed
later.

### Self-Improving Feedback Loop

The long-term system should let agents compare evidence before and after a
change, detect regressions, propose guarded remediations, and learn from
accepted fixes. The stream dashboard is a feedback surface: it makes the current
runtime state inspectable enough that agents and humans can agree on evidence
before any mutation branch runs.

## Approach

Three approaches were considered.

1. Snapshot-only workbench extension.
   This would add a dashboard view over the current `zigeffect.causal.v1`
   artifact only. It is simple, but it does not test stream ordering,
   truncation, or live-update behavior.

2. Production SSE or WebSocket transport now.
   This would feel live, but it would require a host, transport security,
   production telemetry ingestion, RBAC enforcement, and operational ownership.
   Those are later branches.

3. Bounded local stream artifact and adapter-shaped dashboard.
   This adds a stable schema, deterministic fixture, model derivation, UI, and
   graph adapter boundary now. Later transports can produce the same frame
   shape. This is the chosen approach.

## Scope

In scope:

- Define `zigeffect.causal.live-dashboard-stream.v1` as a record-only local
  stream artifact.
- Add a Zig report/contract command that prints the stream workbench policy,
  frame shape, adapter posture, guardrails, and verification commands.
- Register the schema in schema governance and production backlog docs.
- Add pure TypeScript helpers for deriving a `LiveDashboardModel` from either a
  stream artifact or a normal causal event artifact.
- Add a bounded development sample stream artifact.
- Add a Live tab for stream status, frame window, findings, source links, and
  guardrails.
- Add a Visual Graph tab that derives graph data from the causal model and can
  switch between dagre or hierarchical, force, and radial layout intents.
- Add a graph adapter boundary that imports `@dschz/solid-g6` and keeps
  zigeffect's causal graph model as the source of truth.
- Keep all UI actions read-only: selection, filtering, layout choice, and copy
  commands only.

Out of scope:

- Production telemetry ingestion.
- SSE, WebSocket, polling, or bridge callback streaming from live systems.
- RBAC enforcement, identity providers, or artifact decryption.
- Writing to NenDB or any durable store from the workbench.
- Cockroach adapter work.
- React workbench support.
- Running commands from the UI.
- Applying remediation, registry updates, policy decisions, source edits,
  config changes, migrations, deployments, rollbacks, or pages.

## Stream Artifact Contract

The stream artifact is a deterministic JSON object:

```json
{
  "schema": "zigeffect.causal.live-dashboard-stream.v1",
  "schema_version": 1,
  "mode": "local-fixture",
  "target": "package-tests",
  "source": {
    "snapshot": ".zig-cache/causal-artifacts/zigeffect-causal-dogfood.json",
    "aggregation_bundle": ".zig-cache/causal-artifacts/production-artifact-aggregation.json",
    "access_policy": ".zig-cache/causal-artifacts/artifact-access-control.json",
    "alert_preview": ".zig-cache/causal-artifacts/alerting-integrations.json"
  },
  "stream": {
    "window_policy": "drop-oldest",
    "max_frames": 128,
    "frame_count": 6,
    "truncated": false,
    "redaction": "artifact-redacted"
  },
  "frames": [
    {
      "sequence": 1,
      "event_id": 1,
      "event_kind": "run_started",
      "status": "ok",
      "label": "package test run",
      "lane": "run:1",
      "parent_id": null,
      "finding_kind": null,
      "dashboard_priority": "normal"
    }
  ],
  "layouts": ["dagre", "force", "radial"],
  "adapter": {
    "solid": "@dschz/solid-g6",
    "engine": "@antv/g6",
    "direct_engine_api": "not-required"
  },
  "guardrails": [
    "Read-only dashboard evidence only.",
    "No production telemetry connection is opened.",
    "Mutation authority remains none."
  ]
}
```

Rules:

- `schema` and `schema_version` are required for stream artifacts.
- `frames` is optional for forward tolerance; missing frames derive an empty
  stream with a warning.
- `stream.max_frames` is advisory metadata. The workbench also applies its own
  model window cap.
- `sequence` is the stable order key. Missing sequence values fall back to input
  order.
- `event_id`, `parent_id`, `event_kind`, `status`, `label`, and `lane` are
  display references, not raw payloads.
- `finding_kind` links frames to finding-like states without duplicating
  detailed raw evidence.
- `dashboard_priority` is `normal`, `watch`, or `critical`.
- Source paths are shown as text and converted to workbench commands only for
  JSON paths.

## TypeScript Model

Add these pure model boundaries to `causalArtifact.ts`:

- `LiveStreamFrameModel`
- `LiveDashboardSourceStep`
- `LiveDashboardModel`
- `VisualGraphNode`
- `VisualGraphEdge`
- `VisualGraphLayoutMode`
- `VisualGraphModel`
- `deriveLiveDashboardModel(raw, options, workbenchModel, graphModel)`
- `deriveVisualGraphModel(workbenchModel, graphModel, layoutMode)`

The live dashboard helper accepts both:

- `zigeffect.causal.live-dashboard-stream.v1`, where frames come from
  `artifact.frames`;
- ordinary event artifacts, where frames are derived from normalized
  `WorkbenchModel.events`.

That fallback matters because a developer should be able to open a normal
causal artifact and still see the Live tab summarize the current snapshot as a
static stream.

The visual graph helper converts the existing `GraphModel` into a renderer-free
graph model:

- nodes come from `WorkbenchModel.events`;
- edges come from `GraphModel.parentEdges`;
- node tone comes from status and finding membership;
- selected and cause-path information remain UI state, not model mutation;
- layout mode is metadata passed to the adapter.

## Solid G6 Adapter Boundary

The workbench should use `@dschz/solid-g6` as the SolidJS integration layer over
AntV G6. The package currently exports `Graph`, `createGraphData`, and typed
configuration helpers, and its documentation positions it as a SolidJS wrapper
over G6. `@antv/g6` remains the graph engine dependency. Direct G6 engine API
usage is reserved for gaps that the Solid adapter cannot expose cleanly.

The adapter boundary should live in a focused workbench module rather than in
`causalArtifact.ts`:

- `visualGraphAdapter.tsx` maps `VisualGraphModel` to Solid G6 data and layout
  props;
- the exported component remains read-only;
- the module exposes plain metadata for tests so behavior can be verified
  without canvas inspection;
- UI selection can be added through callbacks, but no graph edit or command
  execution is allowed.

The Visual Graph tab should render a real graph when the adapter builds. If the
canvas cannot initialize in a test or constrained browser, the tab still shows
the same nodes and edges as a deterministic fallback list so the evidence is not
hidden.

## UI

Add two tabs to the existing operational workbench.

### Live

The Live tab is a dense dashboard, not a marketing page:

- status strip: target, mode, frame count, max window, truncation, redaction;
- stream source list with copyable workbench commands for JSON sources;
- priority summary: critical, watch, normal;
- latest frame list with event id, kind, status, lane, finding kind, and label;
- findings panel reusing selected event behavior where possible;
- guardrails and warnings.

### Visual Graph

The Visual Graph tab is the first graph visualization surface:

- segmented layout control: dagre, force, radial;
- visual graph area backed by `@dschz/solid-g6`;
- stable fallback node/edge list;
- selected event, cause path, and unhealthy lane summary;
- no editable graph controls.

The existing Graph tab remains useful as the text-first structural view. Visual
Graph is the canvas-first view. Both read from the same causal graph model.

## Safety And Authority

- The workbench remains a read-only local artifact viewer.
- Stream frames are evidence snapshots, not live authority.
- The UI must show `mutation_authority=none` when present in stream artifacts.
- No network request is made except loading local Vite/WebUI assets and local
  sample artifacts.
- No source, config, registry, policy, migration, deployment, rollback,
  alerting, ticketing, SIEM, paging, or durable-store mutation happens in this
  milestone.
- Redaction state is displayed from artifact metadata; raw payload recovery is
  not attempted.

## Documentation

Add `packages/zigeffect/docs/live-dashboard-streaming-workbench.md` covering:

- command usage;
- stream artifact shape;
- local sample operation;
- graph adapter posture;
- live transport non-goals;
- future transport path;
- agent workflow for inspecting stream artifacts.

Update:

- schema governance docs;
- production hardening backlog docs and tool;
- operations workbench section;
- agent guide workbench section;
- roadmap progress ledger;
- performance budget docs if stream window or UI bounds are recorded.

## Verification

Focused checks:

```sh
cd packages/zigeffect
zig test tools/causal_live_dashboard_streaming_workbench.zig
zig build causal-live-dashboard-streaming-workbench
zig build causal-live-dashboard-streaming-workbench -- --format json
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
cd ../..
bun run zigeffect:workbench:test
bun run zigeffect:workbench:typecheck
bun run zigeffect:workbench:build
```

Browser checks:

```sh
bun run zigeffect:workbench:dev -- --port <free-port>
```

Open:

- `http://127.0.0.1:<port>/?sample=live`;
- `http://127.0.0.1:<port>/?sample=default`.

Verify:

- Live tab renders stream metadata and latest frames;
- Visual Graph tab renders a nonblank graph or deterministic fallback;
- layout control changes mode without changing the causal source model;
- selected event and inspector still work;
- mobile viewport has no horizontal overflow;
- console has no errors.

Integration checks:

```sh
cd packages/zigeffect
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```

## Future Direction

After this branch lands, the next graph-specific branch should deepen visual
debugging:

- richer cause-chain, runtime-topology, scope, fiber, retry, resource, and app
  data-lineage layouts;
- screenshot and canvas-pixel verification;
- graph timeline and finding selection sync;
- performance profiling for larger artifacts;
- decision record on whether `solid-flow` belongs in later editable planning
  surfaces.

Later production dashboard branches can attach real transports to the same
frame contract, but only after durable retention, access enforcement, transport
security, and operational runbooks are in place.
