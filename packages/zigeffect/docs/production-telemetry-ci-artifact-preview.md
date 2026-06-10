# zigeffect Causal Production Telemetry CI Artifact Preview

`causal-production-telemetry-ci-artifact-preview` consumes a ready production
telemetry workbench read-only preview JSON artifact and emits a record-only CI
artifact preview. It is the gate between local workbench evidence and future CI
harness boundary work.

The report uses schema
`zigeffect.causal.production-telemetry-ci-artifact-preview.v1`.

## Command

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-artifact-preview -- \
  --from-workbench ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview.json \
  approve \
  --reason "CI artifact preview reviewed" \
  --verified-command "zig build causal-production-telemetry-workbench-readonly-preview" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

Use `reject --reason <reason>` to produce a blocked CI artifact preview.

## Boundary

The preview artifact keeps these authority fields fixed:

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
- `ci_upload_enabled=false`
- `ci_workflow_mutation_enabled=false`
- `ci_artifact_preview_enabled=true`

The artifact does not modify GitHub Actions, upload files, configure CI
retention, create required checks, fail CI, run a telemetry pipeline, ingest
telemetry, configure exporters, serialize OTLP, send network data, write NenDB
records, execute a durable writer, open a hosted dashboard, add non-NenDB
durable adapters, add React or alternate renderers, or grant mutation
authority.

## Upload Policy Preview

The report records a preview-only policy:

- `mode=preview-only`
- `failure_only=true`
- `retention_days=14`
- `allowed_extensions=[".txt", ".json", ".dot"]`
- causal artifact roots only
- missing files ignored
- public upload claims disabled
- CI gate claims disabled

This is archive design evidence for a future CI harness boundary. It is not
CI artifact upload execution.

## Artifact Candidates

The candidate catalog includes:

- source workbench preview JSON;
- source workbench preview text report;
- source NenDB retention fixture JSON;
- generated CI artifact preview JSON;
- generated CI artifact preview text report.

Each candidate records extension, artifact kind, purpose, retention days,
failure-only posture, producer, consumer, redaction requirement, and disabled
public upload claim.

## Status

- `ready`: the source workbench preview artifact is schema v1, ready,
  approved, next-branch-ready, authority-disabled, carries mapping fixtures,
  records source verification evidence, emits only allowlisted artifact
  candidates, keeps CI upload and workflow mutation disabled, and records every
  required CI preview verification command.
- `blocked`: the reviewer rejected, source workbench evidence is blocked,
  authority is enabled, artifact candidates violate policy, mapping evidence is
  missing, or required verification command evidence is missing.

`ready_for_next_branch=true` means a later
`codex/zigeffect-causal-production-telemetry-ci-harness-boundary` branch may
be started. It does not approve artifact upload execution, CI gates, live
ingestion, runtime pipelines, NenDB writes, durable writes, hosted dashboards,
or mutation authority.

## Output Paths

For this input:

```text
.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview.json
```

default output paths are:

```text
.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview.json
.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview.txt
```

Use `--out-prefix <path-prefix>` to choose a custom artifact prefix.

## Agent Guidance

Agents may use a `ready` CI artifact preview to start
`codex/zigeffect-causal-production-telemetry-ci-harness-boundary`. They must
cite the source workbench preview, source retention artifact, upload policy
preview, artifact candidates, authority boundary, checks, required commands,
recorded commands, and blocked claims.

That harness boundary is now delivered. Later agents should consume the
resulting `zigeffect.causal.production-telemetry-ci-harness-boundary.v1`
artifact before starting
`codex/zigeffect-causal-production-telemetry-ci-archive-application`; a CI
artifact preview alone does not approve workflow application.

Agents must treat `blocked` CI artifact previews as stop signs. Blocked
artifacts can guide evidence or policy repair, but they cannot justify CI
upload configuration, CI gate work, live telemetry, durable writes, hosted
dashboard claims, or mutation authority.

## Verification

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_artifact_preview.zig
zig build causal-production-telemetry-ci-artifact-preview -- \
  --from-workbench ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview.json \
  approve \
  --reason "CI artifact preview reviewed" \
  --verified-command "zig build causal-production-telemetry-workbench-readonly-preview" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
zig build causal-production-telemetry-ci-artifact-preview -- \
  --from-workbench ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview.json \
  reject \
  --reason "negative CI artifact preview path"
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
