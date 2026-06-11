# App-Facing CI Advisory Remediation Report Publication Policy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a guarded record-only publication policy for app-facing CI advisory remediation report evidence.

**Architecture:** Add one Zig producer that adapts the production telemetry advisory CI report publication-policy pattern to the app-facing application-boundary schema. The tool consumes only applied record-only source boundaries, renders deterministic JSON/text policy artifacts, updates build wiring, schema governance, backlog, docs, and roadmap state, and hands off to app-facing advisory report consumption readiness.

**Tech Stack:** Zig 0.16.0, `std.json`, `std.crypto.hash.sha2.Sha256`, existing zigeffect build steps, Bun root verification.

---

## File Structure

- Create `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_publication_policy.zig`
  for CLI parsing, source boundary validation, policy evaluation, artifact
  rendering, and tests.
- Modify `packages/zigeffect/build.zig` to add the executable and test step
  after the app-facing advisory report application-boundary tool.
- Create `packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-publication-policy.md`
  for command examples, policy rules, denied claims, and next branch.
- Modify `packages/zigeffect/tools/causal_schema_governance.zig` and generated
  `packages/zigeffect/docs/schema-governance.md` for the new schema.
- Modify `packages/zigeffect/tools/causal_production_hardening_backlog.zig` and
  generated `packages/zigeffect/docs/production-hardening-backlog.md` to mark
  this milestone delivered and advance the recommendation.
- Modify
  `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
  to mark branch 57 delivered and add the consumption-readiness branch.

## Tasks

### Task 1: Red Test The Publication Policy Producer

- [x] Add the new Zig file with tests for constants, CLI parsing, output suffix
  replacement, ready approval output, rejection behavior, incomplete
  verification, planned source rejection, and unsafe source rejection.
- [x] Run:

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_publication_policy.zig
```

Expected first result: compile failure or failing tests because implementation
constants/functions are not present yet.

### Task 2: Implement The Producer

- [x] Implement constants:
  - schema:
    `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-publication-policy.v1`;
  - source schema:
    `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-application-boundary.v1`;
  - tool:
    `causal-app-facing-production-integration-ci-advisory-remediation-report-publication-policy`;
  - next branch:
    `codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness`.
- [x] Implement option parsing for:
  `--from-application`, `approve|reject`, `--reason`, `--by`, `--policy`,
  `--verified-command`, and `--out-prefix`.
- [x] Implement source validation for applied record-only boundary evidence,
  disabled CI/GitHub/app/runtime/storage/deployment authority, source checks,
  evidence presence, source catalogs, and verification evidence.
- [x] Implement interpretation rules, publication surfaces, denied inference
  rules, negative fixtures, and agent guidance.
- [x] Render JSON and text artifacts with policy checks, source evidence refs,
  disabled authority fields, and next-branch guidance.
- [x] Run the Zig test command until it passes.

### Task 3: Wire Build And Generate Artifacts

- [x] Add the build executable/test step.
- [x] Run:

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-publication-policy -- --help
```

- [x] Generate an approved policy artifact from the applied application-boundary
  artifact.
- [x] Generate a rejected negative policy artifact.

### Task 4: Governance, Backlog, Docs, Roadmap

- [x] Register the schema in `causal_schema_governance.zig`.
- [x] Add this milestone to `causal_production_hardening_backlog.zig` and move
  the recommendation to the consumption-readiness branch.
- [x] Add the user-facing docs file.
- [x] Update the master roadmap branch 57 to delivered and add branch 58 for
  consumption readiness.
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
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_publication_policy.zig
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
  docs/superpowers/specs/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-publication-policy-design.md \
  docs/superpowers/plans/2026-06-11-zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-publication-policy-implementation.md \
  packages/zigeffect/build.zig \
  packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-publication-policy.md \
  packages/zigeffect/docs/production-hardening-backlog.md \
  packages/zigeffect/docs/schema-governance.md \
  packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_publication_policy.zig \
  packages/zigeffect/tools/causal_production_hardening_backlog.zig \
  packages/zigeffect/tools/causal_schema_governance.zig
git commit -m "feat(zigeffect): add app-facing advisory report publication policy"
```
