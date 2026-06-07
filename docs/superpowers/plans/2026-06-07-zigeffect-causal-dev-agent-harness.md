# zigeffect Causal Development Agent Harness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `zig build causal-dev-agent -- local [scenario]`, a local verdict reader that prints a deterministic development-agent inspection plan.

**Architecture:** Create a focused `tools/causal_dev_agent.zig` executable that reads the existing local dev-loop verdict JSON, validates it, derives query report paths, and formats a text-first plan. Wire the tool into `build.zig`, then update agent docs and roadmap notes.

**Tech Stack:** Zig 0.16 build system, Zig std JSON parser, existing `causal_run` scenario registry, Bun repo verification commands.

---

## File Structure

- Create `packages/zigeffect/tools/causal_dev_agent.zig`
  - CLI parsing for `local [scenario]`.
  - Verdict path derivation.
  - Verdict JSON parse/validation.
  - Query report path derivation.
  - Text report formatter.
  - Unit tests.
- Modify `packages/zigeffect/build.zig`
  - Add module, executable, run step, tests, and `examples` dependencies.
  - Import `causal_run` into the new tool module.
- Modify `packages/zigeffect/docs/agent-guide.md`
  - Add the local dev-agent command after the dev-loop after phase.
- Modify `packages/zigeffect/docs/causal-scenarios.md`
  - Add the command to the command list and development-loop section.
- Modify `docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md`
  - Mark the dev-agent harness slice as the next delivered part once complete.
- Modify `packages/zigeffect/docs/roadmap.md`
  - Add the harness to the agent-observable causal runtime delivered list once complete.

## Task 1: Add Tool Tests And Core Formatter

**Files:**
- Create: `packages/zigeffect/tools/causal_dev_agent.zig`

- [ ] **Step 1: Write the failing tests**

Create `packages/zigeffect/tools/causal_dev_agent.zig` with these tests and enough type declarations for the file to compile once implementation is added:

```zig
const std = @import("std");
const causal_run = @import("causal_run");

const supported_local_schema = "zigeffect.causal.dev-loop-verdict.v1";

const Verdict = struct {
    schema: []const u8,
    schema_version: u32,
    status: []const u8,
    next_action: []const u8,
    json_artifacts: usize,
    baseline_pairs: usize,
    actions: usize,
    new_actions: usize,
    persisting_actions: usize,
    observed_actions: usize,
    artifacts: []Artifact,
};

const Artifact = struct {
    json_path: []const u8,
    baseline_path: ?[]const u8,
    advice_report_path: []const u8,
    compare_report_path: ?[]const u8,
    actions: usize,
    new_actions: usize,
    persisting_actions: usize,
    observed_actions: usize,
};

test "local verdict path is stable for default target" {
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-verdict.json",
        localVerdictPath(null),
    );
}

test "scenario verdict path includes slug" {
    const path = try localVerdictPathForScenario(std.testing.allocator, "causal-scoped-fiber");
    defer std.testing.allocator.free(path);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-verdict.json",
        path,
    );
}

test "query report path is derived from after json" {
    const path = try queryReportPathForJson(std.testing.allocator, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-after.json");
    defer std.testing.allocator.free(path);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-queries.txt",
        path,
    );
}

test "query report path is derived from scenario after json" {
    const path = try queryReportPathForJson(std.testing.allocator, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-after.json");
    defer std.testing.allocator.free(path);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-queries.txt",
        path,
    );
}

test "local report prioritizes persisting advice from verdict" {
    const verdict = Verdict{
        .schema = supported_local_schema,
        .schema_version = 1,
        .status = "attention",
        .next_action = "inspect-persisting-advice",
        .json_artifacts = 1,
        .baseline_pairs = 1,
        .actions = 4,
        .new_actions = 0,
        .persisting_actions = 4,
        .observed_actions = 0,
        .artifacts = @constCast(&[_]Artifact{
            .{
                .json_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-after.json",
                .baseline_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-before.json",
                .advice_report_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-advice.txt",
                .compare_report_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-compare.txt",
                .actions = 4,
                .new_actions = 0,
                .persisting_actions = 4,
                .observed_actions = 0,
            },
        }),
    };
    const report = try formatLocalAgentReport(std.testing.allocator, .{
        .target = "dogfood",
        .verdict_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-verdict.json",
        .verdict = verdict,
    });
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect causal development agent") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "target: dogfood") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "next_action: inspect-persisting-advice") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "read advice report first; prioritize status=persisting actions") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "query report: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-queries.txt") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-compare -- .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-before.json .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-after.json") != null);
}

test "local report explains clear verdict" {
    const verdict = Verdict{
        .schema = supported_local_schema,
        .schema_version = 1,
        .status = "clear",
        .next_action = "none",
        .json_artifacts = 1,
        .baseline_pairs = 1,
        .actions = 0,
        .new_actions = 0,
        .persisting_actions = 0,
        .observed_actions = 0,
        .artifacts = @constCast(&[_]Artifact{
            .{
                .json_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-after.json",
                .baseline_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-before.json",
                .advice_report_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-advice.txt",
                .compare_report_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-compare.txt",
                .actions = 0,
                .new_actions = 0,
                .persisting_actions = 0,
                .observed_actions = 0,
            },
        }),
    };
    const report = try formatLocalAgentReport(std.testing.allocator, .{
        .target = "causal-scoped-fiber",
        .verdict_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-verdict.json",
        .verdict = verdict,
    });
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "status: clear") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "no advice actions; inspect compare report if the patch claims runtime behavior changed") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "rerun package tests before finalizing") != null);
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```sh
cd packages/zigeffect
zig build examples
```

Expected: FAIL because `causal_dev_agent.zig` is not wired into `build.zig`, or because helper functions such as `localVerdictPath` are missing after wiring.

- [ ] **Step 3: Add minimal implementation in `causal_dev_agent.zig`**

Add:

```zig
const LocalReportInput = struct {
    target: []const u8,
    verdict_path: []const u8,
    verdict: Verdict,
};

fn localVerdictPath(scenario_slug: ?[]const u8) []const u8 {
    if (scenario_slug != null) @panic("use localVerdictPathForScenario for owned scenario paths");
    return causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-verdict.json";
}

fn localVerdictPathForScenario(allocator: std.mem.Allocator, scenario_slug: []const u8) ![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "{s}/zigeffect-causal-dev-loop-{s}-verdict.json",
        .{ causal_run.artifact_dir, scenario_slug },
    );
}

fn queryReportPathForJson(allocator: std.mem.Allocator, json_path: []const u8) ![]const u8 {
    if (std.mem.endsWith(u8, json_path, "-after.json")) {
        return std.fmt.allocPrint(allocator, "{s}-queries.txt", .{json_path[0 .. json_path.len - "-after.json".len]});
    }
    if (!std.mem.endsWith(u8, json_path, ".json")) return error.InvalidVerdictArtifactPath;
    return std.fmt.allocPrint(allocator, "{s}-queries.txt", .{json_path[0 .. json_path.len - ".json".len]});
}

fn appendRecommendedOrder(allocator: std.mem.Allocator, output: *std.ArrayList(u8), verdict: Verdict) !void {
    try output.appendSlice(allocator, "recommended inspection order:\n");
    if (std.mem.eql(u8, verdict.next_action, "none") or verdict.actions == 0) {
        try output.appendSlice(allocator, "- no advice actions; inspect compare report if the patch claims runtime behavior changed\n");
        try output.appendSlice(allocator, "- read query report only if a specific event id needs citation\n");
        try output.appendSlice(allocator, "- rerun package tests before finalizing\n");
    } else if (std.mem.eql(u8, verdict.next_action, "inspect-new-advice")) {
        try output.appendSlice(allocator, "- read advice report first; prioritize status=new actions\n");
        try output.appendSlice(allocator, "- read query report for cited event ids\n");
        try output.appendSlice(allocator, "- read compare report before claiming behavior changed\n");
        try output.appendSlice(allocator, "- query JSON artifact for additional cause or lineage details\n");
    } else if (std.mem.eql(u8, verdict.next_action, "inspect-observed-advice")) {
        try output.appendSlice(allocator, "- read advice report first; prioritize status=observed actions\n");
        try output.appendSlice(allocator, "- read query report for cited event ids\n");
        try output.appendSlice(allocator, "- read compare report before claiming behavior changed\n");
        try output.appendSlice(allocator, "- query JSON artifact for additional cause or lineage details\n");
    } else {
        try output.appendSlice(allocator, "- read advice report first; prioritize status=persisting actions\n");
        try output.appendSlice(allocator, "- read query report for cited event ids\n");
        try output.appendSlice(allocator, "- read compare report before claiming behavior changed\n");
        try output.appendSlice(allocator, "- query JSON artifact for additional cause or lineage details\n");
    }
}
```

Then implement `formatLocalAgentReport`:

```zig
fn formatLocalAgentReport(allocator: std.mem.Allocator, input: LocalReportInput) ![]const u8 {
    if (!std.mem.eql(u8, input.verdict.schema, supported_local_schema)) return error.UnsupportedVerdictSchema;
    if (input.verdict.artifacts.len == 0) return error.EmptyVerdictArtifacts;

    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect causal development agent\n");
    try output.appendSlice(allocator, "mode: local\n");
    try output.print(allocator, "target: {s}\n", .{input.target});
    try output.print(allocator, "verdict: {s}\n", .{input.verdict_path});
    try output.print(allocator, "status: {s}\n", .{input.verdict.status});
    try output.print(allocator, "next_action: {s}\n", .{input.verdict.next_action});
    try output.print(allocator, "actions: {d}\n", .{input.verdict.actions});
    try output.print(allocator, "new_actions: {d}\n", .{input.verdict.new_actions});
    try output.print(allocator, "persisting_actions: {d}\n", .{input.verdict.persisting_actions});
    try output.print(allocator, "observed_actions: {d}\n\n", .{input.verdict.observed_actions});

    for (input.verdict.artifacts, 0..) |artifact, index| {
        const query_report_path = try queryReportPathForJson(allocator, artifact.json_path);
        defer allocator.free(query_report_path);

        try output.print(allocator, "artifact {d}:\n", .{index + 1});
        try output.print(allocator, "json: {s}\n", .{artifact.json_path});
        if (artifact.baseline_path) |path| {
            try output.print(allocator, "baseline: {s}\n", .{path});
        } else {
            try output.appendSlice(allocator, "baseline: none\n");
        }
        if (artifact.compare_report_path) |path| {
            try output.print(allocator, "compare report: {s}\n", .{path});
        } else {
            try output.appendSlice(allocator, "compare report: none\n");
        }
        try output.print(allocator, "query report: {s}\n", .{query_report_path});
        try output.print(allocator, "advice report: {s}\n", .{artifact.advice_report_path});
        try output.print(allocator, "actions: {d}\n", .{artifact.actions});
        try output.print(allocator, "new_actions: {d}\n", .{artifact.new_actions});
        try output.print(allocator, "persisting_actions: {d}\n", .{artifact.persisting_actions});
        try output.print(allocator, "observed_actions: {d}\n\n", .{artifact.observed_actions});
    }

    try appendRecommendedOrder(allocator, &output, input.verdict);
    try output.appendSlice(allocator, "\ncommands:\n");
    for (input.verdict.artifacts) |artifact| {
        try output.print(allocator, "- zig build causal-advice --", .{});
        if (artifact.baseline_path) |baseline_path| try output.print(allocator, " --before {s}", .{baseline_path});
        try output.print(allocator, " --file {s}\n", .{artifact.json_path});
        try output.print(allocator, "- zig build causal-query -- --file {s} snapshot\n", .{artifact.json_path});
        if (artifact.baseline_path) |baseline_path| {
            try output.print(allocator, "- zig build causal-compare -- {s} {s}\n", .{ baseline_path, artifact.json_path });
        }
    }

    return output.toOwnedSlice(allocator);
}
```

- [ ] **Step 4: Wire only the test module temporarily enough to run tests**

Modify `packages/zigeffect/build.zig` near the causal verdict module:

```zig
const causal_dev_agent_tool_module = b.createModule(.{
    .root_source_file = b.path("tools/causal_dev_agent.zig"),
    .target = target,
    .optimize = optimize,
});
causal_dev_agent_tool_module.addImport("causal_run", causal_run_tool_module);

const causal_dev_agent_tool_tests = b.addTest(.{
    .name = "zigeffect-causal-dev-agent-tests",
    .root_module = causal_dev_agent_tool_module,
});
const run_causal_dev_agent_tool_tests = b.addRunArtifact(causal_dev_agent_tool_tests);
```

Add to the `examples_step` dependencies:

```zig
examples_step.dependOn(&run_causal_dev_agent_tool_tests.step);
```

- [ ] **Step 5: Run tests to verify Task 1 passes**

Run:

```sh
cd packages/zigeffect
zig build examples
```

Expected: PASS for the new tool tests and existing examples.

- [ ] **Step 6: Commit Task 1**

```sh
git add packages/zigeffect/tools/causal_dev_agent.zig packages/zigeffect/build.zig
git commit -m "feat(zigeffect): add causal dev-agent report formatter"
```

## Task 2: Add CLI Reading And Clean Failure Behavior

**Files:**
- Modify: `packages/zigeffect/tools/causal_dev_agent.zig`
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Write failing tests for parse and validation**

Add tests:

```zig
test "unsupported verdict schema is rejected" {
    var verdict = Verdict{
        .schema = "zigeffect.causal.other.v1",
        .schema_version = 1,
        .status = "clear",
        .next_action = "none",
        .json_artifacts = 0,
        .baseline_pairs = 0,
        .actions = 0,
        .new_actions = 0,
        .persisting_actions = 0,
        .observed_actions = 0,
        .artifacts = &.{},
    };

    try std.testing.expectError(error.UnsupportedVerdictSchema, validateLocalVerdict(verdict));
}

test "empty verdict artifacts are rejected" {
    var verdict = Verdict{
        .schema = supported_local_schema,
        .schema_version = 1,
        .status = "clear",
        .next_action = "none",
        .json_artifacts = 0,
        .baseline_pairs = 0,
        .actions = 0,
        .new_actions = 0,
        .persisting_actions = 0,
        .observed_actions = 0,
        .artifacts = &.{},
    };

    try std.testing.expectError(error.EmptyVerdictArtifacts, validateLocalVerdict(verdict));
}

test "usage text names local mode" {
    try std.testing.expectEqualStrings(
        "usage: zig build causal-dev-agent -- local [scenario]\n",
        usage(),
    );
}
```

- [ ] **Step 2: Run tests to verify they fail**

```sh
cd packages/zigeffect
zig build examples
```

Expected: FAIL because `validateLocalVerdict` and `usage` are not implemented.

- [ ] **Step 3: Implement validation and usage helpers**

Add:

```zig
fn validateLocalVerdict(verdict: Verdict) !void {
    if (!std.mem.eql(u8, verdict.schema, supported_local_schema)) return error.UnsupportedVerdictSchema;
    if (verdict.schema_version != 1) return error.UnsupportedVerdictSchema;
    if (verdict.artifacts.len == 0) return error.EmptyVerdictArtifacts;
}

fn usage() []const u8 {
    return "usage: zig build causal-dev-agent -- local [scenario]\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-dev-agent error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}
```

Change `formatLocalAgentReport` to call `try validateLocalVerdict(input.verdict);`.

- [ ] **Step 4: Implement file reading and CLI main**

Add:

```zig
fn readVerdict(io: std.Io, allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    return std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(1024 * 1024)) catch |err| switch (err) {
        error.FileNotFound => error.MissingVerdictArtifact,
        else => return err,
    };
}

fn runLocal(init: std.process.Init, scenario_slug: ?[]const u8) !void {
    const allocator = init.gpa;
    const verdict_path = if (scenario_slug) |slug| try localVerdictPathForScenario(allocator, slug) else localVerdictPath(null);
    defer if (scenario_slug != null) allocator.free(verdict_path);

    const target = scenario_slug orelse "dogfood";
    const verdict_json = try readVerdict(init.io, allocator, verdict_path);
    defer allocator.free(verdict_json);

    var parsed = try std.json.parseFromSlice(Verdict, allocator, verdict_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const report = try formatLocalAgentReport(allocator, .{
        .target = target,
        .verdict_path = verdict_path,
        .verdict = parsed.value,
    });
    defer allocator.free(report);
    std.debug.print("{s}", .{report});
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len < 2) failUsage(error.MissingMode);
    if (args.len > 3) failUsage(error.TooManyArguments);
    if (!std.mem.eql(u8, args[1], "local")) failUsage(error.UnknownMode);

    const scenario_slug: ?[]const u8 = if (args.len == 3) blk: {
        _ = causal_run.scenarioByName(args[2]) catch |err| failUsage(err);
        break :blk args[2];
    } else null;

    runLocal(init, scenario_slug) catch |err| switch (err) {
        error.MissingVerdictArtifact,
        error.UnsupportedVerdictSchema,
        error.EmptyVerdictArtifacts,
        error.InvalidVerdictArtifactPath,
        => failUsage(err),
        else => return err,
    };
}
```

- [ ] **Step 5: Wire executable and build step**

In `packages/zigeffect/build.zig`, add:

```zig
const causal_dev_agent_tool = b.addExecutable(.{
    .name = "zigeffect-causal-dev-agent",
    .root_module = causal_dev_agent_tool_module,
});
const run_causal_dev_agent_tool = b.addRunArtifact(causal_dev_agent_tool);
if (b.args) |args| run_causal_dev_agent_tool.addArgs(args);
const causal_dev_agent_step = b.step("causal-dev-agent", "Read a causal dev-loop verdict and print the next agent inspection plan");
causal_dev_agent_step.dependOn(&run_causal_dev_agent_tool.step);
```

Add the executable to `examples_step`:

```zig
examples_step.dependOn(&causal_dev_agent_tool.step);
```

- [ ] **Step 6: Run tests to verify Task 2 passes**

```sh
cd packages/zigeffect
zig build examples
```

Expected: PASS.

- [ ] **Step 7: Commit Task 2**

```sh
git add packages/zigeffect/tools/causal_dev_agent.zig packages/zigeffect/build.zig
git commit -m "feat(zigeffect): wire causal dev-agent command"
```

## Task 3: Verify Runtime Behavior And Update Docs

**Files:**
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/causal-scenarios.md`
- Modify: `docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md`
- Modify: `packages/zigeffect/docs/roadmap.md`

- [ ] **Step 1: Run default integration check**

```sh
cd packages/zigeffect
rm -rf .zig-cache/causal-artifacts
zig build causal-dev-loop -- baseline
zig build causal-dev-loop -- after
zig build causal-dev-agent -- local
```

Expected output includes:

```text
mode: local
target: dogfood
verdict: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-verdict.json
recommended inspection order:
```

- [ ] **Step 2: Run scenario integration check**

```sh
cd packages/zigeffect
rm -rf .zig-cache/causal-artifacts
zig build causal-dev-loop -- baseline causal-scoped-fiber
zig build causal-dev-loop -- after causal-scoped-fiber
zig build causal-dev-agent -- local causal-scoped-fiber
```

Expected output includes:

```text
mode: local
target: causal-scoped-fiber
verdict: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-verdict.json
recommended inspection order:
```

- [ ] **Step 3: Update agent guide**

In `packages/zigeffect/docs/agent-guide.md`, after the paragraph that says to
read `*-verdict.json` first, add:

````markdown
To turn the verdict into a deterministic local agent handoff, run:

```sh
zig build causal-dev-agent -- local
zig build causal-dev-agent -- local causal-scoped-fiber
```

The command reads the existing verdict artifact, prints the recommended
inspection order, and gives exact advice, query, and compare commands. It does
not rerun the loop or apply fixes.
````

- [ ] **Step 4: Update causal scenarios doc**

In `packages/zigeffect/docs/causal-scenarios.md`, add the command near the
development-loop command list:

````markdown
Print the next local agent inspection plan from a saved dev-loop verdict:

```sh
zig build causal-dev-agent -- local [scenario]
```
````

In the development-loop section, add:

```markdown
After an after-phase run, `zig build causal-dev-agent -- local [scenario]`
reads the matching verdict and prints the deterministic local inspection plan.
Use it before manually opening advice, query, or compare artifacts.
```

- [ ] **Step 5: Update roadmap docs**

In `docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md`,
add a delivered slice under Milestone 7:

```markdown
- `zig build causal-dev-agent -- local [scenario]`, which reads local verdicts
  and prints the deterministic next inspection plan for development agents.
```

Move the remaining bullet from "development-agent automation that reads local
verdicts..." to a narrower future bullet:

```markdown
- richer automation that can summarize selected advice/query evidence into a
  patch-ready diagnosis.
```

In `packages/zigeffect/docs/roadmap.md`, add:

```markdown
- Delivered: `zig build causal-dev-agent -- local [scenario]` turns local
  dev-loop verdicts into deterministic agent inspection plans.
```

- [ ] **Step 6: Run final verification**

```sh
cd packages/zigeffect
zig build examples
zig build test --summary none
cd ../..
git diff --check
bun run zig:test
```

Expected: all commands exit 0.

- [ ] **Step 7: Commit Task 3**

```sh
git add packages/zigeffect/docs/agent-guide.md \
  packages/zigeffect/docs/causal-scenarios.md \
  docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md \
  packages/zigeffect/docs/roadmap.md
git commit -m "docs(zigeffect): document causal dev-agent harness"
```

## Completion Checklist

- [ ] `zig build causal-dev-agent -- local` works after a default after-phase run.
- [ ] `zig build causal-dev-agent -- local causal-scoped-fiber` works after a scenario after-phase run.
- [ ] Missing verdicts fail with clean usage text; the executable uses
  usage-style exit code `2`, while `zig build` reports the failed step.
- [ ] `zig build examples` includes the new tool tests and executable build.
- [ ] `zig build test --summary none` passes in `packages/zigeffect`.
- [ ] `bun run zig:test` passes at the repo root.
- [ ] Docs explain when to use the harness and that it is non-mutating.
