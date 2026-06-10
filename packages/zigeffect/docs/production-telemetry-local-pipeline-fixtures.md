# zigeffect Causal Production Telemetry Local Pipeline Fixtures

`causal-production-telemetry-local-pipeline-fixtures` consumes an approved
production telemetry exporter-boundary JSON artifact and emits fixture-only
local pipeline evidence. It is the gate between no-network exporter boundaries
and future NenDB retention fixture mapping.

The report uses schema
`zigeffect.causal.production-telemetry-local-pipeline-fixtures.v1`.

## Command

```sh
cd packages/zigeffect
zig build causal-production-telemetry-local-pipeline-fixtures -- \
  --from-boundary ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary.json \
  approve \
  --reason "approved boundary reviewed for local pipeline fixtures" \
  --verified-command "zig build causal-production-telemetry-exporter-boundary -- --from-proposal ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal.json approve --reason \"proposal evidence reviewed for local pipeline fixtures\" --verified-command \"zig build causal-production-telemetry-implementation-proposal -- --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.json approve --reason \\\"ready evidence reviewed for exporter boundary planning\\\" --verified-command \\\"zig build causal-production-telemetry-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json approve --reason \\\\\\\"fixtures reviewed for implementation proposal\\\\\\\" --verified-command \\\\\\\"zig build causal-production-telemetry-capture-fixtures -- validate --format json\\\\\\\" --verified-command \\\\\\\"zig build causal-schema-governance -- --format json\\\\\\\" --verified-command \\\\\\\"zig build causal-production-hardening-backlog -- --format json\\\\\\\" --verified-command \\\\\\\"zig build examples\\\\\\\" --verified-command \\\\\\\"zig build test\\\\\\\"\\\" --verified-command \\\"zig build causal-schema-governance -- --format json\\\" --verified-command \\\"zig build causal-production-hardening-backlog -- --format json\\\" --verified-command \\\"zig build examples\\\" --verified-command \\\"zig build test\\\"\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

Use `reject --reason <reason>` to produce a blocked fixture artifact.

## Boundary

The fixture artifact keeps these authority fields fixed:

- `applied=false`
- `mutation_authority="none"`
- `production_telemetry_ingestion=false`
- `live_exporter_enabled=false`
- `network_send_enabled=false`
- `collector_endpoint_configured=false`
- `otlp_serialization_enabled=false`
- `durable_write_enabled=false`
- `ci_gate_enabled=false`
- `runtime_pipeline_enabled=false`
- `local_pipeline_fixture_mode=true`

The artifact does not run a pipeline, ingest telemetry, configure exporters,
serialize OTLP, send network data, write NenDB, write durable production
storage, add CI gates, or grant mutation authority.

## Status

- `ready`: the source boundary is approved, every source boundary check passed,
  every local fixture validation check passed, and every required verification
  command was recorded.
- `blocked`: the reviewer rejected, boundary evidence is blocked, a fixture
  check failed, or required verification command evidence is missing.

`ready_for_next_branch=true` means a later
`codex/zigeffect-causal-production-telemetry-nendb-retention-fixtures` branch
may be started. It does not mean a pipeline is implemented, executed, retained
durably, or approved for live production use.

## Fixture Catalog

- `runtime-span-normalized-envelope`
- `app-semantic-normalized-envelope`
- `backend-otel-local-envelope`
- `redaction-access-reviewed-envelope`
- `sampling-kept-envelope`
- `sampling-dropped-envelope`
- `correlation-link-envelope`

Every fixture declares its source envelope, output envelope, output fields, and
blocked fields. Raw payloads, prompts, credentials, headers, tenant ids, user
ids, collector endpoints, network addresses, OTLP wire bytes, and source
database reads remain blocked.

## Checks

The report evaluates:

- source boundary schema, approved status, and approved decision;
- fixture decision and reason;
- authority boundary fields;
- disabled network send, collector endpoint, OTLP serialization, durable
  writes, and runtime pipeline execution;
- source proposal, readiness, and fixture path linkage;
- source boundary checks and verification command evidence;
- exporter boundary contract fields;
- source envelope fixture names;
- local fixture catalog presence;
- redaction and sampling fixture presence;
- validation checks for raw-field blocking and reference-only correlation;
- NenDB-only durable direction;
- SolidJS `webui-dev/zig-webui` direction.

## Output Paths

For this input:

```text
.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary.json
```

default output paths are:

```text
.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures.json
.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures.txt
```

Use `--out-prefix <path-prefix>` to choose a custom artifact prefix.

## Agent Guidance

Agents may use a `ready` local-pipeline-fixtures artifact to start
`codex/zigeffect-causal-production-telemetry-nendb-retention-fixtures`. They
must cite the fixture artifact, source boundary, source proposal, source
readiness, source fixtures, fixture catalog, validation checks, required
commands, recorded commands, and blocked claims.

Agents must treat `blocked` fixture artifacts as stop signs. Blocked fixtures
can guide boundary or fixture repair, but they cannot justify NenDB retention
fixture work.

## Verification

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_local_pipeline_fixtures.zig
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```
