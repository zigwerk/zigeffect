# App-Facing CI Advisory Remediation Report Consumption Report Design

## Summary

Add a local read-only report producer for app-facing CI advisory remediation
report consumption evaluator artifacts.

The producer is:

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report -- \
  --from-evaluator <consumption-evaluator.json> \
  summarize \
  --reason <reason> \
  [--by <actor>] \
  [--policy <policy>] \
  [--out-prefix <path-prefix>]
```

It emits:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report.v1
```

The report consumes `ready` or `advisory-findings` evaluator artifacts and
renders a compact human/agent report over source refs, file analysis, checks,
signals, findings, policy rule ids, consumption scope ids, denied claims,
bounded redaction posture, and next queries. It blocks evaluator artifacts with
blocked findings or authority drift.

## Goals

- Validate source evaluator schema, status, ready flag, and disabled authority.
- Accept `ready` and `advisory-findings` evaluator artifacts as reportable.
- Preserve advisory findings as advisory, not blocked.
- Block invalid source schema, blocked evaluator status, blocked findings,
  missing request/evidence analysis, missing denied claims, missing next
  queries, and any mutation/runtime/storage/CI/GitHub/deployment authority.
- Render JSON and text artifacts for local reviewer and agent consumption.
- Hand off ready or advisory reports to an application-boundary branch that can
  record reviewed local report application evidence without granting authority.

## Non-Goals

- No app runtime integration.
- No app config writes or app data writes.
- No workbench state mutation or live UI wiring.
- No GitHub API calls, workflow edits, required status checks, check-run
  creation, CI uploads, step-summary writes, or pull request comments.
- No live agent projection, raw prompt capture, raw response capture, or raw
  payload capture.
- No durable writes, NenDB writes, NenDB adapter execution, Cockroach work, or
  non-NenDB durable adapter work.
- No deployment, production health, cluster readiness, remediation success, or
  auto-apply claims.
- No renderer change away from SolidJS inside `webui-dev/zig-webui`.

## Source Evaluator Contract

The source artifact must have:

- `schema="zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator.v1"`;
- `evaluation_status` equal to `ready` or `advisory-findings`;
- `ready_for_next_branch=true`;
- `blocked_findings_count=0`;
- `mutation_authority="none"`;
- source policy status `ready`;
- request file analysis;
- checks;
- signal evaluations;
- source interpretation rule ids;
- source consumption scope ids;
- denied claims;
- next queries;
- agent guidance.

All source authority booleans must remain disabled for CI enforcement, required
status checks, workflow mutation, GitHub mutation, app mutation, app runtime
integration, live agent projection, raw payload capture, deployment mutation,
runtime pipelines, durable writes, NenDB writes, and NenDB adapter execution.

The source must keep `advisory_report=true`, `read_only_preview=true`,
`read_only_consumption_enabled=true`, `solid_webui_enabled=true`,
`solid_webui_renderer="solidjs"`, and `webui_bridge="webui-dev/zig-webui"`.

## Report Status

`ready` means the evaluator source is ready, all report checks pass, and no
advisory findings are present.

`advisory` means the evaluator source is reportable, report checks pass, and
the source has advisory status or advisory findings.

`blocked` means any source check fails, the evaluator is blocked, blocked
findings are present, or disabled authority drift is detected.

The report uses the field:

```text
consumption_report_status
```

## Output Shape

The JSON artifact includes:

- schema metadata, source branch, recommendation, and next branch;
- source evaluator path, status, ready flag, finding counts, and source refs;
- report status, ready flag, headline, report sections, and mutation authority;
- disabled authority fields;
- request and support evidence summaries;
- signal summary, blocked findings, advisory findings, and report checks;
- source interpretation rule ids, source consumption scope ids, denied claims,
  next queries, publication channels, required verification commands, and agent
  guidance;
- local JSON/text output paths.

The text artifact mirrors the same evidence for reviewer inspection.

## Build Integration

Add a Zig executable and build step:

```text
causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report
```

Add its unit tests to the package `test` step after the consumption-evaluator
tool.

## Governance And Roadmap

Register:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report.v1
```

Update schema governance from 97 to 98 schemas. Add a delivered backlog item
for this milestone and move the recommended next branch to:

```text
codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary
```

Update the master roadmap so branch 62 is delivered and branch 63 is the
consumption-report application-boundary milestone.

## Testing

Use TDD for the report:

- constants and branch names;
- CLI parsing and invalid option coverage;
- default output suffix replacement;
- ready source produces ready report;
- advisory source produces advisory report;
- blocked source preserves blocked findings and blocks next-branch readiness;
- authority drift in source blocks report;
- local publication channels stay local-only and non-mutating;
- JSON output is parseable.

Run:

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report.zig
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_evaluator.zig
zig test --dep causal_artifact -Mroot=tools/causal_schema_governance.zig -Mcausal_artifact=tools/causal_artifact.zig
zig test tools/causal_production_hardening_backlog.zig
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report -- --help
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build test
zig build examples
cd ../..
bun run check
bun run zig:test
git diff --check
```
