# ZigEffect App-Facing Consumption Report Evaluation Report Evaluation Report Evaluation Report Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the read-only report producer that consumes consumption-report evaluation-report evaluation-report evaluator artifacts and summarizes them for the next guarded application-boundary step.

**Architecture:** Reuse the existing consumption-report evaluation-report evaluation-report producer shape, but shift the source contract to `consumption-report-evaluation-report-evaluation-report-evaluator.v1` and preserve immediate evaluator evidence plus inherited evaluation-report, consumption-report, and application evidence. The tool remains local JSON/text only and carries no mutation authority.

**Tech Stack:** Zig tool under `packages/zigeffect/tools`, Zig build step, schema governance/backlog generators, markdown docs.

---

### Task 1: Failing Report Producer Tests

**Files:**
- Create: `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report.zig`

- [ ] **Step 1: Write the failing constants test**

Create a new Zig tool file with a constants test that expects:

```zig
"zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report.v1"
"codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report"
"start-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-application-boundary"
"codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-application-boundary"
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report.zig
```

Expected: FAIL because `schema`, `source_branch`, `recommendation`, and `next_branch_if_ready` are not implemented yet.

### Task 2: Implement Report Producer

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report.zig`

- [ ] **Step 1: Retarget the existing report producer**

Use `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report.zig` as the template. Replace schema, source evaluator schema, suffixes, status names, recommendation, next branch, and source field names with the evaluation-report evaluation-report evaluation-report naming.

- [ ] **Step 2: Preserve report gates**

Ready output requires reportable source evaluator status, ready handoff, no blocked findings, source refs, source evidence, request/evidence summaries, report sections, disabled authority, SolidJS webui posture, and local-only publication. Advisory source findings remain reportable but must not create mutation authority.

- [ ] **Step 3: Add source model fields introduced by the previous evaluator**

Carry forward the evaluation-report evaluation-report policy/application fields, inherited evaluation-report policy/application fields, inherited consumption-report fields, source request/support/signal summaries, blocked/advisory findings, current checks, denied claims, policy rule ids, consumption scope ids, next queries, and agent guidance.

- [ ] **Step 4: Add ready/advisory/blocked tests**

Add tests for ready evaluator output, advisory evaluator output, blocked evaluator output, authority drift blocking, publication local-only posture, default output path handling, and option parsing.

- [ ] **Step 5: Run tests to verify green**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report.zig
```

Expected: PASS.

### Task 3: Register Build Target And Docs

**Files:**
- Modify: `packages/zigeffect/build.zig`
- Create: `packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report.md`
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Add build target**

Add executable and test registration for:

```text
causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report
```

- [ ] **Step 2: Add docs**

Document the command, source gate, statuses, local-only publication posture, and next handoff.

- [ ] **Step 3: Add schema governance entry**

Register the new schema with strict v1, advisory-only, source evaluation-report evaluation-report evaluator compatibility, local-report-only, bounded explicit evidence, no Cockroach, no CI enforcement, no app runtime integration, no storage writes, no adapter execution, no public upload, no auto-apply, no mutation authority, and SolidJS/webui compatibility tags.

- [ ] **Step 4: Add backlog and roadmap updates**

Mark the report producer delivered, move the recommended next branch to the new application-boundary branch, add verification commands for ready/advisory/blocked report runs, and mark roadmap item 74 delivered with item 75 as the next application-boundary.

### Task 4: Generate Artifacts And Verify

**Files:**
- Modify generated docs:
  - `packages/zigeffect/docs/schema-governance.md`
  - `packages/zigeffect/docs/production-hardening-backlog.md`

- [ ] **Step 1: Generate ready/advisory/blocked report artifacts**

Run the report producer against:

```text
../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary-1559c7e904ae31e2-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluator.json
../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluator-advisory.json
../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluator-blocked.json
```

- [ ] **Step 2: Refresh generated docs**

Run:

```bash
cd packages/zigeffect
zig build causal-schema-governance 2> docs/schema-governance.md
zig build causal-production-hardening-backlog 2> docs/production-hardening-backlog.md
```

- [ ] **Step 3: Full verification**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report.zig
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report -- --help
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```

- [ ] **Step 4: Commit And Continue**

Stage and commit with:

```bash
git add docs/superpowers packages/zigeffect
git commit -m "feat(zigeffect): add app-facing evaluation report evaluation report report"
git switch -c codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-application-boundary
```
