# zigeffect Causal Dev Loop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `zig build causal-dev-loop -- baseline|after` so agents can capture and compare causal evidence around `zigeffect` runtime patches.

**Architecture:** Create a focused `causal_loop.zig` orchestrator that reuses the existing dogfood artifact builder, compare engine, and package-test scenario registry. Keep the loop as a two-phase local command: baseline captures before evidence, after captures after evidence and writes a comparison report.

**Tech Stack:** Zig 0.16, existing `causal_test.zig`, `causal_compare.zig`, `causal_run.zig`, `std.process.run`, `std.Io.Dir`.

---

## File Structure

- Create `packages/zigeffect/tools/causal_loop.zig`
  Owns dev-loop artifact paths, phase parsing, summary formatting, dogfood
  capture, package-test execution, compare report writing, CLI behavior, and
  tests.
- Modify `packages/zigeffect/build.zig`
  Adds `causal-dev-loop`, wires imports for existing causal tool modules, and
  includes loop tests in `examples`.
- Modify `packages/zigeffect/README.md`
  Documents the baseline/after loop command.
- Modify `packages/zigeffect/docs/agent-guide.md`
  Adds the recommended agent workflow.
- Modify `packages/zigeffect/docs/agent-observable-runtime.md`
  Updates Phase 0 with the first dev-loop command.
- Modify `packages/zigeffect/docs/causal-scenarios.md`
  Explains how the loop relates to scenarios and compare reports.
- Modify `docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md`
  Marks Milestone 7's first slice as delivered after implementation.

## Task 1: Add Red Dev-Loop Tests And Build Wiring

**Files:**

- Create `packages/zigeffect/tools/causal_loop.zig`
- Modify `packages/zigeffect/build.zig`

- [ ] **Step 1: Create test-first loop skeleton**

Create `packages/zigeffect/tools/causal_loop.zig` with imports, constants, and
tests that reference the desired API before implementation:

```zig
const std = @import("std");

test "dev loop paths are stable" {
    const paths = loopPaths();
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-before.json",
        paths.before_json_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-after.json",
        paths.after_json_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-compare.txt",
        paths.compare_report_path,
    );
}

test "baseline summary points to after phase" {
    const paths = loopPaths();
    const summary = try formatSummary(std.testing.allocator, .{
        .phase = .baseline,
        .dogfood_findings = 4,
        .package_status = .pass,
        .paths = paths,
        .compare_report = null,
    });
    defer std.testing.allocator.free(summary);

    try std.testing.expect(std.mem.indexOf(u8, summary, "zigeffect causal dev loop") != null);
    try std.testing.expect(std.mem.indexOf(u8, summary, "phase: baseline") != null);
    try std.testing.expect(std.mem.indexOf(u8, summary, "package-tests: pass") != null);
    try std.testing.expect(std.mem.indexOf(u8, summary, "next: zig build causal-dev-loop -- after") != null);
}

test "after summary includes compare path and query hints" {
    const paths = loopPaths();
    const summary = try formatSummary(std.testing.allocator, .{
        .phase = .after,
        .dogfood_findings = 4,
        .package_status = .pass,
        .paths = paths,
        .compare_report = "zigeffect causal compare report\nfinding delta: +0\n",
    });
    defer std.testing.allocator.free(summary);

    try std.testing.expect(std.mem.indexOf(u8, summary, "phase: after") != null);
    try std.testing.expect(std.mem.indexOf(u8, summary, "compare report: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-compare.txt") != null);
    try std.testing.expect(std.mem.indexOf(u8, summary, "zig build causal-query -- --file .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-after.json cause 3") != null);
}

test "package failure status exits nonzero" {
    try std.testing.expectEqual(@as(u8, 0), exitCodeForPackageStatus(.pass));
    try std.testing.expectEqual(@as(u8, 1), exitCodeForPackageStatus(.failure));
}
```

- [ ] **Step 2: Wire the build step**

In `packages/zigeffect/build.zig`, add a `causal_loop_tool_module` after the
existing causal run module. Import existing modules:

```zig
causal_loop_tool_module.addImport("causal_test", causal_test_tool_module);
causal_loop_tool_module.addImport("causal_compare", causal_compare_tool_module);
causal_loop_tool_module.addImport("causal_run", causal_run_tool_module);
```

Add executable, forwarded args, `causal-dev-loop` build step, tests, and include
the executable/tests in `examples_step`.

- [ ] **Step 3: Verify red**

Run:

```sh
cd packages/zigeffect && zig build examples
```

Expected: fail because `loopPaths`, `formatSummary`, and
`exitCodeForPackageStatus` are undefined.

## Task 2: Implement Pure Loop Formatting

**Files:**

- Modify `packages/zigeffect/tools/causal_loop.zig`

- [ ] **Step 1: Add loop types and paths**

Define:

```zig
const causal_test = @import("causal_test");

const Phase = enum { baseline, after };
const PackageStatus = enum { pass, failure };

const LoopPaths = struct {
    before_json_path: []const u8,
    after_json_path: []const u8,
    compare_report_path: []const u8,
};

const SummaryInput = struct {
    phase: Phase,
    dogfood_findings: usize,
    package_status: PackageStatus,
    paths: LoopPaths,
    compare_report: ?[]const u8,
};

fn loopPaths() LoopPaths {
    return .{
        .before_json_path = causal_test.artifact_dir ++ "/zigeffect-causal-dev-loop-before.json",
        .after_json_path = causal_test.artifact_dir ++ "/zigeffect-causal-dev-loop-after.json",
        .compare_report_path = causal_test.artifact_dir ++ "/zigeffect-causal-dev-loop-compare.txt",
    };
}
```

- [ ] **Step 2: Implement summary formatting**

Use `std.ArrayList(u8)` to format:

```txt
zigeffect causal dev loop
phase: baseline
dogfood findings: 4
before json: ...
package-tests: pass
next: zig build causal-dev-loop -- after
```

For after phase, include the compare report path and query hints.

- [ ] **Step 3: Implement exit policy**

```zig
fn exitCodeForPackageStatus(status: PackageStatus) u8 {
    return switch (status) {
        .pass => 0,
        .failure => 1,
    };
}
```

- [ ] **Step 4: Verify green for pure tests**

Run:

```sh
cd packages/zigeffect && zig build examples
```

Expected: pure tests pass once CLI stubs are present.

## Task 3: Implement Runtime Orchestration

**Files:**

- Modify `packages/zigeffect/tools/causal_loop.zig`

- [ ] **Step 1: Add artifact writing helpers**

Add helpers:

- `writeArtifact(io, path, contents)`;
- `captureDogfood(io, allocator, target_json_path)`;
- `writeCompareReport(io, allocator, paths)`.

`captureDogfood` should call `causal_test.buildDogfoodArtifacts`, write normal
dogfood artifacts, then write the same JSON to the target loop path.

- [ ] **Step 2: Add package-test runner**

Import `causal_run` and use:

```zig
const scenario = try causal_run.scenarioByName("package-tests");
```

Run `scenario.argv` through `std.process.run`. If it fails, call
`causal_run.buildFailureArtifacts`, write the returned text/JSON/DOT artifacts,
and return `.failure`.

- [ ] **Step 3: Add phase execution**

Add:

```zig
fn runBaseline(init: std.process.Init) !u8
fn runAfter(init: std.process.Init) !u8
```

`runBaseline` captures before JSON, runs package tests, prints the summary, and
returns the package-test exit code.

`runAfter` checks that before JSON exists, captures after JSON, writes the
compare report, runs package tests, prints the summary, and returns the
package-test exit code.

- [ ] **Step 4: Add CLI parsing**

`main` should accept exactly one phase argument:

```sh
zig build causal-dev-loop -- baseline
zig build causal-dev-loop -- after
```

Unknown or missing phases should print usage and exit `2`.

## Task 4: Update Documentation

**Files:**

- Modify `packages/zigeffect/README.md`
- Modify `packages/zigeffect/docs/agent-guide.md`
- Modify `packages/zigeffect/docs/agent-observable-runtime.md`
- Modify `packages/zigeffect/docs/causal-scenarios.md`
- Modify `docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md`

- [ ] **Step 1: Document the loop command**

Add:

```sh
zig build causal-dev-loop -- baseline
zig build causal-dev-loop -- after
```

Explain that baseline is run before a patch and after is run after the patch.

- [ ] **Step 2: Update roadmap**

Mark Milestone 7 as first dev-loop slice delivered, with remaining work for
scenario-specific before/after traces, query automation, and app-facing loops.

## Task 5: Verification And Commit

**Files:**

- All modified files.

- [ ] **Step 1: Run loop workflow**

Run:

```sh
cd packages/zigeffect && zig build causal-dev-loop -- baseline
cd packages/zigeffect && zig build causal-dev-loop -- after
```

Expected: both commands exit zero, after writes the compare report, and package
tests pass.

- [ ] **Step 2: Run broad verification**

Run:

```sh
cd packages/zigeffect && zig build test
cd packages/zigeffect && zig build examples
bun run zig:test
git diff --check
```

Expected: all pass.

- [ ] **Step 3: Commit**

Run:

```sh
git add docs/superpowers/specs/2026-06-07-zigeffect-causal-dev-loop-design.md docs/superpowers/plans/2026-06-07-zigeffect-causal-dev-loop.md docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md packages/zigeffect/tools/causal_loop.zig packages/zigeffect/build.zig packages/zigeffect/README.md packages/zigeffect/docs/agent-guide.md packages/zigeffect/docs/agent-observable-runtime.md packages/zigeffect/docs/causal-scenarios.md
git commit -m "feat(zigeffect): add causal development loop"
```

Expected: commit succeeds.

## Self-Review

- Spec coverage: The plan covers baseline, after, stable artifacts, compare
  report writing, package-test gating, docs, verification, and commit.
- Placeholder scan: No placeholder-only steps remain.
- Scope check: This is one cohesive Milestone 7 slice. Scenario-specific
  before/after traces and app-facing loops remain later work.
