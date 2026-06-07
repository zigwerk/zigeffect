# zigeffect Causal Diagnosis Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `zig build causal-diagnosis -- local [scenario]`, a deterministic non-mutating tool that turns local dev-loop artifacts into a patch-ready diagnosis report.

**Architecture:** Create `tools/causal_diagnosis.zig` as a focused artifact synthesizer. It reads the local verdict, advice report, query report, and compare report, parses advice action lines and compare posture, writes `*-diagnosis.txt`, and prints the same report.

**Tech Stack:** Zig 0.16 build system, Zig std JSON parser, existing `causal_run` artifact directory and scenario registry, Bun repo verification commands.

---

## File Structure

- Create `packages/zigeffect/tools/causal_diagnosis.zig`
  - CLI parsing for `local [scenario]`.
  - Local verdict and diagnosis path derivation.
  - Verdict JSON parse/validation.
  - Advice action-line parser.
  - Query report existence/count summary.
  - Compare posture parser.
  - Text diagnosis formatter.
  - Artifact writer.
  - Unit tests.
- Modify `packages/zigeffect/build.zig`
  - Add module, executable, run step, tests, and `examples` dependencies.
  - Import `causal_run`.
- Modify `packages/zigeffect/docs/agent-guide.md`
  - Add diagnosis after the dev-agent handoff command.
- Modify `packages/zigeffect/docs/causal-scenarios.md`
  - Add diagnosis command and artifact path.
- Modify `docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md`
  - Mark diagnosis as delivered after implementation.
- Modify `packages/zigeffect/docs/roadmap.md`
  - Add diagnosis to the delivered agent-observable runtime list after implementation.

## Task 1: Parser And Formatter

**Files:**
- Create: `packages/zigeffect/tools/causal_diagnosis.zig`
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Write failing tests**

Create `packages/zigeffect/tools/causal_diagnosis.zig` with these test fixtures and tests:

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
    artifacts: []const VerdictArtifact,
};

const VerdictArtifact = struct {
    json_path: []const u8,
    baseline_path: ?[]const u8,
    advice_report_path: []const u8,
    compare_report_path: ?[]const u8,
    actions: usize,
    new_actions: usize,
    persisting_actions: usize,
    observed_actions: usize,
};

const advice_text =
    \\zigeffect causal advice report
    \\artifact: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-after.json
    \\baseline: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-before.json
    \\actions: 2
    \\- action provide-missing-service status=persisting event=3 kind=service_required label=Config
    \\  why: service requirement is missing a provider
    \\- action inspect-command-failure status=new event=9 kind=assertion_recorded label=package-tests
    \\  why: development command recorded a failed assertion
    \\
;

const no_delta_compare_text =
    \\zigeffect causal compare report
    \\before events: 8
    \\after events: 8
    \\event delta: +0
    \\before findings: 4
    \\after findings: 4
    \\finding delta: +0
    \\added events:
    \\- none
    \\removed events:
    \\- none
    \\changed events:
    \\- none
    \\
;

const regression_compare_text =
    \\zigeffect causal compare report
    \\before events: 2
    \\after events: 3
    \\event delta: +1
    \\before findings: 0
    \\after findings: 1
    \\finding delta: +1
    \\added events:
    \\- event id=9 kind=assertion_recorded label=package-tests status=failure
    \\removed events:
    \\- none
    \\changed events:
    \\- none
    \\
;

test "diagnosis path is stable for default target" {
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-diagnosis.txt",
        localDiagnosisPath(),
    );
}

test "scenario diagnosis path includes slug" {
    const path = try localDiagnosisPathForScenario(std.testing.allocator, "causal-scoped-fiber");
    defer std.testing.allocator.free(path);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-diagnosis.txt",
        path,
    );
}

test "advice action parser captures action status event kind and label" {
    const actions = try parseAdviceActions(std.testing.allocator, advice_text);
    defer deinitAdviceActions(std.testing.allocator, actions);

    try std.testing.expectEqual(@as(usize, 2), actions.len);
    try std.testing.expectEqualStrings("provide-missing-service", actions[0].action);
    try std.testing.expectEqualStrings("persisting", actions[0].status);
    try std.testing.expectEqual(@as(u64, 3), actions[0].event_id);
    try std.testing.expectEqualStrings("service_required", actions[0].kind);
    try std.testing.expectEqualStrings("Config", actions[0].label.?);
}

test "action mapping names subsystem and fix category" {
    const mapped = mapAction("provide-missing-service");

    try std.testing.expectEqualStrings("service_resolution", mapped.subsystem);
    try std.testing.expectEqualStrings("code-or-layer-provider", mapped.fix_category);
    try std.testing.expect(std.mem.indexOf(u8, mapped.diagnosis, "required service") != null);
}

test "unknown action mapping remains inspectable" {
    const mapped = mapAction("new-action");

    try std.testing.expectEqualStrings("unknown", mapped.subsystem);
    try std.testing.expectEqualStrings("inspect-evidence", mapped.fix_category);
}

test "dominant evidence prioritizes new then observed then persisting" {
    try std.testing.expectEqualStrings("new", dominantEvidence(.{
        .new_actions = 1,
        .observed_actions = 5,
        .persisting_actions = 9,
    }));
    try std.testing.expectEqualStrings("observed", dominantEvidence(.{
        .new_actions = 0,
        .observed_actions = 1,
        .persisting_actions = 9,
    }));
    try std.testing.expectEqualStrings("persisting", dominantEvidence(.{
        .new_actions = 0,
        .observed_actions = 0,
        .persisting_actions = 1,
    }));
    try std.testing.expectEqualStrings("none", dominantEvidence(.{
        .new_actions = 0,
        .observed_actions = 0,
        .persisting_actions = 0,
    }));
}

test "compare parser identifies no delta" {
    const posture = parseComparePosture(no_delta_compare_text);

    try std.testing.expectEqual(ComparePosture.no_delta, posture.kind);
    try std.testing.expectEqual(@as(isize, 0), posture.finding_delta);
    try std.testing.expectEqual(@as(isize, 0), posture.event_delta);
}

test "compare parser identifies regression" {
    const posture = parseComparePosture(regression_compare_text);

    try std.testing.expectEqual(ComparePosture.regression, posture.kind);
    try std.testing.expectEqual(@as(isize, 1), posture.finding_delta);
}

test "attention diagnosis report includes patch prompt and citations" {
    const verdict = Verdict{
        .schema = supported_local_schema,
        .schema_version = 1,
        .status = "attention",
        .next_action = "inspect-new-advice",
        .json_artifacts = 1,
        .baseline_pairs = 1,
        .actions = 2,
        .new_actions = 1,
        .persisting_actions = 1,
        .observed_actions = 0,
        .artifacts = &.{
            .{
                .json_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-after.json",
                .baseline_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-before.json",
                .advice_report_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-advice.txt",
                .compare_report_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-compare.txt",
                .actions = 2,
                .new_actions = 1,
                .persisting_actions = 1,
                .observed_actions = 0,
            },
        },
    };
    const actions = try parseAdviceActions(std.testing.allocator, advice_text);
    defer deinitAdviceActions(std.testing.allocator, actions);

    const report = try formatDiagnosisReport(std.testing.allocator, .{
        .target = "dogfood",
        .diagnosis_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-diagnosis.txt",
        .verdict_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-verdict.json",
        .verdict = verdict,
        .actions = actions,
        .query_report_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-queries.txt",
        .query_count = 4,
        .compare_posture = parseComparePosture(regression_compare_text),
    });
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect causal diagnosis") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "dominant evidence: new") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "subsystem: service_resolution") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "fix category: code-or-layer-provider") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "citations: event=3") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "patch prompt: inspect service requirements and provider declarations") != null);
}

test "clear diagnosis report has no evidence actions" {
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
        .artifacts = &.{
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
        },
    };
    const report = try formatDiagnosisReport(std.testing.allocator, .{
        .target = "causal-scoped-fiber",
        .diagnosis_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-diagnosis.txt",
        .verdict_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-verdict.json",
        .verdict = verdict,
        .actions = &.{},
        .query_report_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-queries.txt",
        .query_count = 0,
        .compare_posture = parseComparePosture(no_delta_compare_text),
    });
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "diagnosis status: clear") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "no causal advice actions selected") != null);
}
```

- [ ] **Step 2: Wire test module and verify red**

Modify `packages/zigeffect/build.zig` near `causal_dev_agent_tool_module`:

```zig
const causal_diagnosis_tool_module = b.createModule(.{
    .root_source_file = b.path("tools/causal_diagnosis.zig"),
    .target = target,
    .optimize = optimize,
});
causal_diagnosis_tool_module.addImport("causal_run", causal_run_tool_module);

const causal_diagnosis_tool_tests = b.addTest(.{
    .name = "zigeffect-causal-diagnosis-tests",
    .root_module = causal_diagnosis_tool_module,
});
const run_causal_diagnosis_tool_tests = b.addRunArtifact(causal_diagnosis_tool_tests);
```

Add to the `examples_step` dependencies:

```zig
examples_step.dependOn(&run_causal_diagnosis_tool_tests.step);
```

Run:

```sh
cd packages/zigeffect
zig build examples
```

Expected: FAIL because helpers such as `localDiagnosisPath`,
`parseAdviceActions`, `mapAction`, and `formatDiagnosisReport` are not defined.

- [ ] **Step 3: Implement parser and formatter**

Implement these types and helpers in `causal_diagnosis.zig`:

```zig
const AdviceAction = struct {
    action: []const u8,
    status: []const u8,
    event_id: u64,
    kind: []const u8,
    label: ?[]const u8 = null,
};

const ActionMapping = struct {
    subsystem: []const u8,
    fix_category: []const u8,
    diagnosis: []const u8,
    patch_prompt: []const u8,
};

const ActionCounts = struct {
    new_actions: usize,
    observed_actions: usize,
    persisting_actions: usize,
};

const ComparePosture = enum {
    no_delta,
    improved,
    regression,
    changed,
    unknown,
};

const CompareSummary = struct {
    kind: ComparePosture,
    event_delta: isize = 0,
    finding_delta: isize = 0,
};

const DiagnosisInput = struct {
    target: []const u8,
    diagnosis_path: []const u8,
    verdict_path: []const u8,
    verdict: Verdict,
    actions: []const AdviceAction,
    query_report_path: []const u8,
    query_count: usize,
    compare_posture: CompareSummary,
};
```

Use this behavior:

- `localDiagnosisPath()` returns `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-diagnosis.txt`.
- `localDiagnosisPathForScenario(allocator, slug)` returns `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<slug>-diagnosis.txt`.
- `parseAdviceActions` scans only lines that start with `- action `.
- Token parsing is whitespace-based and accepts the current advice format.
- `deinitAdviceActions` frees duplicated `action`, `status`, `kind`, and `label`.
- `mapAction` implements the six mappings from the design and an unknown fallback.
- `parseComparePosture` reads signed integer values after `event delta:` and `finding delta:`.
- `formatDiagnosisReport` emits the sections from the design.

Keep the first implementation deterministic and text-only.

- [ ] **Step 4: Run green check and commit**

Run:

```sh
cd packages/zigeffect
zig fmt tools/causal_diagnosis.zig build.zig
zig build examples
```

Expected: PASS.

Commit:

```sh
git add packages/zigeffect/tools/causal_diagnosis.zig packages/zigeffect/build.zig
git commit -m "feat(zigeffect): add causal diagnosis formatter"
```

## Task 2: CLI Artifact Reader And Writer

**Files:**
- Modify: `packages/zigeffect/tools/causal_diagnosis.zig`
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Add failing validation and usage tests**

Add tests:

```zig
test "usage names local mode" {
    try std.testing.expectEqualStrings(
        "usage: zig build causal-diagnosis -- local [scenario]\n",
        usage(),
    );
}

test "unsupported verdict schema is rejected" {
    const verdict = Verdict{
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
    const verdict = Verdict{
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
```

Run:

```sh
cd packages/zigeffect
zig build examples
```

Expected: FAIL because `usage` or `validateLocalVerdict` is not implemented.

- [ ] **Step 2: Implement validation and local path derivation**

Add:

```zig
fn validateLocalVerdict(verdict: Verdict) !void {
    if (!std.mem.eql(u8, verdict.schema, supported_local_schema)) return error.UnsupportedVerdictSchema;
    if (verdict.schema_version != 1) return error.UnsupportedVerdictSchema;
    if (verdict.artifacts.len == 0) return error.EmptyVerdictArtifacts;
}

fn localVerdictPath() []const u8 {
    return causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-verdict.json";
}

fn localVerdictPathForScenario(allocator: std.mem.Allocator, scenario_slug: []const u8) ![]const u8 {
    return std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-dev-loop-{s}-verdict.json", .{ causal_run.artifact_dir, scenario_slug });
}

fn queryReportPathForJson(allocator: std.mem.Allocator, json_path: []const u8) ![]const u8 {
    if (std.mem.endsWith(u8, json_path, "-after.json")) {
        return std.fmt.allocPrint(allocator, "{s}-queries.txt", .{json_path[0 .. json_path.len - "-after.json".len]});
    }
    if (!std.mem.endsWith(u8, json_path, ".json")) return error.InvalidVerdictArtifactPath;
    return std.fmt.allocPrint(allocator, "{s}-queries.txt", .{json_path[0 .. json_path.len - ".json".len]});
}
```

- [ ] **Step 3: Implement file IO and `main`**

Add:

```zig
fn usage() []const u8 {
    return "usage: zig build causal-diagnosis -- local [scenario]\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-diagnosis error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

fn readArtifact(io: std.Io, allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    return std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(1024 * 1024)) catch |err| switch (err) {
        error.FileNotFound => error.MissingDiagnosisInput,
        else => return err,
    };
}

fn writeArtifact(io: std.Io, path: []const u8, contents: []const u8) !void {
    const slash = std.mem.lastIndexOfScalar(u8, path, '/') orelse return error.InvalidArtifactPath;
    const cwd = std.Io.Dir.cwd();
    try cwd.createDirPath(io, path[0..slash]);
    try cwd.writeFile(io, .{ .sub_path = path, .data = contents });
}

fn queryCount(query_report: []const u8) usize {
    return std.mem.count(u8, query_report, "query: ");
}
```

Implement `runLocal`:

```zig
fn runLocal(init: std.process.Init, scenario_slug: ?[]const u8) !void {
    const allocator = init.gpa;
    const verdict_path = if (scenario_slug) |slug| try localVerdictPathForScenario(allocator, slug) else localVerdictPath();
    defer if (scenario_slug != null) allocator.free(verdict_path);
    const diagnosis_path = if (scenario_slug) |slug| try localDiagnosisPathForScenario(allocator, slug) else localDiagnosisPath();
    defer if (scenario_slug != null) allocator.free(diagnosis_path);
    const target = scenario_slug orelse "dogfood";

    const verdict_json = try readArtifact(init.io, allocator, verdict_path);
    defer allocator.free(verdict_json);
    var parsed = try std.json.parseFromSlice(Verdict, allocator, verdict_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    try validateLocalVerdict(parsed.value);

    const artifact = parsed.value.artifacts[0];
    const advice_report = try readArtifact(init.io, allocator, artifact.advice_report_path);
    defer allocator.free(advice_report);
    const query_report_path = try queryReportPathForJson(allocator, artifact.json_path);
    defer allocator.free(query_report_path);
    const query_report = try readArtifact(init.io, allocator, query_report_path);
    defer allocator.free(query_report);
    const compare_report = if (artifact.compare_report_path) |path| try readArtifact(init.io, allocator, path) else "";
    defer if (artifact.compare_report_path != null) allocator.free(compare_report);

    const actions = try parseAdviceActions(allocator, advice_report);
    defer deinitAdviceActions(allocator, actions);

    const report = try formatDiagnosisReport(allocator, .{
        .target = target,
        .diagnosis_path = diagnosis_path,
        .verdict_path = verdict_path,
        .verdict = parsed.value,
        .actions = actions,
        .query_report_path = query_report_path,
        .query_count = queryCount(query_report),
        .compare_posture = parseComparePosture(compare_report),
    });
    defer allocator.free(report);

    try writeArtifact(init.io, diagnosis_path, report);
    std.debug.print("{s}", .{report});
}
```

Implement `main`:

```zig
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
        error.MissingDiagnosisInput,
        error.UnsupportedVerdictSchema,
        error.EmptyVerdictArtifacts,
        error.InvalidVerdictArtifactPath,
        error.InvalidArtifactPath,
        => failUsage(err),
        else => return err,
    };
}
```

- [ ] **Step 4: Wire executable and build step**

In `packages/zigeffect/build.zig`, add:

```zig
const causal_diagnosis_tool = b.addExecutable(.{
    .name = "zigeffect-causal-diagnosis",
    .root_module = causal_diagnosis_tool_module,
});
const run_causal_diagnosis_tool = b.addRunArtifact(causal_diagnosis_tool);
if (b.args) |args| run_causal_diagnosis_tool.addArgs(args);
const causal_diagnosis_step = b.step("causal-diagnosis", "Read local causal dev-loop reports and write a patch-ready diagnosis");
causal_diagnosis_step.dependOn(&run_causal_diagnosis_tool.step);
```

Add executable build to `examples_step`:

```zig
examples_step.dependOn(&causal_diagnosis_tool.step);
```

- [ ] **Step 5: Verify and commit**

Run:

```sh
cd packages/zigeffect
zig fmt tools/causal_diagnosis.zig build.zig
zig build examples
```

Expected: PASS.

Commit:

```sh
git add packages/zigeffect/tools/causal_diagnosis.zig packages/zigeffect/build.zig
git commit -m "feat(zigeffect): wire causal diagnosis command"
```

## Task 3: Integration Verification And Docs

**Files:**
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/docs/causal-scenarios.md`
- Modify: `docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md`
- Modify: `packages/zigeffect/docs/roadmap.md`

- [ ] **Step 1: Verify default diagnosis**

Run:

```sh
cd packages/zigeffect
rm -rf .zig-cache/causal-artifacts
zig build causal-dev-loop -- baseline
zig build causal-dev-loop -- after
zig build causal-diagnosis -- local
test -f .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-diagnosis.txt
rg "zigeffect causal diagnosis" .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-diagnosis.txt
rg "target: dogfood" .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-diagnosis.txt
rg "dominant evidence: persisting" .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-diagnosis.txt
```

- [ ] **Step 2: Verify scenario diagnosis**

Run:

```sh
cd packages/zigeffect
rm -rf .zig-cache/causal-artifacts
zig build causal-dev-loop -- baseline causal-scoped-fiber
zig build causal-dev-loop -- after causal-scoped-fiber
zig build causal-diagnosis -- local causal-scoped-fiber
test -f .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-diagnosis.txt
rg "target: causal-scoped-fiber" .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-diagnosis.txt
rg "diagnosis status: clear" .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-diagnosis.txt
```

- [ ] **Step 3: Verify missing input failure**

Run:

```sh
cd packages/zigeffect
rm -rf .zig-cache/causal-artifacts
set +e
output=$(zig build causal-diagnosis -- local 2>&1)
exit_code=$?
set -e
printf "%s\n" "$output"
test "$exit_code" -ne 0
printf "%s\n" "$output" | rg "causal-diagnosis error: MissingDiagnosisInput"
printf "%s\n" "$output" | rg "usage: zig build causal-diagnosis -- local \\[scenario\\]"
```

- [ ] **Step 4: Update agent guide**

In `packages/zigeffect/docs/agent-guide.md`, after the `causal-dev-agent`
paragraph, add:

````markdown
To synthesize the existing verdict, advice, query, and compare reports into a
patch-ready diagnosis, run:

```sh
zig build causal-diagnosis -- local
zig build causal-diagnosis -- local causal-scoped-fiber
```

The command writes `*-diagnosis.txt`, cites event ids from advice, summarizes
compare posture, and suggests patch categories without editing source.
````

- [ ] **Step 5: Update scenario docs**

In `packages/zigeffect/docs/causal-scenarios.md`, add the command near
`causal-dev-agent`:

````markdown
Write a patch-ready local diagnosis from saved dev-loop artifacts:

```sh
zig build causal-diagnosis -- local [scenario]
```
````

Add diagnosis artifact paths to the development-loop artifact lists:

```markdown
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-diagnosis.txt`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-diagnosis.txt`
```

- [ ] **Step 6: Update roadmap docs**

In `docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md`,
add to Milestone 7 delivered slices:

```markdown
- `zig build causal-diagnosis -- local [scenario]`, which summarizes verdict,
  advice, query, and compare artifacts into a patch-ready non-mutating
  diagnosis report.
```

Replace the remaining diagnosis bullet with:

```markdown
- app-facing development loops once applications emit causal runtime artifacts.
```

In `packages/zigeffect/docs/roadmap.md`, add:

```markdown
- Delivered: `zig build causal-diagnosis -- local [scenario]` writes
  patch-ready, non-mutating diagnosis reports from local dev-loop artifacts.
```

- [ ] **Step 7: Run final verification**

Run:

```sh
cd packages/zigeffect
zig build examples
zig build test --summary none
cd ../..
git diff --check
bun run zig:test
```

Expected: all commands exit 0.

- [ ] **Step 8: Commit docs**

```sh
git add packages/zigeffect/docs/agent-guide.md \
  packages/zigeffect/docs/causal-scenarios.md \
  docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md \
  packages/zigeffect/docs/roadmap.md
git commit -m "docs(zigeffect): document causal diagnosis workflow"
```

## Completion Checklist

- [ ] `zig build causal-diagnosis -- local` works after a default after-phase run.
- [ ] `zig build causal-diagnosis -- local causal-scoped-fiber` works after a scenario after-phase run.
- [ ] Diagnosis artifacts are written to stable default and scenario paths.
- [ ] Missing inputs fail with clean usage text.
- [ ] Diagnosis reports cite event ids and report paths.
- [ ] Diagnosis reports preserve `new`, `observed`, and `persisting` semantics.
- [ ] `zig build examples` includes the new tests and executable.
- [ ] `zig build test --summary none` passes in `packages/zigeffect`.
- [ ] `bun run zig:test` passes at the repo root.
