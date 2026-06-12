# Zigeffect App-Facing Ten-Level Policy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the alias-named ten-level app-facing policy that consumes applied ten-level application-boundary evidence and hands ready approvals to the ten-level evaluator branch.

**Architecture:** Promote the proven nine-level policy tool into a ten-level alias file while updating the source contract to the applied ten-level application-boundary artifact. The tool remains local and read-only; `approve` emits ready evidence only after all source and verification gates pass, while `reject` and unsafe sources emit blocked evidence.

**Tech Stack:** Zig build tools and `zig test`, Bun root checks, existing zigeffect causal schema governance and production-hardening backlog generators.

---

### Task 1: Policy Tool RED Test

**Files:**
- Create: `packages/zigeffect/tools/causal_app_facing_ten_level_policy.zig`

- [x] **Step 1: Write the failing constants test**

```zig
const std = @import("std");

test "app-facing ten-level policy constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1", schema);
    try std.testing.expectEqual(@as(u32, 1), schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-ten-level-policy", source_branch);
    try std.testing.expectEqualStrings("start-app-facing-ten-level-evaluator", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-ten-level-evaluator", next_branch_if_ready);
}
```

- [x] **Step 2: Run the focused RED test**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_ten_level_policy.zig
```

Expected: FAIL with undeclared identifiers for `schema`, `schema_version`,
`source_branch`, `recommendation`, and `next_branch_if_ready`.

### Task 2: Promote The Policy Tool

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_facing_ten_level_policy.zig`

- [x] **Step 1: Copy the nine-level policy implementation into the alias file**

Copy from:

```text
packages/zigeffect/tools/causal_app_facing_nine_level_policy.zig
```

- [x] **Step 2: Replace the top-level constants**

Use these exact values:

```zig
pub const schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1";
pub const schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-app-facing-ten-level-policy";
pub const recommendation = "start-app-facing-ten-level-evaluator";
pub const next_branch_if_ready = "codex/zigeffect-causal-app-facing-ten-level-evaluator";

const source_boundary_schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1";
const generated_by = "causal-app-facing-ten-level-policy";
const source_boundary_suffix = "-ci-ten-level-application-boundary.json";
const output_prefix_suffix = "-ci-ten-level-policy";
const compact_output_prefix_name = "app-facing-ci-ten-level-policy";
```

- [x] **Step 3: Promote status fields**

The source application status field is:

```text
evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status
```

The policy status field is:

```text
consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_status
```

- [x] **Step 4: Add source ten-level and source nine-level lineage**

Parse and emit:

```text
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

- [x] **Step 5: Run the focused GREEN test**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_ten_level_policy.zig
```

Expected: PASS.

### Task 3: Build Wiring

**Files:**
- Modify: `packages/zigeffect/build.zig`

- [x] **Step 1: Add alias module, executable, step, and tests after the ten-level application-boundary block**

```zig
const causal_app_facing_ten_level_policy_tool_module = b.createModule(.{
    .root_source_file = b.path("tools/causal_app_facing_ten_level_policy.zig"),
    .target = target,
    .optimize = optimize,
});

const causal_app_facing_ten_level_policy_tool = b.addExecutable(.{
    .name = "zigeffect-causal-app-facing-ten-level-policy",
    .root_module = causal_app_facing_ten_level_policy_tool_module,
});
const run_causal_app_facing_ten_level_policy_tool = b.addRunArtifact(causal_app_facing_ten_level_policy_tool);
if (b.args) |args| run_causal_app_facing_ten_level_policy_tool.addArgs(args);
const causal_app_facing_ten_level_policy_step = b.step("causal-app-facing-ten-level-policy", "Record app-facing ten-level policy evidence");
causal_app_facing_ten_level_policy_step.dependOn(&run_causal_app_facing_ten_level_policy_tool.step);

const causal_app_facing_ten_level_policy_tool_tests = b.addTest(.{
    .name = "zigeffect-causal-app-facing-ten-level-policy-tests",
    .root_module = causal_app_facing_ten_level_policy_tool_module,
});
const run_causal_app_facing_ten_level_policy_tool_tests = b.addRunArtifact(causal_app_facing_ten_level_policy_tool_tests);
test_step.dependOn(&run_causal_app_facing_ten_level_policy_tool_tests.step);
```

- [x] **Step 2: Verify the help step**

Run:

```bash
cd packages/zigeffect
zig build causal-app-facing-ten-level-policy -- --help
```

Expected: usage text for the alias step.

### Task 4: Governance And Backlog

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Modify generated docs: `packages/zigeffect/docs/schema-governance.md`
- Modify generated docs: `packages/zigeffect/docs/production-hardening-backlog.md`

- [x] **Step 1: Register the schema**

Add the schema immediately after the ten-level application-boundary entry with:

```zig
.emitted_by = &.{"causal-app-facing-ten-level-policy"}
.consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing ten-level evaluator" }
.compatibility = &.{ "strict-v1", "record-only", "policy-only", "source-ten-level-application-boundary", "approve-reject-decision", "local-publication-only", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" }
```

- [x] **Step 2: Update production backlog tests and item**

Set:

```zig
pub const recommendation = "start-app-facing-ten-level-evaluator";
pub const recommended_next_branch = "codex/zigeffect-causal-app-facing-ten-level-evaluator";
```

Add delivered item id `app-facing-ten-level-policy`, branch
`codex/zigeffect-causal-app-facing-ten-level-policy`, dependency
`app-facing-ten-level-application-boundary`, and verification commands for
help, approve, and reject generation.

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
- Create: `packages/zigeffect/docs/app-facing-ten-level-policy.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [x] **Step 1: Add docs**

The docs must include consumes/emits schemas, approve/reject usage, gates,
non-authority, and handoff to `codex/zigeffect-causal-app-facing-ten-level-evaluator`.

- [x] **Step 2: Update the master roadmap**

Mark `codex/zigeffect-causal-app-facing-ten-level-policy` as delivered and add
`codex/zigeffect-causal-app-facing-ten-level-evaluator` as the next branch.

- [x] **Step 3: Regenerate governance and backlog docs**

Run:

```bash
cd packages/zigeffect
zig build causal-schema-governance -- --format json > /tmp/zigeffect-schema-governance.out 2> docs/schema-governance.md
zig build causal-production-hardening-backlog -- --format json > /tmp/zigeffect-production-hardening-backlog.out 2> docs/production-hardening-backlog.md
```

Expected: commands exit `0` and docs update.

- [x] **Step 4: Generate approve, reject, and blocked-source artifacts**

Run:

```bash
cd packages/zigeffect
zig build causal-app-facing-ten-level-policy -- --from-application ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-application-boundary.json approve --reason "reviewed app-facing ten-level policy" --verified-command "bun run zigeffect:workbench:typecheck" --verified-command "bun run zigeffect:workbench:test" --verified-command "zig build causal-app-facing-ten-level-application-boundary -- --help" --verified-command "zig build causal-schema-governance -- --format json" --verified-command "zig build causal-production-hardening-backlog -- --format json" --verified-command "zig build examples" --verified-command "zig build test" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-policy
zig build causal-app-facing-ten-level-policy -- --from-application ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-application-boundary.json reject --reason "rejected app-facing ten-level policy" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-policy-reject
zig build causal-app-facing-ten-level-policy -- --from-application ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-application-boundary-blocked.json approve --reason "blocked source app-facing ten-level policy" --verified-command "bun run zigeffect:workbench:typecheck" --verified-command "bun run zigeffect:workbench:test" --verified-command "zig build causal-app-facing-ten-level-application-boundary -- --help" --verified-command "zig build causal-schema-governance -- --format json" --verified-command "zig build causal-production-hardening-backlog -- --format json" --verified-command "zig build examples" --verified-command "zig build test" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-policy-blocked
```

Expected: approve artifact status `ready`, reject artifact status `blocked`,
and blocked-source artifact status `blocked`.

- [x] **Step 5: Run final verification**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_ten_level_policy.zig
zig build causal-app-facing-ten-level-policy -- --help
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

Expected: all commands exit `0`.

- [x] **Step 6: Commit and checkpoint master**

Run:

```bash
git add docs/superpowers packages/zigeffect
git commit -m "feat(zigeffect): add app-facing ten-level policy"
git -C /Users/seanknowles/.config/superpowers/worktrees/yachdee/master-local-merge merge --ff-only codex/zigeffect-causal-app-facing-ten-level-policy
git switch -c codex/zigeffect-causal-app-facing-ten-level-evaluator
```

Expected: the feature branch is committed, local `master` advances by
fast-forward, and the next ten-level evaluator branch is ready.
