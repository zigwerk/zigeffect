# zigeffect Causal Production Telemetry Workbench Read-Only Preview

`causal-production-telemetry-workbench-readonly-preview` consumes a ready
production telemetry NenDB-retention-fixtures JSON artifact and emits a
record-only workbench preview artifact. It is the gate between fixture-only
NenDB mapping evidence and future CI artifact preview work.

The report uses schema
`zigeffect.causal.production-telemetry-workbench-readonly-preview.v1`.

## Command

```sh
cd packages/zigeffect
zig build causal-production-telemetry-workbench-readonly-preview -- \
  --from-retention ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures.json \
  approve \
  --reason "read-only SolidJS webui preview reviewed" \
  --verified-command "bun run zigeffect:workbench:typecheck" \
  --verified-command "bun run zigeffect:workbench:test" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

Use `reject --reason <reason>` to produce a blocked workbench preview artifact.

## Workbench UI

The SolidJS workbench can load the production telemetry fixture sample with:

```sh
bun run zigeffect:workbench:dev
```

Then open:

```text
http://127.0.0.1:5173/?sample=production-telemetry
```

The `Telemetry` tab is shown for
`zigeffect.causal.production-telemetry-nendb-retention-fixtures.v1` and
`zigeffect.causal.production-telemetry-workbench-readonly-preview.v1`
artifacts. It displays:

- status, decision, readiness, fixture count, check count, and authority;
- source retention, local-pipeline, boundary, proposal, readiness, and fixture
  artifact paths;
- disabled authority fields for live exporter, network send, collector
  endpoint, OTLP serialization, runtime pipeline, durable writes, NenDB writes,
  and CI gates;
- source checks and required verification commands;
- NenDB node, edge, retention, compaction, backup, and recovery mapping
  fixtures;
- validation checks, implementation gates, blocked claims, non-goals, and next
  branch.

The development sample lives at:

```text
packages/zigeffect/workbench/public/sample-production-telemetry-nendb-retention-fixtures.json
```

## Boundary

The preview artifact keeps these authority fields fixed:

- `applied=false`
- `mutation_authority="none"`
- `read_only_preview=true`
- `solid_webui_enabled=true`
- `production_telemetry_ingestion=false`
- `live_exporter_enabled=false`
- `network_send_enabled=false`
- `collector_endpoint_configured=false`
- `otlp_serialization_enabled=false`
- `runtime_pipeline_enabled=false`
- `durable_write_enabled=false`
- `nendb_write_enabled=false`
- `ci_gate_enabled=false`

The artifact does not run a telemetry pipeline, ingest telemetry, configure
exporters, serialize OTLP, send network data, write NenDB records, execute a
durable writer, open a hosted production dashboard, add CI gates, add
non-NenDB durable adapters, add React or alternate renderers, or grant mutation
authority.

## Status

- `ready`: the source retention artifact is schema v1, ready, approved,
  authority-disabled, mapping fixtures are present, source checks passed,
  source verification evidence is recorded, and every required workbench/Zig
  verification command was recorded.
- `blocked`: the reviewer rejected, source retention evidence is blocked,
  mapping evidence is incomplete, validation failed, or required verification
  command evidence is missing.

`ready_for_next_branch=true` means a later
`codex/zigeffect-causal-production-telemetry-ci-artifact-preview` branch may be
started. It does not approve live ingestion, a runtime pipeline, NenDB writes,
durable writes, hosted dashboards, CI gates, or mutation authority.

## Output Paths

For this input:

```text
.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures.json
```

default output paths are:

```text
.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview.json
.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview.txt
```

Use `--out-prefix <path-prefix>` to choose a custom artifact prefix.

## Agent Guidance

Agents may use a `ready` workbench preview artifact to start
`codex/zigeffect-causal-production-telemetry-ci-artifact-preview`. They must
cite the source retention artifact, local-pipeline artifact, mapping fixtures,
authority boundary, validation checks, required commands, recorded commands,
and blocked claims.

Agents must treat `blocked` workbench preview artifacts as stop signs. Blocked
artifacts can guide source evidence, UI, or verification repair, but they
cannot justify CI artifact preview work or any live telemetry/durable write
work.

## Verification

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_workbench_readonly_preview.zig
zig build causal-production-telemetry-workbench-readonly-preview -- \
  --from-retention ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures.json \
  approve \
  --reason "read-only SolidJS webui preview reviewed" \
  --verified-command "bun run zigeffect:workbench:typecheck" \
  --verified-command "bun run zigeffect:workbench:test" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
bun run zigeffect:workbench:typecheck
bun run zigeffect:workbench:test
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```
