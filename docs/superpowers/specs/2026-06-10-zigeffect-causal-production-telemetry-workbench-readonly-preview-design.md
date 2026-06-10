# zigeffect Causal Production Telemetry Workbench Read-Only Preview Design

## Context

The production telemetry chain now has ready, record-only evidence up to
`zigeffect.causal.production-telemetry-nendb-retention-fixtures.v1`. That
artifact proves local pipeline evidence, NenDB node and edge mapping fixtures,
retention policy constants, compaction markers, backup/recovery markers, and
disabled runtime/write authority.

The next milestone is a read-only SolidJS `webui-dev/zig-webui` workbench
preview that helps humans and agents inspect those artifacts without turning
the preview into live production telemetry, a durable writer, or mutation
authority.

## Goals

- Add a read-only production telemetry preview surface inside the existing
  SolidJS workbench.
- Detect and parse ready or blocked NenDB retention fixture artifacts.
- Show source artifact handoff, readiness status, authority flags, mapping
  fixtures, retention validation checks, blocked claims, and verification
  commands.
- Provide a development sample artifact loadable through the existing
  `?sample=` mechanism.
- Add a record-only preview contract tool so agents can cite a reviewed
  workbench preview artifact before the next branch.
- Preserve `mutation_authority=none`, `applied=false`, disabled live telemetry,
  disabled network send, disabled OTLP serialization, disabled runtime pipeline
  execution, disabled durable writes, and disabled NenDB writes.

## Non-Goals

- No live telemetry ingestion or streaming.
- No exporter, collector, OTLP, or network configuration.
- No durable or NenDB writes.
- No compaction, backup, or restore execution.
- No CI telemetry gate or fail threshold.
- No React or alternate renderer work.
- No hosted dashboard, authentication, RBAC, or multi-user production UI.
- No source, config, registry, deployment, rollout, alert, app, or production
  mutation authority.

## Architecture

The branch has two small units.

First, the workbench parser gains a `ProductionTelemetryPreviewModel`. It reads
`zigeffect.causal.production-telemetry-nendb-retention-fixtures.v1` artifacts
directly and normalizes the fields the UI needs: status, source paths,
authority flags, mapping fixtures, validation checks, blocked claims,
verification commands, and next branch. The model is intentionally read-only
and is independent of event timeline parsing, because these artifacts are
governance/mapping records, not runtime event logs.

Second, the SolidJS app gains a `Telemetry` tab. The tab appears as a normal
workbench tab and shows dense operational panels rather than a marketing page:
status strip, source artifact chain, mapping fixture table, validation/check
lists, authority boundary, and copyable workbench/query commands. It reuses
existing component patterns such as `Metric`, `ChainSources`, `CommandList`,
and warning lists instead of introducing a new design system.

A small Zig tool,
`causal-production-telemetry-workbench-readonly-preview`, consumes a ready
NenDB retention fixture JSON artifact and emits
`zigeffect.causal.production-telemetry-workbench-readonly-preview.v1`. The
tool records that the preview is reviewed and read-only, points at the sample
and source artifact, and hands off to the CI artifact preview branch. It
does not inspect the UI runtime, write durable state, or grant authority.

## Data Flow

1. The NenDB retention fixture tool emits a ready or blocked retention JSON
   artifact.
2. The workbench bridge loads either that artifact from WebUI or a development
   sample selected by `?sample=production-telemetry`.
3. `deriveProductionTelemetryPreviewModel` detects the retention schema and
   returns a normalized model.
4. The `Telemetry` tab renders the model read-only.
5. The preview contract tool consumes the ready retention artifact plus
   explicit verification commands and emits a review artifact for agents and
   the backlog.

## UI Requirements

- Add a `Telemetry` tab next to the existing Live/Graph/Chain tabs.
- Show `retention_fixture_status`, `ready_for_next_branch`,
  `recommendation`, and `next_branch_if_ready`.
- Show authority flags with warning tone if any write/network/live flag is
  true.
- Show source artifacts as copyable `zig build causal-workbench -- <path>`
  commands where a path exists.
- Show mapping fixtures with source envelope, target schema, label, retained
  fields, and blocked fields.
- Show checks and validation records with pass/fail styling.
- Show required and verified commands in the existing command list style.
- Show guardrails/blocked claims prominently enough that an agent cannot miss
  the non-live boundary.
- Keep text compact and responsive; do not add a landing page or explanatory
  marketing copy.

## Preview Contract

The preview contract tool emits:

- schema `zigeffect.causal.production-telemetry-workbench-readonly-preview.v1`;
- source retention artifact path and source branch;
- decision `approve` or `reject`;
- `preview_status` as `ready` or `blocked`;
- `ready_for_next_branch`;
- `workbench_renderer="SolidJS"`;
- `webui_runtime="webui-dev/zig-webui"`;
- `read_only_preview=true`;
- `live_telemetry_enabled=false`;
- `network_send_enabled=false`;
- `runtime_pipeline_enabled=false`;
- `durable_write_enabled=false`;
- `nendb_write_enabled=false`;
- source readiness checks;
- required verification commands for workbench typecheck/test, Zig tests,
  schema governance, backlog, examples, and full repo checks.

The next branch after this milestone is
`codex/zigeffect-causal-production-telemetry-ci-artifact-preview`.

## Testing

- Add `bun:test` coverage for parsing ready and blocked retention artifacts.
- Add UI source tests that verify the Telemetry tab and panel functions exist.
- Add bridge sample tests for `?sample=production-telemetry`.
- Add Zig tests for the preview contract tool, including approve and reject
  paths.
- Verify with `bun run zigeffect:workbench:typecheck`,
  `bun run zigeffect:workbench:test`, `zig build examples`, `zig build test`,
  `bun run check`, `bun run zig:test`, and `git diff --check`.

## Agent Guidance

Agents may use a ready preview artifact to start the CI artifact preview branch
only. They must cite the source retention artifact, workbench model fields,
authority flags, validation checks, mapping fixtures, required commands, and
verified commands.

Agents must not infer live telemetry, durable writes, NenDB writes, CI gates,
production capacity, alternate renderers, or mutation authority from this
preview.
