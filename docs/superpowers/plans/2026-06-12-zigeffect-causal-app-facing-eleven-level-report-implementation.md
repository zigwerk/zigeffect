# Zigeffect App-Facing Eleven-Level Report Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the alias-named eleven-level app-facing report that consumes ready/advisory ten-level evaluator evidence and hands local report artifacts to the eleven-level application-boundary branch.

**Architecture:** Promote the proven ten-level report implementation into an eleven-level alias file while updating the emitted schema, branch handoff, source evaluator contract, status field, and docs. The tool remains local, read-only, and advisory: it never grants CI, GitHub, app runtime, durable storage, NenDB, deployment, production-health, registry, auto-apply, or mutation authority.

**Tech Stack:** Zig build tools and `zig test`, generated zigeffect schema governance and production-hardening backlog docs, Bun root checks.

---

### Task 1: Report Tool RED Test

**Files:**
- Create: `packages/zigeffect/tools/causal_app_facing_eleven_level_report.zig`

- [ ] **Step 1: Write the failing constants test**

```zig
const std = @import("std");

test "app-facing eleven-level report constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1", schema);
    try std.testing.expectEqual(@as(u32, 1), schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-eleven-level-report", source_branch);
    try std.testing.expectEqualStrings("start-app-facing-eleven-level-application-boundary", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-eleven-level-application-boundary", next_branch_if_ready);
}
```

- [ ] **Step 2: Run the focused RED test**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_eleven_level_report.zig
```

Expected: FAIL with undeclared identifiers for `schema`, `schema_version`,
`source_branch`, `recommendation`, and `next_branch_if_ready`.

### Task 2: Promote The Report Tool

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_facing_eleven_level_report.zig`

- [ ] **Step 1: Copy the ten-level report implementation into the alias file**

Copy from:

```text
packages/zigeffect/tools/causal_app_facing_ten_level_report.zig
```

- [ ] **Step 2: Replace the top-level constants**

Use these exact values:

```zig
pub const schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1";
pub const schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-app-facing-eleven-level-report";
pub const recommendation = "start-app-facing-eleven-level-application-boundary";
pub const next_branch_if_ready = "codex/zigeffect-causal-app-facing-eleven-level-application-boundary";

const source_evaluator_schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1";
const generated_by = "causal-app-facing-eleven-level-report";
const evaluator_suffix = "-ci-ten-level-evaluator.json";
const output_suffix = "-ci-eleven-level-report";
const compact_output_prefix_name = "app-facing-ci-eleven-level-report";
```

- [ ] **Step 3: Promote only the emitted report names**

Replace command names, output files, help text, generated-by names, compact
output prefixes, and emitted report status fields with eleven-level aliases.
The report status field must be:

```text
consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status
```

- [ ] **Step 4: Preserve ten-level source evaluator fields**

Do not rename source fields to `source_eleven_level_*`. The consumed artifact is
the ten-level evaluator, so the parser and emitted report must preserve:

```text
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
source_nine_level_policy
source_nine_level_policy_schema
source_nine_level_policy_status
source_nine_level_application_boundary
source_nine_level_application_boundary_schema
source_nine_level_report
source_nine_level_report_schema
source_nine_level_report_status
```

- [ ] **Step 5: Update command language and next queries**

The help text must include:

```text
usage: zig build causal-app-facing-eleven-level-report -- --from-evaluator <ten-level-evaluator.json> summarize --reason <reason> [--by <actor>] [--policy <policy>] [--out-prefix <path-prefix>]
```

Ready next query text must point to:

```text
codex/zigeffect-causal-app-facing-eleven-level-application-boundary
```

Example artifact placeholders should use:

```text
app-facing-ci-eleven-level-report.json
```

- [ ] **Step 6: Run the focused GREEN test**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_eleven_level_report.zig
```

Expected: PASS.

### Task 3: Build Wiring

**Files:**
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Add alias module, executable, step, and tests after the ten-level evaluator block**

```zig
const causal_app_facing_eleven_level_report_tool_module = b.createModule(.{
    .root_source_file = b.path("tools/causal_app_facing_eleven_level_report.zig"),
    .target = target,
    .optimize = optimize,
});

const causal_app_facing_eleven_level_report_tool = b.addExecutable(.{
    .name = "zigeffect-causal-app-facing-eleven-level-report",
    .root_module = causal_app_facing_eleven_level_report_tool_module,
});
const run_causal_app_facing_eleven_level_report_tool = b.addRunArtifact(causal_app_facing_eleven_level_report_tool);
if (b.args) |args| run_causal_app_facing_eleven_level_report_tool.addArgs(args);
const causal_app_facing_eleven_level_report_step = b.step("causal-app-facing-eleven-level-report", "Summarize app-facing ten-level evaluator evidence");
causal_app_facing_eleven_level_report_step.dependOn(&run_causal_app_facing_eleven_level_report_tool.step);

const causal_app_facing_eleven_level_report_tool_tests = b.addTest(.{
    .name = "zigeffect-causal-app-facing-eleven-level-report-tests",
    .root_module = causal_app_facing_eleven_level_report_tool_module,
});
const run_causal_app_facing_eleven_level_report_tool_tests = b.addRunArtifact(causal_app_facing_eleven_level_report_tool_tests);
test_step.dependOn(&run_causal_app_facing_eleven_level_report_tool_tests.step);
```

- [ ] **Step 2: Verify the help step**

Run:

```bash
cd packages/zigeffect
zig build causal-app-facing-eleven-level-report -- --help
```

Expected: usage text for `causal-app-facing-eleven-level-report` and
`ten-level-evaluator.json`.

### Task 4: Real Artifact Generation

**Files:**
- Generate local artifacts under `.zig-cache/causal-artifacts/`

- [ ] **Step 1: Generate ready, advisory, and blocked report artifacts**

Run:

```bash
cd packages/zigeffect
zig build causal-app-facing-eleven-level-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-evaluator.json summarize --reason "reviewed app-facing eleven-level report" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-report
zig build causal-app-facing-eleven-level-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-evaluator-advisory.json summarize --reason "advisory app-facing eleven-level report source" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-report-advisory
zig build causal-app-facing-eleven-level-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-evaluator-blocked.json summarize --reason "blocked app-facing eleven-level report source" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-report-blocked
```

Expected:

```text
.zig-cache/causal-artifacts/app-facing-ci-eleven-level-report.json
.zig-cache/causal-artifacts/app-facing-ci-eleven-level-report.md
.zig-cache/causal-artifacts/app-facing-ci-eleven-level-report-advisory.json
.zig-cache/causal-artifacts/app-facing-ci-eleven-level-report-advisory.md
.zig-cache/causal-artifacts/app-facing-ci-eleven-level-report-blocked.json
.zig-cache/causal-artifacts/app-facing-ci-eleven-level-report-blocked.md
```

- [ ] **Step 2: Inspect report status summaries**

Run:

```bash
jq '.ready_for_next_branch, .consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status, .blocked_reasons' ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-report.json
jq '.ready_for_next_branch, .consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status, .findings[0].severity' ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-report-advisory.json
jq '.ready_for_next_branch, .consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status, .blocked_reasons[0]' ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-report-blocked.json
```

Expected: ready artifact is `true` and `ready`; advisory artifact is `false`
and `advisory`; blocked artifact is `false` and `blocked`.

### Task 5: Governance And Backlog

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Regenerate: `packages/zigeffect/docs/schema-governance.md`
- Regenerate: `packages/zigeffect/docs/production-hardening-backlog.md`

- [ ] **Step 1: Register the schema**

Add the schema immediately after the ten-level evaluator entry with:

```zig
.schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1",
.emitted_by = &.{"causal-app-facing-eleven-level-report"},
.consumed_by = &.{ "agents", "reviewers", "non-blocking CI advisory readers", "local SolidJS workbench", "production-hardening backlog", "future app-facing eleven-level application-boundary" },
.compatibility = &.{ "strict-v1", "record-only", "advisory-only", "source-ten-level-evaluator", "local-report-only", "read-only-consumption", "bounded-agent-context", "app-facing", "solid-webui", "webui-dev/zig-webui", "no-cockroach", "no-ci-enforcement", "no-required-status-check", "no-workflow-mutation", "no-github-api-mutation", "no-app-mutation", "no-app-runtime-integration", "no-live-agent-projection", "no-raw-payload-capture", "no-deployment-mutation", "no-production-mutation", "no-nendb-write", "no-nendb-adapter-execution", "no-public-artifact-upload", "no-hosted-live-dashboard", "no-auto-apply", "no-mutation-authority" },
```

Update governance tests to expect the entry count to increase by one and to
verify the eleven-level report schema is present in JSON and text output.

- [ ] **Step 2: Update production backlog recommendation and delivered item**

Set:

```zig
pub const recommendation = "start-app-facing-eleven-level-application-boundary";
pub const recommended_next_branch = "codex/zigeffect-causal-app-facing-eleven-level-application-boundary";
```

Add delivered item id `app-facing-eleven-level-report`, branch
`codex/zigeffect-causal-app-facing-eleven-level-report`, dependency
`app-facing-ten-level-evaluator`, and verification commands for help, ready,
advisory, and blocked generation.

- [ ] **Step 3: Regenerate governance and backlog docs**

Run:

```bash
cd packages/zigeffect
zig build causal-schema-governance -- --format json > /tmp/zigeffect-schema-governance.out 2> docs/schema-governance.md
zig build causal-production-hardening-backlog -- --format json > /tmp/zigeffect-production-hardening-backlog.out 2> docs/production-hardening-backlog.md
```

Expected: both commands exit `0`; generated docs mention the eleven-level
report and the eleven-level application-boundary next branch.

### Task 6: Human-Facing Docs And Roadmap

**Files:**
- Create: `packages/zigeffect/docs/app-facing-eleven-level-report.md`
- Modify: `packages/zigeffect/docs/causal-self-improvement-roadmap.md`

- [ ] **Step 1: Add the eleven-level report docs page**

The docs page must include:

```markdown
# App-Facing Eleven-Level Report

`causal-app-facing-eleven-level-report` consumes ten-level evaluator artifacts,
emits local eleven-level report JSON/Markdown, and hands ready/advisory evidence
to `codex/zigeffect-causal-app-facing-eleven-level-application-boundary`.
```

It must also describe ready/advisory/blocked outcomes, local-only artifact
paths, disabled authorities, SolidJS `webui-dev/zig-webui` consumption, and the
three example generation commands from Task 4.

- [ ] **Step 2: Update the master roadmap**

Mark `codex/zigeffect-causal-app-facing-eleven-level-report` delivered and add
the next item:

```markdown
### 107. App-Facing Eleven-Level Application Boundary

- Branch: `codex/zigeffect-causal-app-facing-eleven-level-application-boundary`
- Status: Next
- Consumes ready/advisory eleven-level report artifacts, records planned and
  reviewed local application-boundary evidence, preserves local-only no-mutation
  authority, and hands off to the eleven-level policy branch.
```

### Task 7: Full Verification, Commit, Merge, And Next Branch

**Files:**
- Stage all modified zigeffect docs, tools, build files, and Superpowers docs.

- [ ] **Step 1: Run focused and full verification**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_eleven_level_report.zig
zig build causal-app-facing-eleven-level-report -- --help
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

- [ ] **Step 2: Commit the milestone**

Run:

```bash
git add docs/superpowers packages/zigeffect
git commit -m "feat(zigeffect): add app-facing eleven-level report"
```

- [ ] **Step 3: Fast-forward the local master worktree**

Run:

```bash
git -C /Users/seanknowles/.config/superpowers/worktrees/yachdee/master-local-merge merge --ff-only codex/zigeffect-causal-app-facing-eleven-level-report
```

Expected: master advances to the new commit without a merge commit.

- [ ] **Step 4: Create the next branch**

Run:

```bash
git switch -c codex/zigeffect-causal-app-facing-eleven-level-application-boundary
```

Expected: working tree is on
`codex/zigeffect-causal-app-facing-eleven-level-application-boundary` and clean.
