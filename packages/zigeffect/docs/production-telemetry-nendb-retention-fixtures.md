# zigeffect Causal Production Telemetry NenDB Retention Fixtures

`causal-production-telemetry-nendb-retention-fixtures` consumes a ready
production telemetry local-pipeline-fixtures JSON artifact and emits
fixture-only NenDB mapping evidence. It is the gate between normalized local
telemetry fixture records and the future read-only workbench preview.

The report uses schema
`zigeffect.causal.production-telemetry-nendb-retention-fixtures.v1`.

## Command

```sh
cd packages/zigeffect
zig build causal-production-telemetry-nendb-retention-fixtures -- \
  --from-local-pipeline ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures.json \
  approve \
  --reason "approved local pipeline reviewed for NenDB retention fixtures" \
  --verified-command "zig build causal-production-telemetry-local-pipeline-fixtures" \
  --verified-command "zig build causal-nendb-storage-backend" \
  --verified-command "zig build causal-durable-production-retention -- --format json" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

Use `reject --reason <reason>` to produce a blocked retention fixture artifact.

## Boundary

The fixture artifact keeps these authority fields fixed:

- `applied=false`
- `mutation_authority="none"`
- `production_telemetry_ingestion=false`
- `live_exporter_enabled=false`
- `network_send_enabled=false`
- `collector_endpoint_configured=false`
- `otlp_serialization_enabled=false`
- `runtime_pipeline_enabled=false`
- `durable_write_enabled=false`
- `nendb_write_enabled=false`
- `ci_gate_enabled=false`
- `local_pipeline_fixture_mode=true`
- `nendb_retention_fixture_mode=true`

The artifact does not run a telemetry pipeline, ingest telemetry, configure
exporters, serialize OTLP, send network data, write NenDB records, execute a
durable writer, compact records, run backup or restore, add CI gates, add
non-NenDB durable adapters, add React or alternate renderers, or grant mutation
authority.

## Status

- `ready`: the source local-pipeline artifact is ready, source checks passed,
  source verification evidence is recorded, NenDB node and edge mappings are
  present, retention constants match the durable-retention contract, and every
  required verification command was recorded.
- `blocked`: the reviewer rejected, source local-pipeline evidence is blocked,
  mapping evidence is incomplete, retention validation failed, or required
  verification command evidence is missing.

`ready_for_next_branch=true` means a later
`codex/zigeffect-causal-production-telemetry-workbench-readonly-preview` branch
may be started. It does not approve live ingestion, a runtime pipeline, NenDB
writes, durable writes, compaction execution, backup execution, restore
execution, CI gates, or mutation authority.

## Mapping Fixtures

- `nendb-runtime-event-node-fixture`
- `nendb-app-semantic-node-fixture`
- `nendb-otel-attribute-node-fixture`
- `nendb-redaction-access-node-fixture`
- `nendb-sampling-retention-node-fixture`
- `nendb-correlation-edge-fixture`
- `nendb-retention-policy-record-fixture`
- `nendb-compaction-window-fixture`
- `nendb-backup-recovery-marker-fixture`

The retention policy fixture records the current durable-retention constants:
TTL 14 days, max events 4096, compaction trigger 2048 events, compact to 1024
events, backup required, and recovery required. These are fixture records, not
live deletion, compaction, backup, or restore decisions.

## Checks

The report evaluates:

- source local-pipeline schema, ready status, and approved decision;
- authority boundary fields across source and retention fixtures;
- disabled network send, collector endpoint, OTLP serialization, runtime
  pipeline execution, durable writes, and NenDB writes;
- source boundary, proposal, readiness, fixture, and local-pipeline path
  linkage;
- source local-pipeline checks and verification command evidence;
- local pipeline fixture catalog coverage;
- NenDB node and edge mapping fixture coverage;
- retention policy, compaction, backup, and recovery marker coverage;
- rejection of non-NenDB and Cockroach adapter scope;
- SolidJS inside `webui-dev/zig-webui` as the workbench direction.

## Output Paths

For this input:

```text
.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures.json
```

default output paths are:

```text
.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures.json
.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures.txt
```

Use `--out-prefix <path-prefix>` to choose a custom artifact prefix.

## Agent Guidance

Agents may use a `ready` NenDB retention fixture artifact to inspect the
delivered `codex/zigeffect-causal-production-telemetry-workbench-readonly-preview`
branch or regenerate its source preview artifact. They
must cite the source local-pipeline artifact, boundary, proposal, readiness,
fixture paths, mapping fixture catalog, retention validation checks, required
commands, recorded commands, and blocked claims.

Agents must treat `blocked` retention fixture artifacts as stop signs. Blocked
fixtures can guide source evidence, mapping, or verification repair, but they
cannot justify workbench preview work or any durable write work.

## Verification

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_nendb_retention_fixtures.zig
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```
