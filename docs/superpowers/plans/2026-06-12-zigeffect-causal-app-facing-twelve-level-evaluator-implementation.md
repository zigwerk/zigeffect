# Zigeffect App-Facing Twelve-Level Evaluator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Build the twelve-level app-facing evaluator tool that consumes approved twelve-level policy artifacts plus bounded request/support evidence and hands ready or advisory evidence to the thirteen-level report branch.

**Architecture:** Promote the eleven-level evaluator into a twelve-level alias, then add direct twelve-level policy/application/report gates and output fields. Keep every output local, advisory, read-only, and explicitly non-mutating.

**Tech Stack:** Zig build tools and `zig test`, existing zigeffect causal schema governance and production-hardening backlog generators, Bun root verification commands.

---

### Task 1: Evaluator Tool RED Test

**Files:**
- Create: `packages/zigeffect/tools/causal_app_facing_twelve_level_evaluator.zig`

- [x] **Step 1: Write the failing constant test**

Create a minimal Zig file that references the expected public constants before
the implementation exists:

```zig
const std = @import("std");

test "app-facing twelve-level evaluator constants are stable" {
    try std.testing.expectEqualStrings(
        "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1",
        schema,
    );
    try std.testing.expectEqual(@as(u32, 1), schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-twelve-level-evaluator", source_branch);
    try std.testing.expectEqualStrings("start-app-facing-thirteen-level-report", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-thirteen-level-report", next_branch_if_ready);
}
```

- [x] **Step 2: Run the test to verify RED**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_twelve_level_evaluator.zig
```

Expected: FAIL with `use of undeclared identifier 'schema'`.

### Task 2: Promote The Eleven-Level Evaluator Tool

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_facing_twelve_level_evaluator.zig`

- [x] **Step 1: Replace the RED shell with the eleven-level evaluator**

Copy `packages/zigeffect/tools/causal_app_facing_eleven_level_evaluator.zig`
over the twelve-level evaluator file.

- [x] **Step 2: Apply mechanical alias promotion**

Replace:

```text
eleven-level -> twelve-level
eleven level -> twelve level
eleven_level -> twelve_level
ElevenLevel -> TwelveLevel
```

- [x] **Step 3: Set top-level constants**

Ensure the constants are exactly:

```zig
pub const schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1";
pub const schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-app-facing-twelve-level-evaluator";
pub const recommendation = "start-app-facing-thirteen-level-report";
pub const next_branch_if_ready = "codex/zigeffect-causal-app-facing-thirteen-level-report";

const source_policy_schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1";
const generated_by = "causal-app-facing-twelve-level-evaluator";
const source_policy_suffix = "-ci-twelve-level-policy.json";
const output_prefix_suffix = "-ci-twelve-level-evaluator";
const compact_output_prefix_name = "app-facing-ci-twelve-level-evaluator";
```

- [x] **Step 4: Update required verification commands**

The required upstream command must be:

```zig
"zig build causal-app-facing-twelve-level-policy -- --help",
```

- [x] **Step 5: Restore direct twelve-level and lower-level source fields**

Add direct policy source fields to `SourcePolicyArtifact`:

```zig
source_twelve_level_application_boundary: []const u8 = "",
source_twelve_level_application_boundary_schema: []const u8 = "",
source_twelve_level_report: []const u8 = "",
source_twelve_level_report_schema: []const u8 = "",
source_twelve_level_report_status: []const u8 = "",
source_twelve_level_after_digest: []const u8 = "",
source_twelve_level_after_present: bool = false,
source_twelve_level_application_changes: []const []const u8 = &.{},
```

Keep `source_eleven_level_policy`, `source_eleven_level_application_boundary`,
`source_eleven_level_report`, and lower lineage fields from the source policy.

- [x] **Step 6: Require direct twelve-level refs and evidence**

Add helpers equivalent to:

```zig
fn sourceTwelveLevelRefsPresent(source: SourcePolicyArtifact) bool {
    return source.source_twelve_level_application_boundary.len > 0 and
        source.source_twelve_level_application_boundary_schema.len > 0 and
        source.source_twelve_level_report.len > 0 and
        source.source_twelve_level_report_schema.len > 0 and
        std.mem.eql(u8, source.source_twelve_level_report_status, "ready") and
        source.source_twelve_level_after_digest.len > 0 and
        source.source_twelve_level_after_present;
}
```

Call it from `sourceRefsPresent`. Require
`source.source_twelve_level_application_changes.len > 0` from
`sourceEvidencePresent`.

- [x] **Step 7: Emit twelve-level JSON and text fields**

Emit these fields:

```text
source_twelve_level_policy
source_twelve_level_policy_schema
source_twelve_level_policy_status
source_twelve_level_application_boundary
source_twelve_level_application_boundary_schema
source_twelve_level_report
source_twelve_level_report_schema
source_twelve_level_report_status
source_twelve_level_after_digest
source_twelve_level_after_present
source_twelve_level_application_changes
```

- [x] **Step 8: Update fixtures and tests**

Update fixture schemas, status field names, CLI strings, next queries, agent
guidance, and test expectations so ready/advisory/blocked behavior is proven
for the twelve-level evaluator.

- [x] **Step 9: Run focused test**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_twelve_level_evaluator.zig
```

Expected: all evaluator tests pass.

### Task 3: Build Wiring And Docs

**Files:**
- Modify: `packages/zigeffect/build.zig`
- Create: `packages/zigeffect/docs/app-facing-twelve-level-evaluator.md`

- [x] **Step 1: Add build module, executable, run step, and tests**

Insert the twelve-level evaluator build block immediately after the
twelve-level policy block:

```zig
const causal_app_facing_twelve_level_evaluator_tool_module = b.createModule(.{
    .root_source_file = b.path("tools/causal_app_facing_twelve_level_evaluator.zig"),
    .target = target,
    .optimize = optimize,
});

const causal_app_facing_twelve_level_evaluator_tool = b.addExecutable(.{
    .name = "zigeffect-causal-app-facing-twelve-level-evaluator",
    .root_module = causal_app_facing_twelve_level_evaluator_tool_module,
});
const run_causal_app_facing_twelve_level_evaluator_tool = b.addRunArtifact(causal_app_facing_twelve_level_evaluator_tool);
if (b.args) |args| run_causal_app_facing_twelve_level_evaluator_tool.addArgs(args);
const causal_app_facing_twelve_level_evaluator_step = b.step("causal-app-facing-twelve-level-evaluator", "Evaluate app-facing twelve-level policy evidence");
causal_app_facing_twelve_level_evaluator_step.dependOn(&run_causal_app_facing_twelve_level_evaluator_tool.step);

const causal_app_facing_twelve_level_evaluator_tool_tests = b.addTest(.{
    .name = "zigeffect-causal-app-facing-twelve-level-evaluator-tests",
    .root_module = causal_app_facing_twelve_level_evaluator_tool_module,
});
const run_causal_app_facing_twelve_level_evaluator_tool_tests = b.addRunArtifact(causal_app_facing_twelve_level_evaluator_tool_tests);
test_step.dependOn(&run_causal_app_facing_twelve_level_evaluator_tool_tests.step);
```

- [x] **Step 2: Add docs**

Write `packages/zigeffect/docs/app-facing-twelve-level-evaluator.md` with:

- consumed and emitted schemas
- ready, advisory, and blocked usage examples
- bounded request/support file rules
- readiness gates
- denied authority claims
- SolidJS webui scope
- NenDB adapter-only future direction
- handoff to the thirteen-level report

- [x] **Step 3: Verify build help**

Run:

```bash
cd packages/zigeffect
zig build causal-app-facing-twelve-level-evaluator -- --help
```

Expected: usage text for `causal-app-facing-twelve-level-evaluator`.

### Task 4: Governance, Backlog, And Roadmap

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [x] **Step 1: Register schema governance**

Add the twelve-level evaluator schema after the twelve-level policy schema.
Increment schema count tests by one and add assertions for the schema,
emitting tool, source policy, bounded explicit evidence, SolidJS webui, no
Cockroach, no NenDB write, no adapter execution, and no mutation authority.

- [x] **Step 2: Update production backlog**

Change:

```zig
pub const recommendation = "start-app-facing-thirteen-level-report";
pub const recommended_next_branch = "codex/zigeffect-causal-app-facing-thirteen-level-report";
```

Add delivered item `app-facing-twelve-level-evaluator` after
`app-facing-twelve-level-policy`, add it to dependency order, and add help,
ready, advisory, and blocked verification commands.

- [x] **Step 3: Update master roadmap**

Mark item 113 delivered and add item 114 as
`codex/zigeffect-causal-app-facing-thirteen-level-report`.

- [x] **Step 4: Run governance/backlog tests**

Run:

```bash
cd packages/zigeffect
zig test --dep causal_artifact -Mroot=tools/causal_schema_governance.zig -Mcausal_artifact=tools/causal_artifact.zig
zig test tools/causal_production_hardening_backlog.zig
```

Expected: both tests pass.

### Task 5: Generate Artifacts And Verify

**Files:**
- Generated: `.zig-cache/causal-artifacts/app-facing-ci-twelve-level-evaluator.json`
- Generated: `.zig-cache/causal-artifacts/app-facing-ci-twelve-level-evaluator.txt`
- Generated: `.zig-cache/causal-artifacts/app-facing-ci-twelve-level-evaluator-advisory.json`
- Generated: `.zig-cache/causal-artifacts/app-facing-ci-twelve-level-evaluator-blocked.json`

- [x] **Step 1: Create bounded request/support fixtures if missing**

Use `.zig-cache/causal-artifacts/app-facing-ci-twelve-level-evaluator-request.json`
with a redacted read-only agent request and
`.zig-cache/causal-artifacts/app-facing-ci-twelve-level-evaluator-support.txt`
with SolidJS `webui-dev/zig-webui` support evidence.

- [x] **Step 2: Generate ready, advisory, and blocked artifacts**

Run:

```bash
cd packages/zigeffect
zig build causal-app-facing-twelve-level-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-policy.json evaluate --reason "reviewed app-facing twelve-level evaluator" --request ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-evaluator-request.json --evidence ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-evaluator-support.txt --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-evaluator
zig build causal-app-facing-twelve-level-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-policy.json evaluate --reason "advisory app-facing twelve-level evaluator missing support" --request ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-evaluator-request.json --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-evaluator-advisory
zig build causal-app-facing-twelve-level-evaluator -- --from-policy ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-policy-reject.json evaluate --reason "blocked app-facing twelve-level evaluator source" --request ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-evaluator-request.json --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-evaluator-blocked
```

Expected: ready artifact has `evaluation_status=ready`, advisory artifact has
`evaluation_status=advisory-findings`, and blocked artifact has
`evaluation_status=blocked`.

- [x] **Step 3: Run full verification**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_twelve_level_evaluator.zig
zig build causal-app-facing-twelve-level-evaluator -- --help
zig test --dep causal_artifact -Mroot=tools/causal_schema_governance.zig -Mcausal_artifact=tools/causal_artifact.zig
zig test tools/causal_production_hardening_backlog.zig
zig build causal-schema-governance -- --format json > /tmp/zigeffect-schema-governance-twelve-evaluator.json 2>&1
zig build causal-production-hardening-backlog -- --format json > /tmp/zigeffect-production-backlog-twelve-evaluator.json 2>&1
zig build examples > /tmp/zigeffect-build-examples-twelve-evaluator.log 2>&1
zig build test > /tmp/zigeffect-build-test-twelve-evaluator.log 2>&1
cd ../..
bun run check > /tmp/yachdee-bun-check-twelve-evaluator.log 2>&1
bun run zig:test > /tmp/yachdee-bun-zig-test-twelve-evaluator.log 2>&1
git diff --check
```

Expected: every command exits 0.

### Task 6: Commit, Merge, And Advance

**Files:**
- All modified source, docs, spec, and plan files

- [x] **Step 1: Mark the plan complete**

Change the plan checkboxes from `[ ]` to `[x]` only after the corresponding
steps have actually run.

- [x] **Step 2: Commit**

Run:

```bash
git status --short
git add docs/superpowers/specs/2026-06-12-zigeffect-causal-app-facing-twelve-level-evaluator-design.md docs/superpowers/plans/2026-06-12-zigeffect-causal-app-facing-twelve-level-evaluator-implementation.md packages/zigeffect/tools/causal_app_facing_twelve_level_evaluator.zig packages/zigeffect/build.zig packages/zigeffect/docs/app-facing-twelve-level-evaluator.md packages/zigeffect/tools/causal_schema_governance.zig packages/zigeffect/tools/causal_production_hardening_backlog.zig docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
git commit -m "feat(zigeffect): add app-facing twelve-level evaluator"
```

- [x] **Step 3: Merge local master and create next branch**

Run:

```bash
git -C /Users/seanknowles/.config/superpowers/worktrees/yachdee/master-local-merge merge --ff-only codex/zigeffect-causal-app-facing-twelve-level-evaluator
git switch -c codex/zigeffect-causal-app-facing-thirteen-level-report
```

Expected: local `master` points at the evaluator commit and the active
workspace is on the thirteen-level report branch.
