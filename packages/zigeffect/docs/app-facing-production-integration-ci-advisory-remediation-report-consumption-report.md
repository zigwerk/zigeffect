# App-Facing CI Advisory Remediation Report Consumption Report

`causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report`
consumes a ready or advisory app-facing advisory remediation report
consumption-evaluator artifact and emits
`zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report.v1`.

The report is a local read-only presentation artifact for humans and agents. It
summarizes source refs, request analysis, support evidence, signals, findings,
policy rules, denied claims, next queries, and authority boundaries. It never
turns evaluator evidence into app runtime integration, storage writes, GitHub
mutation, CI enforcement, deployment authority, public artifact upload, or
mutation authority.

## Ready Command

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report -- \
  --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-consumption-evaluator.json \
  summarize \
  --reason "reviewed app-facing advisory remediation report consumption report"
```

Without `--out-prefix`, the tool writes sibling `.json` and `.txt` report
artifacts beside the source evaluator artifact.

## Advisory Command

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report -- \
  --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-evaluator-advisory.json \
  summarize \
  --reason "advisory app-facing consumption report source" \
  --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-advisory
```

Advisory reports are reportable. They keep advisory findings visible and do not
block the next branch by themselves.

## Blocked Command

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report -- \
  --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-evaluator-blocked.json \
  summarize \
  --reason "blocked app-facing consumption report source" \
  --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-blocked
```

Blocked reports preserve blocked source findings and set
`ready_for_next_branch=false`.

## Source Contract

The source artifact must use schema
`zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator.v1`.

Reportable sources have:

- `evaluation_status="ready"` or `evaluation_status="advisory-findings"`;
- `ready_for_next_branch=true`;
- `blocked_findings_count=0`;
- `mutation_authority="none"`;
- `source_policy_status="ready"`;
- source consumption policy, boundary, readiness, publication-policy, and digest
  refs;
- request file analysis;
- checks and signal evaluations;
- source policy rule ids and consumption scope ids;
- denied claims, next queries, and agent guidance;
- SolidJS `webui-dev/zig-webui` read-only scope.

The source must keep CI enforcement, required status checks, workflow mutation,
GitHub mutation, app mutation, app runtime integration, live agent projection,
raw payload capture, deployment mutation, runtime pipelines, durable writes,
NenDB writes, and NenDB adapter execution disabled.

## Statuses

`ready` means all report checks pass and the source evaluator has no advisory or
blocked findings.

`advisory` means all report checks pass but the source evaluator is
`advisory-findings` or carries advisory findings.

`blocked` means any report check fails, the evaluator source is blocked, blocked
findings are present, or authority drift is detected.

## Output

The JSON artifact includes:

- source evaluator path, status, source refs, finding counts, and report status;
- request and support evidence summaries;
- signal summary, blocked findings, advisory findings, and checks;
- source policy rule ids, source consumption scope ids, denied claims, and next
  queries;
- local publication channels;
- disabled authority fields;
- required verification commands and agent guidance;
- local JSON/text output paths.

The text artifact mirrors the same evidence for reviewer inspection.

## Local Publication Boundary

The tool writes only local JSON and text artifacts. It does not upload CI
artifacts, write GitHub step summaries, post pull request comments, create
required status checks, update branch protection, wire app runtime code, write
NenDB, execute a NenDB adapter, deploy anything, prove production health, expose
public artifacts, or grant mutation authority.

## Handoff

Ready and advisory consumption-report artifacts hand off to:

```text
codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary
```

That branch should record reviewed local report application evidence. It must
still avoid mutation authority, runtime wiring, required CI, GitHub mutation,
app mutation, NenDB writes, NenDB adapter execution, Cockroach scope,
deployment, production health claims, public artifact upload, and alternate
renderer scope.

## Verification

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report.zig
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_evaluator.zig
zig test --dep causal_artifact -Mroot=tools/causal_schema_governance.zig -Mcausal_artifact=tools/causal_artifact.zig
zig test tools/causal_production_hardening_backlog.zig
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report -- --help
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```
