# zigeffect Causal Dev Loop Verdict Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `zig build causal-dev-loop -- after [scenario]` write a structured verdict JSON artifact, reusing the same formatter as CI handoff.

**Architecture:** Extract the verdict formatter from `tools/causal_handoff.zig` into a new `tools/causal_verdict.zig` module. Import that module into both handoff and dev-loop tools. Extend `LoopPaths` with a verdict path and write a dev-loop verdict after advice generation.

**Tech Stack:** Zig 0.16, existing causal artifact tools, existing dev-loop and CI handoff build steps, Bun test wrapper.

---

## Files

- Create: `packages/zigeffect/tools/causal_verdict.zig`
- Modify: `packages/zigeffect/tools/causal_handoff.zig`
- Modify: `packages/zigeffect/tools/causal_loop.zig`
- Modify: `packages/zigeffect/tools/causal_artifacts.zig`
- Modify: `packages/zigeffect/build.zig`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/causal-scenarios.md`
- Modify: `docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md`
- Modify: `packages/zigeffect/docs/roadmap.md`

## Task 1: Extract Shared Verdict Formatter

- [ ] **Step 1: Create the shared module by moving existing logic**

Create `packages/zigeffect/tools/causal_verdict.zig` with:

```zig
const std = @import("std");

pub const ArtifactVerdictInput = struct {
    json_path: []const u8,
    baseline_path: ?[]const u8 = null,
    advice_report_path: []const u8,
    compare_report_path: ?[]const u8 = null,
};
```

Move these existing helpers from `causal_handoff.zig` into the new module:

- `ActionCounts`;
- `countAdviceActions`;
- `addCounts`;
- `verdictStatus`;
- `verdictNextAction`;
- `appendJsonString`;
- `formatOptionalJsonString`;
- `formatCiVerdictJson`.

Rename `formatCiVerdictJson` to:

```zig
pub fn formatVerdictJson(
    allocator: std.mem.Allocator,
    schema: []const u8,
    artifacts: []const ArtifactVerdictInput,
    advice_reports: []const []const u8,
) ![]const u8
```

The output should use the supplied `schema`.

- [ ] **Step 2: Move tests into the new module**

Move the existing verdict tests from `causal_handoff.zig` into
`causal_verdict.zig`. Update test artifacts to use `ArtifactVerdictInput`.

- [ ] **Step 3: Update handoff to import the shared module**

In `packages/zigeffect/tools/causal_handoff.zig`, import:

```zig
const causal_verdict = @import("causal_verdict");
```

Replace the private `formatCiVerdictJson` call with:

```zig
const verdict = try causal_verdict.formatVerdictJson(
    allocator,
    "zigeffect.causal.ci-verdict.v1",
    try verdictInputsFromHandoffArtifacts(...),
    advice_reports.items,
);
```

Use a small helper to convert `[]const HandoffArtifact` into
`[]causal_verdict.ArtifactVerdictInput`.

- [ ] **Step 4: Verify GREEN**

Run:

```sh
cd packages/zigeffect && zig build examples
```

Expected: pass, proving extraction preserved CI behavior.

## Task 2: Wire Build Imports

- [ ] **Step 1: Add the verdict module in build.zig**

In `packages/zigeffect/build.zig`, after `causal_compare_tool_module`, add:

```zig
const causal_verdict_tool_module = b.createModule(.{
    .root_source_file = b.path("tools/causal_verdict.zig"),
    .target = target,
    .optimize = optimize,
});
```

Add imports:

```zig
causal_handoff_tool_module.addImport("causal_verdict", causal_verdict_tool_module);
causal_loop_tool_module.addImport("causal_verdict", causal_verdict_tool_module);
```

Add tests:

```zig
const causal_verdict_tool_tests = b.addTest(.{
    .name = "zigeffect-causal-verdict-tests",
    .root_module = causal_verdict_tool_module,
});
const run_causal_verdict_tool_tests = b.addRunArtifact(causal_verdict_tool_tests);
examples_step.dependOn(&run_causal_verdict_tool_tests.step);
```

- [ ] **Step 2: Verify build wiring**

Run:

```sh
cd packages/zigeffect && zig build examples
```

Expected: pass.

## Task 3: RED Local Dev Loop Verdict Paths

- [ ] **Step 1: Add failing path expectations**

In `packages/zigeffect/tools/causal_loop.zig`, extend the `dev loop paths are
stable` test to expect:

```text
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-verdict.json
```

Extend the `scenario dev loop paths include scenario slug` test to expect:

```text
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-verdict.json
```

Extend the after summary test to expect:

```text
verdict: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-verdict.json
next: inspect verdict
```

- [ ] **Step 2: Verify RED**

Run:

```sh
cd packages/zigeffect && zig build examples
```

Expected: fail because `LoopPaths` has no verdict path.

## Task 4: Implement Local Dev Loop Verdict

- [ ] **Step 1: Add verdict path to `LoopPaths`**

Add `verdict_report_path: []const u8` to `LoopPaths`, `loopPaths`, and
`loopPathsForScenario`. Free it in `LoopPaths.deinit` when owned.

- [ ] **Step 2: Update after summary**

In `formatSummary`, after `advice report`, print:

```text
verdict: <path>
```

Change after-phase next action to:

```text
next: inspect verdict
```

- [ ] **Step 3: Write verdict in `runAfter`**

After writing the advice report, call:

```zig
const inputs: []const causal_verdict.ArtifactVerdictInput = &.{
    .{
        .json_path = paths.after_json_path,
        .baseline_path = paths.before_json_path,
        .advice_report_path = paths.advice_report_path,
        .compare_report_path = paths.compare_report_path,
    },
};
const advice_reports: []const []const u8 = &.{advice_report};
const verdict = try causal_verdict.formatVerdictJson(
    allocator,
    "zigeffect.causal.dev-loop-verdict.v1",
    inputs,
    advice_reports,
);
defer allocator.free(verdict);
try writeArtifact(init.io, paths.verdict_report_path, verdict);
```

- [ ] **Step 4: Verify GREEN**

Run:

```sh
cd packages/zigeffect && zig build examples
```

Expected: pass.

## Task 5: Manifest And Docs

- [ ] **Step 1: Update artifact manifest**

In `packages/zigeffect/tools/causal_artifacts.zig`, list:

```text
- dev-loop verdict .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-verdict.json
loop verdict: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-verdict.json
```

Update manifest tests to expect default and scenario verdict paths.

- [ ] **Step 2: Update docs**

Update `packages/zigeffect/docs/agent-guide.md` and
`packages/zigeffect/docs/causal-scenarios.md` so local dev-loop instructions
say to read the verdict before advice/query/compare.

- [ ] **Step 3: Update roadmaps**

Record the local dev-loop verdict artifact in:

- `docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md`
- `packages/zigeffect/docs/roadmap.md`

## Task 6: Verification And Commit

- [ ] **Step 1: Run local dev-loop verdict verification**

Run:

```sh
(cd packages/zigeffect && rm -rf .zig-cache/causal-artifacts && zig build causal-dev-loop -- baseline && zig build causal-dev-loop -- after)
test -f packages/zigeffect/.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-verdict.json
rg "\"schema\": \"zigeffect.causal.dev-loop-verdict.v1\"" packages/zigeffect/.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-verdict.json
rg "\"persisting_actions\": 4" packages/zigeffect/.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-verdict.json
```

- [ ] **Step 2: Run scenario verdict verification**

Run:

```sh
(cd packages/zigeffect && rm -rf .zig-cache/causal-artifacts && zig build causal-dev-loop -- baseline causal-scoped-fiber && zig build causal-dev-loop -- after causal-scoped-fiber)
test -f packages/zigeffect/.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-verdict.json
rg "\"schema\": \"zigeffect.causal.dev-loop-verdict.v1\"" packages/zigeffect/.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-verdict.json
```

- [ ] **Step 3: Run full verification**

Run:

```sh
cd packages/zigeffect && zig build examples
cd packages/zigeffect && zig build test --summary none
git diff --check
bun run zig:test
```

- [ ] **Step 4: Commit**

Run:

```sh
git add packages/zigeffect/tools/causal_verdict.zig \
  packages/zigeffect/tools/causal_handoff.zig \
  packages/zigeffect/tools/causal_loop.zig \
  packages/zigeffect/tools/causal_artifacts.zig \
  packages/zigeffect/build.zig \
  packages/zigeffect/docs/agent-guide.md \
  packages/zigeffect/docs/causal-scenarios.md \
  docs/superpowers/specs/2026-06-07-zigeffect-causal-dev-loop-verdict-design.md \
  docs/superpowers/plans/2026-06-07-zigeffect-causal-dev-loop-verdict.md \
  docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md \
  packages/zigeffect/docs/roadmap.md
git commit -m "feat(zigeffect): add causal dev-loop verdict"
```

## Self-Review

- Spec coverage: The plan covers shared formatter extraction, local verdict
  paths, summary output, artifact generation, manifest/docs, verification, and
  commit.
- Placeholder scan: no placeholder-only instructions remain.
- Type consistency: artifact names, schema names, function names, and build
  module names are consistent across tasks.
