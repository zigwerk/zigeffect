# zigeffect Causal Production Hardening Backlog Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a deterministic `causal-production-hardening-backlog` report that turns the M9 production-gap register into an ordered, machine-readable queue for future hardening branches.

**Architecture:** Add one Zig tool with embedded backlog records, text/JSON renderers, parse tests, and build-step wiring. Register the new schema with causal schema governance, then document the report and link it from README, operations, roadmap, and the master roadmap.

**Tech Stack:** Zig 0.16, existing zigeffect build tooling, Bun repo checks, markdown docs.

---

## File Structure

- Create: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
  - Owns schema constants, backlog item records, dependency order, text and JSON formatting, CLI option parsing, and focused unit tests.
- Create: `packages/zigeffect/docs/production-hardening-backlog.md`
  - Explains how to run and interpret the backlog report.
- Modify: `packages/zigeffect/build.zig`
  - Adds the executable, build step, and test registration.
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
  - Registers `zigeffect.causal.production-hardening-backlog.v1` as an operating-model schema and updates schema-count tests.
- Modify: `packages/zigeffect/docs/schema-governance.md`
  - Documents the new schema family.
- Modify: `packages/zigeffect/docs/operations.md`
  - Adds the backlog command after the M9 completion audit and points production gaps to this branch queue.
- Modify: `packages/zigeffect/docs/roadmap.md`
  - Marks the production-hardening backlog artifact as the next delivered operating-model hardening handoff.
- Modify: `packages/zigeffect/README.md`
  - Adds the command next to the M9 audit section.
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
  - Updates the immediate branch queue to point at the first hardening branch after backlog triage.

## Task 1: Add the Backlog Tool Test Skeleton

**Files:**
- Create: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`

- [ ] **Step 1: Write the initial failing tests**

Create `packages/zigeffect/tools/causal_production_hardening_backlog.zig` with this test-first skeleton:

```zig
const std = @import("std");

pub const production_hardening_backlog_schema = "zigeffect.causal.production-hardening-backlog.v1";
pub const production_hardening_backlog_schema_version: u32 = 1;
pub const recommendation = "start-production-artifact-aggregation";
pub const recommended_next_branch = "codex/zigeffect-causal-production-artifact-aggregation";

const OutputFormat = enum { text, json };

test "production hardening backlog constants preserve the branch boundary" {
    try std.testing.expectEqualStrings(
        "zigeffect.causal.production-hardening-backlog.v1",
        production_hardening_backlog_schema,
    );
    try std.testing.expectEqualStrings(
        "start-production-artifact-aggregation",
        recommendation,
    );
    try std.testing.expectEqualStrings(
        "codex/zigeffect-causal-production-artifact-aggregation",
        recommended_next_branch,
    );
}

test "production hardening backlog exposes branch-ready items" {
    try expectBacklogItem("production-artifact-aggregation");
    try expectBacklogItem("durable-production-retention");
    try expectBacklogItem("live-dashboard-streaming-workbench");
    try expectBacklogItem("production-capacity-planning");
}

test "production hardening backlog preserves user constraints" {
    try expectConstraint("durable storage direction: NenDB adapter only");
    try expectConstraint("workbench direction: SolidJS inside webui-dev/zig-webui");
    try expectNonGoal("Cockroach adapter work");
    try expectNonGoal("React workbench support");
    try expectNonGoal("production mutation authority");
}

test "production hardening backlog text mentions dependency order and next branch" {
    const allocator = std.testing.allocator;
    const report = try formatProductionHardeningBacklogText(allocator);
    defer allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "schema: zigeffect.causal.production-hardening-backlog.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "recommended next branch: codex/zigeffect-causal-production-artifact-aggregation") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "dependency order:") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "production-artifact-aggregation") != null);
}

test "production hardening backlog JSON is agent-readable" {
    const allocator = std.testing.allocator;
    const report = try formatProductionHardeningBacklogJson(allocator);
    defer allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.production-hardening-backlog.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"recommended_next_branch\": \"codex/zigeffect-causal-production-artifact-aggregation\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"global_constraints\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"backlog_items\"") != null);
}

test "production hardening backlog parses supported formats" {
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{"zigeffect-causal-production-hardening-backlog"}));
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{ "zigeffect-causal-production-hardening-backlog", "--format", "text" }));
    try std.testing.expectEqual(OutputFormat.json, try parseOptions(&.{ "zigeffect-causal-production-hardening-backlog", "--format", "json" }));
    try std.testing.expectError(error.UnknownFormat, parseOptions(&.{ "zigeffect-causal-production-hardening-backlog", "--format", "yaml" }));
    try std.testing.expectError(error.MissingFormat, parseOptions(&.{ "zigeffect-causal-production-hardening-backlog", "--format" }));
    try std.testing.expectError(error.UnknownFlag, parseOptions(&.{ "zigeffect-causal-production-hardening-backlog", "--json" }));
}
```

- [ ] **Step 2: Run the package tests and confirm the test file fails to compile**

Run:

```sh
cd packages/zigeffect
zig build test
```

Expected: failure because `expectBacklogItem`, `expectConstraint`, `expectNonGoal`, `formatProductionHardeningBacklogText`, `formatProductionHardeningBacklogJson`, and `parseOptions` are not implemented.

## Task 2: Implement the Deterministic Tool

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`

- [ ] **Step 1: Add records, constants, and public accessors**

Add `BacklogItem`, `backlog_items`, `dependency_order`, `global_constraints`, `non_goals`, and `verification_commands`. Use these exact item ids in this order:

```zig
const dependency_order: []const []const u8 = &.{
    "production-artifact-aggregation",
    "durable-production-retention",
    "production-deployment-runbooks",
    "artifact-access-control",
    "encryption-at-rest-policy",
    "alerting-integrations",
    "live-dashboard-streaming-workbench",
    "rollout-automation-guardrails",
    "wall-clock-benchmark-baselines",
    "production-capacity-planning",
};
```

Each item must include a stable `branch` beginning with `codex/zigeffect-causal-`, sources pointing to the M9 audit or operations docs, and guidance that keeps production mutation authority out of this branch.

- [ ] **Step 2: Add text and JSON renderers**

Implement these functions with the same style as `causal_m9_completion_audit.zig`:

```zig
fn formatProductionHardeningBacklogText(allocator: std.mem.Allocator) ![]const u8
fn formatProductionHardeningBacklogJson(allocator: std.mem.Allocator) ![]const u8
fn appendJsonProperty(allocator: std.mem.Allocator, output: *std.ArrayList(u8), name: []const u8, value: []const u8, comma: bool) !void
fn appendStringArray(allocator: std.mem.Allocator, output: *std.ArrayList(u8), values: []const []const u8) !void
fn appendJsonString(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: []const u8) !void
```

The text report must include sections named `global constraints`, `non-goals`, `backlog items`, `dependency order`, and `verification commands`.

The JSON report must include fields named `schema`, `schema_version`, `status`, `generated_by`, `recommendation`, `recommended_next_branch`, `global_constraints`, `non_goals`, `backlog_items`, `dependency_order`, and `verification_commands`.

- [ ] **Step 3: Add CLI parsing and `main`**

Implement `usage`, `parseOptions`, `main`, and `failUsage` with the same supported formats as the M9 audit:

```zig
zig build causal-production-hardening-backlog
zig build causal-production-hardening-backlog -- --format text
zig build causal-production-hardening-backlog -- --format json
```

- [ ] **Step 4: Run the package tests and confirm the tool tests pass**

Run:

```sh
cd packages/zigeffect
zig build test
```

Expected: pass for `zigeffect-causal-production-hardening-backlog-tests` once the build step is wired in Task 3.

## Task 3: Wire the Build Step

**Files:**
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Add the executable and test registration**

Insert a module after `causal-m9-completion-audit`:

```zig
const causal_production_hardening_backlog_tool_module = b.createModule(.{
    .root_source_file = b.path("tools/causal_production_hardening_backlog.zig"),
    .target = target,
    .optimize = optimize,
});

const causal_production_hardening_backlog_tool = b.addExecutable(.{
    .name = "zigeffect-causal-production-hardening-backlog",
    .root_module = causal_production_hardening_backlog_tool_module,
});
const run_causal_production_hardening_backlog_tool = b.addRunArtifact(causal_production_hardening_backlog_tool);
if (b.args) |args| run_causal_production_hardening_backlog_tool.addArgs(args);
const causal_production_hardening_backlog_step = b.step("causal-production-hardening-backlog", "Print causal production-hardening backlog report");
causal_production_hardening_backlog_step.dependOn(&run_causal_production_hardening_backlog_tool.step);

const causal_production_hardening_backlog_tool_tests = b.addTest(.{
    .name = "zigeffect-causal-production-hardening-backlog-tests",
    .root_module = causal_production_hardening_backlog_tool_module,
});
const run_causal_production_hardening_backlog_tool_tests = b.addRunArtifact(causal_production_hardening_backlog_tool_tests);
test_step.dependOn(&run_causal_production_hardening_backlog_tool_tests.step);
```

- [ ] **Step 2: Run the new command in text and JSON mode**

Run:

```sh
cd packages/zigeffect
zig build causal-production-hardening-backlog
zig build causal-production-hardening-backlog -- --format json
```

Expected: both commands print the backlog report and exit 0.

## Task 4: Register Schema Governance

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/docs/schema-governance.md`

- [ ] **Step 1: Add the schema entry**

Add a `schema_entries` record:

```zig
.{
    .schema = "zigeffect.causal.production-hardening-backlog.v1",
    .version = 1,
    .category = "operating-model",
    .status = "current",
    .emitted_by = &.{"causal-production-hardening-backlog"},
    .consumed_by = &.{ "agents", "reviewers", "future hardening branch workers" },
    .compatibility = &.{"record-only"},
    .governance_requirements = &.{ "backlog report tests", "operations docs", "roadmap update" },
},
```

- [ ] **Step 2: Update schema governance tests**

Add `try expectSchema(entries, "zigeffect.causal.production-hardening-backlog.v1");`.

Increase the expected schema count by one.

Add a text and JSON formatting assertion that includes
`zigeffect.causal.production-hardening-backlog.v1`.

- [ ] **Step 3: Update schema governance docs**

Document the schema as an operating-model artifact emitted by
`causal-production-hardening-backlog`, consumed by agents and reviewers, and
governed as a record-only branch queue.

- [ ] **Step 4: Run governance**

Run:

```sh
cd packages/zigeffect
zig build causal-schema-governance
zig build causal-schema-governance -- --format json
```

Expected: both commands include `zigeffect.causal.production-hardening-backlog.v1` and exit 0.

## Task 5: Add User-Facing Docs

**Files:**
- Create: `packages/zigeffect/docs/production-hardening-backlog.md`
- Modify: `packages/zigeffect/docs/operations.md`
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Write the report docs**

Create `packages/zigeffect/docs/production-hardening-backlog.md` with sections:

```markdown
# zigeffect Causal Production Hardening Backlog

## Command

## What The Report Means

## Dependency Order

## Authority Boundaries

## Verification Suite
```

The docs must state that NenDB is the only durable adapter direction, SolidJS
inside `webui-dev/zig-webui` is the workbench path, and the report does not add
production mutation authority.

- [ ] **Step 2: Link the command from README and operations**

Add the command block:

```sh
cd packages/zigeffect
zig build causal-production-hardening-backlog
zig build causal-production-hardening-backlog -- --format json
```

Place it after the M9 completion audit section.

- [ ] **Step 3: Update roadmap references**

Update the zigeffect roadmap and master roadmap so the immediate queue advances
from the backlog branch to `codex/zigeffect-causal-production-artifact-aggregation`.

- [ ] **Step 4: Run markdown and whitespace checks**

Run:

```sh
git diff --check
```

Expected: no output.

## Task 6: Verify and Commit

**Files:**
- All files changed by Tasks 1-5

- [ ] **Step 1: Run targeted commands**

Run:

```sh
cd packages/zigeffect
zig build causal-production-hardening-backlog
zig build causal-production-hardening-backlog -- --format json
zig build causal-schema-governance
zig build causal-m9-completion-audit
zig build examples
zig build test
```

Expected: every command exits 0.

- [ ] **Step 2: Run repository checks**

Run:

```sh
bun run check
bun run zig:test
git diff --check
```

Expected: every command exits 0.

- [ ] **Step 3: Stage only intentional files**

Run:

```sh
git add packages/zigeffect/tools/causal_production_hardening_backlog.zig
git add packages/zigeffect/docs/production-hardening-backlog.md
git add packages/zigeffect/build.zig
git add packages/zigeffect/tools/causal_schema_governance.zig
git add packages/zigeffect/docs/schema-governance.md
git add packages/zigeffect/docs/operations.md
git add packages/zigeffect/docs/roadmap.md
git add packages/zigeffect/README.md
git add docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
```

Do not stage `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`; it is unrelated existing work.

- [ ] **Step 4: Commit implementation**

Run:

```sh
git commit -m "feat(zigeffect): add causal production hardening backlog"
```

Expected: commit succeeds on `codex/zigeffect-causal-production-hardening-backlog`.

## Plan Self-Review

- Every design requirement maps to a task above.
- No unresolved placeholders remain.
- Names match the selected schema, command, branch, and doc paths.
- The plan preserves NenDB-only durable direction, SolidJS plus `zig-webui`, and no production mutation authority.
