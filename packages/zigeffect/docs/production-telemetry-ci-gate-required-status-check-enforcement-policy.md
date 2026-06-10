# Production Telemetry CI Gate Required Status Check Enforcement Policy

Schema:
`zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-policy.v1`

`causal-production-telemetry-ci-gate-required-status-check-enforcement-policy`
consumes a reviewed required-status-check enforcement application-boundary
artifact and emits a record-only interpretation policy. It decides whether
later agents may cite planned enforcement evidence, externally applied active
required-status-check enforcement evidence, or merge-blocking evidence.

It does not mutate GitHub, branch protection, workflows, check runs, CI
uploads, GitHub step summaries, pull-request comments, live telemetry,
runtime storage, durable stores, NenDB, non-NenDB adapters, renderer choices,
or production systems. It grants no mutation authority.

## Command

Review an enforcement application-boundary artifact:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-policy -- \
  --from-application-boundary ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-application-boundary.json \
  approve \
  --reason "required status check enforcement policy reviewed" \
  --verified-command "zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build release-gate --summary none" \
  --verified-command "zig build release-gate-report" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

Negative path:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-policy -- \
  --from-application-boundary ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-application-boundary-negative.json \
  reject \
  --reason "negative required status check enforcement policy path" \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-policy-negative
```

## Source Contract

The source artifact must use schema
`zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-application-boundary.v1`
with schema version `1`.

Allowed source states:

- `mode="plan"`, `applied=false`,
  `required_status_check_enforcement_application_status="planned"`, and
  `mutation_authority="none"`;
- `mode="record-applied"`, `applied=true`,
  `required_status_check_enforcement_application_status="applied"`, and
  `mutation_authority="none"`.

All GitHub, workflow, check-run, CI upload, summary, comment, live telemetry,
runtime, durable, and NenDB authority fields must remain disabled. Source
checks must contain no failures, evidence catalogs must be present, and the
source must record every required verification command.

## Interpretation Policy

The emitted `enforcement_interpretation_policy` has three branches:

- `planned-enforcement`: planned evidence can guide evaluator design only.
  Active enforcement and merge blocking remain false.
- `applied-active-enforcement`: applied source evidence may be cited as a
  reviewed external active-enforcement record only when the source records
  active enforcement and allows that claim.
- `merge-blocking`: merge-blocking evidence may be cited only when the source
  is applied, records merge blocking, allows the merge-blocker claim, and
  includes merge-blocking evidence.

## Denied Inferences

The policy explicitly denies GitHub API mutation by the tool, branch-protection
mutation by the tool, workflow mutation by the tool, check-run creation by the
tool, CI upload execution by the tool, GitHub step-summary or pull-request
comment writes by the tool, live telemetry coverage, production health,
deployment success, customer impact, production cluster readiness, durable
writes, NenDB writes, non-NenDB durable adapters, alternate renderers, and
mutation authority.

## Handoff

Ready enforcement-policy artifacts hand off to:

`codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-evaluator`

The evaluator should compare bounded observed evidence against this policy. It
must remain record-only and must not create or mutate GitHub state.

## Verification

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_policy.zig
zig test tools/causal_production_hardening_backlog.zig
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-policy -- --help
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-policy -- \
  --from-application-boundary ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-application-boundary.json \
  approve \
  --reason "required status check enforcement policy reviewed" \
  --verified-command "zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build release-gate --summary none" \
  --verified-command "zig build release-gate-report" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```
