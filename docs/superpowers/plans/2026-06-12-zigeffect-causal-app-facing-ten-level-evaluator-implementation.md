# Zigeffect App-Facing Ten-Level Evaluator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the alias-named ten-level app-facing evaluator that consumes approved ten-level policy evidence and hands ready/advisory findings to the eleven-level report branch.

**Architecture:** Promote the proven nine-level evaluator into a ten-level alias file while updating the source policy contract, lineage fields, generated aliases, and next-branch handoff. The evaluator remains local and read-only; unsafe source policy, unsafe request evidence, or authority drift blocks, while missing support evidence remains advisory.

**Tech Stack:** Zig build tools and `zig test`, Bun root checks, existing zigeffect causal schema governance and production-hardening backlog generators.

---

### Task 1: Evaluator Tool RED Test

**Files:**
- Create: `packages/zigeffect/tools/causal_app_facing_ten_level_evaluator.zig`

- [x] **Step 1: Write the failing constants test**

```zig
const std = @import("std");

test "app-facing ten-level evaluator constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1", schema);
    try std.testing.expectEqual(@as(u32, 1), schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-ten-level-evaluator", source_branch);
    try std.testing.expectEqualStrings("start-app-facing-eleven-level-report", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-eleven-level-report", next_branch_if_ready);
}
```

- [x] **Step 2: Run the focused RED test**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_ten_level_evaluator.zig
```

Expected: FAIL with undeclared identifiers for `schema`, `schema_version`,
`source_branch`, `recommendation`, and `next_branch_if_ready`.

### Task 2: Promote The Evaluator Tool

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_facing_ten_level_evaluator.zig`

- [x] **Step 1: Copy the nine-level evaluator implementation into the alias file**

Copy from:

```text
packages/zigeffect/tools/causal_app_facing_nine_level_evaluator.zig
```

- [x] **Step 2: Replace the top-level constants**

Use these exact values:

```zig
pub const schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1";
pub const schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-app-facing-ten-level-evaluator";
pub const recommendation = "start-app-facing-eleven-level-report";
pub const next_branch_if_ready = "codex/zigeffect-causal-app-facing-eleven-level-report";

const source_policy_schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1";
const generated_by = "causal-app-facing-ten-level-evaluator";
const source_policy_suffix = "-ci-ten-level-policy.json";
const output_prefix_suffix = "-ci-ten-level-evaluator";
const compact_output_prefix_name = "app-facing-ci-ten-level-evaluator";
```

- [x] **Step 3: Promote source and output status fields**

Use the ten-level policy source status field:

```text
consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_status
```

Use the ten-level evaluator status field:

```text
consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_status
```

- [x] **Step 4: Add ten-level policy and lineage carryover**

Parse and emit:

```text
source_ten_level_policy
source_ten_level_policy_schema
source_ten_level_policy_status
source_policy_decision
source_ten_level_report
source_ten_level_report_schema
source_ten_level_report_status
source_nine_level_policy
source_nine_level_policy_schema
source_nine_level_policy_status
source_nine_level_application_boundary
source_nine_level_application_boundary_schema
source_nine_level_report
source_nine_level_report_schema
source_nine_level_report_status
```

- [x] **Step 5: Update request/support language and next queries**

Ready next query text must point to:

```text
codex/zigeffect-causal-app-facing-eleven-level-report
```

Example artifact placeholders should use:

```text
app-facing-ci-ten-level-evaluator.json
```

- [x] **Step 6: Run the focused GREEN test**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_ten_level_evaluator.zig
```

Expected: PASS.

### Task 3: Build Wiring

**Files:**
- Modify: `packages/zigeffect/build.zig`

- [x] **Step 1: Add alias module, executable, step, and tests after the ten-level policy block**

```zig
const causal_app_facing_ten_level_evaluator_tool_module = b.createModule(.{
    .root_source_file = b.path("tools/causal_app_facing_ten_level_evaluator.zig"),
    .target = target,
    .optimize = optimize,
});

const causal_app_facing_ten_level_evaluator_tool = b.addExecutable(.{
    .name = "zigeffect-causal-app-facing-ten-level-evaluator",
    .root_module = causal_app_facing_ten_level_evaluator_tool_module,
});
const run_causal_app_facing_ten_level_evaluator_tool = b.addRunArtifact(causal_app_facing_ten_level_evaluator_tool);
if (b.args) |args| run_causal_app_facing_ten_level_evaluator_tool.addArgs(args);
const causal_app_facing_ten_level_evaluator_step = b.step("causal-app-facing-ten-level-evaluator", "Evaluate app-facing ten-level policy evidence");
causal_app_facing_ten_level_evaluator_step.dependOn(&run_causal_app_facing_ten_level_evaluator_tool.step);

const causal_app_facing_ten_level_evaluator_tool_tests = b.addTest(.{
    .name = "zigeffect-causal-app-facing-ten-level-evaluator-tests",
    .root_module = causal_app_facing_ten_level_evaluator_tool_module,
});
const run_causal_app_facing_ten_level_evaluator_tool_tests = b.addRunArtifact(causal_app_facing_ten_level_evaluator_tool_tests);
test_step.dependOn(&run_causal_app_facing_ten_level_evaluator_tool_tests.step);
```

- [x] **Step 2: Verify the help step**

Run:

```bash
cd packages/zigeffect
zig build causal-app-facing-ten-level-evaluator -- --help
```

Expected: usage text for the alias step.

### Task 4: Governance And Backlog

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Modify generated docs: `packages/zigeffect/docs/schema-governance.md`
- Modify generated docs: `packages/zigeffect/docs/production-hardening-backlog.md`

- [x] **Step 1: Register the schema**

Add the schema immediately after the ten-level policy entry with:

```zig
.emitted_by = &.{"causal-app-facing-ten-level-evaluator"}
.consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing eleven-level report" }
.compatibility = &.{ "strict-v1", "record-only", "advisory-only", "source-ten-level-policy", "bounded-explicit-evidence", "local-report-only", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" }
```

- [x] **Step 2: Update production backlog tests and item**

Set:

```zig
pub const recommendation = "start-app-facing-eleven-level-report";
pub const recommended_next_branch = "codex/zigeffect-causal-app-facing-eleven-level-report";
```

Add delivered item id `app-facing-ten-level-evaluator`, branch
`codex/zigeffect-causal-app-facing-ten-level-evaluator`, dependency
`app-facing-ten-level-policy`, and verification commands for help, ready,
advisory, and blocked generation.

- [x] **Step 3: Run focused tests**

Run:

```bash
cd packages/zigeffect
zig test --dep causal_artifact -Mroot=tools/causal_schema_governance.zig -Mcausal_artifact=tools/causal_artifact.zig
zig test tools/causal_production_hardening_backlog.zig
```

Expected: PASS.

### Task 5: Docs, Artifacts, Verification, Commit

**Files:**
- Create: `packages/zigeffect/docs/app-facing-ten-level-evaluator.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [x] **Step 1: Add docs**

The docs must include consumed/emitted schemas, usage, ready/advisory/blocked
states, non-authority, and handoff to
`codex/zigeffect-causal-app-facing-eleven-level-report`.

- [x] **Step 2: Update the master roadmap**

Mark `codex/zigeffect-causal-app-facing-ten-level-evaluator` as delivered and
add `codex/zigeffect-causal-app-facing-eleven-level-report` as the next branch.

- [x] **Step 3: Regenerate governance and backlog docs**

Run:

```bash
cd packages/zigeffect
zig build causal-schema-governance -- --format json > /tmp/zigeffect-schema-governance.out 2> docs/schema-governance.md
zig build causal-production-hardening-backlog -- --format json > /tmp/zigeffect-production-hardening-backlog.out 2> docs/production-hardening-backlog.md
```

- [x] **Step 4: Generate ready, advisory, and blocked artifacts**

Run:

```bash
cd packages/zigeffect
zig build causal-app-facing-ten-level-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-policy.json evaluate --reason "reviewed app-facing ten-level evaluator" --request ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-evaluator-request.json --evidence ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-evaluator-support.txt --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-evaluator
zig build causal-app-facing-ten-level-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-policy.json evaluate --reason "advisory app-facing ten-level evaluator missing support" --request ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-evaluator-request.json --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-evaluator-advisory
zig build causal-app-facing-ten-level-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-policy-reject.json evaluate --reason "blocked app-facing ten-level evaluator source" --request ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-evaluator-request.json --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-evaluator-blocked
```

Expected: ready artifact has status `ready`, advisory artifact has status
`advisory-findings`, and blocked artifact has status `blocked`.

- [x] **Step 5: Run final verification**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_ten_level_evaluator.zig
zig build causal-app-facing-ten-level-evaluator -- --help
zig test --dep causal_artifact -Mroot=tools/causal_schema_governance.zig -Mcausal_artifact=tools/causal_artifact.zig
zig test tools/causal_production_hardening_backlog.zig
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

- [ ] **Step 6: Commit, checkpoint master, and branch next**

Run:

```bash
git add docs/superpowers packages/zigeffect
git commit -m "feat(zigeffect): add app-facing ten-level evaluator"
git -C /Users/seanknowles/.config/superpowers/worktrees/yachdee/master-local-merge merge --ff-only codex/zigeffect-causal-app-facing-ten-level-evaluator
git switch -c codex/zigeffect-causal-app-facing-eleven-level-report
```
