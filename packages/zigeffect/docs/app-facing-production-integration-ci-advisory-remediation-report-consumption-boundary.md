# App-Facing CI Advisory Remediation Report Consumption Boundary

`causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary`
consumes a ready app-facing advisory remediation report consumption-readiness
artifact and emits
`zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary.v1`.

This is a guarded read-only application boundary for consuming advisory report
evidence. It can record planned or reviewed-applied local consumption evidence
for reviewers, agents, non-blocking CI advisory readers, and the SolidJS
`webui-dev/zig-webui` workbench.

Applied records grant only `mutation_authority="record-only"` inside the
artifact. They do not mutate app config or data, wire the app runtime, mutate
workbench state, call GitHub, edit workflows, create required status checks,
publish reports, upload artifacts, write NenDB, execute a NenDB adapter, add
Cockroach scope, deploy anything, prove production health, or enable live agent
projections.

## Plan Command

Use `plan` to record reviewed intent. Plan mode never sets `applied=true`.

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary -- \
  --from-readiness ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-consumption-readiness.json \
  plan \
  --reason "app-facing advisory remediation report consumption boundary planned" \
  --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-boundary-plan
```

## Record-Applied Command

Use `record-applied` only after a local read-only consumption boundary has been
reviewed with before/after evidence, safe after-boundary text, and verification
commands.

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary -- \
  --from-readiness ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-consumption-readiness.json \
  record-applied \
  --reason "reviewed app-facing advisory remediation report consumption boundary" \
  --consumer-after ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-boundary-after.txt \
  --consumer-change "reviewed read-only consumer boundary for agents CI advisory readers reviewers and SolidJS webui" \
  --before "before local read-only consumption boundary evidence" \
  --after "after local read-only consumption boundary evidence" \
  --verified-command "bun run zigeffect:workbench:typecheck" \
  --verified-command "bun run zigeffect:workbench:test" \
  --verified-command "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

## Negative Command

This records a blocked path when applied evidence is missing.

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary -- \
  --from-readiness ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-consumption-readiness.json \
  record-applied \
  --reason "negative app-facing advisory remediation report consumption boundary path" \
  --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-boundary-negative
```

## Source Contract

The source artifact must use schema
`zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness.v1`,
have `decision="approve"`, set `consumption_readiness_status="ready"`, set
`ready_for_next_branch=true`, and keep `mutation_authority="none"`.

The source must carry:

- publication-policy and after-report digest refs;
- passing readiness checks;
- read-only consumer profiles;
- readiness dimensions;
- consumption guardrails;
- denied inference rules;
- negative fixtures;
- blocked claims;
- required and verified command evidence.

The source must keep CI, GitHub, app, runtime, deployment, durable, NenDB, and
adapter authority disabled while preserving SolidJS `webui-dev/zig-webui`
read-only scope.

## Consumer-After Safety

`--consumer-after` content must include:

- `zigeffect`
- `causal`
- `read-only`
- `consumption`
- `boundary`

It must not claim required status checks, CI enforcement, GitHub mutation, app
mutation, app runtime integration, live agent projection, raw payload capture,
deployment success, production health, durable writes, NenDB writes, NenDB
adapter execution, Cockroach work, React or alternate renderer scope, auto-apply
behavior, or mutation authority beyond record-only artifact evidence.

## Handoff

Applied consumption-boundary artifacts hand off to:

```text
codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-policy
```

That branch should define how agents, reviewers, CI advisory readers, and the
SolidJS workbench interpret applied read-only consumption-boundary records. It
still must not create mutation, runtime, storage, deployment, required CI, or
production-health authority.

## Verification

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_boundary.zig
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary -- --help
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```
