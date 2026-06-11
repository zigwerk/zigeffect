# Zigeffect App-Facing Evaluation Report Evaluation Report Policy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the app-facing consumption-report evaluation-report evaluation-report policy producer and wire it into the roadmap.

**Architecture:** Follow the existing consumption-report evaluation-report policy producer, retargeting the source application-boundary schema one stage deeper. Keep approval purely record-only, with explicit interpretation rules, denied claims, negative fixtures, and next-branch evaluator handoff.

**Tech Stack:** Zig tools in `packages/zigeffect`, Bun project verification, Superpowers docs in `docs/superpowers`.

---

### Task 1: Add Failing Policy Test

**Files:**
- Create: `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_policy.zig`

- [ ] **Step 1: Write a minimal constants test**

```zig
const std = @import("std");

test "app-facing consumption report evaluation-report evaluation-report policy constants are stable" {
    try std.testing.expectEqualStrings(
        "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-policy.v1",
        schema,
    );
}
```

- [ ] **Step 2: Run the focused test and confirm RED**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_policy.zig
```

Expected: compile failure because `schema` is undeclared.

### Task 2: Implement Policy Producer

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_policy.zig`

- [ ] **Step 1: Retarget the existing policy producer**

Use `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_policy.zig` as the template. Replace names and field prefixes from `evaluation_report` to `evaluation_report_evaluation_report`, set the source schema to the new application-boundary schema, and set the next branch to the evaluation-report evaluation-report evaluator.

- [ ] **Step 2: Preserve safety gates**

Approval must require expected source schema, `applied=true`, `ready_for_next_branch=true`, no blocked findings, no authority drift, local-only publication, SolidJS WebUI read-only evidence, source refs and summaries, reviewed application changes, before/after evidence, safe after-report content, and all required verification commands.

- [ ] **Step 3: Run focused GREEN checks**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_policy.zig
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-policy -- --help
```

Expected: all policy tests pass and the CLI prints usage.

### Task 3: Wire Build, Docs, Governance, And Backlog

**Files:**
- Modify: `packages/zigeffect/build.zig`
- Create: `packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-policy.md`
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Register the build target**

Add the new Zig source to `packages/zigeffect/build.zig` with a matching `causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-policy` target and test step.

- [ ] **Step 2: Add user documentation**

Document command usage, emitted schema, approval gates, blocked paths, and non-authority constraints in the new package docs file.

- [ ] **Step 3: Update governance and backlog**

Add the policy schema to schema governance, bump the schema count, mark this backlog item delivered, set the next recommendation to the evaluator branch, and add help/approve/reject/blocked verification commands.

- [ ] **Step 4: Update the roadmap**

Mark the policy branch delivered and add the evaluator branch as the next roadmap item.

### Task 4: Generate Artifacts And Verify

**Files:**
- Modify: `packages/zigeffect/docs/schema-governance.md`
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`

- [ ] **Step 1: Generate approve, reject, and blocked artifacts**

Run the new policy tool against the reviewed application-boundary artifact, a reject path, and the blocked application-boundary fixture. Confirm approve emits `ready_for_next_branch=true` and blocked paths emit `ready_for_next_branch=false`.

- [ ] **Step 2: Refresh generated docs**

Run:

```bash
cd packages/zigeffect
zig build causal-schema-governance 2> docs/schema-governance.md
zig build causal-production-hardening-backlog 2> docs/production-hardening-backlog.md
```

- [ ] **Step 3: Run final verification**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_policy.zig
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-policy -- --help
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```

Expected: every command exits 0.

### Task 5: Commit And Continue

**Files:**
- Commit all files changed by this milestone.

- [ ] **Step 1: Commit**

```bash
git add docs/superpowers packages/zigeffect
git commit -m "feat(zigeffect): add app-facing evaluation report policy"
```

- [ ] **Step 2: Create the next branch**

```bash
git switch -c codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluator
```
