# Zigeffect App-Facing Twelve-Level Policy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Build the alias-named twelve-level app-facing policy tool that consumes applied twelve-level application-boundary artifacts and hands approved evidence to the twelve-level evaluator branch.

**Architecture:** Promote the existing eleven-level policy implementation into a twelve-level alias while adding direct twelve-level source application-boundary/report fields. Keep the policy local, advisory, and record-only; approval requires applied source evidence and required verification commands, while rejection and unsafe source artifacts remain blocked evidence.

**Tech Stack:** Zig build tools and `zig test`, existing zigeffect causal schema governance and production-hardening backlog generators, Bun root verification commands.

---

### Task 1: Policy Tool RED Test

**Files:**
- Create: `packages/zigeffect/tools/causal_app_facing_twelve_level_policy.zig`

- [x] **Step 1: Write the failing test shell**

Create a minimal Zig file that references the expected public constants before
the implementation exists:

```zig
const std = @import("std");

test "app-facing twelve-level policy constants are stable" {
    try std.testing.expectEqualStrings(
        "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1",
        schema,
    );
    try std.testing.expectEqual(@as(u32, 1), schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-twelve-level-policy", source_branch);
    try std.testing.expectEqualStrings("start-app-facing-twelve-level-evaluator", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-twelve-level-evaluator", next_branch_if_ready);
}
```

- [x] **Step 2: Run the test to verify RED**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_twelve_level_policy.zig
```

Expected: FAIL with `use of undeclared identifier 'schema'`.

### Task 2: Promote The Eleven-Level Policy Tool

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_facing_twelve_level_policy.zig`

- [x] **Step 1: Replace the RED shell with the eleven-level implementation**

Copy `packages/zigeffect/tools/causal_app_facing_eleven_level_policy.zig` over
the twelve-level file.

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
pub const schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1";
pub const schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-app-facing-twelve-level-policy";
pub const recommendation = "start-app-facing-twelve-level-evaluator";
pub const next_branch_if_ready = "codex/zigeffect-causal-app-facing-twelve-level-evaluator";

const source_boundary_schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1";
const generated_by = "causal-app-facing-twelve-level-policy";
const source_boundary_suffix = "-ci-twelve-level-application-boundary.json";
const output_prefix_suffix = "-ci-twelve-level-policy";
const compact_output_prefix_name = "app-facing-ci-twelve-level-policy";
```

- [x] **Step 4: Update required verification commands**

The required upstream command must be:

```zig
"zig build causal-app-facing-twelve-level-application-boundary -- --help",
```

- [x] **Step 5: Add direct twelve-level source fields**

Add these fields to `SourceApplicationArtifact`:

```zig
source_twelve_level_report: []const u8 = "",
source_twelve_level_report_schema: []const u8 = "",
source_twelve_level_report_status: []const u8 = "",
source_twelve_level_after_digest: []const u8 = "",
source_twelve_level_after_present: bool = false,
source_twelve_level_application_changes: []const []const u8 = &.{},
```

Keep the application-boundary path from `options.application_path`, and emit it
as `source_twelve_level_application_boundary`.

- [x] **Step 6: Require direct twelve-level source evidence**

Add a helper like:

```zig
fn sourceTwelveLevelRefsPresent(source: SourceApplicationArtifact) bool {
    return source.source_twelve_level_report.len > 0 and
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

Add JSON/text output for the direct source fields:

```text
source_twelve_level_application_boundary
source_twelve_level_application_boundary_schema
source_twelve_level_report
source_twelve_level_report_schema
source_twelve_level_report_status
source_twelve_level_after_digest
source_twelve_level_after_present
source_twelve_level_application_changes
```

- [x] **Step 8: Update embedded fixtures and tests**

Update fixture schemas, status field names, required verification command
strings, and test expectations so approve is ready only for a twelve-level
application-boundary source with direct twelve-level fields.

- [x] **Step 9: Run focused test**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_twelve_level_policy.zig
```

Expected: all policy tests pass.

### Task 3: Build Wiring And Docs

**Files:**
- Modify: `packages/zigeffect/build.zig`
- Create: `packages/zigeffect/docs/app-facing-twelve-level-policy.md`

- [x] **Step 1: Add build module, executable, run step, and tests**

Insert the twelve-level policy build block immediately after the twelve-level
application-boundary block:

```zig
const causal_app_facing_twelve_level_policy_tool_module = b.createModule(.{
    .root_source_file = b.path("tools/causal_app_facing_twelve_level_policy.zig"),
    .target = target,
    .optimize = optimize,
});

const causal_app_facing_twelve_level_policy_tool = b.addExecutable(.{
    .name = "zigeffect-causal-app-facing-twelve-level-policy",
    .root_module = causal_app_facing_twelve_level_policy_tool_module,
});
const run_causal_app_facing_twelve_level_policy_tool = b.addRunArtifact(causal_app_facing_twelve_level_policy_tool);
if (b.args) |args| run_causal_app_facing_twelve_level_policy_tool.addArgs(args);
const causal_app_facing_twelve_level_policy_step = b.step("causal-app-facing-twelve-level-policy", "Record app-facing twelve-level policy evidence");
causal_app_facing_twelve_level_policy_step.dependOn(&run_causal_app_facing_twelve_level_policy_tool.step);

const causal_app_facing_twelve_level_policy_tool_tests = b.addTest(.{
    .name = "zigeffect-causal-app-facing-twelve-level-policy-tests",
    .root_module = causal_app_facing_twelve_level_policy_tool_module,
});
const run_causal_app_facing_twelve_level_policy_tool_tests = b.addRunArtifact(causal_app_facing_twelve_level_policy_tool_tests);
test_step.dependOn(&run_causal_app_facing_twelve_level_policy_tool_tests.step);
```

- [x] **Step 2: Add docs**

Write `packages/zigeffect/docs/app-facing-twelve-level-policy.md` with:

- consumed and emitted schemas
- approve and reject usage examples
- readiness gates
- denied authority claims
- SolidJS webui scope
- NenDB adapter-only future direction
- handoff to the twelve-level evaluator

- [x] **Step 3: Verify build help**

Run:

```bash
cd packages/zigeffect
zig build causal-app-facing-twelve-level-policy -- --help
```

Expected: usage text for `causal-app-facing-twelve-level-policy`.

### Task 4: Governance, Backlog, And Roadmap

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [x] **Step 1: Register schema governance**

Add the twelve-level policy schema entry after the twelve-level
application-boundary schema. Increment the schema count tests by one and add
text/JSON assertions for the schema and emitting tool.

- [x] **Step 2: Update production backlog**

Change:

```zig
pub const recommendation = "start-app-facing-twelve-level-evaluator";
pub const recommended_next_branch = "codex/zigeffect-causal-app-facing-twelve-level-evaluator";
```

Add `app-facing-twelve-level-policy` after
`app-facing-twelve-level-application-boundary` with evidence sources for this
spec, plan, tool, and docs. Add approve/reject verification commands and test
assertions for the new id, branch, and build command.

- [x] **Step 3: Update master roadmap**

Mark item 112 as delivered and add item 113:

```markdown
113. `codex/zigeffect-causal-app-facing-twelve-level-evaluator`
   - Next: consume approved twelve-level policy evidence plus bounded request
     and support evidence, emit ready/advisory/blocked evaluator findings,
     preserve twelve/eleven/ten/nine lineage, keep no mutation authority, and
     hand ready or advisory evidence to the thirteen-level report branch.
```

- [x] **Step 4: Run focused governance tests**

Run:

```bash
cd packages/zigeffect
zig test --dep causal_artifact -Mroot=tools/causal_schema_governance.zig -Mcausal_artifact=tools/causal_artifact.zig
zig test tools/causal_production_hardening_backlog.zig
```

Expected: all tests pass.

### Task 5: Artifact Generation And Verification

**Files:**
- Generated: `.zig-cache/causal-artifacts/app-facing-ci-twelve-level-policy.json`
- Generated: `.zig-cache/causal-artifacts/app-facing-ci-twelve-level-policy.txt`
- Generated: `.zig-cache/causal-artifacts/app-facing-ci-twelve-level-policy-blocked.json`
- Generated: `.zig-cache/causal-artifacts/app-facing-ci-twelve-level-policy-blocked.txt`

- [x] **Step 1: Generate approved policy artifact**

Run:

```bash
cd packages/zigeffect
zig build causal-app-facing-twelve-level-policy -- \
  --from-application ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-application-boundary.json \
  approve \
  --reason "reviewed app-facing twelve-level policy" \
  --verified-command "bun run zigeffect:workbench:typecheck" \
  --verified-command "bun run zigeffect:workbench:test" \
  --verified-command "zig build causal-app-facing-twelve-level-application-boundary -- --help" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test" \
  --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-policy
```

Expected: output JSON has `ready_for_next_branch=true`,
`decision=approve`, and `next_branch_if_ready` set to
`codex/zigeffect-causal-app-facing-twelve-level-evaluator`.

- [x] **Step 2: Generate blocked policy artifact**

Run the same command against
`../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-application-boundary-blocked.json`
with `--out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-policy-blocked`.

Expected: output JSON has `ready_for_next_branch=false` and blocked policy
status.

- [x] **Step 3: Run full verification**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_twelve_level_policy.zig
zig build causal-app-facing-twelve-level-policy -- --help
zig test --dep causal_artifact -Mroot=tools/causal_schema_governance.zig -Mcausal_artifact=tools/causal_artifact.zig
zig test tools/causal_production_hardening_backlog.zig
zig build causal-schema-governance -- --format json > /tmp/zigeffect-schema-governance-twelve-policy.json 2>&1
zig build causal-production-hardening-backlog -- --format json > /tmp/zigeffect-production-backlog-twelve-policy.json 2>&1
zig build examples > /tmp/zigeffect-build-examples-twelve-policy.log 2>&1
zig build test > /tmp/zigeffect-build-test-twelve-policy.log 2>&1
cd ../..
bun run check > /tmp/yachdee-bun-check-twelve-policy.log 2>&1
bun run zig:test > /tmp/yachdee-bun-zig-test-twelve-policy.log 2>&1
git diff --check
```

Expected: every command exits 0.

- [x] **Step 4: Commit and merge checkpoint**

Run:

```bash
git add docs/superpowers packages/zigeffect
git commit -m "feat(zigeffect): add app-facing twelve-level policy"
git -C /Users/seanknowles/.config/superpowers/worktrees/yachdee/master-local-merge merge --ff-only codex/zigeffect-causal-app-facing-twelve-level-policy
git switch -c codex/zigeffect-causal-app-facing-twelve-level-evaluator
```

Expected: milestone commit exists, local master is fast-forwarded, and the
current branch is ready for the twelve-level evaluator milestone.
