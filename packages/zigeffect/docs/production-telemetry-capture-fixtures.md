# zigeffect Causal Production Telemetry Capture Fixtures

`causal-production-telemetry-capture-fixtures` emits deterministic fixture
records for future production telemetry capture. The fixtures are examples and
validation evidence only: they teach agents the approved record shapes and the
claims that must remain blocked before any live telemetry work is reviewed.

The report uses schema
`zigeffect.causal.production-telemetry-capture-fixtures.v1`.

## Command

```sh
cd packages/zigeffect
zig build causal-production-telemetry-capture-fixtures
zig build causal-production-telemetry-capture-fixtures -- --format json
zig build causal-production-telemetry-capture-fixtures -- emit runtime-trace-span-event --format json
zig build causal-production-telemetry-capture-fixtures -- validate --format json
```

## Boundary

The top-level authority fields are fixed:

- `status="fixtures-only"`
- `applied=false`
- `mutation_authority="none"`
- `production_telemetry_ingestion=false`
- `live_exporter_enabled=false`
- `durable_write_enabled=false`
- `ci_gate_enabled=false`

The fixture catalog does not enable live ingestion, exporters, OTLP sends,
collector endpoints, durable production writes, CI gates, production capacity
claims, non-NenDB adapter work, alternate renderers, or mutation authority.

## Positive Fixtures

The positive fixture ids are:

- `runtime-trace-span-event`
- `app-semantic-redacted-ref`
- `backend-export-otel-record`
- `redaction-access-evidence`
- `local-observation-correlation-ref`
- `sampling-boundary-sampled-in`

Each positive fixture carries the full telemetry field contract from the
production telemetry capture design report: capture surface, source schema,
signal kind, event kind policy, redaction state, sampling policy, retention
policy, access policy ref, encryption policy ref, disabled transport state,
disabled durable state, local observation refs, review gate, blocked claims,
sample attributes, expected agent use, and forbidden inference.

## Negative Fixtures

The negative fixtures reject live exporters, collector endpoints, raw request
bodies, raw headers, raw prompts, credential or token capture, unbounded
cardinality, sampled-out forwarding, local observations as production capacity
evidence, non-NenDB durable storage, Cockroach adapter work, React or alternate
renderer work, CI telemetry gates, and mutation authority.

## Validation

`validate` emits deterministic checks for:

- positive fixture surface coverage;
- required telemetry field coverage;
- negative fixture blocked-claim coverage;
- forbidden value absence;
- local observation separation;
- NenDB retention direction;
- SolidJS `webui-dev/zig-webui` direction;
- record-only authority boundaries.

Validation runs over static reviewed tables. It does not read live systems,
generated artifacts, environment data, clocks, or network resources.

## Agent Guidance

Agents should cite fixture ids, field names, and validation checks when
proposing future telemetry work. They should use the negative fixtures to
reject raw payload, endpoint, credential, unbounded, non-NenDB, CI, renderer,
and mutation claims.

The readiness review branch is delivered through
`causal-production-telemetry-readiness-review`. It consumes fixture JSON and
emits `ready` or `blocked` artifacts before any implementation proposal branch.
The implementation proposal branch is delivered through
`causal-production-telemetry-implementation-proposal`, and the exporter
boundary branch is delivered through
`causal-production-telemetry-exporter-boundary`. The local-pipeline-fixtures
branch is delivered through
`causal-production-telemetry-local-pipeline-fixtures`. The NenDB-retention
fixtures branch is delivered through
`causal-production-telemetry-nendb-retention-fixtures`. The workbench
read-only preview handoff is delivered through
`causal-production-telemetry-workbench-readonly-preview`. The CI artifact
preview handoff is delivered through
`causal-production-telemetry-ci-artifact-preview`. The CI harness boundary
handoff is delivered through
`causal-production-telemetry-ci-harness-boundary`. The CI archive application
handoff is delivered through
`causal-production-telemetry-ci-archive-application`. The CI archive evidence
policy handoff is delivered through
`causal-production-telemetry-ci-archive-evidence-policy`.
The current next branch is
`codex/zigeffect-causal-production-telemetry-ci-gate-readiness`.

## Verification

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_capture_fixtures.zig
zig build causal-production-telemetry-capture-fixtures
zig build causal-production-telemetry-capture-fixtures -- --format json
zig build causal-production-telemetry-capture-fixtures -- emit runtime-trace-span-event --format json
zig build causal-production-telemetry-capture-fixtures -- validate --format json
zig build causal-production-telemetry-readiness-review -- \
  --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json \
  approve \
  --reason "fixtures reviewed for implementation proposal" \
  --verified-command "zig build causal-production-telemetry-capture-fixtures -- validate --format json" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
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
