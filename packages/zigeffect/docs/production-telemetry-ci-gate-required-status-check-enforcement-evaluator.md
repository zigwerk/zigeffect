# Production Telemetry CI Gate Required Status Check Enforcement Evaluator

Schema:
`zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-evaluator.v1`

`causal-production-telemetry-ci-gate-required-status-check-enforcement-evaluator`
consumes a reviewed required-status-check enforcement policy artifact plus
explicit bounded evidence files. It emits a record-only evaluator report that
classifies the evidence as `ready`, `advisory-findings`, or `blocked`.

The evaluator is an analysis boundary. It does not mutate GitHub, branch
protection, workflows, check runs, CI uploads, GitHub step summaries,
pull-request comments, live telemetry, runtime storage, durable stores, NenDB,
non-NenDB adapters, renderer choices, or production systems. It grants no
mutation authority.

## Command

Evaluate ready enforcement-policy evidence:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-evaluator -- \
  --from-policy ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-policy.json \
  evaluate \
  --reason "required status check enforcement evidence evaluated" \
  --evidence ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-policy.json \
  --evidence ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-application-boundary.json \
  --evidence .zig-cache/release-gate/zigeffect-release-gate.json
```

Negative path:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-evaluator -- \
  --from-policy ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-policy-negative.json \
  evaluate \
  --reason "negative required status check enforcement evaluator path" \
  --evidence ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-policy-negative.json \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-evaluator-negative
```

## Evidence Contract

Evidence is explicit and bounded:

- at least one evidence file is required;
- at most 32 evidence files are accepted;
- each evidence file is limited to one MiB;
- evidence paths must end in `.json` or `.txt`;
- the evaluator does not recurse directories, inspect live systems, use
  network access, or infer evidence from generated caches unless the path is
  explicitly provided.

Supported evidence classes are `source_policy`, `source_application_boundary`,
`release_gate_json`, `release_gate_text`, `causal_json`, `causal_text`, and
`denied`.

## Evaluation States

`ready` means the source enforcement policy is ready, bounded evidence is safe,
and observed active-enforcement or merge-blocking evidence matches the policy.

`advisory-findings` means the source policy is ready and evidence is safe, but
active-enforcement or merge-blocking observations are missing or exceed what
the source policy allows. Advisory artifacts may hand off to the enforcement
report branch as evidence, not as production authority.

`blocked` means the source policy is not ready, required verification is
missing, source catalogs are incomplete, the source schema is unsupported, or
evidence contains denied claims.

## Denied Claims

The evaluator blocks or denies evidence that claims tool-side GitHub mutation,
branch-protection mutation, workflow mutation, check-run creation, CI upload
execution, GitHub step summary writes, pull-request comments, live telemetry,
production health, deployment success, customer impact, production cluster
readiness, durable writes, NenDB writes, non-NenDB durable adapters, alternate
renderers, secrets, or mutation authority.

## Handoff

Ready or advisory evaluator artifacts hand off to:

`codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report`

The enforcement report branch should summarize evaluator findings and preserve
blocked/advisory evidence without converting them into GitHub, CI, production,
durable storage, NenDB, renderer, or mutation authority.

## Verification

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_evaluator.zig
zig test tools/causal_production_hardening_backlog.zig
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-evaluator -- --help
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-evaluator -- \
  --from-policy ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-policy.json \
  evaluate \
  --reason "required status check enforcement evidence evaluated" \
  --evidence ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-policy.json \
  --evidence ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-application-boundary.json \
  --evidence .zig-cache/release-gate/zigeffect-release-gate.json
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-evaluator -- \
  --from-policy ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-policy-negative.json \
  evaluate \
  --reason "negative required status check enforcement evaluator path" \
  --evidence ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-policy-negative.json \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-evaluator-negative
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```
