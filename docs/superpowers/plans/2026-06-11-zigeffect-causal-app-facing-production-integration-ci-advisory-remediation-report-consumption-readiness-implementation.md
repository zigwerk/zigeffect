# App-Facing CI Advisory Remediation Report Consumption Readiness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a guarded record-only consumption-readiness artifact for app-facing CI advisory remediation report policy evidence.

**Architecture:** Add one Zig producer that adapts the production telemetry required-status-check readiness pattern to app-facing read-only consumption. The tool consumes only ready app-facing publication-policy artifacts, renders deterministic JSON/text readiness artifacts, updates build wiring, schema governance, backlog, docs, and roadmap state, and hands off to a guarded consumption boundary branch.

**Tech Stack:** Zig 0.16.0, `std.json`, `std.crypto.hash.sha2.Sha256`, existing zigeffect build steps, Bun root verification.

---

## File Structure

- Create `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_readiness.zig`
  for CLI parsing, source publication-policy validation, readiness evaluation,
  artifact rendering, and tests.
- Modify `packages/zigeffect/build.zig` to add the executable and test step
  after the app-facing advisory report publication-policy tool.
- Create `packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness.md`
  for command examples, source contract, readiness meaning, denied claims, and
  next branch.
- Modify `packages/zigeffect/tools/causal_schema_governance.zig` and generated
  `packages/zigeffect/docs/schema-governance.md` for the new schema.
- Modify `packages/zigeffect/tools/causal_production_hardening_backlog.zig` and
  generated `packages/zigeffect/docs/production-hardening-backlog.md` to mark
  this milestone delivered and advance the recommendation.
- Modify
  `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
  to mark branch 58 delivered and add the guarded consumption boundary branch.

## Tasks

### Task 1: Red Test The Consumption Readiness Producer

- [x] Add the new Zig file with tests for constants, CLI parsing, output suffix
  replacement, ready approval output, rejection behavior, incomplete
  verification, blocked source rejection, and unsafe source rejection.
- [x] Run:

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_readiness.zig
```

Expected first result: compile failure or failing tests because implementation
constants/functions are not present yet.

### Task 2: Implement The Producer

- [x] Implement constants:
  - schema:
    `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness.v1`;
  - source schema:
    `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-publication-policy.v1`;
  - tool:
    `causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness`;
  - next branch:
    `codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary`.
- [x] Implement option parsing for:
  `--from-publication-policy`, `approve|reject`, `--reason`, `--by`,
  `--policy`, `--verified-command`, and `--out-prefix`.
- [x] Implement source validation for ready publication-policy evidence,
  disabled CI/GitHub/app/runtime/storage/deployment authority, policy checks,
  interpretation catalogs, source evidence presence, and verification evidence.
- [x] Implement consumer profiles, readiness dimensions, consumption guardrails,
  denied inference rules, negative fixtures, and agent guidance.
- [x] Render JSON and text artifacts with readiness checks, source evidence
  refs, disabled authority fields, and next-branch guidance.
- [x] Run the Zig test command until it passes.

### Task 3: Wire Build And Generate Artifacts

- [x] Add the build executable/test step.
- [x] Run:

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness -- --help
```

- [x] Generate an approved readiness artifact from the ready
  publication-policy artifact:

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness -- \
  --from-publication-policy ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-publication-policy.json \
  approve \
  --reason "reviewed app-facing advisory remediation report consumption readiness" \
  --verified-command "bun run zigeffect:workbench:typecheck" \
  --verified-command "bun run zigeffect:workbench:test" \
  --verified-command "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-publication-policy" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

- [x] Generate a rejected negative readiness artifact:

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness -- \
  --from-publication-policy ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-publication-policy.json \
  reject \
  --reason "negative app-facing advisory remediation report consumption readiness path" \
  --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-readiness-negative
```

### Task 4: Governance, Backlog, Docs, Roadmap

- [x] Register the schema in `causal_schema_governance.zig`.
- [x] Update schema count tests from `93` to `94` and add text/JSON coverage
  assertions for the new schema.
- [x] Add this milestone to `causal_production_hardening_backlog.zig` and move
  the recommendation to the consumption-boundary branch.
- [x] Add approval/rejection readiness commands to backlog verification commands.
- [x] Add the user-facing docs file.
- [x] Update the master roadmap branch 58 to delivered and add branch 59 for
  the guarded consumption boundary.
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
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_readiness.zig
zig test --dep causal_artifact -Mroot=tools/causal_schema_governance.zig -Mcausal_artifact=tools/causal_artifact.zig
zig test tools/causal_production_hardening_backlog.zig
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
  docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness-design.md \
  docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness-implementation.md \
  packages/zigeffect/build.zig \
  packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness.md \
  packages/zigeffect/docs/production-hardening-backlog.md \
  packages/zigeffect/docs/schema-governance.md \
  packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_readiness.zig \
  packages/zigeffect/tools/causal_production_hardening_backlog.zig \
  packages/zigeffect/tools/causal_schema_governance.zig
git commit -m "feat(zigeffect): add app-facing advisory report consumption readiness"
```
