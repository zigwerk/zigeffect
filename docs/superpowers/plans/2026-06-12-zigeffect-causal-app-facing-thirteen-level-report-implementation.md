# Zigeffect Causal App-Facing Thirteen-Level Report Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the thirteen-level app-facing report tool that consumes twelve-level evaluator evidence and hands ready or advisory report evidence to the thirteen-level application-boundary branch.

**Architecture:** Reuse the existing report producer pattern, but parse and emit direct `source_twelve_level_*` evidence from the twelve-level evaluator instead of mechanically promoting those fields to thirteen-level inputs. The tool remains local-only, read-only, advisory-only, and mutation-authority-free.

**Tech Stack:** Zig tool in `packages/zigeffect/tools`, Zig build steps in `packages/zigeffect/build.zig`, schema/backlog governance tests, Bun root verification.

---

### Task 1: RED Test For Stable Constants

**Files:**
- Create: `packages/zigeffect/tools/causal_app_facing_thirteen_level_report.zig`

- [ ] **Step 1: Write the failing test**

Add only this initial test:

```zig
const std = @import("std");

test "app-facing thirteen-level report constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1", schema);
    try std.testing.expectEqual(@as(u32, 1), schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-thirteen-level-report", source_branch);
    try std.testing.expectEqualStrings("start-app-facing-thirteen-level-application-boundary", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-thirteen-level-application-boundary", next_branch_if_ready);
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_thirteen_level_report.zig
```

Expected: fail with an undeclared identifier such as `schema`.

### Task 2: Implement The Thirteen-Level Report Tool

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_facing_thirteen_level_report.zig`

- [ ] **Step 1: Copy the twelve-level report implementation**

Use `packages/zigeffect/tools/causal_app_facing_twelve_level_report.zig` as the implementation base.

- [ ] **Step 2: Apply the constants**

The top-level constants must be:

```zig
pub const schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1";
pub const schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-app-facing-thirteen-level-report";
pub const recommendation = "start-app-facing-thirteen-level-application-boundary";
pub const next_branch_if_ready = "codex/zigeffect-causal-app-facing-thirteen-level-application-boundary";

const source_evaluator_schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1";
const generated_by = "causal-app-facing-thirteen-level-report";
const evaluator_suffix = "-ci-twelve-level-evaluator.json";
const output_suffix = "-ci-thirteen-level-report";
const compact_output_prefix_name = "app-facing-ci-thirteen-level-report";
```

The required commands must include:

```zig
"zig build causal-app-facing-twelve-level-evaluator -- --help",
```

- [ ] **Step 3: Preserve direct twelve-level inputs**

Add direct fields to `EvaluatorArtifact`:

```zig
source_twelve_level_policy: []const u8 = "",
source_twelve_level_policy_schema: []const u8 = "",
source_twelve_level_policy_status: []const u8 = "",
source_twelve_level_application_boundary: []const u8 = "",
source_twelve_level_application_boundary_schema: []const u8 = "",
source_twelve_level_report: []const u8 = "",
source_twelve_level_report_schema: []const u8 = "",
source_twelve_level_report_status: []const u8 = "",
source_twelve_level_after_digest: []const u8 = "",
source_twelve_level_after_present: bool = false,
source_twelve_level_application_changes: []const []const u8 = &.{},
```

Do not add or require `source_thirteen_level_*` source fields.

- [ ] **Step 4: Update source checks**

The report checks must include names that identify the consumed source:

```zig
"source-twelve-level-evaluator-schema"
"source-twelve-level-evaluator-reportable"
"source-twelve-level-ready-for-next-branch"
"source-twelve-level-no-blocked-findings"
"source-twelve-level-policy-ready"
"source-twelve-level-application-evidence"
```

`sourcePolicyReady` must require ready twelve-level policy, application
boundary, and report evidence before checking eleven/ten/nine lineage.

- [ ] **Step 5: Update output fields**

The JSON output must include:

```json
"source_twelve_level_evaluator": "<path>",
"source_twelve_level_evaluator_schema": "<schema>",
"source_twelve_level_evaluator_status": "<status>",
"source_twelve_level_policy": "<path>",
"source_twelve_level_application_boundary": "<path>",
"source_twelve_level_report": "<path>"
```

The text output must print the same direct twelve-level source fields.

- [ ] **Step 6: Verify GREEN**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_thirteen_level_report.zig
```

Expected: all tests in the new file pass.

### Task 3: Build Wiring And User Docs

**Files:**
- Modify: `packages/zigeffect/build.zig`
- Create: `packages/zigeffect/docs/app-facing-thirteen-level-report.md`

- [ ] **Step 1: Add build wiring**

Insert a build block after the twelve-level evaluator block:

```zig
const causal_app_facing_thirteen_level_report_tool_module = b.createModule(.{
    .root_source_file = b.path("tools/causal_app_facing_thirteen_level_report.zig"),
    .target = target,
    .optimize = optimize,
});
const causal_app_facing_thirteen_level_report_tool = b.addExecutable(.{
    .name = "zigeffect-causal-app-facing-thirteen-level-report",
    .root_module = causal_app_facing_thirteen_level_report_tool_module,
});
const run_causal_app_facing_thirteen_level_report_tool = b.addRunArtifact(causal_app_facing_thirteen_level_report_tool);
if (b.args) |args| run_causal_app_facing_thirteen_level_report_tool.addArgs(args);
const causal_app_facing_thirteen_level_report_step = b.step("causal-app-facing-thirteen-level-report", "Summarize app-facing twelve-level evaluator evidence");
causal_app_facing_thirteen_level_report_step.dependOn(&run_causal_app_facing_thirteen_level_report_tool.step);
const causal_app_facing_thirteen_level_report_tool_tests = b.addTest(.{
    .name = "zigeffect-causal-app-facing-thirteen-level-report-tests",
    .root_module = causal_app_facing_thirteen_level_report_tool_module,
});
const run_causal_app_facing_thirteen_level_report_tool_tests = b.addRunArtifact(causal_app_facing_thirteen_level_report_tool_tests);
test_step.dependOn(&run_causal_app_facing_thirteen_level_report_tool_tests.step);
```

- [ ] **Step 2: Add docs with commands**

Document ready, advisory, and blocked runs:

```bash
zig build causal-app-facing-thirteen-level-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-evaluator.json summarize --reason "reviewed app-facing thirteen-level report" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-thirteen-level-report
zig build causal-app-facing-thirteen-level-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-evaluator-advisory.json summarize --reason "advisory app-facing thirteen-level report source" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-thirteen-level-report-advisory
zig build causal-app-facing-thirteen-level-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-evaluator-blocked.json summarize --reason "blocked app-facing thirteen-level report source" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-thirteen-level-report-blocked
```

- [ ] **Step 3: Verify help**

Run:

```bash
cd packages/zigeffect
zig build causal-app-facing-thirteen-level-report -- --help
```

Expected: usage text for the thirteen-level report command.

### Task 4: Governance, Backlog, And Roadmap

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Register schema governance**

Add the thirteen-level report schema after the twelve-level evaluator entry,
with:

```zig
.emitted_by = &.{"causal-app-facing-thirteen-level-report"},
.consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing thirteen-level application-boundary" },
.compatibility = &.{ "strict-v1", "record-only", "advisory-only", "source-twelve-level-evaluator", "local-report-only", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" },
```

Increment the schema count test from `149` to `150`.

- [ ] **Step 2: Update production backlog**

Set:

```zig
pub const recommendation = "start-app-facing-thirteen-level-application-boundary";
pub const recommended_next_branch = "codex/zigeffect-causal-app-facing-thirteen-level-application-boundary";
```

Add a delivered backlog item:

```zig
.id = "app-facing-thirteen-level-report",
.title = "App-Facing Thirteen-Level Report",
.depends_on = &.{"app-facing-twelve-level-evaluator"},
.branch = "codex/zigeffect-causal-app-facing-thirteen-level-report",
```

Add it to `dependency_order` after `app-facing-twelve-level-evaluator` and add
the three report generation commands to `verification_commands`.

- [ ] **Step 3: Update roadmap**

Mark item 114 delivered and add item 115:

```text
115. `codex/zigeffect-causal-app-facing-thirteen-level-application-boundary`
   - Next: consume ready or advisory thirteen-level report artifacts, record
     planned or reviewed local application-boundary evidence, preserve
     thirteen-level report plus twelve-level, eleven-level, ten-level, and
     nine-level lineage, keep local-only no-mutation authority, and hand applied
     evidence to the thirteen-level policy branch.
```

- [ ] **Step 4: Verify governance and backlog**

Run:

```bash
cd packages/zigeffect
zig test --dep causal_artifact -Mroot=tools/causal_schema_governance.zig -Mcausal_artifact=tools/causal_artifact.zig
zig test tools/causal_production_hardening_backlog.zig
```

Expected: both commands pass.

### Task 5: Generate Artifacts And Full Verification

**Files:**
- Generated under `.zig-cache/causal-artifacts/`

- [ ] **Step 1: Generate ready, advisory, and blocked reports**

Run from `packages/zigeffect`:

```bash
zig build causal-app-facing-thirteen-level-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-evaluator.json summarize --reason "reviewed app-facing thirteen-level report" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-thirteen-level-report
zig build causal-app-facing-thirteen-level-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-evaluator-advisory.json summarize --reason "advisory app-facing thirteen-level report source" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-thirteen-level-report-advisory
zig build causal-app-facing-thirteen-level-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-evaluator-blocked.json summarize --reason "blocked app-facing thirteen-level report source" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-thirteen-level-report-blocked
```

Expected statuses:

```text
app-facing-ci-thirteen-level-report.json: ready
app-facing-ci-thirteen-level-report-advisory.json: advisory
app-facing-ci-thirteen-level-report-blocked.json: blocked
```

- [ ] **Step 2: Run full verification**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_thirteen_level_report.zig
zig build causal-app-facing-thirteen-level-report -- --help
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```

Expected: every command exits `0`.

- [ ] **Step 3: Commit and advance**

Run:

```bash
git add docs/superpowers/specs/2026-06-12-zigeffect-causal-app-facing-thirteen-level-report-design.md docs/superpowers/plans/2026-06-12-zigeffect-causal-app-facing-thirteen-level-report-implementation.md packages/zigeffect/tools/causal_app_facing_thirteen_level_report.zig packages/zigeffect/build.zig packages/zigeffect/docs/app-facing-thirteen-level-report.md packages/zigeffect/tools/causal_schema_governance.zig packages/zigeffect/tools/causal_production_hardening_backlog.zig docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
git commit -m "feat(zigeffect): add app-facing thirteen-level report"
git -C /Users/seanknowles/.config/superpowers/worktrees/yachdee/master-local-merge merge --ff-only codex/zigeffect-causal-app-facing-thirteen-level-report
git switch -c codex/zigeffect-causal-app-facing-thirteen-level-application-boundary
```

Expected: the thirteen-level report milestone is committed, local `master`
contains the milestone, and the main workspace is ready for the thirteen-level
application-boundary milestone.
