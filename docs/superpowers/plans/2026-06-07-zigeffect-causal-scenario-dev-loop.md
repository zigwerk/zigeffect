# zigeffect Scenario-Aware Causal Dev Loop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend `zig build causal-dev-loop -- baseline|after` with an optional scenario argument so agents can capture before/after causal evidence for a selected runtime scenario.

**Architecture:** Keep the existing dogfood loop as the default. Add scenario-targeted paths and execution to `causal_loop.zig`, and add a general command artifact builder to `causal_run.zig` so passing scenarios can emit comparable causal JSON artifacts.

**Tech Stack:** Zig 0.16, existing `causal_loop.zig`, `causal_run.zig`, `causal_compare.zig`, `std.process.run`, `std.Io.Dir`.

---

## File Structure

- Modify `packages/zigeffect/tools/causal_run.zig`
  Add `buildCommandArtifacts` for pass/failure command evidence and keep
  `buildFailureArtifacts` as a wrapper.
- Modify `packages/zigeffect/tools/causal_loop.zig`
  Add optional scenario target parsing, scenario loop paths, scenario status
  policy, scenario capture, and scenario-aware summaries.
- Modify `packages/zigeffect/README.md`
  Document optional scenario usage.
- Modify `packages/zigeffect/docs/agent-guide.md`
  Add targeted scenario loop workflow.
- Modify `packages/zigeffect/docs/agent-observable-runtime.md`
  Note that the loop now targets registered scenarios.
- Modify `packages/zigeffect/docs/causal-scenarios.md`
  Add scenario loop examples and artifact paths.
- Modify `docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md`
  Mark scenario-specific dev-loop traces as delivered.

## Task 1: Add Red Tests For Scenario Loop Paths And Status

**Files:**

- Modify `packages/zigeffect/tools/causal_loop.zig`
- Modify `packages/zigeffect/tools/causal_run.zig`

- [ ] **Step 1: Add failing loop tests**

Add tests to `causal_loop.zig` for:

```zig
test "scenario dev loop paths include scenario slug" {
    const paths = try loopPathsForScenario(std.testing.allocator, "causal-scoped-fiber");
    defer paths.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-before.json",
        paths.before_json_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-after.json",
        paths.after_json_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-compare.txt",
        paths.compare_report_path,
    );
}

test "scenario status treats expected failure as observed evidence" {
    const missing = try causal_run.scenarioByName("missing-service-compile-fail");
    const passing = try causal_run.scenarioByName("causal-scoped-fiber");

    try std.testing.expectEqual(ScenarioStatus.expected_failure_observed, scenarioStatusForTerm(missing, .{ .exited = 1 }));
    try std.testing.expectEqual(ScenarioStatus.failure, scenarioStatusForTerm(missing, .{ .exited = 0 }));
    try std.testing.expectEqual(ScenarioStatus.pass, scenarioStatusForTerm(passing, .{ .exited = 0 }));
    try std.testing.expectEqual(ScenarioStatus.failure, scenarioStatusForTerm(passing, .{ .exited = 1 }));
}
```

- [ ] **Step 2: Add failing command artifact test**

Add a test to `causal_run.zig`:

```zig
test "successful command artifacts record success with no findings" {
    const scenario = try scenarioByName("causal-scoped-fiber");
    const artifacts = try buildCommandArtifacts(std.testing.allocator, scenario, .{
        .term = .{ .exited = 0 },
        .stdout = "ok",
        .stderr = "",
    });
    defer artifacts.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 0), artifacts.finding_count);
    try std.testing.expect(std.mem.indexOf(u8, artifacts.report, "program: zigeffect command: causal-scoped-fiber") != null);
    try std.testing.expect(std.mem.indexOf(u8, artifacts.json, "\"status\": \"success\"") != null);
}
```

- [ ] **Step 3: Verify red**

Run:

```sh
cd packages/zigeffect && zig build examples
```

Expected: fail because the new functions and enum do not exist.

## Task 2: Add General Command Artifacts

**Files:**

- Modify `packages/zigeffect/tools/causal_run.zig`

- [ ] **Step 1: Implement `buildCommandArtifacts`**

Create `buildCommandArtifacts(allocator, scenario, result)` beside
`buildFailureArtifacts`. It should:

- record `run_started`;
- record `effect_started`;
- when the command failed, record `assertion_recorded` and failure
  `exit_recorded`;
- when the command passed, record success `exit_recorded`;
- format text, JSON, and DOT artifacts;
- return `CommandArtifacts`.

- [ ] **Step 2: Keep failure wrapper**

Change `buildFailureArtifacts` to:

```zig
pub fn buildFailureArtifacts(
    allocator: std.mem.Allocator,
    scenario: Scenario,
    result: CommandResult,
) std.mem.Allocator.Error!CommandArtifacts {
    return buildCommandArtifacts(allocator, scenario, result);
}
```

- [ ] **Step 3: Verify green for command artifact test**

Run:

```sh
cd packages/zigeffect && zig build examples
```

Expected: `causal_run` tests pass once loop tests are implemented or temporarily
still fail on loop-specific missing functions.

## Task 3: Implement Scenario Loop Paths, Status, And Summary

**Files:**

- Modify `packages/zigeffect/tools/causal_loop.zig`

- [ ] **Step 1: Add `ScenarioStatus`**

Define:

```zig
const ScenarioStatus = enum {
    pass,
    expected_failure_observed,
    failure,
};
```

- [ ] **Step 2: Make loop paths deinitializable**

Add `deinit` to `LoopPaths`, keep existing `loopPaths()` for static dogfood
paths, and add allocating `loopPathsForScenario(allocator, slug)`.

- [ ] **Step 3: Add status policy**

Implement:

```zig
fn scenarioStatusForTerm(scenario: causal_run.Scenario, term: std.process.Child.Term) ScenarioStatus
fn exitCodeForScenarioStatus(status: ScenarioStatus) u8
```

- [ ] **Step 4: Update summary input**

Add fields for optional scenario slug and scenario status. Summary output should
include scenario status when a scenario target is present, and the next command
should preserve the scenario argument.

- [ ] **Step 5: Verify pure tests**

Run:

```sh
cd packages/zigeffect && zig build examples
```

Expected: pure path/status/summary tests pass.

## Task 4: Implement Scenario Runtime Capture

**Files:**

- Modify `packages/zigeffect/tools/causal_loop.zig`

- [ ] **Step 1: Add scenario capture helper**

Add `captureScenario(io, allocator, scenario, target_json_path)` that runs the
scenario command, builds command artifacts with `causal_run.buildCommandArtifacts`,
writes normal scenario artifacts, writes the JSON to the loop target path, and
returns scenario status.

- [ ] **Step 2: Thread optional target through baseline and after**

Parse:

```sh
zig build causal-dev-loop -- baseline [scenario]
zig build causal-dev-loop -- after [scenario]
```

When no scenario is supplied, keep dogfood behavior. When a scenario is
supplied, use scenario capture and scenario loop paths.

- [ ] **Step 3: Preserve package gate**

Run package tests in both phases. If the selected scenario is `package-tests`,
reuse the selected scenario status as the package status instead of running it
twice.

- [ ] **Step 4: Verify scenario commands**

Run:

```sh
cd packages/zigeffect && zig build causal-dev-loop -- baseline causal-scoped-fiber
cd packages/zigeffect && zig build causal-dev-loop -- after causal-scoped-fiber
cd packages/zigeffect && zig build causal-dev-loop -- baseline missing-service-compile-fail
```

Expected: all exit zero. The missing-service command should report
`scenario status: expected_failure_observed`.

## Task 5: Update Docs, Verify, And Commit

**Files:**

- Modify docs listed in the file structure section.

- [ ] **Step 1: Document optional scenario usage**

Add examples:

```sh
zig build causal-dev-loop -- baseline causal-scoped-fiber
zig build causal-dev-loop -- after causal-scoped-fiber
```

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
git add docs/superpowers/specs/2026-06-07-zigeffect-causal-scenario-dev-loop-design.md docs/superpowers/plans/2026-06-07-zigeffect-causal-scenario-dev-loop.md docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md packages/zigeffect/tools/causal_run.zig packages/zigeffect/tools/causal_loop.zig packages/zigeffect/README.md packages/zigeffect/docs/agent-guide.md packages/zigeffect/docs/agent-observable-runtime.md packages/zigeffect/docs/causal-scenarios.md
git commit -m "feat(zigeffect): make causal dev loop scenario aware"
```

Expected: commit succeeds.

## Self-Review

- Spec coverage: The plan covers optional scenarios, stable paths, expected
  failure policy, command artifacts, docs, verification, and commit.
- Placeholder scan: No placeholder-only steps remain.
- Scope check: Automatic query selection remains a later Milestone 7 slice.
