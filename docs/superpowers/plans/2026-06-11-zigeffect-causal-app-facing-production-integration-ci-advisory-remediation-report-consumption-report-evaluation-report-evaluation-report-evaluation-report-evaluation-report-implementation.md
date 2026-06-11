# Zigeffect App-Facing Evaluation Report Evaluation Report Evaluation Report Evaluation Report Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the four-level app-facing evaluation-report summarizer that consumes triple evaluator artifacts and hands off to the four-level application-boundary branch.

**Architecture:** Mechanically adapt the existing triple report producer. Keep the one-file Zig tool pattern, preserve deterministic JSON/text local artifacts, and update build, docs, governance, backlog, generated docs, and roadmap handoff.

**Tech Stack:** Zig build tool, Zig unit tests, deterministic JSON/text artifacts, Bun project verification.

---

### Task 1: Add Failing Constants Test

**Files:**
- Create: `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report.zig`

- [ ] **Step 1: Write the constants test first**

```zig
const std = @import("std");

test "app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1", schema);
    try std.testing.expectEqual(@as(u32, 1), schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report", source_branch);
    try std.testing.expectEqualStrings("start-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary", next_branch_if_ready);
}
```

- [ ] **Step 2: Run the test to verify RED**

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report.zig
```

Expected: FAIL with undeclared `schema`.

### Task 2: Implement The Four-Level Report Producer

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report.zig`

- [ ] **Step 1: Mechanically adapt the predecessor**

Copy this template:

`packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report.zig`

Retarget constants to:

```zig
pub const schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1";
pub const source_branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report";
pub const recommendation = "start-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary";
pub const next_branch_if_ready = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary";
const source_evaluator_schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1";
const generated_by = "causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report";
const evaluator_suffix = "-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator.json";
const output_suffix = "-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report";
```

- [ ] **Step 2: Retarget required verification commands**

```zig
const required_verification_commands: []const []const u8 = &.{
    "bun run zigeffect:workbench:typecheck",
    "bun run zigeffect:workbench:test",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator -- --help",
    "zig build causal-schema-governance -- --format json",
    "zig build causal-production-hardening-backlog -- --format json",
    "zig build examples",
    "zig build test",
};
```

- [ ] **Step 3: Retarget current-layer source fields**

The source evaluator parser must include:

```zig
source_consumption_report_evaluation_report_evaluation_report_evaluation_report_policy: []const u8 = "",
source_consumption_report_evaluation_report_evaluation_report_evaluation_report_policy_schema: []const u8 = "",
source_evaluation_report_evaluation_report_evaluation_report_policy_status: []const u8 = "",
source_consumption_report_evaluation_report_evaluation_report_evaluation_report_application_boundary: []const u8 = "",
source_consumption_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_schema: []const u8 = "",
source_consumption_report_evaluation_report_evaluation_report_evaluation_report: []const u8 = "",
source_consumption_report_evaluation_report_evaluation_report_evaluation_report_status: []const u8 = "",
source_evaluation_report_evaluation_report_evaluation_report_application_status: []const u8 = "",
source_evaluation_report_evaluation_report_evaluation_report_after_digest: []const u8 = "",
source_evaluation_report_evaluation_report_evaluation_report_after_present: bool = false,
source_evaluation_report_evaluation_report_evaluation_report_application_changes: []const []const u8 = &.{},
```

- [ ] **Step 4: Preserve inherited fields**

Keep double-layer inherited fields:

```zig
source_consumption_report_evaluation_report_evaluation_report_policy: []const u8 = "",
source_consumption_report_evaluation_report_evaluation_report_policy_schema: []const u8 = "",
source_evaluation_report_evaluation_report_policy_status: []const u8 = "",
source_consumption_report_evaluation_report_evaluation_report_application_boundary: []const u8 = "",
source_consumption_report_evaluation_report_evaluation_report_application_boundary_schema: []const u8 = "",
source_consumption_report_evaluation_report_evaluation_report: []const u8 = "",
source_consumption_report_evaluation_report_evaluation_report_status: []const u8 = "",
source_evaluation_report_evaluation_report_application_status: []const u8 = "",
source_evaluation_report_evaluation_report_application_changes: []const []const u8 = &.{},
```

- [ ] **Step 5: Retarget checks, output fields, tests, and usage**

Update all strings, JSON keys, text headings, test fixture schemas, default output suffixes, `headlineForStatus`, and `agentGuidance` so the current branch is four-level and the next branch is four-level application-boundary.

### Task 3: Register Build Target And Docs

**Files:**
- Modify: `packages/zigeffect/build.zig`
- Create: `packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.md`

- [ ] **Step 1: Add the build target after the triple evaluator target**

Register:

```text
causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report
```

Add module, executable, run step, test executable, and `test_step` dependency immediately after the triple evaluator tool block.

- [ ] **Step 2: Add docs**

Document:

```bash
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- \
  --from-evaluator <consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator.json> \
  summarize \
  --reason <reason>
```

State the source gate, local-only publication boundary, and handoff to the application-boundary branch.

### Task 4: Update Governance, Backlog, Roadmap, And Generated Docs

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
- Regenerate: `packages/zigeffect/docs/schema-governance.md`
- Regenerate: `packages/zigeffect/docs/production-hardening-backlog.md`

- [ ] **Step 1: Add schema governance entry**

Add:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1
```

Increment schema count from 113 to 114 and update schema text/json tests.

- [ ] **Step 2: Update production hardening backlog**

Mark this four-level report delivered. Add dependency order, evidence sources, verification commands, and update the recommended next branch to:

```text
codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary
```

- [ ] **Step 3: Update roadmap**

Move the current report branch from Next to Delivered and add the application-boundary branch as the new Next item.

- [ ] **Step 4: Regenerate docs**

```bash
cd packages/zigeffect
zig build causal-schema-governance > /dev/null 2> docs/schema-governance.md
zig build causal-production-hardening-backlog > /dev/null 2> docs/production-hardening-backlog.md
```

### Task 5: Verify Artifacts And Commit

**Files:**
- All changed files

- [ ] **Step 1: Run focused tests and help**

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report.zig
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- --help
```

- [ ] **Step 2: Generate ready, advisory, and blocked artifacts**

```bash
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator-88227538b2cab4f7.json summarize --reason "reviewed app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report"
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator-advisory.json summarize --reason "advisory app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report source" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-advisory
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator-blocked.json summarize --reason "blocked app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report source" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-blocked
```

- [ ] **Step 3: Run project verification**

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

- [ ] **Step 4: Commit and continue**

```bash
git add docs/superpowers packages/zigeffect
git commit -m "feat(zigeffect): add app-facing evaluation report rollup"
git switch -c codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary
```
