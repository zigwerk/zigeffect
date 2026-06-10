# zigeffect Causal Production Telemetry Exporter Boundary

`causal-production-telemetry-exporter-boundary` consumes an approved production
telemetry implementation-proposal JSON artifact and emits a no-network
exporter-boundary artifact. It is the gate between proposal approval and local
pipeline fixture work.

The report uses schema
`zigeffect.causal.production-telemetry-exporter-boundary.v1`.

## Command

```sh
cd packages/zigeffect
mkdir -p ../../.zig-cache/causal-artifacts
zig build causal-production-telemetry-capture-fixtures -- --format json \
  2> ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json
zig build causal-production-telemetry-readiness-review -- \
  --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json \
  approve \
  --reason "fixtures reviewed for implementation proposal" \
  --verified-command "zig build causal-production-telemetry-capture-fixtures -- validate --format json" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
zig build causal-production-telemetry-implementation-proposal -- \
  --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.json \
  approve \
  --reason "ready evidence reviewed for exporter boundary planning" \
  --verified-command "zig build causal-production-telemetry-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json approve --reason \"fixtures reviewed for implementation proposal\" --verified-command \"zig build causal-production-telemetry-capture-fixtures -- validate --format json\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
zig build causal-production-telemetry-exporter-boundary -- \
  --from-proposal ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal.json \
  approve \
  --reason "proposal evidence reviewed for local pipeline fixtures" \
  --verified-command "zig build causal-production-telemetry-implementation-proposal -- --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.json approve --reason \"ready evidence reviewed for exporter boundary planning\" --verified-command \"zig build causal-production-telemetry-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json approve --reason \\\"fixtures reviewed for implementation proposal\\\" --verified-command \\\"zig build causal-production-telemetry-capture-fixtures -- validate --format json\\\" --verified-command \\\"zig build causal-schema-governance -- --format json\\\" --verified-command \\\"zig build causal-production-hardening-backlog -- --format json\\\" --verified-command \\\"zig build examples\\\" --verified-command \\\"zig build test\\\"\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

Use `reject --reason <reason>` to produce a blocked boundary artifact.

## Boundary

The boundary artifact keeps these authority fields fixed:

- `applied=false`
- `mutation_authority="none"`
- `production_telemetry_ingestion=false`
- `live_exporter_enabled=false`
- `network_send_enabled=false`
- `collector_endpoint_configured=false`
- `otlp_serialization_enabled=false`
- `durable_write_enabled=false`
- `ci_gate_enabled=false`

The exporter boundary contract is:

- `boundary_id=exporter-neutral-no-network`
- `input_contract=redacted-causal-otel-record-or-fixture-ref`
- `output_contract=local-export-envelope-fixture`
- `transport_state=disabled`
- `network_state=disabled`
- `collector_endpoint_state=not-configured`
- `serialization_state=boundary-json-only-not-otlp`
- `durable_write_state=disabled`
- `review_gate=local-pipeline-fixtures-review`

The local envelope fixture names are:

- `runtime-span-event-envelope`
- `app-semantic-ref-envelope`
- `backend-otel-record-envelope`
- `redaction-access-envelope`
- `sampling-boundary-envelope`

## Status

- `approved`: the source proposal is approved, every source proposal check
  passed, every required source and boundary verification command was recorded,
  and the no-network authority boundary is intact.
- `blocked`: the reviewer rejected, proposal evidence is blocked, a required
  check failed, or required verification command evidence is missing.

`approved_for_next_branch=true` means a later
`codex/zigeffect-causal-production-telemetry-local-pipeline-fixtures` branch
may be started. It does not mean telemetry has been implemented, deployed,
serialized to OTLP, sent over a network, retained durably, or approved for live
production use.

## Checks

The boundary report evaluates:

- proposal schema, approved status, and approved decision;
- boundary decision and reason;
- authority boundary fields;
- disabled network send and collector endpoint;
- disabled OTLP serialization;
- readiness and fixture source-chain linkage;
- source proposal checks;
- source proposal phase handoff;
- source proposal verification command evidence;
- boundary verification command evidence;
- NenDB-only durable direction;
- SolidJS `webui-dev/zig-webui` direction.

## Output Paths

For this input:

```text
.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal.json
```

default output paths are:

```text
.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary.json
.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary.txt
```

Use `--out-prefix <path-prefix>` to choose a custom artifact prefix.

## Agent Guidance

Agents may use an `approved` boundary to start
`codex/zigeffect-causal-production-telemetry-local-pipeline-fixtures`. They
must cite the boundary artifact, source proposal path, source readiness path,
source fixture path, check names, required commands, recorded commands, local
envelope fixture names, and no-network contract fields.

Agents must treat `blocked` boundary artifacts as stop signs. Blocked
boundaries can guide proposal, verification, or authority-boundary repair, but
they cannot justify local pipeline fixture work.

The local-pipeline-fixtures branch is now delivered through
`causal-production-telemetry-local-pipeline-fixtures`. The current handoff is
`codex/zigeffect-causal-production-telemetry-nendb-retention-fixtures`, which
must consume ready fixture artifacts rather than treating this boundary report
as runtime telemetry.

## Verification

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_exporter_boundary.zig
mkdir -p ../../.zig-cache/causal-artifacts
zig build causal-production-telemetry-capture-fixtures -- --format json \
  2> ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json
zig build causal-production-telemetry-readiness-review -- \
  --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json \
  approve \
  --reason "fixtures reviewed for implementation proposal" \
  --verified-command "zig build causal-production-telemetry-capture-fixtures -- validate --format json" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
zig build causal-production-telemetry-implementation-proposal -- \
  --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.json \
  approve \
  --reason "ready evidence reviewed for exporter boundary planning" \
  --verified-command "zig build causal-production-telemetry-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json approve --reason \"fixtures reviewed for implementation proposal\" --verified-command \"zig build causal-production-telemetry-capture-fixtures -- validate --format json\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
zig build causal-production-telemetry-exporter-boundary -- \
  --from-proposal ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal.json \
  approve \
  --reason "proposal evidence reviewed for local pipeline fixtures" \
  --verified-command "zig build causal-production-telemetry-implementation-proposal -- --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.json approve --reason \"ready evidence reviewed for exporter boundary planning\" --verified-command \"zig build causal-production-telemetry-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json approve --reason \\\"fixtures reviewed for implementation proposal\\\" --verified-command \\\"zig build causal-production-telemetry-capture-fixtures -- validate --format json\\\" --verified-command \\\"zig build causal-schema-governance -- --format json\\\" --verified-command \\\"zig build causal-production-hardening-backlog -- --format json\\\" --verified-command \\\"zig build examples\\\" --verified-command \\\"zig build test\\\"\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
zig build causal-production-telemetry-exporter-boundary -- \
  --from-proposal ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal.json \
  reject \
  --reason "negative boundary path"
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```
