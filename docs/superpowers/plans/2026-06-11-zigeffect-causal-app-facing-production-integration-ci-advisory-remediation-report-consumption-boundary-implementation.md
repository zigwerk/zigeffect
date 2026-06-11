# App-Facing CI Advisory Remediation Report Consumption Boundary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the guarded read-only consumption-boundary artifact for app-facing CI advisory remediation report evidence.

**Architecture:** Add one Zig producer that consumes ready consumption-readiness artifacts, supports `plan` and `record-applied` modes, emits deterministic JSON/text boundary artifacts, and never grants runtime, app, CI, GitHub, storage, deployment, or adapter authority. Wire it into build, schema governance, backlog, user docs, and the master roadmap.

**Tech Stack:** Zig 0.16.0, `std.json`, `std.crypto.hash.sha2.Sha256`, existing zigeffect build steps, Bun root verification.

---

## File Structure

- Create `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_boundary.zig`
  for CLI parsing, source readiness validation, `plan`/`record-applied`
  boundary evaluation, artifact rendering, and unit tests.
- Modify `packages/zigeffect/build.zig` to add the executable and test step
  after the app-facing consumption-readiness tool.
- Create `packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary.md`
  for command examples, source contract, mode semantics, denied claims, and
  next-branch handoff.
- Modify `packages/zigeffect/tools/causal_schema_governance.zig` and generated
  `packages/zigeffect/docs/schema-governance.md` for the new schema.
- Modify `packages/zigeffect/tools/causal_production_hardening_backlog.zig` and
  generated `packages/zigeffect/docs/production-hardening-backlog.md` to mark
  this milestone delivered and advance the recommendation.
- Modify
  `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
  to mark branch 59 delivered and add branch 60 for consumption policy.

## Tasks

### Task 1: Red Test The Consumption Boundary Producer

- [x] Add the new Zig file with failing tests for constants, CLI parsing,
  output suffix replacement, plan output, blocked `record-applied`, applied
  `record-applied`, unsafe source rejection, and unsafe consumer-after
  rejection.
- [x] Run:

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_boundary.zig
```

Expected first result: compile failure or failing tests because implementation
constants/functions are not present yet.

### Task 2: Implement The Producer

- [x] Implement constants:
  - schema:
    `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary.v1`;
  - source schema:
    `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness.v1`;
  - tool:
    `causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary`;
  - next branch:
    `codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-policy`.
- [x] Implement option parsing for:
  `--from-readiness`, `plan|record-applied`, `--reason`, `--consumer-after`,
  `--by`, `--policy`, `--consumer-change`, `--before`, `--after`,
  `--verified-command`, and `--out-prefix`.
- [x] Implement source validation for ready consumption-readiness evidence,
  disabled CI/GitHub/app/runtime/storage/deployment authority, source consumer
  catalogs, guardrails, denied rules, negative fixtures, blocked claims, and
  verification evidence.
- [x] Implement consumer-after safety checks requiring `zigeffect`, `causal`,
  `read-only`, `consumption`, and `boundary`, while rejecting strings that imply
  CI enforcement, GitHub mutation, app mutation, runtime integration, raw
  payload capture, NenDB writes, adapter execution, Cockroach scope, deployment,
  production health, alternate renderers, auto-apply, or mutation authority.
- [x] Render JSON and text artifacts with boundary checks, source evidence refs,
  reviewed consumer changes, before/after evidence, consumer-after digest,
  disabled authority fields, and next-branch guidance.
- [x] Run the Zig test command until it passes.

### Task 3: Wire Build And Generate Artifacts

- [x] Add the build executable/test step.
- [x] Run:

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary -- --help
```

- [x] Write a local after-boundary fixture:

```sh
mkdir -p ../../.zig-cache/causal-artifacts
printf '%s\n' \
  'zigeffect causal read-only consumption boundary reviewed for app-facing advisory remediation report evidence.' \
  'SolidJS webui-dev/zig-webui and agent consumers receive bounded source ids and denied claims only.' \
  > ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-boundary-after.txt
```

- [x] Generate a planned boundary artifact:

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary -- \
  --from-readiness ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-consumption-readiness.json \
  plan \
  --reason "app-facing advisory remediation report consumption boundary planned" \
  --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-boundary-plan
```

- [x] Generate an applied boundary artifact:

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

- [x] Generate a blocked negative boundary artifact:

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary -- \
  --from-readiness ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-consumption-readiness.json \
  record-applied \
  --reason "negative app-facing advisory remediation report consumption boundary path" \
  --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-boundary-negative
```

### Task 4: Governance, Backlog, Docs, Roadmap

- [x] Register the schema in `causal_schema_governance.zig`.
- [x] Update schema count tests from `94` to `95` and add text/JSON coverage
  assertions for the new schema.
- [x] Add this milestone to `causal_production_hardening_backlog.zig` and move
  the recommendation to the consumption-policy branch.
- [x] Add plan/applied/negative boundary commands to backlog verification
  commands.
- [x] Add the user-facing docs file.
- [x] Update the master roadmap branch 59 to delivered and add branch 60 for
  the consumption-policy milestone.
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
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_boundary.zig
zig test --dep causal_artifact -Mroot=tools/causal_schema_governance.zig -Mcausal_artifact=tools/causal_artifact.zig
zig test tools/causal_production_hardening_backlog.zig
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary -- --help
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
  docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary-design.md \
  docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary-implementation.md \
  packages/zigeffect/build.zig \
  packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary.md \
  packages/zigeffect/docs/production-hardening-backlog.md \
  packages/zigeffect/docs/schema-governance.md \
  packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_boundary.zig \
  packages/zigeffect/tools/causal_production_hardening_backlog.zig \
  packages/zigeffect/tools/causal_schema_governance.zig
git commit -m "feat(zigeffect): add app-facing advisory report consumption boundary"
```
