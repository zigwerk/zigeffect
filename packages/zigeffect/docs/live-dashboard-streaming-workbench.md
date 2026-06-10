# zigeffect Live Dashboard Streaming Workbench

`causal-live-dashboard-streaming-workbench` is the deterministic contract for
the first read-only live dashboard stream and visual graph workbench slice.
It records the stream schema, frame fields, graph adapter posture, guardrails,
non-goals, and verification commands.

## Command

```sh
cd packages/zigeffect
zig build causal-live-dashboard-streaming-workbench
zig build causal-live-dashboard-streaming-workbench -- --format json
```

The text report is for maintainers. The JSON report uses schema
`zigeffect.causal.live-dashboard-streaming-workbench.v1`. The stream artifacts
consumed by the workbench use schema
`zigeffect.causal.live-dashboard-stream.v1`.

## Stream Artifact Shape

A live dashboard stream artifact is a bounded, record-only JSON object. It is
safe for local fixtures and future transport producers:

- `schema`: `zigeffect.causal.live-dashboard-stream.v1`;
- `schema_version`: `1`;
- `mode`: local or future transport label;
- `target`: run, app, CI job, or retained artifact bundle label;
- `mutation_authority`: always `none` for this slice;
- `source`: JSON and text artifact refs such as snapshot, aggregation bundle,
  access policy, alert preview, and compare report;
- `stream`: `window_policy`, `max_frames`, `frame_count`, `truncated`, and
  `redaction`;
- `frames`: ordered frame records with `sequence`, `event_id`, `parent_id`,
  `event_kind`, `status`, `label`, `lane`, `finding_kind`, and
  `dashboard_priority`;
- `layouts`: supported visual layout intents, currently `dagre`, `force`, and
  `radial`;
- `guardrails`: read-only authority boundaries.

The workbench also treats ordinary `zigeffect.causal.v1` event artifacts as
static streams, so saved runtime artifacts can use the Live tab without a
separate stream producer.

## Workbench

Run the local workbench:

```sh
cd ../..
bun run zigeffect:workbench:dev -- --port 5179
```

Open the live stream sample:

```text
http://127.0.0.1:5179/?sample=live
```

The Live tab renders stream metadata, priority counts, source artifacts,
latest frames, guardrails, and warnings. The Visual Graph tab renders a
read-only graph from the same causal model. The existing Graph tab remains the
text-first structural view.

## Graph Adapter

The visual graph path starts with `@dschz/solid-g6` over `@antv/g6`. The
workbench keeps zigeffect's derived causal graph model as the source of truth
and maps that model into the Solid G6 adapter at the UI boundary. Direct
`@antv/g6` engine API usage remains `not-required` in this slice.

The G6 adapter is lazy-loaded, so the normal workbench bundle remains small and
the large graph dependency is loaded only when Visual Graph renders.

## Authority Boundaries

This milestone does not:

- connect to production telemetry;
- open SSE, WebSocket, polling, or bridge callback streams;
- execute copied commands;
- send alerts, create tickets, forward SIEM events, or page humans;
- enforce live RBAC;
- decrypt artifacts;
- write NenDB or other durable stores;
- edit source, config, registries, policies, migrations, deployments,
  rollbacks, or app state;
- add Cockroach adapter work;
- add React workbench support.

Mutation authority remains `none`.

## Verification

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

## Next Branch

The next branch is
`codex/zigeffect-causal-workbench-graph-visual-debugging`. It should deepen
the visual graph layouts, browser screenshot and canvas-pixel verification,
timeline/selection synchronization, and graph-debugging fixtures.
