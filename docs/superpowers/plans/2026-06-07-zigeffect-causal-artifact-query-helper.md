# zigeffect Causal Artifact Query Helper Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `zig build causal-query -- <query> [argument]` so agents can query saved `zigeffect` causal JSON artifacts during core development.

**Architecture:** Create a focused Zig tool that parses the current causal JSON artifact into typed structs, runs query filters over the event slice, and prints line-oriented event citations. Wire it into `packages/zigeffect/build.zig` with forwarded build args and include its tests in the package examples aggregate.

**Tech Stack:** Zig 0.16 stdlib, `std.json.parseFromSlice`, `std.process.Init`, `std.Io.Dir`, existing `zigeffect` build/tool patterns.

---

## File Structure

- Create: `packages/zigeffect/tools/causal_query.zig`
  Owns artifact parsing, query execution, output formatting, CLI parsing, and
  unit tests.
- Modify: `packages/zigeffect/build.zig`
  Adds `zigeffect-causal-query`, the `causal-query` build step, argument
  forwarding through `b.args`, and tests.
- Modify: `packages/zigeffect/docs/agent-guide.md`
  Documents how agents run the query helper after `causal-test`.
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
  Adds the artifact query helper to the CLI/tooling direction.
- Modify: `packages/zigeffect/README.md`
  Lists the new query command beside the dogfood harness.

## Task 1: Add Failing Query Tool Tests

**Files:**
- Create: `packages/zigeffect/tools/causal_query.zig`

- [ ] **Step 1: Create the contract tests**

Create `packages/zigeffect/tools/causal_query.zig` with the public test-facing
API and failing compile errors:

```zig
const std = @import("std");

pub const default_artifact_path = ".zig-cache/causal-artifacts/zigeffect-causal-dogfood.json";

const sample_json =
    \\{
    \\  "events": [
    \\    {
    \\      "id": 1,
    \\      "kind": "run_started",
    \\      "run_id": 1,
    \\      "parent_id": null,
    \\      "fiber_id": null,
    \\      "scope_id": null,
    \\      "trace_id": null,
    \\      "span_id": null,
    \\      "label": "zigeffect dogfood",
    \\      "type_name": "DogfoodHarness",
    \\      "status": "",
    \\      "redacted_detail": ""
    \\    },
    \\    {
    \\      "id": 2,
    \\      "kind": "scope_opened",
    \\      "run_id": 1,
    \\      "parent_id": 1,
    \\      "fiber_id": null,
    \\      "scope_id": 1,
    \\      "trace_id": null,
    \\      "span_id": null,
    \\      "label": "dogfood scope",
    \\      "type_name": "",
    \\      "status": "opened",
    \\      "redacted_detail": ""
    \\    },
    \\    {
    \\      "id": 3,
    \\      "kind": "service_required",
    \\      "run_id": 1,
    \\      "parent_id": 2,
    \\      "fiber_id": null,
    \\      "scope_id": null,
    \\      "trace_id": null,
    \\      "span_id": null,
    \\      "label": "Config",
    \\      "type_name": "services.config.Config",
    \\      "status": "missing",
    \\      "redacted_detail": "missing provider for config descriptor"
    \\    },
    \\    {
    \\      "id": 4,
    \\      "kind": "resource_acquired",
    \\      "run_id": 1,
    \\      "parent_id": 2,
    \\      "fiber_id": null,
    \\      "scope_id": 1,
    \\      "trace_id": null,
    \\      "span_id": null,
    \\      "label": "dogfood database",
    \\      "type_name": "DogfoodDatabaseConnection",
    \\      "status": "success",
    \\      "redacted_detail": "resource intentionally left open by fixture"
    \\    },
    \\    {
    \\      "id": 5,
    \\      "kind": "fiber_forked",
    \\      "run_id": 1,
    \\      "parent_id": 2,
    \\      "fiber_id": 42,
    \\      "scope_id": 1,
    \\      "trace_id": null,
    \\      "span_id": null,
    \\      "label": "dogfood child fiber",
    \\      "type_name": "",
    \\      "status": "pending",
    \\      "redacted_detail": ""
    \\    },
    \\    {
    \\      "id": 6,
    \\      "kind": "schedule_decision",
    \\      "run_id": 1,
    \\      "parent_id": 1,
    \\      "fiber_id": null,
    \\      "scope_id": null,
    \\      "trace_id": null,
    \\      "span_id": null,
    \\      "label": "dogfood retry policy",
    \\      "type_name": "Schedule.exponential",
    \\      "status": "exhausted",
    \\      "redacted_detail": "retry budget exhausted after deterministic fixture"
    \\    }
    \\  ]
    \\}
;

pub fn runQuery(allocator: std.mem.Allocator, json: []const u8, args: []const []const u8) ![]const u8 {
    _ = allocator;
    _ = json;
    _ = args;
    @compileError("runQuery is not implemented yet");
}

pub fn main(init: std.process.Init) !void {
    _ = init;
    @compileError("causal query main is not implemented yet");
}

test "snapshot query prints all events" {
    const output = try runQuery(std.testing.allocator, sample_json, &.{"snapshot"});
    defer std.testing.allocator.free(output);

    try std.testing.expect(std.mem.indexOf(u8, output, "causal.query: snapshot") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "events: 6") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "event id=1 kind=run_started") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "event id=6 kind=schedule_decision") != null);
}

test "cause query prints parent chain" {
    const output = try runQuery(std.testing.allocator, sample_json, &.{ "cause", "3" });
    defer std.testing.allocator.free(output);

    try std.testing.expect(std.mem.indexOf(u8, output, "events: 3") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "event id=1 kind=run_started") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "event id=2 kind=scope_opened") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "event id=3 kind=service_required") != null);
}

test "lineage query prints event and direct children" {
    const output = try runQuery(std.testing.allocator, sample_json, &.{ "lineage", "2" });
    defer std.testing.allocator.free(output);

    try std.testing.expect(std.mem.indexOf(u8, output, "events: 4") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "event id=2 kind=scope_opened") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "event id=3 kind=service_required") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "event id=4 kind=resource_acquired") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "event id=5 kind=fiber_forked") != null);
}

test "resource fiber requirement and retry queries filter events" {
    const resources = try runQuery(std.testing.allocator, sample_json, &.{ "resources", "1" });
    defer std.testing.allocator.free(resources);
    try std.testing.expect(std.mem.indexOf(u8, resources, "event id=4 kind=resource_acquired") != null);

    const fibers = try runQuery(std.testing.allocator, sample_json, &.{ "fibers", "pending" });
    defer std.testing.allocator.free(fibers);
    try std.testing.expect(std.mem.indexOf(u8, fibers, "event id=5 kind=fiber_forked") != null);

    const requirements = try runQuery(std.testing.allocator, sample_json, &.{ "requirements", "1" });
    defer std.testing.allocator.free(requirements);
    try std.testing.expect(std.mem.indexOf(u8, requirements, "event id=3 kind=service_required") != null);

    const retries = try runQuery(std.testing.allocator, sample_json, &.{ "retries", "1" });
    defer std.testing.allocator.free(retries);
    try std.testing.expect(std.mem.indexOf(u8, retries, "event id=6 kind=schedule_decision") != null);
}
```

- [ ] **Step 2: Run the missing build step as red check**

Run:

```sh
cd packages/zigeffect && zig build causal-query -- snapshot
```

Expected: fail with `no step named 'causal-query'`.

## Task 2: Wire The Build Step

**Files:**
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Add the executable, test artifact, and build step**

Add a `causal_query_tool_module` block after the causal test tool block:

```zig
    const causal_query_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_query.zig"),
        .target = target,
        .optimize = optimize,
    });

    const causal_query_tool = b.addExecutable(.{
        .name = "zigeffect-causal-query",
        .root_module = causal_query_tool_module,
    });
    const run_causal_query_tool = b.addRunArtifact(causal_query_tool);
    if (b.args) |args| run_causal_query_tool.addArgs(args);
    const causal_query_step = b.step("causal-query", "Query a saved causal JSON artifact");
    causal_query_step.dependOn(&run_causal_query_tool.step);

    const causal_query_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-query-tests",
        .root_module = causal_query_tool_module,
    });
    const run_causal_query_tool_tests = b.addRunArtifact(causal_query_tool_tests);
```

Then add these dependencies to `examples_step`:

```zig
    examples_step.dependOn(&causal_query_tool.step);
    examples_step.dependOn(&run_causal_query_tool_tests.step);
```

- [ ] **Step 2: Run the red tool compile**

Run:

```sh
cd packages/zigeffect && zig build causal-query -- snapshot
```

Expected: fail because `runQuery` and `main` are intentionally unimplemented.

## Task 3: Implement Query Logic

**Files:**
- Modify: `packages/zigeffect/tools/causal_query.zig`

- [ ] **Step 1: Define artifact and event structs**

Add:

```zig
const Artifact = struct {
    events: []Event,
};

const Event = struct {
    id: u64,
    kind: []const u8,
    run_id: ?u64,
    parent_id: ?u64,
    fiber_id: ?u64,
    scope_id: ?u64,
    trace_id: ?u64,
    span_id: ?u64,
    label: []const u8,
    type_name: []const u8,
    status: []const u8,
    redacted_detail: []const u8,
};
```

- [ ] **Step 2: Implement query parsing and formatting**

Implement `runQuery` by parsing `Artifact` with:

```zig
var parsed = try std.json.parseFromSlice(Artifact, allocator, json, .{ .ignore_unknown_fields = true });
defer parsed.deinit();
```

Then dispatch on `args[0]`:

- `snapshot`: all events
- `cause <id>`: recurse through `parent_id` to root, then print target
- `lineage <id>`: event where `id == target` plus events whose `parent_id == target`
- `resources <scope_id>`: resource events in scope
- `fibers <status>`: fiber lifecycle events with that status
- `requirements <run_id>`: `service_required` events in run
- `retries <run_id>`: `schedule_decision` events in run

Format output with a helper that prints:

```text
causal.query: <query>
events: <count>
- event id=<id> kind=<kind> run=<run?> scope=<scope?> fiber=<fiber?> label=<label?> type=<type?> status=<status?>
```

- [ ] **Step 3: Run tests green**

Run:

```sh
cd packages/zigeffect && zig build examples
```

Expected: query helper tests pass with existing examples and tools.

## Task 4: Implement CLI File Reading

**Files:**
- Modify: `packages/zigeffect/tools/causal_query.zig`

- [ ] **Step 1: Parse command arguments**

Implement `main(init: std.process.Init) !void`:

```zig
pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const query_args = args[1..];
    var file_path: []const u8 = default_artifact_path;
    var query_start: usize = 0;

    if (query_args.len >= 1 and std.mem.eql(u8, query_args[0], "--file")) {
        if (query_args.len < 3) return error.MissingFileArgument;
        file_path = query_args[1];
        query_start = 2;
    }

    const json = try std.Io.Dir.cwd().readFileAlloc(
        init.io,
        file_path,
        allocator,
        .limited(1024 * 1024),
    );
    defer allocator.free(json);

    const output = try runQuery(allocator, json, query_args[query_start..]);
    defer allocator.free(output);
    std.debug.print("{s}", .{output});
}
```

- [ ] **Step 2: Verify CLI against generated artifact**

Run:

```sh
cd packages/zigeffect && zig build causal-test
cd packages/zigeffect && zig build causal-query -- snapshot
cd packages/zigeffect && zig build causal-query -- cause 3
cd packages/zigeffect && zig build causal-query -- lineage 2
cd packages/zigeffect && zig build causal-query -- resources 1
cd packages/zigeffect && zig build causal-query -- fibers pending
cd packages/zigeffect && zig build causal-query -- requirements 1
cd packages/zigeffect && zig build causal-query -- retries 1
```

Expected: each query prints line-oriented events and exits 0.

## Task 5: Document The Query Workflow

**Files:**
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
- Modify: `packages/zigeffect/README.md`

- [ ] **Step 1: Add the agent query commands**

Add command examples beside the causal dogfood harness docs:

```md
After generating artifacts, follow next-query hints with:

```sh
zig build causal-query -- cause 3
zig build causal-query -- lineage 2
zig build causal-query -- resources 1
zig build causal-query -- fibers pending
zig build causal-query -- requirements 1
zig build causal-query -- retries 1
```

Use `--file <path>` to query a non-default artifact.
```

## Task 6: Verification And Commit

**Files:**
- All modified files

- [ ] **Step 1: Run verification**

Run:

```sh
cd packages/zigeffect && zig build causal-test
cd packages/zigeffect && zig build causal-query -- cause 3
cd packages/zigeffect && zig build test
cd packages/zigeffect && zig build examples
bun run zig:test
```

Expected: all commands exit 0.

- [ ] **Step 2: Commit**

Run:

```sh
git add docs/superpowers/specs/2026-06-07-zigeffect-causal-artifact-query-helper-design.md docs/superpowers/plans/2026-06-07-zigeffect-causal-artifact-query-helper.md packages/zigeffect/tools/causal_query.zig packages/zigeffect/build.zig packages/zigeffect/docs/agent-guide.md packages/zigeffect/docs/agent-observable-runtime.md packages/zigeffect/README.md
git commit -m "feat(zigeffect): add causal artifact query helper"
```

Expected: one commit on `codex/zigeffect-causal-dogfood-harness`.

## Plan Self-Review

- Spec coverage: query command, default artifact, supported query names, docs,
  and verification all map to explicit tasks.
- Placeholder scan: no unresolved placeholders remain.
- Type consistency: `Artifact`, `Event`, `runQuery`, and `default_artifact_path`
  are used consistently.
- Scope check: findings rematerialization, schema versioning, comparison, and
  live runtime queries remain future work.
