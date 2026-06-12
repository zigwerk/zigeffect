# zigeffect Causal App-Facing Eleven-Level Application Boundary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the alias-named eleven-level app-facing application boundary that consumes eleven-level report artifacts and hands applied evidence to the eleven-level policy branch.

**Architecture:** Promote the proven ten-level application-boundary tool into an eleven-level alias file while preserving direct ten-level lineage and inherited nine-level and lower lineage in emitted artifacts. The tool remains local, record-only, and read-only; only `record-applied` can set `applied=true`, and only after reviewed evidence, safe after-report content, and verification command gates pass.

**Tech Stack:** Zig build tools and `zig test`, Bun root checks, existing zigeffect causal schema governance and production-hardening backlog generators.

---

### Task 1: Boundary Tool RED Test

**Files:**
- Create: `packages/zigeffect/tools/causal_app_facing_eleven_level_application_boundary.zig`

- [ ] **Step 1: Write the failing constants test**

```zig
const std = @import("std");

test "app-facing eleven-level application boundary constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1", schema);
    try std.testing.expectEqual(@as(u32, 1), schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-eleven-level-application-boundary", source_branch);
    try std.testing.expectEqualStrings("start-app-facing-eleven-level-policy", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-eleven-level-policy", next_branch_if_applied);
}
```

- [ ] **Step 2: Run the focused RED test**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_eleven_level_application_boundary.zig
```

Expected: FAIL with undeclared identifiers for `schema`, `schema_version`, `source_branch`, `recommendation`, and `next_branch_if_applied`.

### Task 2: Promote The Boundary Tool

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_facing_eleven_level_application_boundary.zig`

- [ ] **Step 1: Copy the ten-level application-boundary implementation into the alias file**

Copy from:

```text
packages/zigeffect/tools/causal_app_facing_ten_level_application_boundary.zig
```

- [ ] **Step 2: Replace the top-level constants**

Use these exact values:

```zig
pub const schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1";
pub const schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-app-facing-eleven-level-application-boundary";
pub const recommendation = "start-app-facing-eleven-level-policy";
pub const next_branch_if_applied = "codex/zigeffect-causal-app-facing-eleven-level-policy";

const source_report_schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1";
const generated_by = "causal-app-facing-eleven-level-application-boundary";
const source_report_suffix = "-ci-eleven-level-report.json";
const output_prefix_suffix = "-ci-eleven-level-application-boundary";
const compact_output_prefix_name = "app-facing-ci-eleven-level-application-boundary";
```

- [ ] **Step 3: Promote report-level status and output fields**

The source report status field is:

```text
consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status
```

The application output fields are:

```text
evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status
evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_path
evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_digest
evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_present
evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_changes
```

- [ ] **Step 4: Preserve direct ten-level source lineage**

The promoted `SourceReportArtifact` must parse and emit:

```zig
source_ten_level_policy
source_ten_level_policy_schema
source_ten_level_policy_status
source_ten_level_application_boundary
source_ten_level_application_boundary_schema
source_ten_level_report
source_ten_level_report_schema
source_ten_level_report_status
source_ten_level_after_digest
source_ten_level_after_present
source_ten_level_application_changes
source_nine_level_policy
source_nine_level_policy_schema
source_nine_level_policy_status
source_nine_level_application_boundary
source_nine_level_application_boundary_schema
source_nine_level_report
source_nine_level_report_schema
source_nine_level_report_status
```

- [ ] **Step 5: Keep the alias usage string**

The usage text must begin:

```text
usage: zig build causal-app-facing-eleven-level-application-boundary -- --from-report <eleven-level-report.json> plan|record-applied
```

- [ ] **Step 6: Run the focused GREEN test**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_eleven_level_application_boundary.zig
```

Expected: PASS.

### Task 3: Build Wiring

**Files:**
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Add alias module, executable, step, and tests after the eleven-level report block**

```zig
const causal_app_facing_eleven_level_application_boundary_tool_module = b.createModule(.{
    .root_source_file = b.path("tools/causal_app_facing_eleven_level_application_boundary.zig"),
    .target = target,
    .optimize = optimize,
});

const causal_app_facing_eleven_level_application_boundary_tool = b.addExecutable(.{
    .name = "zigeffect-causal-app-facing-eleven-level-application-boundary",
    .root_module = causal_app_facing_eleven_level_application_boundary_tool_module,
});
const run_causal_app_facing_eleven_level_application_boundary_tool = b.addRunArtifact(causal_app_facing_eleven_level_application_boundary_tool);
if (b.args) |args| run_causal_app_facing_eleven_level_application_boundary_tool.addArgs(args);
const causal_app_facing_eleven_level_application_boundary_step = b.step("causal-app-facing-eleven-level-application-boundary", "Record app-facing eleven-level application boundary evidence");
causal_app_facing_eleven_level_application_boundary_step.dependOn(&run_causal_app_facing_eleven_level_application_boundary_tool.step);

const causal_app_facing_eleven_level_application_boundary_tool_tests = b.addTest(.{
    .name = "zigeffect-causal-app-facing-eleven-level-application-boundary-tests",
    .root_module = causal_app_facing_eleven_level_application_boundary_tool_module,
});
const run_causal_app_facing_eleven_level_application_boundary_tool_tests = b.addRunArtifact(causal_app_facing_eleven_level_application_boundary_tool_tests);
test_step.dependOn(&run_causal_app_facing_eleven_level_application_boundary_tool_tests.step);
```

- [ ] **Step 2: Verify the help step**

Run:

```bash
cd packages/zigeffect
zig build causal-app-facing-eleven-level-application-boundary -- --help
```

Expected: usage text for the alias step.

### Task 4: Governance And Backlog

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Modify generated docs: `packages/zigeffect/docs/schema-governance.md`
- Modify generated docs: `packages/zigeffect/docs/production-hardening-backlog.md`

- [ ] **Step 1: Update schema governance tests first**

Increase the expected schema count by one and add an assertion for:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1
```

- [ ] **Step 2: Register the schema**

Add the schema immediately after the eleven-level report entry with:

```zig
.emitted_by = &.{"causal-app-facing-eleven-level-application-boundary"}
.consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing eleven-level policy" }
.compatibility = &.{ "strict-v1", "record-only", "advisory-only", "application-boundary", "source-eleven-level-report", "guarded-record-applied", "local-report-only", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" }
```

- [ ] **Step 3: Update production backlog tests and item**

Set:

```zig
pub const recommendation = "start-app-facing-eleven-level-policy";
pub const recommended_next_branch = "codex/zigeffect-causal-app-facing-eleven-level-policy";
```

Add delivered item id `app-facing-eleven-level-application-boundary`, branch
`codex/zigeffect-causal-app-facing-eleven-level-application-boundary`,
dependency `app-facing-eleven-level-report`, and verification commands for
help, plan, record-applied, and blocked source generation.

- [ ] **Step 4: Run focused tests**

Run:

```bash
cd packages/zigeffect
zig test --dep causal_artifact -Mroot=tools/causal_schema_governance.zig -Mcausal_artifact=tools/causal_artifact.zig
zig test tools/causal_production_hardening_backlog.zig
```

Expected: PASS.

### Task 5: Docs, Fixture, Artifacts, Verification, Commit

**Files:**
- Create: `packages/zigeffect/docs/app-facing-eleven-level-application-boundary.md`
- Create: `packages/zigeffect/test/fixtures/app-facing-eleven-level-application-boundary-after-safe.txt`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Add docs and fixture**

The fixture content must include the required safe markers:

```text
zigeffect causal read-only consumption evaluation-report application evidence.
This local evaluation report records reviewed eleven-level application boundary
evidence for agents reviewers advisory CI readers and the SolidJS webui.
Denied claims remain listed by id in the artifact; this text grants no extra
authority.
```

- [ ] **Step 2: Update the master roadmap**

Mark `codex/zigeffect-causal-app-facing-eleven-level-application-boundary` as
delivered and add `codex/zigeffect-causal-app-facing-eleven-level-policy` as the
next branch.

- [ ] **Step 3: Regenerate governance and backlog docs**

Run:

```bash
cd packages/zigeffect
zig build causal-schema-governance -- --format json > /tmp/zigeffect-schema-governance.out 2> docs/schema-governance.md
zig build causal-production-hardening-backlog -- --format json > /tmp/zigeffect-production-hardening-backlog.out 2> docs/production-hardening-backlog.md
```

Expected: commands exit `0` and docs update.

- [ ] **Step 4: Generate plan, applied, and blocked artifacts**

Run:

```bash
cd packages/zigeffect
zig build causal-app-facing-eleven-level-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-report.json plan --reason "planned app-facing eleven-level application boundary" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-application-boundary-plan
zig build causal-app-facing-eleven-level-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-report.json record-applied --reason "reviewed app-facing eleven-level application boundary" --after-report test/fixtures/app-facing-eleven-level-application-boundary-after-safe.txt --application-change "reviewed local eleven-level application boundary for agents reviewers CI advisory readers and SolidJS webui" --before "before local eleven-level application boundary evidence" --after "after local eleven-level application boundary evidence" --verified-command "bun run zigeffect:workbench:typecheck" --verified-command "bun run zigeffect:workbench:test" --verified-command "zig build causal-app-facing-eleven-level-report -- --help" --verified-command "zig build causal-schema-governance -- --format json" --verified-command "zig build causal-production-hardening-backlog -- --format json" --verified-command "zig build examples" --verified-command "zig build test" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-application-boundary
zig build causal-app-facing-eleven-level-application-boundary -- --from-report ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-report-blocked.json record-applied --reason "blocked app-facing eleven-level application boundary source" --after-report test/fixtures/app-facing-eleven-level-application-boundary-after-safe.txt --application-change "reviewed local eleven-level blocked source boundary probe" --before "before local eleven-level blocked source evidence" --after "after local eleven-level blocked source evidence" --verified-command "bun run zigeffect:workbench:typecheck" --verified-command "bun run zigeffect:workbench:test" --verified-command "zig build causal-app-facing-eleven-level-report -- --help" --verified-command "zig build causal-schema-governance -- --format json" --verified-command "zig build causal-production-hardening-backlog -- --format json" --verified-command "zig build examples" --verified-command "zig build test" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-application-boundary-blocked
```

Expected: plan artifact status `planned`, applied artifact status `applied`,
and blocked artifact status `blocked`.

- [ ] **Step 5: Run final verification**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_eleven_level_application_boundary.zig
zig build causal-app-facing-eleven-level-application-boundary -- --help
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

Expected: every command exits `0`.

- [ ] **Step 6: Commit, merge local master, and branch next**

Run:

```bash
git add docs/superpowers packages/zigeffect
git commit -m "feat(zigeffect): add app-facing eleven-level application boundary"
git -C /Users/seanknowles/.config/superpowers/worktrees/yachdee/master-local-merge merge --ff-only codex/zigeffect-causal-app-facing-eleven-level-application-boundary
git switch -c codex/zigeffect-causal-app-facing-eleven-level-policy
```

Expected: commit succeeds, local master fast-forwards, and the next branch is
ready for the eleven-level policy milestone.
