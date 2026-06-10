# zigeffect Causal Workbench Graph Visual Debugging Design

Date: 2026-06-10

## Purpose

This branch deepens the read-only Visual Graph tab that was introduced by the
live dashboard streaming workbench branch. The current visual graph proves the
`@dschz/solid-g6` adapter boundary and renders parent edges for normal causal
artifacts or bounded live stream frames. The next useful step is making that
graph an investigation surface: humans should be able to switch between cause,
runtime topology, ownership, and app lineage perspectives while agents get
stable model fields and fixtures they can cite.

The branch remains part of the causal self-improvement loop. It should help
developers and agents answer why a zigeffect run failed, which runtime objects
were involved, where ownership or finalization went wrong, and how app semantic
events relate to data refs. It must not approve or apply remediation.

## Existing Evidence

The current handoff comes from:

- `packages/zigeffect/docs/production-hardening-backlog.md`, which names
  `codex/zigeffect-causal-workbench-graph-visual-debugging` as the next branch;
- `packages/zigeffect/docs/live-dashboard-streaming-workbench.md`, which says
  this branch should deepen layouts, browser screenshot and canvas-pixel
  verification, timeline/selection synchronization, and graph-debugging
  fixtures;
- `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`,
  which requires cause-chain, runtime-topology, scope/fiber/resource ownership,
  and app data-lineage debugging without making `solid-flow` a default
  dependency;
- the existing workbench files:
  - `packages/zigeffect/workbench/src/causalArtifact.ts`;
  - `packages/zigeffect/workbench/src/visualGraphAdapter.tsx`;
  - `packages/zigeffect/workbench/src/App.tsx`;
  - `packages/zigeffect/workbench/src/styles.css`;
  - `packages/zigeffect/workbench/src/causalArtifact.test.ts`;
  - `packages/zigeffect/workbench/src/workbenchBridge.ts`.

## Design Brief

- Product: local zigeffect causal workbench.
- Renderer: SolidJS inside `webui-dev/zig-webui`.
- Graph adapter: keep `@dschz/solid-g6` over `@antv/g6`.
- Interaction level: read-only visual debugging with local selection, no writes.
- Visual style: dense operational tool, compact controls, stable graph area,
  readable fallback tables, no landing-page or marketing treatment.
- Browser support: desktop and mobile-width workbench verification with
  nonblank canvas evidence.

## Scope

In scope:

- Add explicit visual graph perspectives:
  - `cause`: parent/cause chain investigation;
  - `topology`: runtime lane and relationship topology;
  - `ownership`: scope, fiber, resource, finalizer, and ownership inspection;
  - `lineage`: app semantic refs for reads, writes, transforms, artifacts, and
    responses.
- Extend the pure TypeScript visual graph model with:
  - node `group`, `detail`, `refs`, and `priority`;
  - edge `kind`, `detail`, and `tone`;
  - graph `perspective`, `warnings`, and `legend` metadata.
- Keep the existing layout modes but make them perspective-aware:
  - `dagre` for cause chains;
  - `force` for runtime topology;
  - `radial` for ownership and lineage exploration.
- Add a graph-debugging sample artifact and route it through the workbench
  development sample loader.
- Keep timeline/list selection synchronized with graph fallback selection.
- Make the fallback panels useful even if the canvas adapter fails.
- Add tests for the new graph derivation behavior and stream compatibility.
- Add documentation and roadmap/backlog updates that mark this branch delivered
  and hand off to the human-agent feedback loop.
- Verify the graph in a real browser with desktop and mobile-width checks,
  including canvas-pixel evidence when the browser can expose canvas data.

Out of scope:

- Production telemetry ingestion.
- SSE, WebSocket, polling, or bridge callback streaming.
- Editable remediation planning.
- `solid-flow` as a default dependency.
- Direct `@antv/g6` engine APIs unless the Solid wrapper blocks a required
  read-only visualization feature.
- Source, config, registry, policy, migration, deployment, rollback, app-state,
  alert, ticket, page, SIEM, or durable-store mutation.
- Cockroach adapter work.
- React workbench support.

Mutation authority remains `none`.

## Architecture

The branch keeps the existing boundary order:

```text
artifact JSON -> WorkbenchModel -> VisualGraphModel -> Solid G6 adapter -> UI
```

The pure model work belongs in `causalArtifact.ts`. Rendering components should
consume the model and avoid re-deriving graph semantics in JSX. The G6 adapter
should only map the model into `@dschz/solid-g6` data, layout, style, and
behavior options.

### Model Additions

Add these types:

```ts
export type VisualGraphPerspective = "cause" | "topology" | "ownership" | "lineage";

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
```

`VisualGraphModel` should keep existing fields and add:

- `perspective`;
- `legend`;
- `warnings`;
- richer node and edge metadata.

Existing callers should keep working by passing a default perspective of
`cause`.

### Perspective Rules

`cause` perspective:

- include event nodes and parent edges;
- prioritize the selected event's cause path when a selected event exists;
- preserve roots and orphan warnings.

`topology` perspective:

- include event nodes plus lane/group nodes for run, scope, fiber, resource,
  and retry identities;
- connect lane/group nodes to owned event nodes with `owns` edges;
- retain parent edges for causality context.

`ownership` perspective:

- emphasize scope, fiber, resource, and finalizer relationships;
- create resource nodes from `resource_id`, resource-like event labels, or
  resource event kinds;
- create finalizer edges for `resource_finalized` events;
- surface missing finalization and pending fiber findings as high priority.

`lineage` perspective:

- include app semantic ref nodes for `artifact_id`, `domain_entity_ref`,
  `data_subject_ref`, and `schema_ref`;
- connect events to refs with `reads`, `writes`, `transforms`, or `emits` edges
  based on event kind and semantic fields;
- tolerate ordinary runtime artifacts that lack app refs by returning a clear
  warning and the normal event graph.

Live stream artifacts should keep rendering even when they have no normal
`events` array. Stream frames can populate `cause`, `topology`, and ownership
fallback nodes. `lineage` can warn that stream frames do not carry app semantic
refs yet.

## UI

The Visual Graph tab should add a second segmented control for perspective next
to the existing layout control. Controls must be compact and wrap cleanly on
mobile.

The view should show:

- graph title and read-only posture;
- perspective selector;
- layout selector;
- summary metrics for perspective, layout, nodes, edges, adapter, and engine;
- stable graph shell with the lazy G6 canvas;
- selected graph element detail panel;
- cause path strip;
- fallback node and edge lists with group, tone, and edge kind;
- legend and warnings panels.

Clicking a fallback node or edge target should update the same selected event id
used by the timeline and inspector when the graph node maps to an event. Ref
nodes should be selectable in the graph detail panel without implying source
mutation or query execution.

## Adapter

`visualGraphAdapter.tsx` should continue importing from `@dschz/solid-g6`.
It should map:

- node labels, group, tone, and priority into G6 node data/style;
- edge kind and tone into edge labels/style;
- perspective-aware layout config into `createGraphLayout`;
- read-only behaviors such as drag canvas, zoom canvas, and optional click
  selection.

Direct `@antv/g6` APIs remain `not-required` unless the Solid wrapper cannot
express the selected behavior or style. If direct API usage becomes necessary,
the adapter metadata must change and the docs/tests must call out the reason.

## Fixtures

Add `sample-visual-graph-debugging.json` under
`packages/zigeffect/workbench/public/`. It should be a normal
`zigeffect.causal.v1` artifact with enough events and refs to exercise:

- a cause chain;
- a run lane;
- a scope lane;
- a fiber lane;
- a resource with finalizer failure;
- a retry event;
- a service requirement;
- app semantic refs for data read/write or artifact emission.

Expose it through `?sample=visual-graph`.

## Safety

- The graph is a viewer and local debugging aid only.
- Copy buttons remain command-copy helpers, not execution approvals.
- The UI must not call networks except local dev-server assets.
- The workbench bridge remains bounded and read-only.
- Graph warnings should state when evidence is missing, redacted, truncated, or
  inferred from fallback labels.

## Verification

Focused checks:

```sh
bun run zigeffect:workbench:test
bun run zigeffect:workbench:typecheck
bun run zigeffect:workbench:build
```

Browser checks:

```sh
bun run zigeffect:workbench:dev -- --port <free-port>
```

Open:

```text
http://127.0.0.1:<port>/?sample=visual-graph
```

Verify:

- all four perspectives can be selected;
- all three layout modes can be selected;
- Visual Graph reports nonzero nodes and edges;
- G6 canvas renders nonblank pixels on desktop;
- mobile width has no horizontal page overflow;
- fallback node/edge lists remain readable;
- selecting graph fallback rows updates the inspector when the node maps to an
  event;
- console has no application exceptions.

Integration checks before final commit:

```sh
cd packages/zigeffect
zig build causal-production-hardening-backlog -- --format json
zig build causal-schema-governance -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```

## Acceptance Criteria

- The branch has a committed design spec and implementation plan.
- `VisualGraphModel` supports perspectives and richer node/edge metadata.
- The Visual Graph tab renders perspective controls, graph metrics, legend,
  warnings, graph detail, and fallback lists.
- The graph-debugging sample works through `?sample=visual-graph`.
- Browser verification proves desktop and mobile graph rendering.
- Roadmap/backlog docs mark graph visual debugging delivered and hand off to
  `codex/zigeffect-causal-human-agent-feedback-loop`.
- Mutation authority remains `none`.
