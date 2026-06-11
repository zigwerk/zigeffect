# App-Facing CI Advisory Remediation Report Application Boundary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a guarded record-only application boundary for app-facing CI advisory remediation reports.

**Architecture:** Add one Zig producer that follows the existing production telemetry application-boundary pattern while consuming the app-facing CI advisory remediation report schema. The tool supports `plan` and `record-applied`, renders deterministic JSON/text artifacts, updates build wiring, schema governance, backlog, docs, and roadmap state, and keeps CI/GitHub/app/NenDB/deployment authority disabled.

**Tech Stack:** Zig 0.16.0, `std.json`, `std.crypto.hash.sha2.Sha256`, existing zigeffect build steps, Bun root verification.

---

## File Structure

- Create `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_application_boundary.zig`
  for CLI parsing, source report validation, plan/applied evaluation, artifact
  rendering, and tests.
- Modify `packages/zigeffect/build.zig` to add the executable and test step
  after the CI advisory remediation report tool.
- Create `packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-application-boundary.md`
  for command examples, modes, guardrails, and next branch.
- Modify `packages/zigeffect/tools/causal_schema_governance.zig` and generated
  `packages/zigeffect/docs/schema-governance.md` for the new schema.
- Modify `packages/zigeffect/tools/causal_production_hardening_backlog.zig` and
  generated `packages/zigeffect/docs/production-hardening-backlog.md` to mark
  this milestone delivered and advance the recommendation.
- Modify
  `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
  to mark this branch delivered and add the publication-policy follow-up.

## Tasks

### Task 1: Red Test The New Producer

- [x] Add the new Zig file with tests for constants, CLI parsing, output suffix
  replacement, planned boundary output, blocked source behavior, record-applied
  evidence gates, report-after safety, and source authority drift.
- [x] Run:

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_application_boundary.zig
```

Expected first result: compile failure or failing tests because the
implementation is not present yet.

### Task 2: Implement The Producer

- [x] Implement constants:
  - schema:
    `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-application-boundary.v1`;
  - source schema:
    `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report.v1`;
  - tool:
    `causal-app-facing-production-integration-ci-advisory-remediation-report-application-boundary`;
  - next branch:
    `codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-publication-policy`.
- [x] Implement `plan|record-applied` option parsing with:
  `--from-report`, `--reason`, `--by`, `--policy`, `--report-after`,
  `--publication-change`, `--before`, `--after`, `--verified-command`, and
  `--out-prefix`.
- [x] Implement source validation for report readiness, disabled authority,
  source checks, bridge-record presence, blocked claims, and verification
  evidence.
- [x] Implement report-after digest and safety checks.
- [x] Render JSON and text artifacts with application checks, source checks,
  bridge records, boundary rules, denied claims, and negative fixtures.
- [x] Run the Zig test command until it passes.

### Task 3: Wire Build And Generate Artifacts

- [x] Add the build executable/test step.
- [x] Run:

```sh
cd packages/zigeffect
zig build --help | rg causal-app-facing-production-integration-ci-advisory-remediation-report-application-boundary
```

- [x] Generate a planned artifact from the ready CI advisory report artifact.
- [x] Generate a record-applied artifact with reviewed before/after evidence and
  safe report-after content.
- [x] Generate a blocked negative artifact.

### Task 4: Governance, Backlog, Docs, Roadmap

- [x] Register the schema in `causal_schema_governance.zig`.
- [x] Add this milestone to `causal_production_hardening_backlog.zig` and move
  the recommendation to the publication-policy branch.
- [x] Add the user-facing docs file.
- [x] Update the master roadmap branch 56 to delivered and add branch 57 for
  publication policy.
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
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_application_boundary.zig
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
  docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-application-boundary-design.md \
  docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-application-boundary-implementation.md \
  packages/zigeffect/build.zig \
  packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-application-boundary.md \
  packages/zigeffect/docs/production-hardening-backlog.md \
  packages/zigeffect/docs/schema-governance.md \
  packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_application_boundary.zig \
  packages/zigeffect/tools/causal_production_hardening_backlog.zig \
  packages/zigeffect/tools/causal_schema_governance.zig
git commit -m "feat(zigeffect): add app-facing advisory report application boundary"
```
