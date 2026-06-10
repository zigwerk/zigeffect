# zigeffect Causal Load-Test Observation Harness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a schema-governed, record-only local load-test observation harness that catalogs approved scenario families and can opt in to bounded local observations without production load, telemetry, capacity claims, or mutation authority.

**Architecture:** Create one Zig tool that defaults to deterministic catalog output and supports an explicit `observe <scenario-id>` subcommand for curated local scenarios. Keep command execution behind a runner interface so tests use fake outputs, while live execution uses curated argv arrays, capped output snippets, capped iterations, and advisory review gates.

**Tech Stack:** Zig 0.16 build steps and tests, `std.process.run`, `std.time.Timer`, existing zigeffect causal report patterns, Markdown docs, Bun verification commands.

---

## Files And Responsibilities

- Create `packages/zigeffect/tools/causal_load_test_observation_harness.zig`
  - Owns `zigeffect.causal.load-test-observation-harness.v1`.
  - Provides catalog text/JSON output.
  - Provides `observe <scenario-id> --iterations <n> --format text|json`.
  - Defines scenario catalog, source contracts, observation record fields,
    execution constraints, review gates, negative fixtures, agent guidance,
    non-goals, and verification commands.
  - Implements runner abstraction and observation math.
  - Tests parser behavior, scenario coverage, default catalog output, JSON
    output, fake-runner observation math, command failure records, future-CI
    rejection, and bounded authority fields.

- Modify `packages/zigeffect/build.zig`
  - Adds `causal-load-test-observation-harness` executable step.
  - Adds tool tests to `zig build test`.

- Modify `packages/zigeffect/tools/causal_schema_governance.zig`
  - Registers `zigeffect.causal.load-test-observation-harness.v1`.
  - Updates schema-count expectations from `49` to `50`.
  - Adds `local-observation` compatibility posture text and tests.

- Modify `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
  - Adds `load-test-observation-harness` as delivered.
  - Updates recommendation to `start-production-telemetry-capture-design`.
  - Updates recommended next branch to
    `codex/zigeffect-causal-production-telemetry-capture-design`.
  - Adds the new command to verification commands.

- Create `packages/zigeffect/docs/load-test-observation-harness.md`
  - Documents command usage, schema, catalog mode, observation mode, scenario
    catalog, execution constraints, review gates, negative fixtures,
    verification, and next branch.

- Modify docs:
  - `packages/zigeffect/README.md`
  - `packages/zigeffect/docs/operations.md`
  - `packages/zigeffect/docs/schema-governance.md`
  - `packages/zigeffect/docs/production-hardening-backlog.md`
  - `packages/zigeffect/docs/production-hardening-completion-audit.md`
  - `packages/zigeffect/docs/roadmap.md`
  - `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

## Command Contract

Supported invocations:

```sh
zig build causal-load-test-observation-harness
zig build causal-load-test-observation-harness -- --format json
zig build causal-load-test-observation-harness -- observe app-request-trace --iterations 1 --format json
```

Parser rules:

- No args after the executable means catalog text.
- `--format text|json` means catalog report in that format.
- `observe <scenario-id> --iterations <n> --format text|json` runs an approved
  local-safe scenario.
- Unknown scenario returns `error.UnknownScenario`.
- `ci-baseline-capture` returns `error.FutureCiOnlyScenario` in observation
  mode.
- Missing `--iterations` returns `error.MissingIterations`.
- Non-positive or non-numeric iterations returns `error.InvalidIterations`.
- Iterations above `10` returns `error.IterationLimitExceeded`.
- Unknown flags return `error.UnknownFlag`.
- Unknown formats return `error.UnknownFormat`.

## Scenario Command Choices

Use curated argv arrays. Do not accept shell strings.

Initial executable local scenarios:

- `app-request-trace`
  - argv: `zig build causal-app-request-example`
- `background-job-trace`
  - argv: `zig build causal-run -- scoped-fiber`
- `causal-artifact-formatting`
  - argv: `zig build causal-report`
- `causal-query-agent-slices`
  - argv: `zig build causal-query -- --agent`
- `causal-compare-before-after`
  - argv: `zig build causal-compare -- .zig-cache/causal-artifacts/before.json .zig-cache/causal-artifacts/after.json`
  - status: `local-safe-needs-artifacts`
  - v1 observation is blocked because the CLI does not accept reviewed
    before/after artifact refs.
- `causal-dev-loop-package-tests`
  - argv: `zig build test-raw`
- `workbench-solid-build`
  - argv: `bun run zigeffect:workbench:build`
  - status: `local-safe-workspace-root`
  - v1 observation is blocked because the live process runner executes from
    `packages/zigeffect`, while this command must run from the repository root.
- `ci-baseline-capture`
  - status: `future-ci-only`
  - not executable locally.

For v1 implementation, only `app-request-trace`, `background-job-trace`,
`causal-artifact-formatting`, `causal-query-agent-slices`, and
`causal-dev-loop-package-tests` must be executable. The other three are
cataloged with deterministic blocking reasons.

## Task 1: Add Failing Tool Tests

**Files:**

- Create `packages/zigeffect/tools/causal_load_test_observation_harness.zig`

- [ ] Add schema constants:

```zig
pub const load_test_observation_harness_schema = "zigeffect.causal.load-test-observation-harness.v1";
pub const load_test_observation_harness_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-load-test-observation-harness";
pub const recommendation = "start-production-telemetry-capture-design";
pub const next_branch = "codex/zigeffect-causal-production-telemetry-capture-design";
```

- [ ] Add initial type declarations:

```zig
const OutputFormat = enum { text, json };
const Action = enum { catalog, observe };

const Options = struct {
    action: Action,
    format: OutputFormat,
    scenario_id: ?[]const u8 = null,
    iterations: u32 = 0,
};

const ScenarioStatus = enum {
    local_safe,
    local_safe_needs_artifacts,
    local_safe_workspace_root,
    future_ci_only,
};

const CommandStatus = enum { ok, failed };

const SourceContract = struct {
    id: []const u8,
    schema: []const u8,
    producer: []const u8,
    evidence_role: []const u8,
    authority_boundary: []const u8,
};

const Scenario = struct {
    id: []const u8,
    category: []const u8,
    status: ScenarioStatus,
    upstream_source: []const u8,
    argv: []const []const u8,
    measurement_kind: []const u8,
    required_evidence: []const []const u8,
    local_safety_boundary: []const u8,
    blocked_claim: []const u8,
    agent_guidance: []const u8,
};

const RunOutput = struct {
    status: CommandStatus,
    exit_code: ?i32,
    stdout: []const u8,
    stderr: []const u8,
    elapsed_ms: u64,
};

const ObservationRecord = struct {
    scenario_id: []const u8,
    scenario_category: []const u8,
    command_status: CommandStatus,
    exit_code: ?i32,
    warmup_iterations: u32,
    measured_iterations: u32,
    sample_count: u32,
    median_ms: u64,
    p95_ms: u64,
    min_ms: u64,
    max_ms: u64,
    stdout_snippet: []const u8,
    stderr_snippet: []const u8,
    review_gate: []const u8,
};
```

- [ ] Add stub functions:

```zig
fn parseOptions(args: []const []const u8) !Options {
    _ = args;
    return error.ExpectedRedFailure;
}

fn scenarios() []const Scenario {
    return &.{};
}

fn sourceContracts() []const SourceContract {
    return &.{};
}

fn formatCatalogText(allocator: std.mem.Allocator) ![]const u8 {
    _ = allocator;
    return error.ExpectedRedFailure;
}

fn formatCatalogJson(allocator: std.mem.Allocator) ![]const u8 {
    _ = allocator;
    return error.ExpectedRedFailure;
}

fn formatObservationJson(allocator: std.mem.Allocator, record: ObservationRecord) ![]const u8 {
    _ = allocator;
    _ = record;
    return error.ExpectedRedFailure;
}
```

- [ ] Add failing tests:

```zig
test "load-test observation harness usage names command and schema" {
    try std.testing.expectEqualStrings("zigeffect.causal.load-test-observation-harness.v1", load_test_observation_harness_schema);
    try std.testing.expectEqualStrings("start-production-telemetry-capture-design", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-capture-design", next_branch);
}

test "load-test observation harness parses catalog and observe options" {
    try std.testing.expectEqual(Action.catalog, (try parseOptions(&.{"zigeffect-causal-load-test-observation-harness"})).action);
    try std.testing.expectEqual(OutputFormat.json, (try parseOptions(&.{ "zigeffect-causal-load-test-observation-harness", "--format", "json" })).format);
    const observe = try parseOptions(&.{ "zigeffect-causal-load-test-observation-harness", "observe", "app-request-trace", "--iterations", "3", "--format", "json" });
    try std.testing.expectEqual(Action.observe, observe.action);
    try std.testing.expectEqualStrings("app-request-trace", observe.scenario_id.?);
    try std.testing.expectEqual(@as(u32, 3), observe.iterations);
    try std.testing.expectError(error.IterationLimitExceeded, parseOptions(&.{ "zigeffect-causal-load-test-observation-harness", "observe", "app-request-trace", "--iterations", "11" }));
    try std.testing.expectError(error.UnknownFormat, parseOptions(&.{ "zigeffect-causal-load-test-observation-harness", "--format", "yaml" }));
}

test "load-test observation harness scenario catalog covers upstream families" {
    try std.testing.expectEqual(@as(usize, 8), scenarios().len);
    try std.testing.expect(hasScenario("app-request-trace"));
    try std.testing.expect(hasScenario("background-job-trace"));
    try std.testing.expect(hasScenario("causal-artifact-formatting"));
    try std.testing.expect(hasScenario("causal-query-agent-slices"));
    try std.testing.expect(hasScenario("causal-compare-before-after"));
    try std.testing.expect(hasScenario("causal-dev-loop-package-tests"));
    try std.testing.expect(hasScenario("workbench-solid-build"));
    try std.testing.expect(hasScenarioStatus("ci-baseline-capture", .future_ci_only));
}

test "load-test observation harness catalog json preserves authority boundaries" {
    const report = try formatCatalogJson(std.testing.allocator);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.load-test-observation-harness.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"applied\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"mutation_authority\": \"none\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"production_load\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"capacity_claim\": false") != null);
}
```

- [ ] Run expected red:

```sh
cd packages/zigeffect
zig test tools/causal_load_test_observation_harness.zig
```

Expected: tests fail because parser, catalog, and formatters are stubs.

## Task 2: Implement Catalog Records And Formatters

**Files:**

- Modify `packages/zigeffect/tools/causal_load_test_observation_harness.zig`

- [ ] Implement `parseOptions` exactly for the command contract above.

- [ ] Fill `source_contracts` with:

```zig
const source_contracts: []const SourceContract = &.{
    .{ .id = "wall-clock-benchmark-baselines", .schema = "zigeffect.causal.wall-clock-benchmark-baselines.v1", .producer = "causal-wall-clock-benchmark-baselines", .evidence_role = "scenario families environment metadata calibration policy and advisory review gates", .authority_boundary = "advisory timing contract only" },
    .{ .id = "production-capacity-planning", .schema = "zigeffect.causal.production-capacity-planning.v1", .producer = "causal-production-capacity-planning", .evidence_role = "capacity domains load-test fixture plan storage assumptions and readiness gates", .authority_boundary = "planning-only and not production capacity evidence" },
    .{ .id = "production-hardening-completion-audit", .schema = "zigeffect.causal.production-hardening-completion-audit.v1", .producer = "causal-production-hardening-completion-audit", .evidence_role = "hardening completion boundaries and remaining evidence gaps", .authority_boundary = "record-only completion evidence" },
};
```

- [ ] Fill `scenario_catalog` with the eight scenarios from the design.

- [ ] Add arrays:

```zig
const execution_constraints: []const []const u8 = &.{
    "curated argv arrays only",
    "no shell invocation",
    "approved scenario ids only",
    "measured iterations capped at 10",
    "stdout and stderr snippets capped at 240 bytes",
    "redaction-safe environment metadata only",
    "no production telemetry",
    "no production load",
    "no capacity claim",
};

const review_gates: []const []const u8 = &.{
    "record-only",
    "needs-more-samples",
    "needs-review",
    "failed-command-finding",
    "environment-drift-review",
    "ready-for-telemetry-design",
};
```

- [ ] Add negative fixtures and non-goals from the design.

- [ ] Implement `formatCatalogText` and `formatCatalogJson` with the same
  `std.ArrayList(u8).empty` and `appendJsonString` helper style used by the
  existing hardening tools.

- [ ] Run:

```sh
cd packages/zigeffect
zig test tools/causal_load_test_observation_harness.zig
```

Expected: catalog/parser tests pass; observation tests added in Task 3 still do
not exist.

## Task 3: Implement Observation Engine With Fake Runner Tests

**Files:**

- Modify `packages/zigeffect/tools/causal_load_test_observation_harness.zig`

- [ ] Add runner interface:

```zig
const Runner = struct {
    ptr: *anyopaque,
    runFn: *const fn (*anyopaque, std.mem.Allocator, []const []const u8) anyerror!RunOutput,

    fn run(self: Runner, allocator: std.mem.Allocator, argv: []const []const u8) !RunOutput {
        return self.runFn(self.ptr, allocator, argv);
    }
};
```

- [ ] Add `FakeRunner` for tests, copying the style from
  `causal_dev_session.zig` but including `elapsed_ms`.

- [ ] Add `ProcessRunner` for live execution:

```zig
const ProcessRunner = struct {
    io: std.Io,

    fn runner(self: *ProcessRunner) Runner {
        return .{ .ptr = self, .runFn = run };
    }

    fn run(ptr: *anyopaque, allocator: std.mem.Allocator, argv: []const []const u8) !RunOutput {
        const self: *ProcessRunner = @ptrCast(@alignCast(ptr));
        var timer = try std.time.Timer.start();
        const result = std.process.run(allocator, self.io, .{
            .argv = argv,
            .stdout_limit = .limited(64 * 1024),
            .stderr_limit = .limited(64 * 1024),
        }) catch |err| {
            return .{
                .status = .failed,
                .exit_code = null,
                .stdout = try allocator.dupe(u8, ""),
                .stderr = try allocator.dupe(u8, @errorName(err)),
                .elapsed_ms = 0,
            };
        };
        const elapsed_ms = @divTrunc(timer.read(), std.time.ns_per_ms);
        return .{
            .status = statusForTerm(result.term),
            .exit_code = exitCodeForTerm(result.term),
            .stdout = result.stdout,
            .stderr = result.stderr,
            .elapsed_ms = elapsed_ms,
        };
    }
};
```

- [ ] Add observation math helpers:

```zig
fn median(sorted: []const u64) u64 {
    return sorted[sorted.len / 2];
}

fn p95(sorted: []const u64) u64 {
    const index = @min(sorted.len - 1, (sorted.len * 95 + 99) / 100 - 1);
    return sorted[index];
}
```

- [ ] Add `runObservation`:

```zig
fn runObservation(
    allocator: std.mem.Allocator,
    runner: Runner,
    scenario: Scenario,
    iterations: u32,
) !ObservationRecord
```

Behavior:

- Reject `.future_ci_only`, `.local_safe_needs_artifacts`, and
  `.local_safe_workspace_root` with deterministic errors.
- Run one warmup iteration and discard timing.
- Run `iterations` measured iterations.
- Store measured `elapsed_ms`.
- Return failed record immediately if a measured command fails.
- Calculate min, max, median, p95 from sorted samples.
- Use `review_gate = "needs-more-samples"` when iterations < 5.
- Use `review_gate = "needs-review"` when iterations >= 5.
- Snippet stdout/stderr from the final measured command.

- [ ] Add tests:

```zig
test "load-test observation harness fake runner records median p95 and bounds" {
    var fake = FakeRunner.init(&.{
        .{ .status = .ok, .exit_code = 0, .stdout = "warmup", .stderr = "", .elapsed_ms = 100 },
        .{ .status = .ok, .exit_code = 0, .stdout = "one", .stderr = "", .elapsed_ms = 10 },
        .{ .status = .ok, .exit_code = 0, .stdout = "two", .stderr = "", .elapsed_ms = 20 },
        .{ .status = .ok, .exit_code = 0, .stdout = "three", .stderr = "", .elapsed_ms = 30 },
        .{ .status = .ok, .exit_code = 0, .stdout = "four", .stderr = "", .elapsed_ms = 40 },
        .{ .status = .ok, .exit_code = 0, .stdout = "five", .stderr = "", .elapsed_ms = 50 },
    });
    defer fake.deinit(std.testing.allocator);

    const record = try runObservation(std.testing.allocator, fake.runner(), scenarioById("app-request-trace").?, 5);
    defer freeObservationRecord(std.testing.allocator, record);

    try std.testing.expectEqual(@as(u32, 1), record.warmup_iterations);
    try std.testing.expectEqual(@as(u32, 5), record.sample_count);
    try std.testing.expectEqual(@as(u64, 30), record.median_ms);
    try std.testing.expectEqual(@as(u64, 50), record.p95_ms);
    try std.testing.expectEqualStrings("needs-review", record.review_gate);
}
```

```zig
test "load-test observation harness failed command becomes finding gate" {
    var fake = FakeRunner.init(&.{
        .{ .status = .ok, .exit_code = 0, .stdout = "warmup", .stderr = "", .elapsed_ms = 5 },
        .{ .status = .failed, .exit_code = 1, .stdout = "", .stderr = "failure", .elapsed_ms = 7 },
    });
    defer fake.deinit(std.testing.allocator);

    const record = try runObservation(std.testing.allocator, fake.runner(), scenarioById("app-request-trace").?, 1);
    defer freeObservationRecord(std.testing.allocator, record);

    try std.testing.expectEqual(CommandStatus.failed, record.command_status);
    try std.testing.expectEqual(@as(?i32, 1), record.exit_code);
    try std.testing.expectEqualStrings("failed-command-finding", record.review_gate);
}
```

- [ ] Run:

```sh
cd packages/zigeffect
zig test tools/causal_load_test_observation_harness.zig
```

Expected: observation tests pass.

## Task 4: Wire Main, Build Step, And Live Smoke Command

**Files:**

- Modify `packages/zigeffect/tools/causal_load_test_observation_harness.zig`
- Modify `packages/zigeffect/build.zig`

- [ ] Implement `main`:

```zig
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const options = parseOptions(args) catch |err| failUsage(err);
    switch (options.action) {
        .catalog => {
            const report = switch (options.format) {
                .text => try formatCatalogText(init.gpa),
                .json => try formatCatalogJson(init.gpa),
            };
            defer init.gpa.free(report);
            std.debug.print("{s}", .{report});
        },
        .observe => {
            const scenario = scenarioById(options.scenario_id.?) orelse failUsage(error.UnknownScenario);
            var process_runner = ProcessRunner{ .io = init.io };
            const record = runObservation(init.gpa, process_runner.runner(), scenario, options.iterations) catch |err| failUsage(err);
            defer freeObservationRecord(init.gpa, record);
            const report = switch (options.format) {
                .text => try formatObservationText(init.gpa, record),
                .json => try formatObservationJson(init.gpa, record),
            };
            defer init.gpa.free(report);
            std.debug.print("{s}", .{report});
        },
    }
}
```

- [ ] Add build step after production-hardening completion audit:

```zig
const causal_load_test_observation_harness_tool_module = b.createModule(.{
    .root_source_file = b.path("tools/causal_load_test_observation_harness.zig"),
    .target = target,
    .optimize = optimize,
});

const causal_load_test_observation_harness_tool = b.addExecutable(.{
    .name = "zigeffect-causal-load-test-observation-harness",
    .root_module = causal_load_test_observation_harness_tool_module,
});
const run_causal_load_test_observation_harness_tool = b.addRunArtifact(causal_load_test_observation_harness_tool);
if (b.args) |args| run_causal_load_test_observation_harness_tool.addArgs(args);
const causal_load_test_observation_harness_step = b.step("causal-load-test-observation-harness", "Print or run causal load-test observation harness");
causal_load_test_observation_harness_step.dependOn(&run_causal_load_test_observation_harness_tool.step);

const causal_load_test_observation_harness_tool_tests = b.addTest(.{
    .name = "zigeffect-causal-load-test-observation-harness-tests",
    .root_module = causal_load_test_observation_harness_tool_module,
});
const run_causal_load_test_observation_harness_tool_tests = b.addRunArtifact(causal_load_test_observation_harness_tool_tests);
test_step.dependOn(&run_causal_load_test_observation_harness_tool_tests.step);
```

- [ ] Run:

```sh
cd packages/zigeffect
zig build causal-load-test-observation-harness
zig build causal-load-test-observation-harness -- --format json
zig build causal-load-test-observation-harness -- observe app-request-trace --iterations 1 --format json
```

Expected: catalog commands print reports; observation command prints one local
observation record with `production_load=false`, `capacity_claim=false`, and
`mutation_authority="none"`.

## Task 5: Register Schema And Backlog Handoff

**Files:**

- Modify `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify `packages/zigeffect/tools/causal_production_hardening_backlog.zig`

- [ ] Add schema entry after completion audit:

```zig
.{
    .schema = "zigeffect.causal.load-test-observation-harness.v1",
    .version = 1,
    .category = "production-hardening",
    .status = "current",
    .emitted_by = &.{"causal-load-test-observation-harness"},
    .consumed_by = &.{ "agents", "reviewers", "production telemetry capture design", "future capacity sizing review" },
    .compatibility = &.{ "strict-v1", "record-only", "mutation-authority-none", "local-observation" },
    .governance_requirements = &.{ "observation harness tests", "bounded runner tests", "redaction docs", "next-branch handoff" },
},
```

- [ ] Update schema-count tests from `49` to `50`.

- [ ] Add compatibility posture text:

```text
local-observation: bounded local command observation with advisory review gates and no production capacity claim
```

- [ ] Add backlog item:

```zig
.{
    .id = "load-test-observation-harness",
    .title = "Load-Test Observation Harness",
    .gap_id = "load-test-observation-harness",
    .priority = "P5",
    .status = "delivered",
    .summary = "Adds a bounded local observation harness for approved wall-clock scenario families without production load telemetry capacity claims or mutation authority.",
    .depends_on = &.{ "production-hardening-completion-audit", "production-capacity-planning", "wall-clock-benchmark-baselines" },
    .deliverables = &.{
        "scenario catalog",
        "bounded local observation command",
        "fake-runner observation math tests",
        "advisory review gates",
        "negative observation fixtures",
        "production telemetry capture handoff",
    },
    .evidence_sources = &.{
        "docs/superpowers/specs/2026-06-10-zigeffect-causal-load-test-observation-harness-design.md",
        "docs/superpowers/plans/2026-06-10-zigeffect-causal-load-test-observation-harness-implementation.md",
        "packages/zigeffect/tools/causal_load_test_observation_harness.zig",
        "packages/zigeffect/docs/load-test-observation-harness.md",
        "packages/zigeffect/docs/production-hardening-completion-audit.md",
    },
    .branch = "codex/zigeffect-causal-load-test-observation-harness",
    .agent_guidance = "Use causal-load-test-observation-harness for local advisory observations only; keep production telemetry and reviewed capacity sizing future.",
},
```

- [ ] Update backlog recommendation constants:

```zig
pub const recommendation = "start-production-telemetry-capture-design";
pub const recommended_next_branch = "codex/zigeffect-causal-production-telemetry-capture-design";
```

- [ ] Run:

```sh
cd packages/zigeffect
zig test tools/causal_schema_governance.zig
zig test tools/causal_production_hardening_backlog.zig
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
```

Expected: schema count is `50`; backlog recommendation points to production
telemetry capture design.

## Task 6: Documentation And Roadmap Updates

**Files:**

- Create `packages/zigeffect/docs/load-test-observation-harness.md`
- Modify docs listed in Files And Responsibilities

- [ ] Add dedicated doc with these sections:
  - `Command`
  - `Authority Boundary`
  - `Scenario Catalog`
  - `Observation Mode`
  - `Review Gates`
  - `Negative Observation Fixtures`
  - `Handoff`
  - `Verification`

- [ ] Update README with the new command after completion audit.

- [ ] Update operations command map and add a `Load-Test Observation Harness`
  section after `Production Hardening Completion Audit`.

- [ ] Update schema-governance docs with the schema and `local-observation`
  posture.

- [ ] Update production-hardening backlog docs to mark the harness delivered
  and move the next branch to production telemetry capture design.

- [ ] Update completion-audit docs to say the observation harness branch is now
  delivered and hands off to telemetry capture design.

- [ ] Update roadmap and master roadmap:
  - mark `codex/zigeffect-causal-load-test-observation-harness` delivered;
  - add `codex/zigeffect-causal-production-telemetry-capture-design` as the
    current next branch.

## Task 7: Full Verification And Commit

**Files:**

- All files touched by Tasks 1-6

- [ ] Format Zig:

```sh
zig fmt packages/zigeffect/tools/causal_load_test_observation_harness.zig packages/zigeffect/build.zig packages/zigeffect/tools/causal_schema_governance.zig packages/zigeffect/tools/causal_production_hardening_backlog.zig
```

- [ ] Run focused verification:

```sh
cd packages/zigeffect
zig test tools/causal_load_test_observation_harness.zig
zig build causal-load-test-observation-harness
zig build causal-load-test-observation-harness -- --format json
zig build causal-load-test-observation-harness -- observe app-request-trace --iterations 1 --format json
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
```

- [ ] Run broad verification:

```sh
zig build examples
zig build test
cd ../..
bun run zigeffect:workbench:test
bun run zigeffect:workbench:typecheck
bun run zigeffect:workbench:build
bun run check
bun run zig:test
git diff --check
```

- [ ] Stage only this branch's files, leaving pre-existing unrelated dirty files
  unstaged:

```sh
git add \
  docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md \
  docs/superpowers/specs/2026-06-10-zigeffect-causal-load-test-observation-harness-design.md \
  docs/superpowers/plans/2026-06-10-zigeffect-causal-load-test-observation-harness-implementation.md \
  packages/zigeffect/README.md \
  packages/zigeffect/build.zig \
  packages/zigeffect/docs/load-test-observation-harness.md \
  packages/zigeffect/docs/operations.md \
  packages/zigeffect/docs/production-hardening-backlog.md \
  packages/zigeffect/docs/production-hardening-completion-audit.md \
  packages/zigeffect/docs/roadmap.md \
  packages/zigeffect/docs/schema-governance.md \
  packages/zigeffect/tools/causal_load_test_observation_harness.zig \
  packages/zigeffect/tools/causal_production_hardening_backlog.zig \
  packages/zigeffect/tools/causal_schema_governance.zig
```

- [ ] Commit:

```sh
git commit -m "feat(zigeffect): add load-test observation harness"
```

Expected final branch commits:

- `docs(zigeffect): design load-test observation harness`
- `docs(zigeffect): plan load-test observation harness`
- `feat(zigeffect): add load-test observation harness`
