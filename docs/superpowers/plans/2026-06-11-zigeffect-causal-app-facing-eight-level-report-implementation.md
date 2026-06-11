# Zigeffect App-Facing Eight-Level Report Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Build the read-only eight-level report producer that consumes ready or advisory seven-level evaluator evidence and advances the backlog to the eight-level application-boundary branch.

**Architecture:** Promote the existing seven-level report producer by one evaluation-report lineage level. Keep the established ready/advisory/blocked report status model, local-only publication boundary, source evaluator parsing, schema governance entry, backlog handoff, and roadmap update.

**Tech Stack:** Zig build tool, Zig unit tests, deterministic JSON/text artifacts, Bun project verification.

---

### Task 1: Add Failing Report Test

**Files:**
- Create: `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report.zig`

- [x] **Step 1: Write the constants test first**

```zig
const std = @import("std");

test "app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report constants are stable" {
    try std.testing.expectEqualStrings(
        "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1",
        schema,
    );
    try std.testing.expectEqual(@as(u32, 1), schema_version);
    try std.testing.expectEqualStrings(
        "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report",
        source_branch,
    );
    try std.testing.expectEqualStrings(
        "start-app-facing-eight-level-application-boundary",
        recommendation,
    );
    try std.testing.expectEqualStrings(
        "codex/zigeffect-causal-app-facing-eight-level-application-boundary",
        next_branch_if_ready,
    );
}
```

- [x] **Step 2: Run the focused test to verify RED**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report.zig
```

Expected: FAIL with undeclared `schema`.

### Task 2: Add Failing Governance And Backlog Tests

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`

- [x] **Step 1: Update schema governance test expectations first**

Change the expected schema count from `129` to `130`, and add:

```zig
try expectSchema(entries, "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1");
```

Update text and JSON report tests to expect `schema count: 130` and `"schema_count": 130`.

- [x] **Step 2: Update backlog test expectations first**

Update the top-level recommendation expectations to:

```zig
"start-app-facing-eight-level-application-boundary"
"codex/zigeffect-causal-app-facing-eight-level-application-boundary"
```

Add delivered item assertions for:

```zig
try expectBacklogItem("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report");
try expectBacklogItemStatus("app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report", "delivered");
```

Add JSON assertions for the new report id, branch, and help command:

```zig
try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report\"") != null);
try std.testing.expect(std.mem.indexOf(u8, report, "\"branch\": \"codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report\"") != null);
try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- --help") != null);
```

- [x] **Step 3: Run tests to verify RED**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_production_hardening_backlog.zig
```

Expected: FAIL because the backlog still recommends the eight-level report branch and does not contain the delivered eight-level report item.

### Task 3: Implement The Report Producer

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report.zig`

- [x] **Step 1: Promote the predecessor report**

Use the seven-level report as the source:

```bash
cp packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report.zig \
  packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report.zig
```

Then promote every evaluation-report lineage token by one level. Use sentinel replacement from longest token to shortest so the top-level output, source evaluator schema, and inherited source fields all move exactly one level:

```bash
perl -0pi -e 's/evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report/__EVAL8_U__/g; s/evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report/__EVAL7_U__/g; s/evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report/__EVAL6_U__/g; s/evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report/__EVAL5_U__/g; s/evaluation_report_evaluation_report_evaluation_report_evaluation_report/__EVAL4_U__/g; s/evaluation_report_evaluation_report_evaluation_report/__EVAL3_U__/g; s/evaluation_report_evaluation_report/__EVAL2_U__/g; s/evaluation_report/evaluation_report_evaluation_report/g; s/__EVAL2_U__/evaluation_report_evaluation_report_evaluation_report/g; s/__EVAL3_U__/evaluation_report_evaluation_report_evaluation_report_evaluation_report/g; s/__EVAL4_U__/evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report/g; s/__EVAL5_U__/evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report/g; s/__EVAL6_U__/evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report/g; s/__EVAL7_U__/evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report/g; s/__EVAL8_U__/evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report/g' \
  packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report.zig
```

Repeat the same guarded promotion for hyphenated and spaced tokens in the tool and docs.

- [x] **Step 2: Confirm top-level constants**

The new file must contain:

```zig
pub const schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1";
pub const source_branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report";
pub const recommendation = "start-app-facing-eight-level-application-boundary";
pub const next_branch_if_ready = "codex/zigeffect-causal-app-facing-eight-level-application-boundary";

const source_evaluator_schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1";
const generated_by = "causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report";
const evaluator_suffix = "-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.json";
const output_suffix = "-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report";
```

- [x] **Step 3: Verify source evaluator parsing against real artifact**

Run:

```bash
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.json summarize --reason "reviewed app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report"
```

Expected: report text says `status: ready` and `ready_for_next_branch: true`.

- [x] **Step 4: Run focused tests**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report.zig
```

Expected: PASS.

### Task 4: Add Build Target And Docs

**Files:**
- Modify: `packages/zigeffect/build.zig`
- Create: `packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.md`

- [x] **Step 1: Add build target after the seven-level evaluator target**

Add a module, executable, run artifact, public step, test artifact, and `test_step` dependency for:

```text
causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report
```

Use a short internal test artifact name:

```zig
.name = "zigeffect-causal-app-facing-eight-level-report-tests"
```

- [x] **Step 2: Verify build help**

Run:

```bash
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- --help
```

Expected: usage text names `--from-evaluator`, `summarize`, `--reason`, and `--out-prefix`.

- [x] **Step 3: Add docs**

Write docs that name the source schema, output schema, ready/advisory/blocked behavior, local-only publication boundary, and eight-level application-boundary handoff branch.

### Task 5: Update Governance, Backlog, And Roadmap

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
- Generated: `packages/zigeffect/docs/schema-governance.md`
- Generated: `packages/zigeffect/docs/production-hardening-backlog.md`

- [x] **Step 1: Register schema**

Add schema governance entry:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1
```

Set emitted_by to the new build step and consumed_by to agents, reviewers, non-blocking CI advisory readers, local SolidJS workbench, production-hardening backlog, and the future eight-level application-boundary branch.

- [x] **Step 2: Update backlog**

Add a delivered report item after the seven-level evaluator item. Update:

```zig
pub const recommendation = "start-app-facing-eight-level-application-boundary";
pub const recommended_next_branch = "codex/zigeffect-causal-app-facing-eight-level-application-boundary";
```

Add the new report id to `dependency_order` after the seven-level evaluator item, and add verification commands for help, ready source evaluator, advisory source evaluator, and blocked source evaluator.

- [x] **Step 3: Update roadmap**

Mark roadmap item 94 delivered and add item 95 as:

```text
codex/zigeffect-causal-app-facing-eight-level-application-boundary
```

The new item should be `Next` and describe consuming ready/advisory eight-level report artifacts with reviewed local application-boundary evidence.

- [x] **Step 4: Regenerate generated docs**

Run:

```bash
cd packages/zigeffect
zig build causal-schema-governance > /dev/null 2> docs/schema-governance.md
zig build causal-production-hardening-backlog > /dev/null 2> docs/production-hardening-backlog.md
```

Expected: generated docs include schema count `130`, the eight-level report schema, the delivered report backlog item, and the eight-level application-boundary recommendation.

### Task 6: Generate Report Artifacts And Verify

**Files:**
- Generated only: `.zig-cache/causal-artifacts/*evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report*`

- [x] **Step 1: Generate ready artifact**

Run:

```bash
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.json summarize --reason "reviewed app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report
```

Expected: text output includes `status: ready`, `ready_for_next_branch: true`, and no blocked findings.

- [x] **Step 2: Generate advisory artifact**

Run the same command with source evaluator `...-evaluator-advisory.json` and out-prefix:

```bash
--out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-advisory
```

Expected: text output includes `status: advisory` and `ready_for_next_branch: true`.

- [x] **Step 3: Generate blocked artifact**

Run the same command with source evaluator `...-evaluator-blocked.json` and out-prefix:

```bash
--out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-blocked
```

Expected: text output includes `status: blocked` and `ready_for_next_branch: false`.

- [x] **Step 4: Run final verification**

Run:

```bash
cd packages/zigeffect
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```

Expected: all commands exit 0.

### Task 7: Commit And Prepare Next Branch

**Files:**
- All modified and created files from Tasks 1-6.

- [x] **Step 1: Mark this plan complete**

Replace every remaining `- [x]` in this plan with `- [x]`.

- [x] **Step 2: Stage and commit**

Run:

```bash
git add docs/superpowers packages/zigeffect
git commit -m "feat(zigeffect): add app-facing eight-level report"
```

- [x] **Step 3: Fast-forward master**

Because `master` is checked out in the merge worktree, run:

```bash
git -C /Users/seanknowles/.config/superpowers/worktrees/yachdee/master-local-merge merge --ff-only codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report
```

- [x] **Step 4: Create next branch**

Run:

```bash
git switch -c codex/zigeffect-causal-app-facing-eight-level-application-boundary
```

Expected: working tree is clean on the next application-boundary branch.

## Self-Review

- Spec coverage: The plan covers producer behavior, source schema, output schema, local publication boundary, governance, backlog, roadmap, artifact generation, and verification.
- Placeholder scan: No TBD or TODO placeholders remain.
- Type consistency: The plan consistently uses eight-level report for the output producer and eight-level application-boundary for the next branch.
