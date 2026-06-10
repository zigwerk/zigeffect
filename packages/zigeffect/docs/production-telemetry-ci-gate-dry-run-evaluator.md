# Production Telemetry CI Gate Dry-Run Evaluator

`causal-production-telemetry-ci-gate-dry-run-evaluator` consumes a ready
production telemetry CI gate dry-run policy artifact plus explicit bounded
local or CI evidence files. It emits a record-only evaluator report with
observed signals, advisory findings, blocked findings, next queries, and
agent guidance.

It does not enable CI gate enforcement, create required status checks, mutate
GitHub Actions workflows, execute artifact uploads, configure secrets, ingest
live telemetry, call networks, write NenDB, write durable production storage,
orchestrate production clusters, claim production readiness, or grant mutation
authority.

## Command

Evaluate a ready dry-run policy artifact:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-dry-run-evaluator -- \
  --from-dry-run-policy ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-gate-dry-run-policy.json \
  evaluate \
  --reason "CI gate dry-run evidence evaluated" \
  --evidence .zig-cache/release-gate/zigeffect-release-gate.json \
  --evidence .zig-cache/causal-artifacts/zigeffect-causal-causal-scoped-fiber.json
```

Use `--evidence` once per explicit file. The evaluator does not crawl
directories, expand globs, fetch remote artifacts, or infer evidence.

## Source Policy

The source artifact must use schema
`zigeffect.causal.production-telemetry-ci-gate-dry-run-policy.v1`, have
`dry_run_policy_status="ready"`, `ready_for_next_branch=true`, and
`decision="approve"`.

The source must also preserve the disabled authority boundary:

- `ci_gate_enforcement_enabled=false`
- `ci_required_status_check_enabled=false`
- `ci_workflow_mutation_enabled=false`
- `ci_upload_execution_enabled=false`
- `production_telemetry_ingestion=false`
- `network_send_enabled=false`
- `runtime_pipeline_enabled=false`
- `durable_write_enabled=false`
- `nendb_write_enabled=false`

Source checks must contain no `fail` statuses, and the source policy must
include candidate signal policies, evidence requirements, and blocked claims.

## Evidence Boundary

Allowed evidence files are explicit `.json` or `.txt` files under:

- `.zig-cache/causal-artifacts/`
- `.zig-cache/release-gate/`

The evaluator classifies evidence as causal JSON/text, release-gate JSON/text,
CI handoff evidence, source policy evidence, or denied evidence. Inputs are
bounded to 32 files and 1 MiB per file.

Evidence is blocked when it contains secret-shaped material, live telemetry
enablement, network send claims, required status check enablement, workflow
mutation claims, artifact upload execution, durable writes, NenDB writes,
non-NenDB durable adapter claims, retention over fourteen days, public upload
claims, or alternate renderer claims.

## Signals

The evaluator records these dry-run signals:

- `boundary-source-valid`
- `release-gate-artifact-present`
- `causal-artifact-schema-parse`
- `archive-policy-conformance`
- `redaction-retention-conformance`
- `ci-handoff-present`

Missing release-gate, causal schema, or handoff evidence is advisory. Invalid
source policy or denied evidence is blocked.

## Statuses

- `ready`: source policy is valid, evidence is bounded, and all signals are
  observed.
- `advisory-findings`: source policy and evidence boundary are valid, but one
  or more optional evidence signals is missing.
- `blocked`: source policy is invalid, no evidence is available, evidence is
  outside the allowed boundary, or evidence contains denied markers.

`ready_for_next_branch=true` for `ready` and `advisory-findings`. It is false
for `blocked`.

## Handoff

Ready or advisory evaluator artifacts hand off to
`codex/zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report`.
That branch should decide how to present evaluator findings in CI artifacts or
reviewer summaries while still avoiding required checks, workflow mutation,
live telemetry, durable writes, NenDB writes, production cluster claims, and
mutation authority.

## Verification

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_dry_run_evaluator.zig
zig build causal-production-telemetry-ci-gate-dry-run-evaluator -- --help
zig build causal-production-telemetry-ci-gate-dry-run-evaluator -- \
  --from-dry-run-policy ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-gate-dry-run-policy.json \
  evaluate \
  --reason "CI gate dry-run evidence evaluated" \
  --evidence .zig-cache/release-gate/zigeffect-release-gate.json \
  --evidence .zig-cache/causal-artifacts/zigeffect-causal-causal-scoped-fiber.json
zig build causal-production-telemetry-ci-gate-dry-run-evaluator -- \
  --from-dry-run-policy ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-dry-run-policy-negative.json \
  evaluate \
  --reason "negative CI gate dry-run evaluator path" \
  --evidence .zig-cache/release-gate/zigeffect-release-gate.json \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-dry-run-evaluator-negative
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```
