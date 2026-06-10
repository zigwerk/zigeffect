# Production Telemetry CI Gate Readiness

`causal-production-telemetry-ci-gate-readiness` consumes a ready production
telemetry CI archive evidence policy artifact and emits a record-only readiness
artifact for a future CI telemetry gate application boundary.

It does not edit `.github/workflows/zigeffect-causal.yml`, enable CI gates,
create required status checks, execute artifact uploads, configure secrets,
ingest live telemetry, write NenDB, write durable production storage,
orchestrate production clusters, or grant mutation authority.

## Command

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-readiness -- \
  --from-archive-evidence-policy ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-archive-evidence-policy.json \
  approve \
  --reason "CI gate readiness reviewed" \
  --verified-command "zig build causal-production-telemetry-ci-archive-evidence-policy" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build release-gate --summary none" \
  --verified-command "zig build release-gate-report" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

Use `reject --reason <reason>` to produce a blocked readiness artifact. Use
`--out-prefix <path-prefix>` for negative-path artifacts.

## Source Evidence

The source artifact must use schema
`zigeffect.causal.production-telemetry-ci-archive-evidence-policy.v1`, have
`archive_evidence_policy_status="ready"`, set
`ready_for_next_branch=true`, preserve disabled authority flags, and carry
archive evidence classes, required metadata, interpretation rules, negative
fixtures, and blocked claims.

## Readiness Dimensions

The report records:

- `source-policy-ready`
- `archive-evidence-bounded`
- `release-gate-contract-present`
- `cluster-workflow-aligned`
- `gate-semantics-limited`
- `redaction-retention-reviewed`
- `human-review-before-application`

The existing `zig build release-gate --summary none` remains the
clustering-aware execution body. `zig build release-gate-report` remains the
artifact producer for `.zig-cache/release-gate` text and JSON reports.

## Candidate Gate Signals

Candidate signals are advisory and record `enforcement_enabled=false`:

- `release-gate-artifact-present`
- `causal-artifact-schema-parse`
- `archive-policy-conformance`
- `redaction-retention-conformance`
- `ci-handoff-present`

They may guide a later gate application boundary. They do not fail CI in this
branch.

## Status

- `ready`: the source archive evidence policy is ready, source authority is
  disabled, required evidence classes and metadata exist, source negative
  fixtures are present, blocked claims are carried forward, reviewer approved,
  every required verification command is recorded, release-gate verification is
  recorded, and readiness catalogs are valid.
- `blocked`: source policy is blocked or malformed, reviewer rejected,
  verification evidence is incomplete, release-gate verification is missing,
  authority is enabled, or readiness catalogs are invalid.

`ready_for_next_branch=true` means
`codex/zigeffect-causal-production-telemetry-ci-gate-application-boundary` may
be started. It does not approve CI gate enforcement, required status checks,
workflow mutation, artifact upload execution, live telemetry, runtime
pipelines, NenDB writes, durable writes, hosted dashboards, production cluster
claims, or mutation authority.

That application boundary is now delivered by
`causal-production-telemetry-ci-gate-application-boundary`. The dry-run policy
is now delivered by `causal-production-telemetry-ci-gate-dry-run-policy`. The
dry-run evaluator is now delivered by
`causal-production-telemetry-ci-gate-dry-run-evaluator`. The advisory CI
report is now delivered by
`causal-production-telemetry-ci-gate-advisory-ci-report`. The current next
branch is
`codex/zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary`.

## Verification

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_readiness.zig
zig build causal-production-telemetry-ci-gate-readiness -- --help
zig build causal-production-telemetry-ci-gate-readiness -- \
  --from-archive-evidence-policy ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-archive-evidence-policy.json \
  approve \
  --reason "CI gate readiness reviewed" \
  --verified-command "zig build causal-production-telemetry-ci-archive-evidence-policy" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build release-gate --summary none" \
  --verified-command "zig build release-gate-report" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
zig build causal-production-telemetry-ci-gate-readiness -- \
  --from-archive-evidence-policy ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-archive-evidence-policy.json \
  reject \
  --reason "negative CI gate readiness path" \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-readiness-negative
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```
