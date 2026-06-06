# zigeffect Causal Failure Capture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `zig build causal-check`, a first causal development check that writes dogfood artifacts and exits nonzero when findings exist.

**Architecture:** Reuse `packages/zigeffect/tools/causal_test.zig` for both artifact-only and failure-gated modes. Keep `causal-test` as the zero-exit probe, add `causal-check` as a build step that passes `--fail-on-findings`, and make the exit decision a pure tested helper.

**Tech Stack:** Zig build system, `std.process.Init`, `std.Io`, `CausalStore`, Bun repository scripts.

---

## File Structure

- Modify `packages/zigeffect/tools/causal_test.zig`
  Adds `ArtifactSet.finding_count`, `exitCodeForFindings`, CLI arg parsing, and
  tests for fail-on-findings behavior.
- Modify `packages/zigeffect/build.zig`
  Adds the `causal-check` build step using the existing causal test executable.
- Modify `packages/zigeffect/README.md`
  Documents `causal-check` beside `causal-test` and `causal-query`.
- Modify `packages/zigeffect/docs/agent-guide.md`
  Explains the agent workflow for non-failing artifact probes versus failing
  causal checks.
- Modify `packages/zigeffect/docs/agent-observable-runtime.md`
  Records the Phase 0 failure-gated lane and the next real test-wrapper step.

## Task 1: Add The Red Test For Finding Count And Exit Policy

**Files:**

- Modify: `packages/zigeffect/tools/causal_test.zig`

- [ ] **Step 1: Add test expectations before implementation**

In `packages/zigeffect/tools/causal_test.zig`, update the existing test and add
a new pure exit-policy test:

```zig
test "dogfood artifacts include report json dot and stable paths" {
    const artifacts = try buildDogfoodArtifacts(std.testing.allocator);
    defer artifacts.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 4), artifacts.finding_count);
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

test "fail-on-findings mode exits nonzero only when findings exist" {
    try std.testing.expectEqual(@as(u8, 0), exitCodeForFindings(0, false));
    try std.testing.expectEqual(@as(u8, 0), exitCodeForFindings(4, false));
    try std.testing.expectEqual(@as(u8, 0), exitCodeForFindings(0, true));
    try std.testing.expectEqual(@as(u8, 1), exitCodeForFindings(4, true));
}
```

- [ ] **Step 2: Run the focused red check**

Run:

```sh
cd packages/zigeffect && zig build examples
```

Expected: fail because `ArtifactSet` has no `finding_count` field and
`exitCodeForFindings` is not defined.

## Task 2: Implement Structured Finding Count And Exit Policy

**Files:**

- Modify: `packages/zigeffect/tools/causal_test.zig`

- [ ] **Step 1: Add finding count to `ArtifactSet`**

Change the struct to:

```zig
pub const ArtifactSet = struct {
    report_path: []const u8,
    json_path: []const u8,
    dot_path: []const u8,
    report: []const u8,
    json: []const u8,
    dot: []const u8,
    finding_count: usize,

    pub fn deinit(self: ArtifactSet, allocator: std.mem.Allocator) void {
        allocator.free(self.report);
        allocator.free(self.json);
        allocator.free(self.dot);
    }
};
```

- [ ] **Step 2: Compute the finding count before formatting artifacts**

In `buildDogfoodArtifacts`, insert finding extraction after recording the
scenario:

```zig
try recordDogfoodScenario(&store);

var findings = try store.findings(allocator);
defer findings.deinit();
const finding_count = findings.items.len;

const report = try fx.formatCausalCiReport(allocator, "zigeffect dogfood", &store);
```

Return the count:

```zig
return .{
    .report_path = report_path,
    .json_path = json_path,
    .dot_path = dot_path,
    .report = report,
    .json = json,
    .dot = dot,
    .finding_count = finding_count,
};
```

- [ ] **Step 3: Add the pure exit helper**

Add below `buildDogfoodArtifacts`:

```zig
pub fn exitCodeForFindings(finding_count: usize, fail_on_findings: bool) u8 {
    if (fail_on_findings and finding_count > 0) return 1;
    return 0;
}
```

- [ ] **Step 4: Run the focused green check**

Run:

```sh
cd packages/zigeffect && zig build examples
```

Expected: pass.

## Task 3: Add CLI Fail-On-Findings Mode

**Files:**

- Modify: `packages/zigeffect/tools/causal_test.zig`

- [ ] **Step 1: Replace `main` with an arg-aware version**

Replace:

```zig
pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var threaded: std.Io.Threaded = .init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    const artifacts = try buildDogfoodArtifacts(allocator);
    defer artifacts.deinit(allocator);

    try writeArtifacts(io, artifacts);

    std.debug.print(
        "zigeffect causal dogfood artifacts written:\n- {s}\n- {s}\n- {s}\n",
        .{ artifacts.report_path, artifacts.json_path, artifacts.dot_path },
    );
}
```

with:

```zig
fn usage() []const u8 {
    return "usage: zig build causal-test -- [--fail-on-findings]\n";
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const args = try init.minimal.args.toSlice(init.arena.allocator());

    var fail_on_findings = false;
    for (args[1..]) |arg| {
        if (std.mem.eql(u8, arg, "--fail-on-findings")) {
            fail_on_findings = true;
        } else {
            std.debug.print("causal-test error: unknown argument '{s}'\n{s}", .{ arg, usage() });
            std.process.exit(2);
        }
    }

    const artifacts = try buildDogfoodArtifacts(allocator);
    defer artifacts.deinit(allocator);

    try writeArtifacts(init.io, artifacts);

    std.debug.print(
        "zigeffect causal dogfood artifacts written:\n- {s}\n- {s}\n- {s}\nfindings: {d}\n",
        .{
            artifacts.report_path,
            artifacts.json_path,
            artifacts.dot_path,
            artifacts.finding_count,
        },
    );

    const exit_code = exitCodeForFindings(artifacts.finding_count, fail_on_findings);
    if (exit_code != 0) {
        std.debug.print("causal dogfood check failed: {d} findings detected\n", .{artifacts.finding_count});
        std.process.exit(exit_code);
    }
}
```

- [ ] **Step 2: Verify the default mode still succeeds**

Run:

```sh
cd packages/zigeffect && zig build causal-test
```

Expected: pass and print all three artifact paths plus `findings: 4`.

- [ ] **Step 3: Verify direct fail-on-findings mode fails after writing artifacts**

Run:

```sh
cd packages/zigeffect && if zig build causal-test -- --fail-on-findings; then echo "expected fail-on-findings to fail"; exit 1; else test -f .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json; fi
```

Expected: pass as a shell assertion because the Zig command exits nonzero and
the JSON artifact exists.

## Task 4: Add The `causal-check` Build Step

**Files:**

- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Verify the red build step**

Run:

```sh
cd packages/zigeffect && zig build causal-check
```

Expected: fail with `no step named 'causal-check'`.

- [ ] **Step 2: Add the build step**

After the existing `causal-test` step in `packages/zigeffect/build.zig`, add:

```zig
const run_causal_check_tool = b.addRunArtifact(causal_test_tool);
run_causal_check_tool.addArg("--fail-on-findings");
const causal_check_step = b.step("causal-check", "Run dogfood causal check and fail when findings exist");
causal_check_step.dependOn(&run_causal_check_tool.step);
```

Do not add `run_causal_check_tool.step` to `examples_step`.

- [ ] **Step 3: Verify `causal-check` fails intentionally and leaves artifacts**

Run:

```sh
cd packages/zigeffect && if zig build causal-check; then echo "expected causal-check to fail"; exit 1; else test -f .zig-cache/causal-artifacts/zigeffect-causal-dogfood.txt && test -f .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json && test -f .zig-cache/causal-artifacts/zigeffect-causal-dogfood.dot; fi
```

Expected: pass as a shell assertion because `causal-check` exits nonzero and
all three artifacts exist.

## Task 5: Update Agent Documentation

**Files:**

- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/agent-observable-runtime.md`

- [ ] **Step 1: Update README command docs**

In `packages/zigeffect/README.md`, after the `causal-test` section, add:

````md
Run the failure-gated causal dogfood check:

```bash
cd packages/zigeffect
zig build causal-check
```

`causal-check` writes the same artifacts as `causal-test`, then exits nonzero
when the dogfood fixture contains findings. Use it when a development or CI
agent should treat causal findings as actionable failures.
````

- [ ] **Step 2: Update the agent guide**

In `packages/zigeffect/docs/agent-guide.md`, after the causal artifact list,
add:

````md
Use the non-failing probe when you want evidence:

```sh
zig build causal-test
```

Use the failure-gated check when causal findings should fail the development
loop:

```sh
zig build causal-check
```

The check still writes artifacts before failing, so inspect the JSON with
`causal-query` instead of rerunning blindly.
````

- [ ] **Step 3: Update the observable runtime roadmap**

In `packages/zigeffect/docs/agent-observable-runtime.md`, extend the Phase 0
dogfood lane with:

```md
The companion `zig build causal-check` command runs the same dogfood scenario in
fail-on-findings mode. It writes artifacts first, then exits nonzero when
findings exist. This is the first development-agent gate; real failing-test
capture should reuse the same policy with scenario-specific artifact names.
```

- [ ] **Step 4: Run docs diff check**

Run:

```sh
git diff --check
```

Expected: no whitespace errors.

## Task 6: Full Verification And Commit

**Files:**

- All modified files.

- [ ] **Step 1: Run causal artifact generation**

Run:

```sh
cd packages/zigeffect && zig build causal-test
```

Expected: pass.

- [ ] **Step 2: Run failure-gated check assertion**

Run:

```sh
cd packages/zigeffect && if zig build causal-check; then echo "expected causal-check to fail"; exit 1; else echo "causal-check failed as expected"; fi
```

Expected: pass as a shell assertion and print `causal-check failed as expected`.

- [ ] **Step 3: Verify query helper still reads the artifact**

Run:

```sh
cd packages/zigeffect && zig build causal-query -- cause 3
```

Expected: pass and print a cause chain that includes event `3` and its parent
events.

- [ ] **Step 4: Run package tests**

Run:

```sh
cd packages/zigeffect && zig build test
```

Expected: pass.

- [ ] **Step 5: Run examples**

Run:

```sh
cd packages/zigeffect && zig build examples
```

Expected: pass.

- [ ] **Step 6: Run repository Zig test script**

Run:

```sh
bun run zig:test
```

Expected: pass.

- [ ] **Step 7: Check diff hygiene**

Run:

```sh
git diff --check
```

Expected: no output.

- [ ] **Step 8: Commit**

Run:

```sh
git add docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md docs/superpowers/specs/2026-06-07-zigeffect-causal-failure-capture-design.md docs/superpowers/plans/2026-06-07-zigeffect-causal-failure-capture.md packages/zigeffect/tools/causal_test.zig packages/zigeffect/build.zig packages/zigeffect/README.md packages/zigeffect/docs/agent-guide.md packages/zigeffect/docs/agent-observable-runtime.md
git commit -m "feat(zigeffect): add causal failure capture check"
```

Expected: commit succeeds.

## Self-Review

- Spec coverage: The plan maps every design goal to a task: structured finding
  count, pure exit policy, arg-aware CLI, build step, docs, and verification.
- Placeholder scan: No unfinished markers or underspecified implementation
  steps remain.
- Type consistency: The plan uses `finding_count` consistently in `ArtifactSet`,
  tests, output, and exit policy.
- Scope check: Real `zig build test` wrapping is intentionally deferred to the
  next milestone.
