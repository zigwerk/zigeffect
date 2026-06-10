# Production Telemetry CI Gate Dry-Run Policy

`causal-production-telemetry-ci-gate-dry-run-policy` consumes a reviewed
production telemetry CI gate application boundary artifact and emits a
record-only, advisory dry-run policy artifact for future CI telemetry gate
evaluation.

It does not enable CI telemetry gate enforcement, create required status
checks, mutate GitHub Actions workflows, execute artifact uploads, configure
secrets, ingest live telemetry, call networks, write NenDB, write durable
production storage, orchestrate production clusters, or grant mutation
authority.

## Command

Approve the dry-run policy from the planned or applied gate application
boundary:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-dry-run-policy -- \
  --from-gate-application-boundary ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-gate-application-boundary.json \
  approve \
  --reason "CI gate dry-run policy reviewed" \
  --verified-command "zig build causal-production-telemetry-ci-gate-application-boundary" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build release-gate --summary none" \
  --verified-command "zig build release-gate-report" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

Use `reject` to produce a blocked policy artifact for negative fixtures or
review failures.

## Source Evidence

The source artifact must use schema
`zigeffect.causal.production-telemetry-ci-gate-application-boundary.v1`, have
`gate_application_status="planned"` or `"applied"`, keep source boundary
checks free of failures, preserve disabled enforcement and write flags, and
carry application boundary rules, denied application claims, negative fixtures,
and blocked claims.

If the source boundary has `applied=false`, its mutation authority must remain
`none`. If it has `applied=true`, its mutation authority must be `record-only`.
Either state remains evidence-only for this policy.

## Policy Output

The report records:

- `dry_run_policy_status`: `ready` or `blocked`
- `ready_for_next_branch`: true only for approved, fully verified, valid
  source evidence
- advisory candidate signal policies for release-gate artifacts, causal schema
  parsing, archive policy conformance, redaction and retention conformance, CI
  handoff presence, and source boundary validity
- bounded evidence requirements and denied evidence classes
- negative fixtures for enforcement, required checks, workflow mutation, public
  uploads, live telemetry, durable writes, NenDB writes, non-NenDB adapters,
  alternate renderers, and production health claims

Every candidate signal has `evaluation_mode="dry-run"`,
`enforcement_enabled=false`, `required_status_check_enabled=false`, and
`failure_effect="advisory"`.

## Handoff

Ready dry-run policy artifacts hand off to the delivered
`codex/zigeffect-causal-production-telemetry-ci-gate-dry-run-evaluator`
branch. The evaluator inspects bounded local or CI artifacts and emits ready,
advisory, or blocked findings, but it still must not create required checks,
mutate workflows, ingest live telemetry, write durable stores, write NenDB,
claim production cluster readiness, or grant mutation authority.

Evaluator artifacts then hand off to
`codex/zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report` for
reviewer-facing CI report presentation. That report is now delivered and hands
off to
`codex/zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary`.

## Verification

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_dry_run_policy.zig
zig build causal-production-telemetry-ci-gate-dry-run-policy -- --help
zig build causal-production-telemetry-ci-gate-dry-run-policy -- \
  --from-gate-application-boundary ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-gate-application-boundary.json \
  approve \
  --reason "CI gate dry-run policy reviewed" \
  --verified-command "zig build causal-production-telemetry-ci-gate-application-boundary" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build release-gate --summary none" \
  --verified-command "zig build release-gate-report" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
zig build causal-production-telemetry-ci-gate-dry-run-policy -- \
  --from-gate-application-boundary ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-gate-application-boundary.json \
  reject \
  --reason "negative CI gate dry-run policy path" \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-dry-run-policy-negative
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```
