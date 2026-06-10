# zigeffect Causal Production Telemetry Capture Design

`causal-production-telemetry-capture-design` is a schema-governed design
report for future production telemetry capture. It defines which telemetry
surfaces may be modeled, which fields every future record must carry, and which
review gates must pass before fixture or live telemetry work can proceed.

The report is deliberately design-only. It does not ingest live production
telemetry, configure an exporter, send OTLP, write durable production storage,
size production capacity, fail CI, add non-NenDB adapter work, add alternate
renderer work, or grant mutation authority.

## Command

```sh
cd packages/zigeffect
zig build causal-production-telemetry-capture-design
zig build causal-production-telemetry-capture-design -- --format json
```

The report uses schema
`zigeffect.causal.production-telemetry-capture-design.v1`.

## Report Boundary

The top-level authority fields are intentionally fixed:

- `status="design-only"`
- `applied=false`
- `mutation_authority="none"`
- `production_telemetry_ingestion=false`
- `live_exporter_enabled=false`

Agents may cite the report to classify future telemetry fixture work. They must
not infer that production telemetry is live, that a collector endpoint exists,
that durable production writes are allowed, that CI may fail on telemetry
evidence, or that production capacity has been measured.

## Capture Surfaces

- `runtime-trace`: core causal runtime events mapped to spans or span events
  through the existing OTel record bridge.
- `app-semantic`: app semantic trace API events such as redacted data refs,
  domain refs, schema refs, policy decisions, artifacts, and responses.
- `backend-export-otel`: exporter-neutral `CausalOtelRecord` values from the
  backend bridge and conformance tests.
- `redaction-access`: redaction state, trust boundary, visibility class, and
  review gate names from aggregation, access-control, and encryption contracts.
- `local-observation-correlation`: local observation refs from the load-test
  observation harness, kept advisory and separate from production evidence.

## Field Contract

Future production telemetry fixtures should model these fields before any live
capture exists:

- `capture_surface_id`
- `source_schema`
- `signal_kind`
- `event_kind_policy`
- `redaction_state`
- `sampling_policy`
- `retention_policy`
- `access_policy_ref`
- `encryption_policy_ref`
- `telemetry_transport_state`
- `durable_write_state`
- `local_observation_refs`
- `review_gate`
- `blocked_claims`

The design rejects environment hostnames, endpoints, raw user ids, tenant ids,
credentials, request bodies, headers, prompts, raw payload fragments,
unbounded attributes, sampled-out forwarded events, and production capacity
claims.

## Readiness Gates

- `schema-registered`
- `redaction-reviewed`
- `sampling-bounded`
- `retention-nendb-compatible`
- `access-policy-reviewed`
- `encryption-policy-reviewed`
- `otel-bridge-reviewed`
- `local-observation-separated`
- `capacity-claim-blocked`
- `fixture-handoff-ready`

These gates are prerequisites for the next fixture branch. They do not approve
live collection, storage, dashboards, CI gates, or production mutations.

## Negative Fixtures

The report rejects live exporters, OTLP collector endpoints, raw request body
capture, raw header capture, raw prompt capture, credential capture, unbounded
attribute cardinality, sampled-out event forwarding, local observations treated
as production capacity evidence, non-NenDB durable storage, Cockroach adapter
work, React or alternate renderer work, CI telemetry gates, and mutation
authority.

## Agent Guidance

Agents should classify the capture surface first, cite the source schema and
review gates, keep local observations separate from production telemetry, and
use `blocked_claims` to avoid over-stating evidence.

The fixture branch is now delivered through
`causal-production-telemetry-capture-fixtures`. It models approved telemetry
records without touching production systems. The readiness-review branch is now
delivered through `causal-production-telemetry-readiness-review`, and the
implementation-proposal branch is now delivered through
`causal-production-telemetry-implementation-proposal`, and the
exporter-boundary branch is now delivered through
`causal-production-telemetry-exporter-boundary`. The local-pipeline-fixtures
branch is now delivered through
`causal-production-telemetry-local-pipeline-fixtures`. The NenDB-retention
fixtures branch is now delivered through
`causal-production-telemetry-nendb-retention-fixtures`. The workbench
read-only preview handoff is now delivered through
`causal-production-telemetry-workbench-readonly-preview`. The CI artifact
preview handoff is now delivered through
`causal-production-telemetry-ci-artifact-preview`. The CI harness boundary
handoff is now delivered through
`causal-production-telemetry-ci-harness-boundary`. The CI archive application
handoff is now delivered through
`causal-production-telemetry-ci-archive-application`. The CI archive evidence
policy handoff is now delivered through
`causal-production-telemetry-ci-archive-evidence-policy`.
The CI gate readiness handoff is now delivered through
`causal-production-telemetry-ci-gate-readiness`.
The CI gate application boundary handoff is now delivered through
`causal-production-telemetry-ci-gate-application-boundary`.
The CI gate dry-run policy handoff is now delivered through
`causal-production-telemetry-ci-gate-dry-run-policy`.
The CI gate dry-run evaluator handoff is now delivered through
`causal-production-telemetry-ci-gate-dry-run-evaluator`.
The CI gate advisory CI report handoff is now delivered through
`causal-production-telemetry-ci-gate-advisory-ci-report`.
The CI gate advisory CI report application boundary handoff is now delivered
through `causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary`.
The current next branch is
`codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-application-boundary`.

## Verification

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_capture_design.zig
zig build causal-production-telemetry-capture-design
zig build causal-production-telemetry-capture-design -- --format json
zig build causal-production-telemetry-capture-fixtures
zig build causal-production-telemetry-capture-fixtures -- --format json
zig build causal-production-telemetry-capture-fixtures -- emit runtime-trace-span-event --format json
zig build causal-production-telemetry-capture-fixtures -- validate --format json
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
