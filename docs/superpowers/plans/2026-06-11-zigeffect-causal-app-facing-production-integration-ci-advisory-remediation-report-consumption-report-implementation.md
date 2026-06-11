# App-Facing CI Advisory Remediation Report Consumption Report Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the local read-only consumption-report producer for app-facing
CI advisory remediation report consumption evaluator artifacts.

**Architecture:** Add one Zig report producer that consumes reportable evaluator
artifacts, validates disabled authority, emits ready/advisory/blocked JSON and
text report artifacts, and updates build, schema governance, backlog, docs, and
the master roadmap. The report is local-only and hands off to an
application-boundary branch.

**Tech Stack:** Zig 0.16.0, `std.json`, existing zigeffect build steps, Bun root
verification.

---

## File Structure

- Create
  `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report.zig`
  for CLI parsing, evaluator validation, report rendering, local publication
  channels, and unit tests.
- Modify `packages/zigeffect/build.zig` to add the executable and test step
  after the consumption-evaluator tool.
- Create
  `packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report.md`
  for command examples, source contract, statuses, output shape, denied
  authority, and handoff.
- Modify `packages/zigeffect/tools/causal_schema_governance.zig` and generated
  `packages/zigeffect/docs/schema-governance.md` for the new schema.
- Modify `packages/zigeffect/tools/causal_production_hardening_backlog.zig` and
  generated `packages/zigeffect/docs/production-hardening-backlog.md` to mark
  this milestone delivered and advance the recommendation.
- Modify
  `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
  to mark branch 62 delivered and add branch 63 for the
  consumption-report application boundary.

## Tasks

### Task 1: Red Test The Consumption Report Producer

- [x] Add the new Zig file with failing tests for constants, CLI parsing,
  invalid options, output suffix replacement, ready output, advisory output,
  blocked output, authority drift blocking, local-only publication channels,
  and parseable JSON.
- [x] Run:

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report.zig
```

Expected first result: compile failure or failing tests because implementation
constants/functions are not present yet.

### Task 2: Implement The Report

- [x] Implement constants:
  - schema:
    `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report.v1`;
  - source schema:
    `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator.v1`;
  - tool:
    `causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report`;
  - next branch:
    `codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary`.
- [x] Implement option parsing for:
  `--from-evaluator`, `summarize`, `--reason`, `--by`, `--policy`, and
  `--out-prefix`.
- [x] Implement source evaluator validation for reportable `ready` and
  `advisory-findings` statuses, ready flag, no blocked findings, source refs,
  request/evidence summaries, signals, checks, denied claims, rule ids, scope
  ids, next queries, guidance, and SolidJS WebUI scope.
- [x] Implement disabled authority checks for CI, GitHub, app, runtime,
  deployment, durable, NenDB, and adapter boundaries.
- [x] Implement report statuses: `ready`, `advisory`, and `blocked`.
- [x] Render JSON and text artifacts with source refs, evidence summaries,
  signals, findings, checks, denied claims, policy rule ids, scope ids, next
  queries, local publication channels, disabled authority fields, and handoff.
- [x] Run the Zig test command until it passes.

### Task 3: Wire Build And Generate Artifacts

- [x] Add the build executable/test step.
- [x] Run:

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report -- --help
```

- [x] Generate a ready consumption-report artifact from the default ready
  evaluator artifact:

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report -- \
  --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-consumption-evaluator.json \
  summarize \
  --reason "reviewed app-facing advisory remediation report consumption report"
```

- [x] Generate an advisory report artifact:

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report -- \
  --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-evaluator-advisory.json \
  summarize \
  --reason "advisory app-facing consumption report source" \
  --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-advisory
```

- [x] Generate a blocked report artifact:

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report -- \
  --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-evaluator-blocked.json \
  summarize \
  --reason "blocked app-facing consumption report source" \
  --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-blocked
```

### Task 4: Governance, Backlog, Docs, Roadmap

- [x] Register the schema in `causal_schema_governance.zig`.
- [x] Update schema count tests from `97` to `98` and add text/JSON coverage
  assertions for the new schema.
- [x] Add this milestone to `causal_production_hardening_backlog.zig` and move
  the recommendation to the consumption-report application-boundary branch.
- [x] Add ready/advisory/blocked report commands to backlog verification
  commands.
- [x] Add the user-facing docs file.
- [x] Update the master roadmap branch 62 to delivered and add branch 63 for
  the consumption-report application-boundary milestone.
- [x] Regenerate:

```sh
cd packages/zigeffect
zig build causal-schema-governance > docs/schema-governance.md 2>&1
zig build causal-production-hardening-backlog > docs/production-hardening-backlog.md 2>&1
```

### Task 5: Verify And Commit

- [x] Run:

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
```

- [x] Run:

```sh
bun run check
bun run zig:test
git diff --check
```

- [x] Stage and commit:

```sh
git add docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md \
  docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-design.md \
  docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-implementation.md \
  packages/zigeffect/build.zig \
  packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report.md \
  packages/zigeffect/docs/production-hardening-backlog.md \
  packages/zigeffect/docs/schema-governance.md \
  packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report.zig \
  packages/zigeffect/tools/causal_production_hardening_backlog.zig \
  packages/zigeffect/tools/causal_schema_governance.zig
git commit -m "feat(zigeffect): add app-facing advisory report consumption report"
```
