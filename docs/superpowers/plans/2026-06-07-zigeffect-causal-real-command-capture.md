# zigeffect Causal Real Command Capture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Zig-native causal command harness that captures scenario-specific artifacts for real zigeffect command failures.

**Architecture:** Keep deterministic dogfood fixtures in `causal_test.zig` and add a focused `causal_run.zig` tool for command execution. The new tool owns scenario metadata, command execution with `std.process.run`, failure artifact generation through `CausalStore`, and build-step integration for compile-fail capture and package-test development runs.

**Tech Stack:** Zig 0.16, `std.process.run`, `std.process.Init`, `std.Io.Dir`, `CausalStore`, existing zigeffect build steps.

---

## File Structure

- Create `packages/zigeffect/tools/causal_run.zig`
  Owns scenario metadata, command execution, artifact building, path creation,
  and CLI behavior.
- Modify `packages/zigeffect/build.zig`
  Adds the `causal-run`, `causal-capture-missing-service`, and `causal-dev-test`
  steps.
- Modify `packages/zigeffect/src/services/causal.zig`
  Adds a finding for failed `assertion_recorded` events.
- Modify `packages/zigeffect/test/services_test.zig`
  Covers the new assertion-failure finding.
- Modify `packages/zigeffect/README.md`
  Documents the real command capture workflow.
- Modify `packages/zigeffect/docs/agent-guide.md`
  Explains when agents should use `causal-dev-test` and how to query artifacts.
- Modify `packages/zigeffect/docs/agent-observable-runtime.md`
  Updates Phase 0 with real command capture.

## Task 1: Add Failing Core Finding Test

**Files:**

- Modify `packages/zigeffect/test/services_test.zig`

- [ ] **Step 1: Add the failing test**

Append this test near the other causal finding tests:

```zig
test "causal findings surface failed assertions as agent-readable evidence" {
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    const run_id = store.nextRunId();
    _ = try store.record(.{
        .kind = .assertion_recorded,
        .run_id = run_id,
        .label = "missing-service-compile-fail",
        .type_name = "CommandExit",
        .status = "failure",
        .redacted_detail = "command exited with code 1",
    });

    var findings = try store.findings(std.testing.allocator);
    defer findings.deinit();

    try expectFinding(findings, .assertion_failure);
}
```

- [ ] **Step 2: Verify the red test**

Run:

```sh
cd packages/zigeffect && zig build test
```

Expected: fail because `CausalFindingKind.assertion_failure` does not exist.

## Task 2: Implement Assertion Failure Findings

**Files:**

- Modify `packages/zigeffect/src/services/causal.zig`

- [ ] **Step 1: Add the finding kind**

Add to `CausalFindingKind`:

```zig
assertion_failure,
```

- [ ] **Step 2: Extract assertion failure findings**

In `CausalStore.findings`, add:

```zig
.assertion_recorded => if (std.mem.eql(u8, event.status, "failure")) {
    try appendFinding(allocator, &output, .assertion_failure, event);
},
```

- [ ] **Step 3: Verify green**

Run:

```sh
cd packages/zigeffect && zig build test
```

Expected: pass.

## Task 3: Add Red Tool Tests For Scenario Metadata And Artifacts

**Files:**

- Create `packages/zigeffect/tools/causal_run.zig`
- Modify `packages/zigeffect/build.zig`

- [ ] **Step 1: Create `causal_run.zig` with tests that reference missing functions**

Create `packages/zigeffect/tools/causal_run.zig`:

```zig
const std = @import("std");
const fx = @import("zigeffect");

test "scenario artifact paths are stable and scenario-specific" {
    const paths = try artifactPaths(std.testing.allocator, "missing-service-compile-fail");
    defer paths.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-missing-service-compile-fail.txt",
        paths.report_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-missing-service-compile-fail.json",
        paths.json_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-missing-service-compile-fail.dot",
        paths.dot_path,
    );
}

test "failed command artifacts cite scenario command and assertion finding" {
    const scenario = try scenarioByName("missing-service-compile-fail");
    const artifacts = try buildFailureArtifacts(std.testing.allocator, scenario, .{
        .term = .{ .exited = 1 },
        .stdout = "",
        .stderr = "zigeffect service not found",
    });
    defer artifacts.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), artifacts.finding_count);
    try std.testing.expect(std.mem.indexOf(u8, artifacts.report, "program: zigeffect command: missing-service-compile-fail") != null);
    try std.testing.expect(std.mem.indexOf(u8, artifacts.report, "findings: 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, artifacts.report, "finding event=3 kind=assertion_failure") != null);
    try std.testing.expect(std.mem.indexOf(u8, artifacts.json, "\"kind\": \"assertion_recorded\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, artifacts.dot, "event_2 -> event_3") != null);
}
```

- [ ] **Step 2: Wire the tool tests into `build.zig`**

Add the module, executable, run step, and test artifact following the existing
`causal_query` pattern. The tests should be included in `examples_step`, but the
runtime command steps should not.

- [ ] **Step 3: Verify red**

Run:

```sh
cd packages/zigeffect && zig build examples
```

Expected: fail because `artifactPaths`, `scenarioByName`, and
`buildFailureArtifacts` are undefined.

## Task 4: Implement The Causal Run Tool

**Files:**

- Modify `packages/zigeffect/tools/causal_run.zig`

- [ ] **Step 1: Add scenario and artifact types**

Implement:

```zig
pub const artifact_dir = ".zig-cache/causal-artifacts";

pub const Expectation = enum {
    expected_pass,
    expected_failure,
};

pub const Scenario = struct {
    slug: []const u8,
    label: []const u8,
    expectation: Expectation,
    argv: []const []const u8,
};

pub const CommandResult = struct {
    term: std.process.Child.Term,
    stdout: []const u8,
    stderr: []const u8,
};
```

Add an `ArtifactPaths` struct with `deinit`, and a `CommandArtifacts` struct
with `deinit`.

- [ ] **Step 2: Add built-in scenarios**

Implement `scenarioByName` for:

- `missing-service-compile-fail`
- `package-tests`

Use `zig` as `argv[0]`.

- [ ] **Step 3: Add artifact path creation**

Implement:

```zig
pub fn artifactPaths(allocator: std.mem.Allocator, slug: []const u8) std.mem.Allocator.Error!ArtifactPaths
```

It returns the three scenario-specific paths.

- [ ] **Step 4: Add failure artifact generation**

Implement:

```zig
pub fn buildFailureArtifacts(
    allocator: std.mem.Allocator,
    scenario: Scenario,
    result: CommandResult,
) std.mem.Allocator.Error!CommandArtifacts
```

Record `run_started`, `effect_started`, `assertion_recorded`, and
`exit_recorded`, then format report, JSON, and DOT. Compute finding count from
`store.findings`.

- [ ] **Step 5: Add process execution and CLI**

Implement `main(init: std.process.Init) !void` so:

- unknown or missing scenarios print usage and exit `2`;
- command failures write artifacts;
- expected-failure command failures exit `0`;
- expected-pass command failures exit `1`;
- unexpected success for expected-failure scenarios writes artifacts and exits
  `1`;
- expected-pass command success exits `0` without writing failure artifacts.

- [ ] **Step 6: Verify green**

Run:

```sh
cd packages/zigeffect && zig build examples
```

Expected: pass.

## Task 5: Add Build Steps And Docs

**Files:**

- Modify `packages/zigeffect/build.zig`
- Modify `packages/zigeffect/README.md`
- Modify `packages/zigeffect/docs/agent-guide.md`
- Modify `packages/zigeffect/docs/agent-observable-runtime.md`

- [ ] **Step 1: Add build steps**

Add:

```zig
const run_causal_capture_missing_service_tool = b.addRunArtifact(causal_run_tool);
run_causal_capture_missing_service_tool.addArg("missing-service-compile-fail");
const causal_capture_missing_service_step = b.step("causal-capture-missing-service", "Capture causal artifacts for the missing-service compile-fail scenario");
causal_capture_missing_service_step.dependOn(&run_causal_capture_missing_service_tool.step);

const run_causal_dev_test_tool = b.addRunArtifact(causal_run_tool);
run_causal_dev_test_tool.addArg("package-tests");
const causal_dev_test_step = b.step("causal-dev-test", "Run zigeffect tests with causal failure capture");
causal_dev_test_step.dependOn(&run_causal_dev_test_tool.step);
```

- [ ] **Step 2: Update docs**

Document:

- `zig build causal-capture-missing-service`;
- `zig build causal-dev-test`;
- querying the missing-service artifact with `causal-query -- --file`.

## Task 6: Verification And Commit

**Files:**

- All modified files.

- [ ] **Step 1: Run compile-fail capture**

Run:

```sh
cd packages/zigeffect && zig build causal-capture-missing-service
```

Expected: exits zero and writes all three missing-service artifacts.

- [ ] **Step 2: Query the missing-service artifact**

Run:

```sh
cd packages/zigeffect && zig build causal-query -- --file .zig-cache/causal-artifacts/zigeffect-causal-missing-service-compile-fail.json cause 3
```

Expected: prints event `3` and its parent events.

- [ ] **Step 3: Run package-test causal dev harness**

Run:

```sh
cd packages/zigeffect && zig build causal-dev-test
```

Expected: exits zero while package tests are green.

- [ ] **Step 4: Run package verification**

Run:

```sh
cd packages/zigeffect && zig build test
cd packages/zigeffect && zig build examples
bun run zig:test
git diff --check
```

Expected: all commands pass.

- [ ] **Step 5: Commit**

Run:

```sh
git add docs/superpowers/specs/2026-06-07-zigeffect-causal-real-command-capture-design.md docs/superpowers/plans/2026-06-07-zigeffect-causal-real-command-capture.md packages/zigeffect/src/services/causal.zig packages/zigeffect/test/services_test.zig packages/zigeffect/tools/causal_run.zig packages/zigeffect/build.zig packages/zigeffect/README.md packages/zigeffect/docs/agent-guide.md packages/zigeffect/docs/agent-observable-runtime.md
git commit -m "feat(zigeffect): capture causal artifacts for real command failures"
```

Expected: commit succeeds.

## Self-Review

- Spec coverage: The plan covers scenario-specific paths, assertion failure
  findings, command failure artifacts, build steps, docs, and verification.
- Placeholder scan: No unfinished markers or underspecified implementation
  steps remain.
- Scope check: This implements the first real command failure-capture slice; a
  full scenario registry and before/after comparison remain later milestones.
