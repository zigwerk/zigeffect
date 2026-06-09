# zigeffect Causal Performance Budget Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a deterministic causal performance-budget report and release guidance for the M9 zigeffect causal operating model.

**Architecture:** Implement a small Zig report tool that inventories current causal overhead controls and verifies the constants that are stable enough for CI. Register the report as an official causal schema, document how agents and reviewers should use it, and update the roadmap so performance budget and release guidance are no longer vague M9 gaps.

**Tech Stack:** Zig 0.16 build steps and tests, existing zigeffect causal modules, SolidJS workbench docs hosted by `webui-dev/zig-webui`, Bun verification commands.

---

## Files And Responsibilities

- Create `packages/zigeffect/tools/causal_performance_budget.zig`
  - Owns `zigeffect.causal.performance-budget.v1`.
  - Provides text and JSON report formatting.
  - Checks runtime constants from `zigeffect` and workbench constants from `causal_workbench_session`.
  - Exposes tests for option parsing, budget count, text output, JSON output, and constant alignment.

- Modify `packages/zigeffect/build.zig`
  - Adds the `causal-performance-budget` executable step.
  - Adds tool tests to `zig build test`.
  - Imports `zigeffect` and `causal_workbench_session` into the new tool module.

- Modify `packages/zigeffect/tools/causal_schema_governance.zig`
  - Adds the new performance-budget schema entry.
  - Updates schema count expectations from 31 to 32.
  - Adds representative test expectations.

- Create `packages/zigeffect/docs/performance-budget.md`
  - Documents command usage, budget categories, release-note guidance, agent interpretation, SolidJS inside `webui-dev/zig-webui`, and non-goals.

- Modify `packages/zigeffect/README.md`
  - Links the performance budget command near schema governance and operating docs.

- Modify `packages/zigeffect/docs/operations.md`
  - Adds the command to the command map.
  - Replaces "performance budgets remain a production gap" with the remaining production gaps after this branch.

- Modify `packages/zigeffect/docs/schema-governance.md`
  - Adds the official schema entry under a new Operating Model section.

- Modify `packages/zigeffect/docs/roadmap.md`
  - Records the delivered performance-budget command and release guidance.

- Modify `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
  - Marks M9 performance budget and release template guidance as delivered.
  - Names the next M9 follow-up as a production-readiness completion audit rather than another performance branch.

## Task 1: Add The Failing Performance-Budget Tool Tests

**Files:**
- Create: `packages/zigeffect/tools/causal_performance_budget.zig`
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Create the tool file with tests that reference the target API**

Create `packages/zigeffect/tools/causal_performance_budget.zig` with this initial content:

```zig
const std = @import("std");
const fx = @import("zigeffect");
const workbench_session = @import("causal_workbench_session");

pub const performance_budget_schema = "zigeffect.causal.performance-budget.v1";
pub const performance_budget_schema_version: u32 = 1;

const OutputFormat = enum { text, json };

fn usage() []const u8 {
    return
        \\usage:
        \\  zig build causal-performance-budget
        \\  zig build causal-performance-budget -- --format text
        \\  zig build causal-performance-budget -- --format json
        \\
        \\formats:
        \\  --format text|json
        \\
    ;
}

fn parseOptions(args: []const []const u8) !OutputFormat {
    _ = args;
    return error.ExpectedRedFailure;
}

pub fn budgetEntries() []const BudgetEntry {
    return &.{};
}

const BudgetEntry = struct {
    id: []const u8,
    category: []const u8,
    description: []const u8,
    budget: []const u8,
    source: []const u8,
    check: []const u8,
    agent_guidance: []const u8,
};

fn formatPerformanceBudgetText(allocator: std.mem.Allocator) ![]const u8 {
    _ = allocator;
    return error.ExpectedRedFailure;
}

fn formatPerformanceBudgetJson(allocator: std.mem.Allocator) ![]const u8 {
    _ = allocator;
    return error.ExpectedRedFailure;
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const format = parseOptions(args) catch |err| failUsage(err);
    const report = switch (format) {
        .text => try formatPerformanceBudgetText(init.gpa),
        .json => try formatPerformanceBudgetJson(init.gpa),
    };
    defer init.gpa.free(report);

    std.debug.print("{s}", .{report});
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-performance-budget error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

test "performance budget usage names command and formats" {
    try std.testing.expect(std.mem.indexOf(u8, usage(), "causal-performance-budget") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage(), "--format text|json") != null);
    try std.testing.expectEqualStrings("zigeffect.causal.performance-budget.v1", performance_budget_schema);
}

test "performance budget inventory includes checked runtime constants" {
    try std.testing.expectEqual(@as(usize, 9), budgetEntries().len);
    try expectBudget("app-request-retention");
    try expectBudget("app-background-job-retention");
    try expectBudget("app-event-string-bound");
    try expectBudget("workbench-artifact-size");
}

test "performance budget constants align with runtime defaults" {
    try std.testing.expectEqual(@as(usize, 256), fx.default_request_max_events);
    try std.testing.expectEqual(@as(usize, 1024), fx.default_job_max_events);
    try std.testing.expectEqual(@as(usize, 256), fx.default_app_max_event_string_bytes);
    try std.testing.expectEqual(@as(usize, 4 * 1024 * 1024), workbench_session.max_artifact_bytes);
}

test "performance budget text report includes release checklist" {
    const report = try formatPerformanceBudgetText(std.testing.allocator);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect causal performance budget") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "schema: zigeffect.causal.performance-budget.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "app-request-retention") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "SolidJS renderer hosted by webui-dev/zig-webui") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "release checklist:") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-performance-budget -- --format json") != null);
}

test "performance budget json report is machine readable" {
    const report = try formatPerformanceBudgetJson(std.testing.allocator);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.performance-budget.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema_version\": 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-request-retention\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"verification_commands\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"non_goals\"") != null);
}

test "performance budget parses format options" {
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{"zigeffect-causal-performance-budget"}));
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{ "zigeffect-causal-performance-budget", "--format", "text" }));
    try std.testing.expectEqual(OutputFormat.json, try parseOptions(&.{ "zigeffect-causal-performance-budget", "--format", "json" }));
    try std.testing.expectError(error.UnknownFormat, parseOptions(&.{ "zigeffect-causal-performance-budget", "--format", "yaml" }));
    try std.testing.expectError(error.UnknownFlag, parseOptions(&.{ "zigeffect-causal-performance-budget", "--json" }));
}

fn expectBudget(id: []const u8) !void {
    for (budgetEntries()) |entry| {
        if (std.mem.eql(u8, entry.id, id)) return;
    }
    return error.MissingBudgetEntry;
}
```

- [ ] **Step 2: Wire the test module into `build.zig` with missing implementation still failing**

After the `causal_schema_governance_tool_tests` block in `packages/zigeffect/build.zig`, add:

```zig
    const causal_performance_budget_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_performance_budget.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_performance_budget_tool_module.addImport("zigeffect", zigeffect);
    causal_performance_budget_tool_module.addImport("causal_workbench_session", causal_workbench_session_tool_module);

    const causal_performance_budget_tool = b.addExecutable(.{
        .name = "zigeffect-causal-performance-budget",
        .root_module = causal_performance_budget_tool_module,
    });
    const run_causal_performance_budget_tool = b.addRunArtifact(causal_performance_budget_tool);
    if (b.args) |args| run_causal_performance_budget_tool.addArgs(args);
    const causal_performance_budget_step = b.step("causal-performance-budget", "Print causal instrumentation performance budget report");
    causal_performance_budget_step.dependOn(&run_causal_performance_budget_tool.step);

    const causal_performance_budget_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-performance-budget-tests",
        .root_module = causal_performance_budget_tool_module,
    });
    const run_causal_performance_budget_tool_tests = b.addRunArtifact(causal_performance_budget_tool_tests);
    test_step.dependOn(&run_causal_performance_budget_tool_tests.step);
```

Place this block after `causal_workbench_session_tool_module` exists, because it imports that module.

- [ ] **Step 3: Run the focused test and verify RED**

Run:

```sh
cd packages/zigeffect
zig build test
```

Expected: FAIL. The new tests should fail because `parseOptions`, `budgetEntries`, `formatPerformanceBudgetText`, and `formatPerformanceBudgetJson` are not implemented.

- [ ] **Step 4: Commit the failing test checkpoint only if the team wants red commits**

The preferred branch style in this repo has been green commits. Do not commit the RED checkpoint unless explicitly requested. Keep it as local evidence and proceed to Task 2.

## Task 2: Implement The Performance-Budget Report

**Files:**
- Modify: `packages/zigeffect/tools/causal_performance_budget.zig`

- [ ] **Step 1: Replace the stub with the budget model and formatters**

Implement these top-level arrays and helpers in `packages/zigeffect/tools/causal_performance_budget.zig`:

```zig
const verification_commands: []const []const u8 = &.{
    "cd packages/zigeffect",
    "zig build causal-performance-budget",
    "zig build causal-performance-budget -- --format json",
    "zig build causal-schema-governance",
    "zig build examples",
    "zig build test",
    "cd ../..",
    "bun run check",
    "bun run zig:test",
    "git diff --check",
};

const release_review: []const []const u8 = &.{
    "Document retained event count changes.",
    "Document event string bound or truncation changes.",
    "Document sampling behavior changes.",
    "Document backend emission or failure-posture changes.",
    "Document artifact schema, compatibility, or migration changes.",
    "Document workbench artifact-size, bridge, host, or renderer changes.",
    "Document CI upload glob or retention changes.",
};

const non_goals: []const []const u8 = &.{
    "wall-clock latency gates",
    "throughput benchmarks",
    "production capacity planning",
    "production dashboards",
    "alerting or paging",
    "RBAC or encryption-at-rest policy",
    "source or config mutation authority",
    "React workbench support",
    "Cockroach adapter work",
};
```

The final `budget_entries` should include exactly these ids:

```zig
const budget_entries: []const BudgetEntry = &.{
    .{
        .id = "default-store-retention",
        .category = "store-retention",
        .description = "Plain CausalStore remains unbounded unless callers opt into retention.",
        .budget = "max_events=unbounded",
        .source = "CausalStore.init",
        .check = "documented",
        .agent_guidance = "Use bounded options for request paths, long-running jobs, and CI probes.",
    },
    .{
        .id = "app-request-retention",
        .category = "store-retention",
        .description = "Default app request traces keep a bounded retained event set.",
        .budget = "max_events=256",
        .source = "fx.default_request_max_events",
        .check = "passed",
        .agent_guidance = "Treat dropped_events as incomplete retained evidence and cite oldest_retained_event_id.",
    },
    .{
        .id = "app-background-job-retention",
        .category = "store-retention",
        .description = "Default app background-job traces keep a larger bounded retained event set.",
        .budget = "max_events=1024",
        .source = "fx.default_job_max_events",
        .check = "passed",
        .agent_guidance = "Use job defaults for background work; tighten only with explicit evidence.",
    },
    .{
        .id = "app-event-string-bound",
        .category = "event-string-bounds",
        .description = "Default app traces bound event label, type, status, and detail strings.",
        .budget = "max_event_string_bytes=256",
        .source = "fx.default_app_max_event_string_bytes",
        .check = "passed",
        .agent_guidance = "Cite truncated_fields when reasoning depends on event payload text.",
    },
    .{
        .id = "observability-sampling",
        .category = "sampling",
        .description = "Sampling is opt-in and limited to log, metric, and span observability events.",
        .budget = "structural_events=unsampled",
        .source = "CausalStore.shouldRetainEvent",
        .check = "documented",
        .agent_guidance = "Do not assume sampled log, metric, or span evidence is complete.",
    },
    .{
        .id = "workbench-artifact-size",
        .category = "artifact-bounds",
        .description = "Workbench rejects selected artifacts above the bounded read limit before full read.",
        .budget = "max_artifact_bytes=4194304",
        .source = "causal_workbench_session.max_artifact_bytes",
        .check = "passed",
        .agent_guidance = "Split or query large artifacts before opening them in the local workbench.",
    },
    .{
        .id = "workbench-ui-host",
        .category = "workbench",
        .description = "Workbench UI is a SolidJS renderer hosted by webui-dev/zig-webui.",
        .budget = "renderer=SolidJS host=zig-webui mode=read-only",
        .source = "causal-workbench and package scripts",
        .check = "documented",
        .agent_guidance = "Keep workbench changes on the SolidJS plus zig-webui path unless a future adapter is justified.",
    },
    .{
        .id = "ci-artifact-retention",
        .category = "artifact-retention",
        .description = "CI uploads only causal text, JSON, and DOT artifacts for failed causal jobs.",
        .budget = "globs=*.txt,*.json,*.dot retention_days=14",
        .source = ".github/workflows/zigeffect-causal.yml",
        .check = "documented",
        .agent_guidance = "Do not upload the rest of .zig-cache; review artifacts for redaction before sharing.",
    },
    .{
        .id = "backend-sink-failure-posture",
        .category = "backend-sinks",
        .description = "Backend adapters are sinks; deterministic store writes remain authoritative.",
        .budget = "backend_failures=nonfatal failed_writes=reported",
        .source = "CausalStore.record and backend conformance tests",
        .check = "documented",
        .agent_guidance = "If failed_writes is nonzero, backend durability/export evidence is incomplete.",
    },
};
```

The formatter implementation must:

- preserve deterministic ordering;
- escape JSON strings with the same helper style as `causal_schema_governance.zig`;
- print the release checklist and non-goals in both text and JSON;
- return allocator-owned output from both formatters;
- reject `--format yaml`, bare `--format`, and unknown flags.

- [ ] **Step 2: Run focused tests and verify GREEN**

Run:

```sh
cd packages/zigeffect
zig build test
```

Expected: PASS.

- [ ] **Step 3: Run the new report manually**

Run:

```sh
cd packages/zigeffect
zig build causal-performance-budget
zig build causal-performance-budget -- --format json
```

Expected:

- text output contains `zigeffect causal performance budget`;
- JSON output contains `"schema": "zigeffect.causal.performance-budget.v1"`;
- both outputs include `app-request-retention`, `workbench-ui-host`, and `Cockroach adapter work`.

## Task 3: Register The Schema In Governance

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/docs/schema-governance.md`

- [ ] **Step 1: Add the schema-governance entry**

Add this entry to `schema_entries` in `packages/zigeffect/tools/causal_schema_governance.zig` near the workbench or governance entries:

```zig
    .{
        .schema = "zigeffect.causal.performance-budget.v1",
        .version = 1,
        .category = "operating-model",
        .status = "current",
        .emitted_by = &.{"causal-performance-budget"},
        .consumed_by = &.{ "agents", "reviewers", "CI docs" },
        .compatibility = &.{"record-only"},
        .governance_requirements = &.{ "budget report tests", "operations docs", "release guidance" },
    },
```

Update tests in the same file:

```zig
try std.testing.expectEqual(@as(usize, 32), entries.len);
try expectSchema(entries, "zigeffect.causal.performance-budget.v1");
```

Update text and JSON report tests from `schema count: 31` and `"schema_count": 31` to `32`.

- [ ] **Step 2: Update schema governance docs**

In `packages/zigeffect/docs/schema-governance.md`, add a new section after Workbench:

```md
### Operating Model

- `zigeffect.causal.performance-budget.v1`

The performance-budget report is a record-only operating-model artifact. It
names deterministic overhead budgets, release-review checks, and verification
commands for causal runtime changes. It is not a wall-clock benchmark, mutation
surface, production dashboard, or capacity plan.
```

- [ ] **Step 3: Verify schema governance**

Run:

```sh
cd packages/zigeffect
zig build causal-schema-governance
zig build causal-schema-governance -- --format json
zig build test
```

Expected: all commands pass, text report says `schema count: 32`, JSON report says `"schema_count": 32`.

## Task 4: Add Performance Budget Documentation

**Files:**
- Create: `packages/zigeffect/docs/performance-budget.md`
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/operations.md`

- [ ] **Step 1: Create the dedicated performance budget guide**

Create `packages/zigeffect/docs/performance-budget.md` with sections:

```md
# zigeffect Causal Performance Budget

## Command

## What The Budget Checks

## How Agents Should Read It

## Release Notes Checklist

## Workbench UI Direction

## Non-Goals
```

Include these exact command snippets:

```sh
cd packages/zigeffect
zig build causal-performance-budget
zig build causal-performance-budget -- --format json
```

Include this UI statement:

```md
The workbench UI direction is SolidJS inside `webui-dev/zig-webui`: SolidJS
renders the interface, Bun/Vite builds it, and Zig plus `zig-webui` host the
native window or local server through a bounded read-only bridge.
```

Include this release-note rule:

```md
Add a causal runtime release-note entry whenever a change alters retained event
count, event string bounds, sampling behavior, backend emission, artifact
schema compatibility, workbench artifact bounds, workbench bridge behavior, CI
artifact upload globs, or CI artifact retention.
```

- [ ] **Step 2: Link the command from README**

In `packages/zigeffect/README.md`, after the schema governance command block, add:

```md
Print the deterministic causal performance budget and release-review checklist:

```bash
cd packages/zigeffect
zig build causal-performance-budget
zig build causal-performance-budget -- --format json
```

The report uses schema `zigeffect.causal.performance-budget.v1` and lists the
current retention, string-bound, sampling, workbench, artifact-retention,
backend-sink, and release-note budgets. The full policy is in
[docs/performance-budget.md](docs/performance-budget.md).
```

- [ ] **Step 3: Update operations command map and production gaps**

In `packages/zigeffect/docs/operations.md`, add `zig build causal-performance-budget` and the JSON variant under the schema/workbench/backend command block.

Add a new section before Production Gaps:

```md
## Performance Budget And Release Review

Run the performance budget report before changing causal overhead surfaces:

```sh
cd packages/zigeffect
zig build causal-performance-budget
zig build causal-performance-budget -- --format json
```

The report is deterministic. It checks stable constants such as app request
retention, app background-job retention, app event string bounds, and the
workbench artifact read limit. It also records documented budgets for sampling,
CI artifact retention, backend sink failure posture, and the SolidJS inside
`webui-dev/zig-webui` workbench direction.

Add release notes whenever a causal runtime change alters retention, string
bounds, sampling, backend emission, artifact schemas, workbench bounds or
bridge behavior, CI upload globs, or CI retention.
```

In Production Gaps, replace `performance budgets, benchmarks, or capacity planning` with:

```md
- wall-clock benchmark baselines or gates;
- production capacity planning;
```

- [ ] **Step 4: Verify docs links and syntax**

Run:

```sh
rg -n "performance-budget|causal-performance-budget|performance-budget.v1" packages/zigeffect/README.md packages/zigeffect/docs
git diff --check
```

Expected: the new guide and all links are present; `git diff --check` passes.

## Task 5: Update Roadmaps

**Files:**
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Update zigeffect roadmap delivered list**

In `packages/zigeffect/docs/roadmap.md`, add a delivered causal runtime note:

```md
- Delivered: `causal-performance-budget` publishes
  `zigeffect.causal.performance-budget.v1` with deterministic overhead budgets,
  SolidJS plus `webui-dev/zig-webui` workbench posture, and release-review
  guidance for causal runtime changes.
```

- [ ] **Step 2: Update the master roadmap M9 row**

In `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`, change the M9 row to:

```md
| M9 Operating model | active | schema governance, operations docs, performance budget report, and release guidance exist | move to production-readiness completion audit |
```

Replace the immediate branch queue entry with:

```md
1. `codex/zigeffect-causal-m9-completion-audit`
   - Audit schema governance, operations docs, performance budget, release
     guidance, verification commands, and remaining production gaps before
     declaring the operating model complete.
```

- [ ] **Step 3: Verify roadmap references**

Run:

```sh
rg -n "M9 Operating model|causal-performance-budget|performance budget|release guidance|SolidJS|zig-webui" docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md packages/zigeffect/docs/roadmap.md
```

Expected: M9 points at completion audit, and the current branch is no longer listed as pending work.

## Task 6: Final Verification And Green Commit

**Files:**
- All modified files from Tasks 1 through 5

- [ ] **Step 1: Run focused report verification**

Run:

```sh
cd packages/zigeffect
zig build causal-performance-budget
zig build causal-performance-budget -- --format json
zig build causal-schema-governance
zig build causal-schema-governance -- --format json
```

Expected: all four commands pass; JSON outputs include their schema names and schema versions.

- [ ] **Step 2: Run package verification**

Run:

```sh
cd packages/zigeffect
zig build examples
zig build test
```

Expected: both commands pass.

- [ ] **Step 3: Run repository verification**

Run:

```sh
cd /Users/seanknowles/Desktop/Projects/yachdee
bun run check
bun run zig:test
git diff --check
```

Expected: all commands pass.

- [ ] **Step 4: Review git status**

Run:

```sh
git status --short --branch
```

Expected: modified files are only performance-budget branch files plus the pre-existing unrelated untracked durable roadmap file:

```text
?? docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md
```

Do not stage the unrelated untracked durable roadmap file.

- [ ] **Step 5: Commit implementation**

Run:

```sh
git add packages/zigeffect/tools/causal_performance_budget.zig \
  packages/zigeffect/build.zig \
  packages/zigeffect/tools/causal_schema_governance.zig \
  packages/zigeffect/docs/performance-budget.md \
  packages/zigeffect/README.md \
  packages/zigeffect/docs/operations.md \
  packages/zigeffect/docs/schema-governance.md \
  packages/zigeffect/docs/roadmap.md \
  docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
git commit -m "feat(zigeffect): add causal performance budget report"
```

Expected: commit succeeds.

## Completion Notes

After this plan is implemented, the long-running goal remains active. The next branch should be `codex/zigeffect-causal-m9-completion-audit`, focused on proving whether the whole M9 operating model is complete or whether additional production operating gaps need their own branches.
