# zigeffect Causal Dogfood Harness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the first local self-improving development harness for `zigeffect` by wiring `zig build causal-test` to emit causal CI artifacts from a deterministic dogfood scenario.

**Architecture:** Add a focused Zig tool under `packages/zigeffect/tools/` that builds a `CausalStore`, records a stable diagnostic scenario, formats text/JSON/DOT artifacts with existing causal APIs, and writes them under `.zig-cache/causal-artifacts/`. Wire the tool into `packages/zigeffect/build.zig` as a tested executable and document the development-agent workflow.

**Tech Stack:** Zig stdlib, `zig build`, existing `zigeffect` causal APIs, Bun workspace scripts for top-level verification.

---

## File Structure

- Create: `packages/zigeffect/tools/causal_test.zig`
  Owns the dogfood scenario, artifact rendering helpers, artifact path
  constants, file-writing helper, executable `main`, and tests for the harness.
- Modify: `packages/zigeffect/build.zig`
  Adds the `zigeffect-causal-test` executable, its tests, the `causal-test`
  build step, and includes harness tests in the existing `examples` aggregate.
- Modify: `packages/zigeffect/docs/agent-guide.md`
  Documents how agents run the dogfood harness and inspect artifacts.
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
  Adds the Phase 0 dogfood lane to the causal runtime documentation.
- Modify: `packages/zigeffect/README.md`
  Adds the command to the public package command list.

## Task 1: Write The Harness Contract Tests

**Files:**
- Create: `packages/zigeffect/tools/causal_test.zig`

- [ ] **Step 1: Run the missing build step as the first red check**

Run:

```sh
cd packages/zigeffect && zig build causal-test
```

Expected: fail with an unknown build step. This proves the package has no
dogfood harness command yet.

- [ ] **Step 2: Write contract tests for artifact paths and content**

Create `packages/zigeffect/tools/causal_test.zig` with tests and declarations
that describe the desired API before implementation:

```zig
const std = @import("std");
const fx = @import("zigeffect");

pub const ArtifactSet = struct {
    report_path: []const u8,
    json_path: []const u8,
    dot_path: []const u8,
    report: []const u8,
    json: []const u8,
    dot: []const u8,

    pub fn deinit(self: ArtifactSet, allocator: std.mem.Allocator) void {
        allocator.free(self.report);
        allocator.free(self.json);
        allocator.free(self.dot);
    }
};

pub fn buildDogfoodArtifacts(allocator: std.mem.Allocator) std.mem.Allocator.Error!ArtifactSet {
    _ = allocator;
    @compileError("buildDogfoodArtifacts is not implemented yet");
}

pub fn main() !void {
    @compileError("causal dogfood main is not implemented yet");
}

test "dogfood artifacts include report json dot and stable paths" {
    const artifacts = try buildDogfoodArtifacts(std.testing.allocator);
    defer artifacts.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dogfood.txt",
        artifacts.report_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dogfood.json",
        artifacts.json_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dogfood.dot",
        artifacts.dot_path,
    );
    try std.testing.expect(std.mem.indexOf(u8, artifacts.report, "zigeffect causal ci report") != null);
    try std.testing.expect(std.mem.indexOf(u8, artifacts.report, "program: zigeffect dogfood") != null);
    try std.testing.expect(std.mem.indexOf(u8, artifacts.report, "findings: 4") != null);
    try std.testing.expect(std.mem.indexOf(u8, artifacts.report, "causal.requirements") != null);
    try std.testing.expect(std.mem.indexOf(u8, artifacts.report, "causal.resources") != null);
    try std.testing.expect(std.mem.indexOf(u8, artifacts.report, "causal.fibers pending") != null);
    try std.testing.expect(std.mem.indexOf(u8, artifacts.report, "causal.retries") != null);
    try std.testing.expect(std.mem.indexOf(u8, artifacts.json, "\"kind\": \"service_required\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, artifacts.json, "\"kind\": \"resource_acquired\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, artifacts.dot, "digraph zigeffect_causal") != null);
    try std.testing.expect(std.mem.indexOf(u8, artifacts.dot, "event_1 -> event_2") != null);
}
```

- [ ] **Step 3: Wire only enough build plumbing to run the red test**

Temporarily add the `causal_test_tool_module`, `causal_test_tool`, `run_causal_test_tool`,
`causal_test_step`, `causal_test_tool_tests`, and `run_causal_test_tool_tests`
block described in Task 3. Do not implement `buildDogfoodArtifacts` yet.

- [ ] **Step 4: Run the red test**

Run:

```sh
cd packages/zigeffect && zig build causal-test
```

Expected: fail or compile-error because `buildDogfoodArtifacts` and `main` are
declared but not implemented.

## Task 2: Implement The Dogfood Artifact Builder

**Files:**
- Modify: `packages/zigeffect/tools/causal_test.zig`

- [ ] **Step 1: Replace compile errors with a deterministic causal scenario**

Implement constants, scenario recording, and artifact formatting:

```zig
pub const artifact_dir = ".zig-cache/causal-artifacts";
pub const report_path = artifact_dir ++ "/zigeffect-causal-dogfood.txt";
pub const json_path = artifact_dir ++ "/zigeffect-causal-dogfood.json";
pub const dot_path = artifact_dir ++ "/zigeffect-causal-dogfood.dot";

fn recordDogfoodScenario(store: *fx.CausalStore) std.mem.Allocator.Error!void {
    const run_id = store.nextRunId();
    const scope_id = store.nextScopeId();
    const run_started = try store.record(.{
        .kind = .run_started,
        .run_id = run_id,
        .label = "zigeffect dogfood",
        .type_name = "DogfoodHarness",
    });
    const scope_opened = try store.record(.{
        .kind = .scope_opened,
        .run_id = run_id,
        .parent_id = run_started,
        .scope_id = scope_id,
        .label = "dogfood scope",
        .status = "opened",
    });
    _ = try store.record(.{
        .kind = .service_required,
        .run_id = run_id,
        .parent_id = scope_opened,
        .label = "Config",
        .type_name = @typeName(fx.Config),
        .status = "missing",
        .redacted_detail = "missing provider for config descriptor",
    });
    _ = try store.record(.{
        .kind = .resource_acquired,
        .run_id = run_id,
        .parent_id = scope_opened,
        .scope_id = scope_id,
        .label = "dogfood database",
        .type_name = "DogfoodDatabaseConnection",
        .status = "success",
        .redacted_detail = "resource intentionally left open by fixture",
    });
    _ = try store.record(.{
        .kind = .fiber_forked,
        .run_id = run_id,
        .parent_id = scope_opened,
        .scope_id = scope_id,
        .fiber_id = 42,
        .label = "dogfood child fiber",
        .status = "pending",
    });
    _ = try store.record(.{
        .kind = .schedule_decision,
        .run_id = run_id,
        .parent_id = run_started,
        .label = "dogfood retry policy",
        .type_name = "Schedule.exponential",
        .status = "exhausted",
        .redacted_detail = "retry budget exhausted after deterministic fixture",
    });
    _ = try store.record(.{
        .kind = .scope_closed,
        .run_id = run_id,
        .parent_id = scope_opened,
        .scope_id = scope_id,
        .label = "dogfood scope",
        .status = "closed",
    });
    _ = try store.record(.{
        .kind = .exit_recorded,
        .run_id = run_id,
        .parent_id = run_started,
        .label = "dogfood exit",
        .type_name = "DogfoodFailure",
        .status = "failure",
        .redacted_detail = "fixture records failure for artifact analysis",
    });
}
```

- [ ] **Step 2: Return owned artifact strings**

Implement `buildDogfoodArtifacts`:

```zig
pub fn buildDogfoodArtifacts(allocator: std.mem.Allocator) std.mem.Allocator.Error!ArtifactSet {
    var store = fx.CausalStore.init(allocator);
    defer store.deinit();

    try recordDogfoodScenario(&store);

    const report = try fx.formatCausalCiReport(allocator, "zigeffect dogfood", &store);
    errdefer allocator.free(report);
    const json = try fx.formatCausalJson(allocator, &store);
    errdefer allocator.free(json);
    const dot = try fx.formatCausalDot(allocator, &store);
    errdefer allocator.free(dot);

    return .{
        .report_path = report_path,
        .json_path = json_path,
        .dot_path = dot_path,
        .report = report,
        .json = json,
        .dot = dot,
    };
}
```

- [ ] **Step 3: Run the tool test directly once build wiring exists**

Run:

```sh
cd packages/zigeffect && zig build test
```

Expected after build wiring: PASS for the harness test and existing tests.

## Task 3: Wire The Build Step

**Files:**
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Keep the executable, test artifact, and run step**

After the `causal_report_tool` block, keep:

```zig
    const causal_test_tool_module = b.createModule(.{
        .root_source_file = b.path("tools/causal_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    causal_test_tool_module.addImport("zigeffect", zigeffect);

    const causal_test_tool = b.addExecutable(.{
        .name = "zigeffect-causal-test",
        .root_module = causal_test_tool_module,
    });
    const run_causal_test_tool = b.addRunArtifact(causal_test_tool);
    const causal_test_step = b.step("causal-test", "Run dogfood causal test harness and write artifacts");
    causal_test_step.dependOn(&run_causal_test_tool.step);

    const causal_test_tool_tests = b.addTest(.{
        .name = "zigeffect-causal-test-tests",
        .root_module = causal_test_tool_module,
    });
    const run_causal_test_tool_tests = b.addRunArtifact(causal_test_tool_tests);
```

Then add these dependencies to `examples_step`:

```zig
    examples_step.dependOn(&causal_test_tool.step);
    examples_step.dependOn(&run_causal_test_tool_tests.step);
```

- [ ] **Step 2: Verify the build step exists**

Run:

```sh
cd packages/zigeffect && zig build causal-test
```

Expected: the command runs the harness and attempts to write artifacts.

## Task 4: Write Artifact Files

**Files:**
- Modify: `packages/zigeffect/tools/causal_test.zig`

- [ ] **Step 1: Add file writing helpers**

Add:

```zig
fn writeArtifact(path: []const u8, contents: []const u8) !void {
    const slash = std.mem.lastIndexOfScalar(u8, path, '/') orelse return error.InvalidArtifactPath;
    try std.fs.cwd().makePath(path[0..slash]);
    const file = try std.fs.cwd().createFile(path, .{ .truncate = true });
    defer file.close();
    try file.writeAll(contents);
}

fn writeArtifacts(artifacts: ArtifactSet) !void {
    try writeArtifact(artifacts.report_path, artifacts.report);
    try writeArtifact(artifacts.json_path, artifacts.json);
    try writeArtifact(artifacts.dot_path, artifacts.dot);
}
```

- [ ] **Step 2: Implement `main`**

Replace `main` with:

```zig
pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const artifacts = try buildDogfoodArtifacts(allocator);
    defer artifacts.deinit(allocator);

    try writeArtifacts(artifacts);

    std.debug.print(
        "zigeffect causal dogfood artifacts written:\n- {s}\n- {s}\n- {s}\n",
        .{ artifacts.report_path, artifacts.json_path, artifacts.dot_path },
    );
}
```

- [ ] **Step 3: Verify artifacts are written**

Run:

```sh
cd packages/zigeffect && zig build causal-test
test -f .zig-cache/causal-artifacts/zigeffect-causal-dogfood.txt
test -f .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json
test -f .zig-cache/causal-artifacts/zigeffect-causal-dogfood.dot
```

Expected: all commands exit 0.

## Task 5: Document The Development Agent Workflow

**Files:**
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
- Modify: `packages/zigeffect/README.md`

- [ ] **Step 1: Add the agent workflow**

In `packages/zigeffect/docs/agent-guide.md`, add a short section named
`Causal Dogfood Harness` with:

```md
## Causal Dogfood Harness

Run the local dogfood harness before changing causal runtime behavior:

```sh
cd packages/zigeffect
zig build causal-test
```

The harness writes:

- `.zig-cache/causal-artifacts/zigeffect-causal-dogfood.txt`
- `.zig-cache/causal-artifacts/zigeffect-causal-dogfood.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dogfood.dot`

Use the text report for finding summaries and next-query suggestions. Use the
JSON artifact when citing event ids in a fix proposal. Use the DOT artifact when
checking graph shape.
```

- [ ] **Step 2: Add the Phase 0 lane**

In `packages/zigeffect/docs/agent-observable-runtime.md`, add a short section
named `Phase 0 Dogfood Lane` that points to `zig build causal-test` and explains
that this is the internal feedback loop for building the causal runtime.

- [ ] **Step 3: Add the command to README**

In `packages/zigeffect/README.md`, add `zig build causal-test` beside the other
local package commands.

## Task 6: Full Verification And Commit

**Files:**
- All modified files

- [ ] **Step 1: Run package verification**

Run:

```sh
cd packages/zigeffect && zig build causal-test
cd packages/zigeffect && zig build test
cd packages/zigeffect && zig build examples
```

Expected: all commands exit 0.

- [ ] **Step 2: Run top-level Zig verification**

Run:

```sh
bun run zig:test
```

Expected: `zigeffect:test` and `zgroach:test` both exit 0.

- [ ] **Step 3: Inspect git diff**

Run:

```sh
git diff -- docs/superpowers/specs/2026-06-07-zigeffect-causal-dogfood-harness-design.md docs/superpowers/plans/2026-06-07-zigeffect-causal-dogfood-harness.md packages/zigeffect/tools/causal_test.zig packages/zigeffect/build.zig packages/zigeffect/docs/agent-guide.md packages/zigeffect/docs/agent-observable-runtime.md packages/zigeffect/README.md
```

Expected: diff only contains the dogfood harness, docs, and build wiring.

- [ ] **Step 4: Commit**

Run:

```sh
git add docs/superpowers/specs/2026-06-07-zigeffect-causal-dogfood-harness-design.md docs/superpowers/plans/2026-06-07-zigeffect-causal-dogfood-harness.md packages/zigeffect/tools/causal_test.zig packages/zigeffect/build.zig packages/zigeffect/docs/agent-guide.md packages/zigeffect/docs/agent-observable-runtime.md packages/zigeffect/README.md
git commit -m "feat(zigeffect): add causal dogfood harness"
```

Expected: one commit on `codex/zigeffect-causal-dogfood-harness`.

## Plan Self-Review

- Spec coverage: Milestone 1 acceptance criteria map to Tasks 1 through 6.
- Placeholder scan: no `TBD` or open-ended implementation steps remain.
- Type consistency: `ArtifactSet`, `buildDogfoodArtifacts`, and artifact path
  names are used consistently.
- Scope check: real test failure capture, query helpers, before/after
  comparison, hardening, and app-facing agents remain future milestones.
