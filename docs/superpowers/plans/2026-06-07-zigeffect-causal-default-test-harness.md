# zigeffect Causal Default Test Harness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the ordinary `zig build test` package gate run through zigeffect's causal command harness so package-test failures emit causal CI artifacts automatically.

**Architecture:** Keep the existing unit-test binary as a raw build step named `test-raw`. Point the `package-tests` causal scenario at `test-raw`, then make both `test` and `causal-dev-test` depend on the existing `causal_run package-tests` run artifact.

**Tech Stack:** Zig 0.16 build system, zigeffect causal command harness, Bun repository scripts.

---

## Files

- Modify: `packages/zigeffect/tools/causal_run.zig`
- Modify: `packages/zigeffect/build.zig`
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`
- Modify: `packages/zigeffect/docs/causal-scenarios.md`
- Modify: `packages/zigeffect/docs/roadmap.md`

## Task 1: RED Scenario Test

- [ ] **Step 1: Add package scenario argv test**

In `packages/zigeffect/tools/causal_run.zig`, add:

```zig
fn argvContains(args: []const []const u8, expected: []const u8) bool {
    for (args) |arg| {
        if (std.mem.eql(u8, arg, expected)) return true;
    }
    return false;
}

test "package test scenario targets raw package test step" {
    const scenario = try scenarioByName("package-tests");
    try std.testing.expect(argvContains(scenario.argv, "test-raw"));
    try std.testing.expect(!argvContains(scenario.argv, "test"));
}
```

- [ ] **Step 2: Verify RED**

Run:

```bash
cd packages/zigeffect && zig build examples
```

Expected: FAIL because the package-test scenario currently invokes `test`.

## Task 2: Build Step Wiring

- [ ] **Step 1: Add raw test step**

In `packages/zigeffect/build.zig`, replace the early `test` step with:

```zig
const raw_test_step = b.step("test-raw", "Run zigeffect tests without causal wrapping");
raw_test_step.dependOn(&run_unit_tests.step);
```

- [ ] **Step 2: Change package-tests argv**

In `packages/zigeffect/tools/causal_run.zig`, change:

```zig
"test",
```

to:

```zig
"test-raw",
```

inside `package_tests_argv`.

- [ ] **Step 3: Rewire `test` and `causal-dev-test`**

In `packages/zigeffect/build.zig`, after `causal_run_tool` is defined, create:

```zig
const run_causal_package_test_tool = b.addRunArtifact(causal_run_tool);
run_causal_package_test_tool.addArg("package-tests");

const test_step = b.step("test", "Run zigeffect tests with causal failure capture");
test_step.dependOn(&run_causal_package_test_tool.step);

const causal_dev_test_step = b.step("causal-dev-test", "Run zigeffect tests with causal failure capture");
causal_dev_test_step.dependOn(&run_causal_package_test_tool.step);
```

Remove the old `run_causal_dev_test_tool` block that separately adds
`package-tests`.

- [ ] **Step 4: Verify GREEN**

Run:

```bash
cd packages/zigeffect && zig build examples
```

Expected: PASS, including the updated `causal-run` tool test.

## Task 3: Docs

- [ ] **Step 1: Update README**

Document:

```markdown
`zig build test` is the normal package gate and now runs through causal failure
capture. Use `zig build test-raw` only when debugging the underlying Zig test
binary without the causal wrapper.
```

- [ ] **Step 2: Update agent docs**

Update `packages/zigeffect/docs/agent-guide.md`,
`packages/zigeffect/docs/agent-observable-runtime.md`, and
`packages/zigeffect/docs/causal-scenarios.md` with the same command split.

- [ ] **Step 3: Update roadmap**

Add:

```markdown
- Delivered: default `zig build test` now runs through the causal package-test
  harness, with `test-raw` kept as the unwrapped unit-test step.
```

## Task 4: Verification and Commit

- [ ] **Step 1: Run full verification**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary none
cd packages/zigeffect && zig build test --summary none
cd packages/zigeffect && zig build causal-dev-test
cd packages/zigeffect && zig build examples
bun run zig:test
cd packages/zigeffect && zig build causal-dev-loop -- baseline
cd packages/zigeffect && zig build causal-dev-loop -- after
git diff --check
```

- [ ] **Step 2: Commit implementation**

Run:

```bash
git add packages/zigeffect/tools/causal_run.zig \
  packages/zigeffect/build.zig \
  packages/zigeffect/README.md \
  packages/zigeffect/docs/agent-guide.md \
  packages/zigeffect/docs/agent-observable-runtime.md \
  packages/zigeffect/docs/causal-scenarios.md \
  packages/zigeffect/docs/roadmap.md
git commit -m "feat(zigeffect): run package tests through causal harness"
```

## Self-Review

- Spec coverage: The plan covers raw test step creation, default test wrapping,
  package scenario recursion avoidance, docs, and verification.
- Placeholder scan: No implementation placeholders remain.
- Type consistency: The plan consistently uses `test-raw`, `test`,
  `causal-dev-test`, and `package-tests`.
