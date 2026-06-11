# zigeffect Causal App-Facing Eight-Level Application Boundary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the alias-named eight-level app-facing application boundary that consumes the full eight-level report schema and hands off to the short eight-level policy branch.

**Architecture:** Promote the existing seven-level application-boundary tool into a short physical file while preserving full schema lineage in emitted artifacts. The tool remains local, record-only, and read-only, with `record-applied` guarded by reviewed change, before evidence, after evidence, safe after-report text, and verification commands.

**Tech Stack:** Zig build tools and `zig test`, Bun root checks, existing zigeffect causal schema governance and production-hardening backlog generators.

---

### Task 1: Boundary Tool RED Test

**Files:**
- Create: `packages/zigeffect/tools/causal_app_facing_eight_level_application_boundary.zig`

- [ ] **Step 1: Write the failing constants test**

```zig
const std = @import("std");

test "app-facing eight-level application boundary constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1", schema);
    try std.testing.expectEqual(@as(u32, 1), schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-eight-level-application-boundary", source_branch);
    try std.testing.expectEqualStrings("start-app-facing-eight-level-policy", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-eight-level-policy", next_branch_if_applied);
}
```

- [ ] **Step 2: Run the focused RED test**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_eight_level_application_boundary.zig
```

Expected: FAIL with undeclared identifiers for `schema`, `schema_version`, `source_branch`, `recommendation`, and `next_branch_if_applied`.

### Task 2: Promote The Boundary Tool

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_facing_eight_level_application_boundary.zig`

- [ ] **Step 1: Copy the seven-level application-boundary implementation into the alias file**

Copy from:

```text
packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary.zig
```

- [ ] **Step 2: Replace the top-level constants**

Use these exact values:

```zig
pub const schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1";
pub const schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-app-facing-eight-level-application-boundary";
pub const recommendation = "start-app-facing-eight-level-policy";
pub const next_branch_if_applied = "codex/zigeffect-causal-app-facing-eight-level-policy";

const source_report_schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1";
const generated_by = "causal-app-facing-eight-level-application-boundary";
const source_report_suffix = "-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.json";
const output_prefix_suffix = "-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary";
const compact_output_prefix_name = "app-facing-ci-eight-level-application-boundary";
```

- [ ] **Step 3: Promote report-level status and field names**

Replace seven-level status fields with eight-level status fields:

```text
consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status
```

Application output fields should use:

```text
evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status
evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_path
evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_digest
evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_present
evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_changes
```

- [ ] **Step 4: Keep the alias usage string**

The usage text should begin:

```text
usage: zig build causal-app-facing-eight-level-application-boundary -- --from-report <eight-level-report.json> plan|record-applied
```

- [ ] **Step 5: Run the focused GREEN test**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_eight_level_application_boundary.zig
```

Expected: PASS.

### Task 3: Build Wiring

**Files:**
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Add alias module, executable, step, and tests**

Add a build block after the eight-level report step:

```zig
const causal_app_facing_eight_level_application_boundary_tool_module = b.createModule(.{
    .root_source_file = b.path("tools/causal_app_facing_eight_level_application_boundary.zig"),
    .target = target,
    .optimize = optimize,
});

const causal_app_facing_eight_level_application_boundary_tool = b.addExecutable(.{
    .name = "zigeffect-causal-app-facing-eight-level-application-boundary",
    .root_module = causal_app_facing_eight_level_application_boundary_tool_module,
});
const run_causal_app_facing_eight_level_application_boundary_tool = b.addRunArtifact(causal_app_facing_eight_level_application_boundary_tool);
if (b.args) |args| run_causal_app_facing_eight_level_application_boundary_tool.addArgs(args);
const causal_app_facing_eight_level_application_boundary_step = b.step("causal-app-facing-eight-level-application-boundary", "Record app-facing eight-level application boundary evidence");
causal_app_facing_eight_level_application_boundary_step.dependOn(&run_causal_app_facing_eight_level_application_boundary_tool.step);

const causal_app_facing_eight_level_application_boundary_tool_tests = b.addTest(.{
    .name = "zigeffect-causal-app-facing-eight-level-application-boundary-tests",
    .root_module = causal_app_facing_eight_level_application_boundary_tool_module,
});
const run_causal_app_facing_eight_level_application_boundary_tool_tests = b.addRunArtifact(causal_app_facing_eight_level_application_boundary_tool_tests);
test_step.dependOn(&run_causal_app_facing_eight_level_application_boundary_tool_tests.step);
```

- [ ] **Step 2: Verify the help step**

Run:

```bash
cd packages/zigeffect
zig build causal-app-facing-eight-level-application-boundary -- --help
```

Expected: usage text for the alias step.

### Task 4: Schema Governance RED And GREEN

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`

- [ ] **Step 1: Update tests first**

Increase the expected schema count by one and add an assertion for:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1
```

- [ ] **Step 2: Run the governance RED test**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_schema_governance.zig
```

Expected: FAIL because the schema entry is not registered.

- [ ] **Step 3: Register the schema**

Add a schema entry with:

```zig
.emitted_by = &.{"causal-app-facing-eight-level-application-boundary"}
.compatibility = &.{ "strict-v1", "record-only", "advisory-only", "application-boundary", "source-eight-level-report", "guarded-record-applied", "local-report-only", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" }
```

- [ ] **Step 4: Run the governance GREEN test**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_schema_governance.zig
```

Expected: PASS.

### Task 5: Production Backlog RED And GREEN

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`

- [ ] **Step 1: Update tests first**

Expect:

```text
recommendation = start-app-facing-eight-level-policy
recommended_next_branch = codex/zigeffect-causal-app-facing-eight-level-policy
delivered item id = app-facing-eight-level-application-boundary
branch = codex/zigeffect-causal-app-facing-eight-level-application-boundary
verification = zig build causal-app-facing-eight-level-application-boundary -- --help
```

- [ ] **Step 2: Run the backlog RED test**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_production_hardening_backlog.zig
```

Expected: FAIL because the backlog still points at the boundary branch.

- [ ] **Step 3: Update the backlog data**

Mark `app-facing-eight-level-application-boundary` delivered, append it after the eight-level report item in dependency order, and set the next recommendation to the policy branch.

- [ ] **Step 4: Run the backlog GREEN test**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_production_hardening_backlog.zig
```

Expected: PASS.

### Task 6: Docs And Roadmap

**Files:**
- Create: `packages/zigeffect/docs/app-facing-eight-level-application-boundary.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
- Create: `packages/zigeffect/test/fixtures/app-facing-eight-level-application-boundary-after-safe.txt`

- [ ] **Step 1: Add the tool docs**

Document consumed schema, emitted schema, alias naming policy, modes, gates, denied authority, and next branch.

- [ ] **Step 2: Add safe after-report fixture**

Use this exact content:

```text
zigeffect causal read-only consumption report evaluation-report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report application boundary reviewed locally for agents reviewers non-blocking CI advisory readers and SolidJS webui.
```

- [ ] **Step 3: Update the roadmap**

Mark item 95 delivered and add item 96:

```text
96. `codex/zigeffect-causal-app-facing-eight-level-policy`
   - Next: consume applied eight-level application-boundary evidence, make a record-only approve or reject decision, preserve no-mutation authority, and hand off to the eight-level evaluator.
```

### Task 7: Generate Artifacts And Full Verification

**Files:**
- Modify generated docs:
  - `packages/zigeffect/docs/schema-governance.md`
  - `packages/zigeffect/docs/production-hardening-backlog.md`

- [ ] **Step 1: Regenerate governance and backlog docs**

Run:

```bash
cd packages/zigeffect
zig build causal-schema-governance > /dev/null 2> docs/schema-governance.md
zig build causal-production-hardening-backlog > /dev/null 2> docs/production-hardening-backlog.md
```

- [ ] **Step 2: Generate plan and record-applied artifacts**

Run the alias step against the eight-level report artifact under `.zig-cache/causal-artifacts`, once in `plan` mode and once in `record-applied` mode with the safe fixture and all required verification commands.

- [ ] **Step 3: Run all verification**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_eight_level_application_boundary.zig
zig test tools/causal_schema_governance.zig
zig test tools/causal_production_hardening_backlog.zig
zig build causal-app-facing-eight-level-application-boundary -- --help
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

### Task 8: Commit And Merge Checkpoint

**Files:**
- Stage the completed milestone files.

- [ ] **Step 1: Commit the milestone**

Run:

```bash
git add docs/superpowers packages/zigeffect
git commit -m "feat(zigeffect): add app-facing eight-level application boundary"
```

- [ ] **Step 2: Fast-forward master**

Run:

```bash
git -C /Users/seanknowles/.config/superpowers/worktrees/yachdee/master-local-merge merge --ff-only codex/zigeffect-causal-app-facing-eight-level-application-boundary
```

- [ ] **Step 3: Create the next branch**

Run:

```bash
git switch -c codex/zigeffect-causal-app-facing-eight-level-policy
```

Expected: the next milestone starts from the merged eight-level application-boundary checkpoint.
