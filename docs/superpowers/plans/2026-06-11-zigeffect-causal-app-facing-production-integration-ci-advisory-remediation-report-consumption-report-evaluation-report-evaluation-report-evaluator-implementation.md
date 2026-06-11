# Zigeffect App-Facing Evaluation Report Evaluation Report Evaluator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the app-facing consumption-report evaluation-report evaluation-report evaluator producer and wire it into the roadmap.

**Architecture:** Retarget the existing consumption-report evaluation-report evaluator producer one stage deeper. The new tool consumes ready record-only policy artifacts, analyzes explicit local request/evidence files, emits ready/advisory/blocked evaluator artifacts, and hands off to the next evaluation-report branch without creating mutation authority.

**Tech Stack:** Zig tools in `packages/zigeffect`, Bun project verification, Superpowers docs in `docs/superpowers`.

---

### Task 1: Add Failing Evaluator Test

**Files:**
- Create: `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluator.zig`

- [ ] **Step 1: Write a minimal constants test**

```zig
const std = @import("std");

test "app-facing consumption report evaluation-report evaluation-report evaluator constants are stable" {
    try std.testing.expectEqualStrings(
        "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluator.v1",
        schema,
    );
}
```

- [ ] **Step 2: Run the focused test and confirm RED**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluator.zig
```

Expected: compile failure because `schema` is undeclared.

### Task 2: Implement Evaluator Producer

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluator.zig`

- [ ] **Step 1: Retarget the existing evaluator**

Use `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluator.zig` as the template. Replace schema, source policy schema, suffixes, field names, status names, recommendation, and next branch with the evaluation-report evaluation-report evaluator naming.

- [ ] **Step 2: Preserve evaluator gates**

Ready output requires ready source policy, approve decision, no blocked findings, policy checks without failure, catalogs present, required verification evidence, local-only publication, SolidJS WebUI read-only scope, bounded request file analysis, and no denied authority or mutation content. Missing support evidence may produce advisory output but must not grant authority.

- [ ] **Step 3: Run focused GREEN checks**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluator.zig
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluator -- --help
```

Expected: all evaluator tests pass and the CLI prints usage.

### Task 3: Wire Build, Docs, Governance, And Backlog

**Files:**
- Modify: `packages/zigeffect/build.zig`
- Create: `packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluator.md`
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Register the build target**

Add the new Zig source to `packages/zigeffect/build.zig` with a matching `causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluator` target and test step.

- [ ] **Step 2: Add package documentation**

Document command usage, emitted schema, ready/advisory/blocked behavior, source policy gates, denied claims, request/evidence handling, and non-authority constraints.

- [ ] **Step 3: Update governance and backlog**

Add the evaluator schema to schema governance, bump the schema count, mark this backlog item delivered, set the next recommendation to the evaluation-report evaluation-report evaluation-report branch, and add help/ready/advisory/blocked verification commands.

- [ ] **Step 4: Update the roadmap**

Mark the evaluator branch delivered and add the next evaluation-report branch as the next roadmap item.

### Task 4: Generate Artifacts And Verify

**Files:**
- Modify: `packages/zigeffect/docs/schema-governance.md`
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`

- [ ] **Step 1: Generate ready, advisory, and blocked artifacts**

Run the evaluator against the ready policy artifact with request and support evidence, against the ready policy with request only for advisory, and against the blocked policy fixture. Confirm status fields are `ready`, `advisory-findings`, and `blocked`.

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
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluator.zig
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluator -- --help
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
git commit -m "feat(zigeffect): add app-facing evaluation report evaluator"
```

- [ ] **Step 2: Create the next branch**

```bash
git switch -c codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report
```
