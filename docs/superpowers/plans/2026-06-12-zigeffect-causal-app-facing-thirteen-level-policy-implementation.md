# Zigeffect App-Facing Thirteen-Level Policy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Build the thirteen-level app-facing policy tool that consumes applied thirteen-level application-boundary artifacts and hands approved evidence to the thirteen-level evaluator branch.

**Architecture:** Promote the verified twelve-level policy implementation into a thirteen-level alias, then add direct thirteen-level source application-boundary/report fields and preserve the richer twelve-level evaluator/policy/application/report lineage emitted by the source boundary. Keep the policy local, advisory, and non-mutating; approval requires applied source evidence plus required verification commands, while rejection and unsafe sources remain blocked evidence.

**Tech Stack:** Zig build tools and `zig test`, existing zigeffect causal schema governance and production-hardening backlog generators, Bun root verification commands.

---

### Task 1: Policy Tool RED Test

**Files:**
- Create: `packages/zigeffect/tools/causal_app_facing_thirteen_level_policy.zig`

- [x] **Step 1: Write the failing test shell**

Create a minimal Zig file that references the expected public constants before
the implementation exists:

```zig
const std = @import("std");

test "app-facing thirteen-level policy constants are stable" {
    try std.testing.expectEqualStrings(
        "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1",
        schema,
    );
    try std.testing.expectEqual(@as(u32, 1), schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-thirteen-level-policy", source_branch);
    try std.testing.expectEqualStrings("start-app-facing-thirteen-level-evaluator", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-thirteen-level-evaluator", next_branch_if_ready);
}
```

- [x] **Step 2: Run the test to verify RED**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_thirteen_level_policy.zig
```

Expected: FAIL with `use of undeclared identifier 'schema'`.

### Task 2: Promote The Twelve-Level Policy Tool

**Files:**
- Modify: `packages/zigeffect/tools/causal_app_facing_thirteen_level_policy.zig`

- [x] **Step 1: Replace the RED shell with the twelve-level implementation**

Copy `packages/zigeffect/tools/causal_app_facing_twelve_level_policy.zig` over
the thirteen-level file.

- [x] **Step 2: Apply mechanical alias promotion**

Replace:

```text
twelve-level -> thirteen-level
twelve level -> thirteen level
twelve_level -> thirteen_level
TwelveLevel -> ThirteenLevel
```

Do not mechanically rename carried source fields that must stay twelve-level,
such as `source_twelve_level_policy` and
`source_twelve_level_application_boundary`.

- [x] **Step 3: Set top-level constants**

Ensure the constants are exactly:

```zig
pub const schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1";
pub const schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-app-facing-thirteen-level-policy";
pub const recommendation = "start-app-facing-thirteen-level-evaluator";
pub const next_branch_if_ready = "codex/zigeffect-causal-app-facing-thirteen-level-evaluator";

const source_boundary_schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1";
const generated_by = "causal-app-facing-thirteen-level-policy";
const source_boundary_suffix = "-ci-thirteen-level-application-boundary.json";
const output_prefix_suffix = "-ci-thirteen-level-policy";
const compact_output_prefix_name = "app-facing-ci-thirteen-level-policy";
```

- [x] **Step 4: Update required verification commands**

The required upstream command must be:

```zig
"zig build causal-app-facing-thirteen-level-application-boundary -- --help",
```

- [x] **Step 5: Add direct thirteen-level source fields**

Add these fields to `SourceApplicationArtifact`:

```zig
source_thirteen_level_report: []const u8 = "",
source_thirteen_level_report_schema: []const u8 = "",
source_thirteen_level_report_status: []const u8 = "",
```

Emit the application-boundary path from `options.application_path` as
`source_thirteen_level_application_boundary` and emit source schema/status from
the parsed source artifact.

- [x] **Step 6: Preserve direct twelve-level source fields**

Ensure `SourceApplicationArtifact` keeps and emits:

```zig
source_twelve_level_evaluator: []const u8 = "",
source_twelve_level_evaluator_schema: []const u8 = "",
source_twelve_level_evaluator_status: []const u8 = "",
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

- [x] **Step 7: Require source evidence**

Update source gates so approval requires:

```text
source generated_by == causal-app-facing-thirteen-level-application-boundary
source mode == record-applied
source application status == applied
source applied == true
source ready_for_next_branch == true
source mutation_authority == record-only
source thirteen-level report status == ready
source twelve-level evaluator status == ready
source twelve-level policy status == ready
source twelve-level report status == ready
source twelve-level after evidence present
source application/report checks have no failures
source publication channels remain local-only
source authority flags remain disabled
```

- [x] **Step 8: Emit thirteen-level JSON and text fields**

Add JSON/text output for:

```text
source_thirteen_level_application_boundary
source_thirteen_level_application_boundary_schema
source_thirteen_level_application_boundary_status
source_thirteen_level_report
source_thirteen_level_report_schema
source_thirteen_level_report_status
source_thirteen_level_after_digest
source_thirteen_level_after_present
source_thirteen_level_application_changes
source_twelve_level_evaluator
source_twelve_level_evaluator_schema
source_twelve_level_evaluator_status
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

- [x] **Step 9: Update embedded fixtures and tests**

Update fixture schemas, status field names, required verification command
strings, and test expectations so approve is ready only for a thirteen-level
application-boundary source with direct thirteen-level and twelve-level fields.

- [x] **Step 10: Run focused test**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_thirteen_level_policy.zig
```

Expected: all policy tests pass.

### Task 3: Build Wiring And Docs

**Files:**
- Modify: `packages/zigeffect/build.zig`
- Create: `packages/zigeffect/docs/app-facing-thirteen-level-policy.md`

- [x] **Step 1: Add build module, executable, run step, and tests**

Insert the thirteen-level policy build block immediately after the
thirteen-level application-boundary block. The executable name must be
`zigeffect-causal-app-facing-thirteen-level-policy`, and the build step must be
`causal-app-facing-thirteen-level-policy`.

- [x] **Step 2: Add docs**

Write `packages/zigeffect/docs/app-facing-thirteen-level-policy.md` with
consumed and emitted schemas, approve/reject/blocked-source usage examples,
readiness gates, denied authority claims, SolidJS webui scope, NenDB adapter
only future direction, and handoff to the thirteen-level evaluator.

- [x] **Step 3: Verify build help**

Run:

```bash
cd packages/zigeffect
zig build causal-app-facing-thirteen-level-policy -- --help
```

Expected: usage text for `causal-app-facing-thirteen-level-policy`.

### Task 4: Governance, Backlog, And Roadmap

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [x] **Step 1: Register schema governance**

Add the thirteen-level policy schema entry after the thirteen-level
application-boundary schema. Increment schema count tests from 151 to 152 and
add text/JSON assertions for the schema and emitting tool.

- [x] **Step 2: Update production backlog**

Change:

```zig
pub const recommendation = "start-app-facing-thirteen-level-evaluator";
pub const recommended_next_branch = "codex/zigeffect-causal-app-facing-thirteen-level-evaluator";
```

Add `app-facing-thirteen-level-policy` after
`app-facing-thirteen-level-application-boundary` with evidence sources for this
spec, plan, tool, and docs. Add approve, reject, and blocked-source
verification commands and test assertions for the new id, branch, and build
command.

- [x] **Step 3: Update master roadmap**

Mark item 116 as delivered and add item 117:

```markdown
117. `codex/zigeffect-causal-app-facing-thirteen-level-evaluator`
   - Next: consume approved thirteen-level policy evidence plus bounded local
     request and support evidence, emit ready/advisory/blocked evaluator
     findings, preserve thirteen/twelve/eleven/ten/nine lineage, keep no
     mutation authority, and hand ready or advisory evidence to the
     fourteen-level report branch.
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
- Generated: `.zig-cache/causal-artifacts/app-facing-ci-thirteen-level-policy.json`
- Generated: `.zig-cache/causal-artifacts/app-facing-ci-thirteen-level-policy.txt`
- Generated: `.zig-cache/causal-artifacts/app-facing-ci-thirteen-level-policy-reject.json`
- Generated: `.zig-cache/causal-artifacts/app-facing-ci-thirteen-level-policy-reject.txt`
- Generated: `.zig-cache/causal-artifacts/app-facing-ci-thirteen-level-policy-blocked.json`
- Generated: `.zig-cache/causal-artifacts/app-facing-ci-thirteen-level-policy-blocked.txt`

- [x] **Step 1: Generate approved policy artifact**

Run:

```bash
cd packages/zigeffect
zig build causal-app-facing-thirteen-level-policy -- \
  --from-application ../../.zig-cache/causal-artifacts/app-facing-ci-thirteen-level-application-boundary.json \
  approve \
  --reason "reviewed app-facing thirteen-level policy" \
  --verified-command "bun run zigeffect:workbench:typecheck" \
  --verified-command "bun run zigeffect:workbench:test" \
  --verified-command "zig build causal-app-facing-thirteen-level-application-boundary -- --help" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test" \
  --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-thirteen-level-policy
```

Expected: output JSON has `ready_for_next_branch=true`, `decision=approve`,
and `next_branch_if_ready` set to
`codex/zigeffect-causal-app-facing-thirteen-level-evaluator`.

- [x] **Step 2: Generate rejected policy artifact**

Run the same command with `reject` and
`--out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-thirteen-level-policy-reject`.

Expected: output JSON has `ready_for_next_branch=false` and blocked policy
status.

- [x] **Step 3: Generate blocked-source policy artifact**

Run the approve command against
`../../.zig-cache/causal-artifacts/app-facing-ci-thirteen-level-application-boundary-blocked.json`
with `--out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-thirteen-level-policy-blocked`.

Expected: output JSON has `ready_for_next_branch=false`, blocked policy status,
and a failing source gate.

- [x] **Step 4: Run full verification**

Run:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_thirteen_level_policy.zig
zig build causal-app-facing-thirteen-level-policy -- --help
zig test --dep causal_artifact -Mroot=tools/causal_schema_governance.zig -Mcausal_artifact=tools/causal_artifact.zig
zig test tools/causal_production_hardening_backlog.zig
zig build causal-schema-governance -- --format json > /tmp/zigeffect-schema-governance-thirteen-policy.json 2>&1
zig build causal-production-hardening-backlog -- --format json > /tmp/zigeffect-production-backlog-thirteen-policy.json 2>&1
zig build examples > /tmp/zigeffect-build-examples-thirteen-policy.log 2>&1
zig build test > /tmp/zigeffect-build-test-thirteen-policy.log 2>&1
cd ../..
bun run check > /tmp/yachdee-bun-check-thirteen-policy.log 2>&1
bun run zig:test > /tmp/yachdee-bun-zig-test-thirteen-policy.log 2>&1
git diff --check
```

Expected: every command exits 0.

- [x] **Step 5: Commit and merge checkpoint**

Run:

```bash
git add docs/superpowers packages/zigeffect
git commit -m "feat(zigeffect): add app-facing thirteen-level policy"
git -C /Users/seanknowles/.config/superpowers/worktrees/yachdee/master-local-merge merge --ff-only codex/zigeffect-causal-app-facing-thirteen-level-policy
git switch -c codex/zigeffect-causal-app-facing-thirteen-level-evaluator
```

Expected: milestone commit exists, local master is fast-forwarded, and the
current branch is ready for the thirteen-level evaluator milestone.
