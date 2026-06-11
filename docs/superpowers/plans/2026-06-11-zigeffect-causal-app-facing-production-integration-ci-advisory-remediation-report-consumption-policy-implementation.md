# App-Facing CI Advisory Remediation Report Consumption Policy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the guarded read-only consumption-policy artifact for applied app-facing CI advisory remediation report consumption-boundary evidence.

**Architecture:** Add one Zig producer that consumes applied consumption-boundary artifacts, supports `approve` and `reject` decisions, emits deterministic JSON/text policy artifacts, and never grants runtime, app, CI, GitHub, storage, deployment, or adapter authority. Wire it into build, schema governance, backlog, user docs, and the master roadmap.

**Tech Stack:** Zig 0.16.0, `std.json`, `std.crypto.hash.sha2.Sha256`, existing zigeffect build steps, Bun root verification.

---

## File Structure

- Create `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_policy.zig`
  for CLI parsing, source boundary validation, `approve`/`reject` policy
  evaluation, artifact rendering, and unit tests.
- Modify `packages/zigeffect/build.zig` to add the executable and test step
  after the app-facing consumption-boundary tool.
- Create `packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-policy.md`
  for command examples, source contract, decision semantics, denied claims, and
  next-branch handoff.
- Modify `packages/zigeffect/tools/causal_schema_governance.zig` and generated
  `packages/zigeffect/docs/schema-governance.md` for the new schema.
- Modify `packages/zigeffect/tools/causal_production_hardening_backlog.zig` and
  generated `packages/zigeffect/docs/production-hardening-backlog.md` to mark
  this milestone delivered and advance the recommendation.
- Modify
  `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
  to mark branch 60 delivered and add branch 61 for the consumption evaluator.

## Tasks

### Task 1: Red Test The Consumption Policy Producer

- [x] Add the new Zig file with failing tests for constants, CLI parsing,
  output suffix replacement, approved policy output, rejected policy output,
  unsafe source rejection, missing verification rejection, interpretation rule
  presence, consumption scope presence, denied rule presence, and negative
  fixture presence.
- [x] Run:

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_policy.zig
```

Expected first result: compile failure or failing tests because implementation
constants/functions are not present yet.

### Task 2: Implement The Producer

- [x] Implement constants:
  - schema:
    `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-policy.v1`;
  - source schema:
    `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary.v1`;
  - tool:
    `causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-policy`;
  - next branch:
    `codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator`.
- [x] Implement option parsing for:
  `--from-boundary`, `approve|reject`, `--reason`, `--by`, `--policy`,
  `--verified-command`, and `--out-prefix`.
- [x] Implement source validation for applied consumption-boundary evidence,
  record-only source authority, disabled CI/GitHub/app/runtime/storage/
  deployment authority, source consumer profiles, source readiness dimensions,
  source guardrails, boundary rules, denied boundary claims, negative fixtures,
  blocked claims, and verification evidence.
- [x] Implement interpretation rules for maintainers, bounded agents,
  non-blocking CI advisory readers, SolidJS workbench viewers, and the future
  consumption evaluator.
- [x] Implement read-only consumption scopes for local JSON/text artifacts,
  SolidJS workbench rendering, bounded agent context, non-blocking CI advisory
  reading, and future evaluator input.
- [x] Render JSON and text artifacts with policy checks, source evidence refs,
  interpretation rules, scopes, denied claims, negative fixtures, disabled
  authority fields, and next-branch guidance.
- [x] Run the Zig test command until it passes.

### Task 3: Wire Build And Generate Artifacts

- [x] Add the build executable/test step.
- [x] Run:

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-policy -- --help
```

- [x] Generate an approved consumption-policy artifact:

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-policy -- \
  --from-boundary ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-consumption-boundary.json \
  approve \
  --reason "reviewed app-facing advisory remediation report consumption policy" \
  --verified-command "bun run zigeffect:workbench:typecheck" \
  --verified-command "bun run zigeffect:workbench:test" \
  --verified-command "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

- [x] Generate a blocked negative policy artifact:

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-policy -- \
  --from-boundary ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-consumption-boundary.json \
  reject \
  --reason "negative app-facing advisory remediation report consumption policy path" \
  --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-policy-negative
```

### Task 4: Governance, Backlog, Docs, Roadmap

- [x] Register the schema in `causal_schema_governance.zig`.
- [x] Update schema count tests from `95` to `96` and add text/JSON coverage
  assertions for the new schema.
- [x] Add this milestone to `causal_production_hardening_backlog.zig` and move
  the recommendation to the consumption-evaluator branch.
- [x] Add approve/reject policy commands to backlog verification commands.
- [x] Add the user-facing docs file.
- [x] Update the master roadmap branch 60 to delivered and add branch 61 for
  the consumption-evaluator milestone.
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
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_policy.zig
zig test --dep causal_artifact -Mroot=tools/causal_schema_governance.zig -Mcausal_artifact=tools/causal_artifact.zig
zig test tools/causal_production_hardening_backlog.zig
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-policy -- --help
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
  docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-policy-design.md \
  docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-policy-implementation.md \
  packages/zigeffect/build.zig \
  packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-policy.md \
  packages/zigeffect/docs/production-hardening-backlog.md \
  packages/zigeffect/docs/schema-governance.md \
  packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_policy.zig \
  packages/zigeffect/tools/causal_production_hardening_backlog.zig \
  packages/zigeffect/tools/causal_schema_governance.zig
git commit -m "feat(zigeffect): add app-facing advisory report consumption policy"
```
