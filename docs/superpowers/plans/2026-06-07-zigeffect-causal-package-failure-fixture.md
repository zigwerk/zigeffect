# zigeffect Causal Package Failure Fixture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a controlled package-test failure fixture that proves zigeffect's causal command harness writes agent-readable artifacts when a package-shaped test command fails.

**Architecture:** Keep the real default `zig build test` healthy and causal-wrapped. Add a separate expected-failure scenario named `package-tests-failure-fixture` that runs one intentionally failing Zig test file, writes scenario-specific causal artifacts, and exits zero as a harness self-test because the failure is expected.

**Tech Stack:** Zig 0.16 build system, zigeffect causal command harness, `std.process.run`, `bun:test` repository scripts.

---

## Files

- Create: `packages/zigeffect/test/fixtures/causal_package_failure.zig`
- Modify: `packages/zigeffect/tools/causal_run.zig`
- Modify: `packages/zigeffect/build.zig`
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
- Modify: `packages/zigeffect/docs/causal-scenarios.md`
- Modify: `packages/zigeffect/docs/roadmap.md`

## Task 1: RED Scenario Tests

- [ ] **Step 1: Add failing scenario expectations**

In `packages/zigeffect/tools/causal_run.zig`, add this test near the existing
scenario registry tests:

```zig
test "package failure fixture scenario is registered as expected package failure" {
    const scenario = try scenarioByName("package-tests-failure-fixture");
    try std.testing.expectEqual(RuntimeSubsystem.package, scenario.owner);
    try std.testing.expectEqual(Expectation.expected_failure, scenario.expectation);
    try std.testing.expectEqual(ExpectedFindingsPolicy.expected_failure_command_emits_assertion, scenario.finding_policy);
    try std.testing.expect(argvContains(scenario.argv, "test/fixtures/causal_package_failure.zig"));

    const paths = try artifactPaths(std.testing.allocator, scenario.slug);
    defer paths.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-package-tests-failure-fixture.json",
        paths.json_path,
    );
}
```

Add this artifact-format test near the existing package-test failure artifact
test:

```zig
test "package failure fixture artifacts preserve fixture marker and next query" {
    const scenario = try scenarioByName("package-tests-failure-fixture");
    const artifacts = try buildFailureArtifacts(std.testing.allocator, scenario, .{
        .term = .{ .exited = 1 },
        .stdout = "",
        .stderr = "causal package failure fixture marker",
    });
    defer artifacts.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), artifacts.finding_count);
    try std.testing.expect(std.mem.indexOf(u8, artifacts.report, "program: zigeffect command: package-tests-failure-fixture") != null);
    try std.testing.expect(std.mem.indexOf(u8, artifacts.report, "finding event=3 kind=assertion_failure") != null);
    try std.testing.expect(std.mem.indexOf(u8, artifacts.report, "- causal.cause 3") != null);
    try std.testing.expect(std.mem.indexOf(u8, artifacts.json, "causal package failure fixture marker") != null);
}
```

- [ ] **Step 2: Verify RED**

Run:

```bash
cd packages/zigeffect && zig build examples
```

Expected: FAIL because `package-tests-failure-fixture` is not registered.

## Task 2: Add The Intentional Failure Fixture

- [ ] **Step 1: Create fixture file**

Create `packages/zigeffect/test/fixtures/causal_package_failure.zig`:

```zig
const std = @import("std");

test "causal package failure fixture intentionally fails" {
    std.debug.print("causal package failure fixture marker\n", .{});
    try std.testing.expectEqual(@as(u8, 1), @as(u8, 2));
}
```

- [ ] **Step 2: Verify the fixture fails directly**

Run:

```bash
cd packages/zigeffect && if zig test test/fixtures/causal_package_failure.zig; then echo "expected fixture to fail"; exit 1; else echo "fixture failed as expected"; fi
```

Expected: PASS as a shell assertion, printing `fixture failed as expected`.

## Task 3: Register The Scenario

- [ ] **Step 1: Add fixture argv**

In `packages/zigeffect/tools/causal_run.zig`, add:

```zig
const package_tests_failure_fixture_argv: []const []const u8 = &.{
    "zig",
    "test",
    "test/fixtures/causal_package_failure.zig",
    "--cache-dir",
    ".zig-cache/causal-run-package-failure-fixture-cache",
    "--global-cache-dir",
    ".zig-cache/causal-run-global-cache",
};
```

- [ ] **Step 2: Add scenario registry entry**

Add this scenario after `package-tests`:

```zig
.{
    .slug = "package-tests-failure-fixture",
    .label = "Package Tests Failure Fixture",
    .expectation = .expected_failure,
    .owner = .package,
    .purpose = "prove package-shaped test failures write causal command artifacts without breaking the real package gate",
    .finding_policy = .expected_failure_command_emits_assertion,
    .invariant_ids = package_test_invariants,
    .argv = package_tests_failure_fixture_argv,
},
```

- [ ] **Step 3: Verify GREEN**

Run:

```bash
cd packages/zigeffect && zig build examples
```

Expected: PASS, including the new scenario registry tests.

## Task 4: Add Build Step And Runtime Proof

- [ ] **Step 1: Verify the build step is absent**

Run:

```bash
cd packages/zigeffect && zig build causal-package-failure-fixture
```

Expected: FAIL with no step named `causal-package-failure-fixture`.

- [ ] **Step 2: Add the build step**

In `packages/zigeffect/build.zig`, after the `causal-capture-missing-service`
step, add:

```zig
const run_causal_package_failure_fixture_tool = b.addRunArtifact(causal_run_tool);
run_causal_package_failure_fixture_tool.addArg("package-tests-failure-fixture");
const causal_package_failure_fixture_step = b.step("causal-package-failure-fixture", "Capture causal artifacts for an intentional package-test failure fixture");
causal_package_failure_fixture_step.dependOn(&run_causal_package_failure_fixture_tool.step);
```

- [ ] **Step 3: Verify runtime artifact creation**

Run:

```bash
cd packages/zigeffect && zig build causal-package-failure-fixture
```

Expected: PASS because the scenario is an expected failure and it writes:

```text
.zig-cache/causal-artifacts/zigeffect-causal-package-tests-failure-fixture.txt
.zig-cache/causal-artifacts/zigeffect-causal-package-tests-failure-fixture.json
.zig-cache/causal-artifacts/zigeffect-causal-package-tests-failure-fixture.dot
```

## Task 5: Docs And Verification

- [ ] **Step 1: Update docs**

Update the README, agent guide, agent-observable runtime doc, causal scenarios
doc, and roadmap to describe:

- `zig build test` remains the real causal-wrapped package gate.
- `zig build test-raw` remains the unwrapped escape hatch.
- `zig build causal-package-failure-fixture` is a harness self-test that proves
  package-shaped failures produce causal artifacts without requiring the real
  package tests to fail.

- [ ] **Step 2: Run full verification**

Run:

```bash
cd packages/zigeffect && zig build examples
cd packages/zigeffect && zig build causal-package-failure-fixture
cd packages/zigeffect && zig build causal-query -- --file .zig-cache/causal-artifacts/zigeffect-causal-package-tests-failure-fixture.json cause 3
cd packages/zigeffect && zig build test --summary none
bun run zig:test
git diff --check
```

- [ ] **Step 3: Commit implementation**

Run:

```bash
git add docs/superpowers/plans/2026-06-07-zigeffect-causal-package-failure-fixture.md \
  packages/zigeffect/test/fixtures/causal_package_failure.zig \
  packages/zigeffect/tools/causal_run.zig \
  packages/zigeffect/build.zig \
  packages/zigeffect/README.md \
  packages/zigeffect/docs/agent-guide.md \
  packages/zigeffect/docs/agent-observable-runtime.md \
  packages/zigeffect/docs/causal-scenarios.md \
  packages/zigeffect/docs/roadmap.md
git commit -m "feat(zigeffect): add causal package failure fixture"
```

## Self-Review

- Spec coverage: This plan implements the follow-up named in the default test
  harness design: a controlled failing fixture that exercises the package-test
  failure artifact lane.
- Placeholder scan: No `TBD`, `TODO`, or vague implementation-only steps remain.
- Type consistency: The plan consistently uses `package-tests-failure-fixture`,
  `causal-package-failure-fixture`, and
  `test/fixtures/causal_package_failure.zig`.
