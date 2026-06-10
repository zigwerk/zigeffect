# zigeffect Causal Production Telemetry Implementation Proposal

`causal-production-telemetry-implementation-proposal` consumes a ready
production telemetry readiness-review JSON artifact and emits a proposal-only
implementation artifact. It is the gate between reviewed fixture readiness and
any later exporter-boundary branch.

The report uses schema
`zigeffect.causal.production-telemetry-implementation-proposal.v1`.

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
```

Use `reject --reason <reason>` to produce a blocked proposal artifact.

## Boundary

The proposal artifact keeps these authority fields fixed:

- `applied=false`
- `mutation_authority="none"`
- `production_telemetry_ingestion=false`
- `live_exporter_enabled=false`
- `durable_write_enabled=false`
- `ci_gate_enabled=false`

The proposal does not enable live ingestion, exporters, OTLP sends, collector
endpoints, durable production writes, CI telemetry gates, production capacity
claims, non-NenDB adapter work, alternate renderers, or mutation authority.

## Status

- `approved`: the proposer approved, the source readiness artifact is ready,
  every proposal check passed, and every required verification command was
  recorded.
- `blocked`: the proposer rejected, readiness evidence is blocked, a required
  check failed, or required verification command evidence is missing.

`approved_for_next_branch=true` means a later
`codex/zigeffect-causal-production-telemetry-exporter-boundary` branch may be
started. It does not mean telemetry has been implemented, deployed, or approved
for live production use.

## Checks

The proposal report evaluates:

- readiness schema and ready status;
- source readiness approval;
- proposal decision and reason;
- authority boundary fields;
- source fixture path linkage;
- source readiness checks;
- source readiness verification command evidence;
- proposal verification command evidence;
- NenDB-only durable direction;
- SolidJS `webui-dev/zig-webui` direction.

## Proposal Phases

The approved proposal records these later phases:

1. `exporter-boundary`
2. `local-pipeline-fixtures`
3. `nendb-retention-fixtures`
4. `workbench-readonly-preview`
5. `ci-artifact-preview`

Only `exporter-boundary` is the next recommended branch. Later phases remain
advisory until reviewed by their own artifacts.

## Output Paths

For this input:

```text
.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.json
```

default output paths are:

```text
.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal.json
.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal.txt
```

Use `--out-prefix <path-prefix>` to choose a custom artifact prefix.

## Agent Guidance

Agents may use an `approved` proposal to start
`codex/zigeffect-causal-production-telemetry-exporter-boundary`. They must cite
the proposal artifact, source readiness path, source fixture path, check names,
required commands, recorded commands, and approved phase names.

Agents must treat `blocked` proposal artifacts as stop signs. Blocked proposals
can guide fixture, readiness, or proposal repair, but they cannot justify
exporter work.

## Verification

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_implementation_proposal.zig
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
zig build causal-production-telemetry-implementation-proposal -- \
  --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.json \
  reject \
  --reason "negative proposal path"
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```
