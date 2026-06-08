# zigeffect Causal Test Matrix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the M2 causal test matrix: coverage-domain metadata, `zig build causal-test-matrix`, shared causal assertion helpers, and documentation for bug-to-scenario graduation.

**Architecture:** Extend the existing scenario registry rather than creating a second source of truth. Add one focused matrix tool that validates registry consistency and formats domain coverage; add one package test support helper for structural event/finding assertions; register the existing `causal_readiness.zig` example as the observability scenario.

**Tech Stack:** Zig stdlib, existing `packages/zigeffect/build.zig` tool modules, `std.testing`, Bun repo verification commands.

---

## File Map

- Modify: `packages/zigeffect/tools/causal_run.zig`
  - Add `CausalCoverageDomain`, scenario `coverage_domains`, coverage helpers,
    the `causal-readiness` scenario registration, and registry consistency
    tests.
- Create: `packages/zigeffect/tools/causal_test_matrix.zig`
  - Build domain coverage rows from `causal_run.scenarioRegistry()`, validate
    duplicate ids and unknown invariant references, and format the text matrix.
- Modify: `packages/zigeffect/build.zig`
  - Add the causal test matrix tool module, tests, executable, build step, and
    examples/test-step dependencies.
- Create: `packages/zigeffect/test/support/causal_assertions.zig`
  - Shared structural assertions for causal event patterns, event sequences,
    findings, and no-findings checks.
- Modify: `packages/zigeffect/test/all_test.zig`
  - Import the causal assertion helper tests.
- Modify: `packages/zigeffect/test/runtime_test.zig`
  - Replace local event sequence helper usage with shared assertions.
- Modify: `packages/zigeffect/test/fiber_test.zig`
  - Replace local event sequence helper usage with shared assertions.
- Modify: `packages/zigeffect/test/layer_test.zig`
  - Replace local event lookup helper usage with shared assertions.
- Modify: `packages/zigeffect/test/schedule_test.zig`
  - Replace schedule decision lookup if the `detail_contains` pattern remains
    simple.
- Modify: `packages/zigeffect/docs/causal-scenarios.md`
  - Document the matrix command, status vocabulary, current matrix, and failure
    graduation guide.
- Modify: `packages/zigeffect/docs/agent-guide.md`
  - Tell agents to consult the matrix before proposing new scenarios.
- Modify: `packages/zigeffect/README.md`
  - Add the new command to the zigeffect causal tooling overview.
- Modify: `packages/zigeffect/docs/roadmap.md`
  - Mark the M2 test matrix as active or delivered.
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
  - Update the progress ledger and M2 status.

## Implementation Constraints

- Do not add a second scenario registry.
- Do not make partial or missing coverage fail the command in this milestone.
- Do not write success artifacts for all passing scenarios.
- Do not claim complete config/cause coverage unless a named invariant or
  dedicated scenario proves it.
- Keep exact event-order checks only where ordering is part of the runtime
  contract.
- Register `examples/causal_readiness.zig` instead of creating a duplicate
  observability example.
- Leave the unrelated untracked durable-workflows roadmap file untouched.

---

### Task 1: Registry Coverage Metadata

**Files:**
- Modify: `packages/zigeffect/tools/causal_run.zig`

- [ ] **Step 1: Write failing tests for coverage domains and readiness registration**

Add these tests near the existing registry tests in
`packages/zigeffect/tools/causal_run.zig` before implementing the new field:

```zig
fn scenarioHasDomain(scenario: Scenario, domain: CausalCoverageDomain) bool {
    for (scenario.coverage_domains) |candidate| {
        if (candidate == domain) return true;
    }
    return false;
}

test "scenario registry declares causal coverage domains" {
    for (scenarioRegistry()) |scenario| {
        try std.testing.expect(scenario.coverage_domains.len > 0);
    }

    const scoped_fiber = try scenarioByName("causal-scoped-fiber");
    try std.testing.expect(scenarioHasDomain(scoped_fiber, .fiber));
    try std.testing.expect(scenarioHasDomain(scoped_fiber, .scope));

    const cleanup = try scenarioByName("causal-cleanup-failure");
    try std.testing.expect(scenarioHasDomain(cleanup, .resource));
    try std.testing.expect(scenarioHasDomain(cleanup, .cause));
}

test "causal readiness scenario is registered for observability coverage" {
    const scenario = try scenarioByName("causal-readiness");

    try std.testing.expectEqual(RuntimeSubsystem.observability, scenario.owner);
    try std.testing.expectEqual(Expectation.expected_pass, scenario.expectation);
    try std.testing.expect(scenarioHasDomain(scenario, .observability));
    try std.testing.expect(scenarioHasDomain(scenario, .layer));
    try std.testing.expect(scenarioHasDomain(scenario, .config));
    try std.testing.expect(argvContains(scenario.argv, "-Mroot=examples/causal_readiness.zig"));
}

test "scenario invariant references resolve" {
    for (scenarioRegistry()) |scenario| {
        for (scenario.invariant_ids) |id| {
            _ = try invariantById(id);
        }
    }
}
```

- [ ] **Step 2: Run RED**

Run:

```sh
zig build test --summary none
```

Expected: FAIL at compile time because `CausalCoverageDomain`,
`coverage_domains`, and `RuntimeSubsystem.observability` do not exist yet.

- [ ] **Step 3: Implement coverage domain types and scenario field**

In `packages/zigeffect/tools/causal_run.zig`, add the coverage-domain enum after
`RuntimeSubsystem` and add observability to `RuntimeSubsystem`:

```zig
pub const RuntimeSubsystem = enum {
    command_harness,
    service_resolution,
    scope_lifecycle,
    fiber_runtime,
    schedule_retry,
    observability,
    package,
};

pub const CausalCoverageDomain = enum {
    service,
    layer,
    scope,
    fiber,
    schedule,
    config,
    resource,
    retry,
    cause,
    observability,
};
```

Extend `Scenario`:

```zig
pub const Scenario = struct {
    slug: []const u8,
    label: []const u8,
    expectation: Expectation,
    owner: RuntimeSubsystem,
    purpose: []const u8,
    finding_policy: ExpectedFindingsPolicy,
    invariant_ids: []const []const u8,
    coverage_domains: []const CausalCoverageDomain,
    argv: []const []const u8,
};
```

- [ ] **Step 4: Add coverage-domain slices and readiness argv**

Add domain slices next to the invariant slices:

```zig
const missing_service_domains: []const CausalCoverageDomain = &.{ .service };
const package_test_domains: []const CausalCoverageDomain = &.{
    .service,
    .layer,
    .scope,
    .fiber,
    .schedule,
    .config,
    .resource,
    .retry,
    .cause,
    .observability,
};
const package_failure_fixture_domains: []const CausalCoverageDomain = &.{ .cause };
const scoped_fiber_domains: []const CausalCoverageDomain = &.{ .fiber, .scope };
const retry_exhaustion_domains: []const CausalCoverageDomain = &.{ .schedule, .retry };
const cleanup_failure_domains: []const CausalCoverageDomain = &.{ .scope, .resource, .cause };
const missing_config_domains: []const CausalCoverageDomain = &.{ .service, .layer, .config };
const readiness_domains: []const CausalCoverageDomain = &.{
    .service,
    .layer,
    .config,
    .resource,
    .cause,
    .observability,
};
```

Add the readiness command argv near the other example argv constants:

```zig
const causal_readiness_argv: []const []const u8 = &.{
    "zig",
    "test",
    "--dep",
    "zigeffect",
    "-Mroot=examples/causal_readiness.zig",
    "-Mzigeffect=src/zigeffect.zig",
    "--cache-dir",
    ".zig-cache/causal-run-readiness-cache",
    "--global-cache-dir",
    ".zig-cache/causal-run-global-cache",
};
```

- [ ] **Step 5: Add observability invariant and scenario fields**

Add an invariant:

```zig
.{
    .id = "observability-events-are-sampleable",
    .subsystem = .observability,
    .finding_kind = null,
    .rule = "Log, metric, and span causal events are sampleable observability evidence, not finding evidence.",
    .detection_query = "causal.lineage {event_id}",
},
```

Add the invariant id slice:

```zig
const readiness_invariants: []const []const u8 = &.{
    "service-requirement-has-provider",
    "resource-finalized-after-acquire",
    "observability-events-are-sampleable",
};
```

Set `.coverage_domains = ...` on every scenario and register:

```zig
.{
    .slug = "causal-readiness",
    .label = "Causal Readiness",
    .expectation = .expected_pass,
    .owner = .observability,
    .purpose = "verify app-shaped readiness, graph startup, and observability causal examples stay healthy",
    .finding_policy = .failure_artifact_on_command_failure,
    .invariant_ids = readiness_invariants,
    .coverage_domains = readiness_domains,
    .argv = causal_readiness_argv,
},
```

- [ ] **Step 6: Update catalog formatting for domains**

Inside `formatCatalog`, after printing invariants for a scenario, print coverage
domains:

```zig
try output.appendSlice(allocator, "  coverage:");
for (scenario.coverage_domains) |domain| {
    try output.print(allocator, " {s}", .{@tagName(domain)});
}
try output.append(allocator, '\n');
```

Update the existing catalog test to expect:

```zig
try std.testing.expect(std.mem.indexOf(u8, catalog, "scenario causal-readiness") != null);
try std.testing.expect(std.mem.indexOf(u8, catalog, "coverage:") != null);
try std.testing.expect(std.mem.indexOf(u8, catalog, "observability-events-are-sampleable") != null);
```

- [ ] **Step 7: Run GREEN**

Run:

```sh
zig build test --summary none
```

Expected: PASS.

- [ ] **Step 8: Commit registry metadata**

```sh
git add packages/zigeffect/tools/causal_run.zig
git commit -m "feat(zigeffect): add causal coverage metadata"
```

---

### Task 2: Causal Test Matrix Command

**Files:**
- Create: `packages/zigeffect/tools/causal_test_matrix.zig`
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Write failing tests for matrix rows and formatting**

Create `packages/zigeffect/tools/causal_test_matrix.zig` with imports,
constants, tests, and references to the intended API:

```zig
const std = @import("std");
const causal_run = @import("causal_run");

pub const matrix_schema = "zigeffect.causal.test-matrix.v1";

test "matrix builds requested coverage domains from the scenario registry" {
    const matrix = try buildMatrix(std.testing.allocator);
    defer matrix.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 10), matrix.rows.len);
    try std.testing.expect(rowByDomain(matrix, .service) != null);
    try std.testing.expect(rowByDomain(matrix, .layer) != null);
    try std.testing.expect(rowByDomain(matrix, .scope) != null);
    try std.testing.expect(rowByDomain(matrix, .fiber) != null);
    try std.testing.expect(rowByDomain(matrix, .schedule) != null);
    try std.testing.expect(rowByDomain(matrix, .config) != null);
    try std.testing.expect(rowByDomain(matrix, .resource) != null);
    try std.testing.expect(rowByDomain(matrix, .retry) != null);
    try std.testing.expect(rowByDomain(matrix, .cause) != null);
    try std.testing.expect(rowByDomain(matrix, .observability) != null);

    const observability = rowByDomain(matrix, .observability).?;
    try std.testing.expectEqual(CoverageStatus.covered, observability.status);
    try std.testing.expect(contains(observability.scenarios, "causal-readiness"));
}

test "matrix formatter prints schema statuses scenarios and invariants" {
    const matrix = try buildMatrix(std.testing.allocator);
    defer matrix.deinit(std.testing.allocator);

    const text = try formatMatrix(std.testing.allocator, matrix);
    defer std.testing.allocator.free(text);

    try std.testing.expect(std.mem.indexOf(u8, text, "zigeffect causal test matrix") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "schema: zigeffect.causal.test-matrix.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "- domain observability") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "status: covered") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "scenarios: causal-readiness") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "invariants: observability-events-are-sampleable") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "- domain config") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "status: partial") != null);
}

test "matrix validation catches duplicate scenario and invariant ids" {
    try validateUniqueNames(&.{ "a", "b", "c" });
    try std.testing.expectError(error.DuplicateName, validateUniqueNames(&.{ "a", "b", "a" }));
}
```

- [ ] **Step 2: Wire matrix module tests into the build before implementation**

In `packages/zigeffect/build.zig`, after the causal run tool module/tests,
add:

```zig
const causal_test_matrix_tool_module = b.createModule(.{
    .root_source_file = b.path("tools/causal_test_matrix.zig"),
    .target = target,
    .optimize = optimize,
});
causal_test_matrix_tool_module.addImport("causal_run", causal_run_tool_module);

const causal_test_matrix_tool = b.addExecutable(.{
    .name = "zigeffect-causal-test-matrix",
    .root_module = causal_test_matrix_tool_module,
});
const run_causal_test_matrix_tool = b.addRunArtifact(causal_test_matrix_tool);
const causal_test_matrix_step = b.step("causal-test-matrix", "Print the zigeffect causal scenario coverage matrix");
causal_test_matrix_step.dependOn(&run_causal_test_matrix_tool.step);

const causal_test_matrix_tool_tests = b.addTest(.{
    .name = "zigeffect-causal-test-matrix-tests",
    .root_module = causal_test_matrix_tool_module,
});
const run_causal_test_matrix_tool_tests = b.addRunArtifact(causal_test_matrix_tool_tests);
test_step.dependOn(&run_causal_test_matrix_tool_tests.step);
```

Also add to `examples_step` near other causal tools:

```zig
examples_step.dependOn(&causal_test_matrix_tool.step);
examples_step.dependOn(&run_causal_test_matrix_tool_tests.step);
```

- [ ] **Step 3: Run RED**

Run:

```sh
zig build test --summary none
```

Expected: FAIL because `buildMatrix`, `formatMatrix`, `rowByDomain`,
`contains`, and `validateUniqueNames` are not implemented.

- [ ] **Step 4: Implement matrix types and static domain policy**

Add these types:

```zig
pub const CoverageStatus = enum {
    covered,
    partial,
    missing,
};

pub const DomainExpectation = struct {
    domain: causal_run.CausalCoverageDomain,
    status: CoverageStatus,
    note: []const u8,
};

pub const MatrixRow = struct {
    domain: causal_run.CausalCoverageDomain,
    status: CoverageStatus,
    scenarios: []const []const u8,
    invariants: []const []const u8,
    note: []const u8,
};

pub const Matrix = struct {
    rows: []MatrixRow,
    scenario_count: usize,
    invariant_count: usize,

    pub fn deinit(self: Matrix, allocator: std.mem.Allocator) void {
        for (self.rows) |row| {
            allocator.free(row.scenarios);
            allocator.free(row.invariants);
        }
        allocator.free(self.rows);
    }
};
```

Add the expectation catalog:

```zig
const domain_expectations: []const DomainExpectation = &.{
    .{ .domain = .service, .status = .covered, .note = "service requirements have compile-fail and runtime graph evidence" },
    .{ .domain = .layer, .status = .covered, .note = "layer graph startup and readiness scenarios record causal graph evidence" },
    .{ .domain = .scope, .status = .covered, .note = "scope close and cleanup scenarios assert causal lifecycle events" },
    .{ .domain = .fiber, .status = .covered, .note = "scoped fiber scenarios assert fork, interruption, and join causality" },
    .{ .domain = .schedule, .status = .covered, .note = "schedule decisions are asserted in retry scenarios and tests" },
    .{ .domain = .config, .status = .partial, .note = "config failures are covered through service/layer examples but need a named config invariant" },
    .{ .domain = .resource, .status = .covered, .note = "resource acquisition and finalization events are asserted directly" },
    .{ .domain = .retry, .status = .covered, .note = "retry exhaustion is recorded as causal schedule evidence" },
    .{ .domain = .cause, .status = .partial, .note = "cause evidence is present in cleanup/runtime tests but needs a dedicated cause invariant" },
    .{ .domain = .observability, .status = .covered, .note = "causal readiness records log, metric, and span observability events" },
};
```

- [ ] **Step 5: Implement matrix building helpers**

Implement helpers with ownership rules that match the tests:

```zig
fn scenarioCovers(scenario: causal_run.Scenario, domain: causal_run.CausalCoverageDomain) bool {
    for (scenario.coverage_domains) |candidate| {
        if (candidate == domain) return true;
    }
    return false;
}

fn invariantMatchesDomain(invariant: causal_run.Invariant, domain: causal_run.CausalCoverageDomain) bool {
    return switch (domain) {
        .service => invariant.subsystem == .service_resolution,
        .layer => invariant.subsystem == .service_resolution or invariant.subsystem == .scope_lifecycle,
        .scope => invariant.subsystem == .scope_lifecycle,
        .fiber => invariant.subsystem == .fiber_runtime,
        .schedule, .retry => invariant.subsystem == .schedule_retry,
        .config => invariant.subsystem == .service_resolution,
        .resource => invariant.subsystem == .scope_lifecycle,
        .cause => invariant.finding_kind != null,
        .observability => invariant.subsystem == .observability,
    };
}

fn collectScenarioNames(
    allocator: std.mem.Allocator,
    domain: causal_run.CausalCoverageDomain,
) ![]const []const u8 {
    var names = std.ArrayList([]const u8).empty;
    errdefer names.deinit(allocator);

    for (causal_run.scenarioRegistry()) |scenario| {
        if (scenarioCovers(scenario, domain)) {
            try names.append(allocator, scenario.slug);
        }
    }

    return names.toOwnedSlice(allocator);
}

fn collectInvariantNames(
    allocator: std.mem.Allocator,
    domain: causal_run.CausalCoverageDomain,
) ![]const []const u8 {
    var names = std.ArrayList([]const u8).empty;
    errdefer names.deinit(allocator);

    for (causal_run.invariantCatalog()) |invariant| {
        if (invariantMatchesDomain(invariant, domain)) {
            try names.append(allocator, invariant.id);
        }
    }

    return names.toOwnedSlice(allocator);
}
```

Then implement `buildMatrix`, `rowByDomain`, `contains`, and
`validateUniqueNames`.

- [ ] **Step 6: Implement validation of registry references**

Add:

```zig
fn validateRegistry() !void {
    var scenario_names: [32][]const u8 = undefined;
    var scenario_count: usize = 0;
    for (causal_run.scenarioRegistry()) |scenario| {
        if (scenario.coverage_domains.len == 0) return error.MissingCoverageDomain;
        scenario_names[scenario_count] = scenario.slug;
        scenario_count += 1;

        for (scenario.invariant_ids) |id| {
            _ = try causal_run.invariantById(id);
        }
    }
    try validateUniqueNames(scenario_names[0..scenario_count]);

    var invariant_names: [32][]const u8 = undefined;
    var invariant_count: usize = 0;
    for (causal_run.invariantCatalog()) |invariant| {
        invariant_names[invariant_count] = invariant.id;
        invariant_count += 1;
    }
    try validateUniqueNames(invariant_names[0..invariant_count]);
}
```

Call it at the start of `buildMatrix`.

- [ ] **Step 7: Implement text formatting and main**

Format output using only deterministic registry data:

```zig
pub fn formatMatrix(allocator: std.mem.Allocator, matrix: Matrix) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect causal test matrix\n");
    try output.print(allocator, "schema: {s}\n", .{matrix_schema});
    try output.print(allocator, "coverage domains: {d}\n", .{matrix.rows.len});
    try output.print(allocator, "scenarios: {d}\n", .{matrix.scenario_count});
    try output.print(allocator, "invariants: {d}\n", .{matrix.invariant_count});

    for (matrix.rows) |row| {
        try output.print(allocator, "\n- domain {s}\n", .{@tagName(row.domain)});
        try output.print(allocator, "  status: {s}\n", .{@tagName(row.status)});
        try output.appendSlice(allocator, "  scenarios:");
        for (row.scenarios) |scenario| try output.print(allocator, " {s}", .{scenario});
        try output.append(allocator, '\n');
        try output.appendSlice(allocator, "  invariants:");
        for (row.invariants) |invariant| try output.print(allocator, " {s}", .{invariant});
        try output.append(allocator, '\n');
        try output.print(allocator, "  notes: {s}\n", .{row.note});
    }

    return output.toOwnedSlice(allocator);
}

pub fn main(init: std.process.Init) !void {
    const matrix = try buildMatrix(init.gpa);
    defer matrix.deinit(init.gpa);

    const text = try formatMatrix(init.gpa, matrix);
    defer init.gpa.free(text);

    std.debug.print("{s}", .{text});
}
```

- [ ] **Step 8: Run GREEN**

Run:

```sh
zig build test --summary none
zig build causal-test-matrix
```

Expected: both PASS; the command prints all ten domains.

- [ ] **Step 9: Commit matrix command**

```sh
git add packages/zigeffect/tools/causal_test_matrix.zig packages/zigeffect/build.zig
git commit -m "feat(zigeffect): add causal test matrix command"
```

---

### Task 3: Shared Causal Assertion Helper

**Files:**
- Create: `packages/zigeffect/test/support/causal_assertions.zig`
- Modify: `packages/zigeffect/test/all_test.zig`

- [ ] **Step 1: Write failing helper tests**

Create `packages/zigeffect/test/support/causal_assertions.zig` with tests first:

```zig
const std = @import("std");
const fx = @import("zigeffect");

pub const EventPattern = struct {
    kind: fx.CausalEventKind,
    label: ?[]const u8 = null,
    type_name: ?[]const u8 = null,
    status: ?[]const u8 = null,
    detail_contains: ?[]const u8 = null,
};

test "causal assertions match event patterns and sequences" {
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    const run_id = store.nextRunId();
    const started = try store.record(.{ .kind = .run_started, .run_id = run_id, .label = "test-run" });
    _ = try store.record(.{
        .kind = .schedule_decision,
        .run_id = run_id,
        .parent_id = started,
        .label = "retry",
        .status = "exhausted",
        .redacted_detail = "attempt=2 delay_ms=null decision=exhausted",
    });

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();

    try expectEventSequence(snapshot, &.{ .run_started, .schedule_decision });
    const event = try expectEvent(snapshot, .{
        .kind = .schedule_decision,
        .label = "retry",
        .status = "exhausted",
        .detail_contains = "decision=exhausted",
    });
    try std.testing.expectEqual(started, event.parent_id.?);
}

test "causal assertions match findings and quiet stores" {
    var quiet = fx.CausalStore.init(std.testing.allocator);
    defer quiet.deinit();
    _ = try quiet.record(.{ .kind = .run_started, .label = "quiet" });
    try expectNoFindings(&quiet);

    var failing = fx.CausalStore.init(std.testing.allocator);
    defer failing.deinit();
    _ = try failing.record(.{
        .kind = .service_required,
        .type_name = @typeName(fx.Config),
        .status = "missing",
    });

    const finding = try expectFinding(&failing, .service_requirement_without_provider);
    try std.testing.expectEqual(fx.CausalFindingKind.service_requirement_without_provider, finding.kind);
    try std.testing.expect(finding.event_id > 0);
}
```

Import it from `packages/zigeffect/test/all_test.zig`:

```zig
_ = @import("support/causal_assertions.zig");
```

- [ ] **Step 2: Run RED**

Run:

```sh
zig build test --summary none
```

Expected: FAIL because `expectEventSequence`, `expectEvent`,
`expectNoFindings`, and `expectFinding` are not implemented.

- [ ] **Step 3: Implement event and finding helpers**

Add:

```zig
fn matchesOptional(actual: []const u8, expected: ?[]const u8) bool {
    if (expected) |value| return std.mem.eql(u8, actual, value);
    return true;
}

fn containsOptional(actual: []const u8, expected: ?[]const u8) bool {
    if (expected) |value| return std.mem.indexOf(u8, actual, value) != null;
    return true;
}

pub fn expectEvent(snapshot: fx.CausalSnapshot, pattern: EventPattern) !fx.CausalEvent {
    for (snapshot.events) |event| {
        if (event.kind != pattern.kind) continue;
        if (!matchesOptional(event.label, pattern.label)) continue;
        if (!matchesOptional(event.type_name, pattern.type_name)) continue;
        if (!matchesOptional(event.status, pattern.status)) continue;
        if (!containsOptional(event.redacted_detail, pattern.detail_contains)) continue;
        return event;
    }
    return error.ExpectedCausalEventMissing;
}

pub fn expectEventSequence(snapshot: fx.CausalSnapshot, expected: []const fx.CausalEventKind) !void {
    try std.testing.expectEqual(expected.len, snapshot.events.len);
    for (expected, 0..) |kind, index| {
        try std.testing.expectEqual(kind, snapshot.events[index].kind);
    }
}

pub fn expectFinding(store: *const fx.CausalStore, kind: fx.CausalFindingKind) !fx.CausalFinding {
    var findings = try store.findings(std.testing.allocator);
    defer findings.deinit();

    for (findings.items) |finding| {
        if (finding.kind == kind) {
            return .{
                .kind = finding.kind,
                .event_id = finding.event_id,
                .run_id = finding.run_id,
                .scope_id = finding.scope_id,
                .fiber_id = finding.fiber_id,
            };
        }
    }
    return error.ExpectedCausalFindingMissing;
}

pub fn expectNoFindings(store: *const fx.CausalStore) !void {
    var findings = try store.findings(std.testing.allocator);
    defer findings.deinit();
    if (findings.items.len != 0) return error.UnexpectedCausalFinding;
}
```

- [ ] **Step 4: Run GREEN**

Run:

```sh
zig build test --summary none
```

Expected: PASS.

- [ ] **Step 5: Commit helper**

```sh
git add packages/zigeffect/test/support/causal_assertions.zig packages/zigeffect/test/all_test.zig
git commit -m "test(zigeffect): add causal assertion helpers"
```

---

### Task 4: Adopt Shared Assertions In Core Tests

**Files:**
- Modify: `packages/zigeffect/test/runtime_test.zig`
- Modify: `packages/zigeffect/test/fiber_test.zig`
- Modify: `packages/zigeffect/test/layer_test.zig`
- Modify: `packages/zigeffect/test/schedule_test.zig`

- [ ] **Step 1: Convert runtime tests**

In `runtime_test.zig`, add:

```zig
const causal = @import("support/causal_assertions.zig");
```

Remove the local `expectCausalKinds` helper. Replace calls:

```zig
try expectCausalKinds(snapshot, &.{ ... });
```

with:

```zig
try causal.expectEventSequence(snapshot, &.{ ... });
```

For resource/finalizer tests, replace direct indexing where it improves clarity:

```zig
const acquired = try causal.expectEvent(snapshot, .{
    .kind = .resource_acquired,
    .type_name = @typeName(fixtures.TrackedResource),
});
const finalized = try causal.expectEvent(snapshot, .{
    .kind = .resource_finalized,
    .type_name = @typeName(fixtures.TrackedResource),
    .status = "success",
});
try std.testing.expectEqual(acquired.scope_id.?, finalized.scope_id.?);
try causal.expectNoFindings(&store);
```

- [ ] **Step 2: Run runtime tests**

Run:

```sh
zig build test --summary none
```

Expected: PASS.

- [ ] **Step 3: Convert fiber tests**

In `fiber_test.zig`, add:

```zig
const causal = @import("support/causal_assertions.zig");
```

Remove the local `expectCausalKinds` helper. Replace sequence checks and direct
event lookups with:

```zig
try causal.expectEventSequence(snapshot, &.{
    .fiber_forked,
    .scope_opened,
    .fiber_started,
    .scope_closed,
    .fiber_joined,
});

const joined = try causal.expectEvent(snapshot, .{
    .kind = .fiber_joined,
    .status = "success",
});
try std.testing.expectEqual(fiber.id, joined.fiber_id.?);
try causal.expectNoFindings(&store);
```

Keep direct index assertions when the ordering itself is the behavior under
test.

- [ ] **Step 4: Run fiber tests**

Run:

```sh
zig build test --summary none
```

Expected: PASS.

- [ ] **Step 5: Convert layer and schedule tests**

In `layer_test.zig`, add:

```zig
const causal = @import("support/causal_assertions.zig");
```

Remove the local `expectCausalEvent` helper and replace calls:

```zig
_ = try expectCausalEvent(snapshot, .service_provided, @typeName(fixtures.GraphLoggerEnv), @typeName(fx.Logger), "provided");
```

with:

```zig
_ = try causal.expectEvent(snapshot, .{
    .kind = .service_provided,
    .label = @typeName(fixtures.GraphLoggerEnv),
    .type_name = @typeName(fx.Logger),
    .status = "provided",
});
```

In `schedule_test.zig`, either keep the local helper if it is clearer or convert
it to:

```zig
_ = try causal.expectEvent(snapshot, .{
    .kind = .schedule_decision,
    .label = "retry-metrics",
    .detail_contains = "attempt=0 delay_ms=5 decision=retry",
});
```

- [ ] **Step 6: Run full package tests**

Run:

```sh
zig build test --summary none
```

Expected: PASS.

- [ ] **Step 7: Commit assertion adoption**

```sh
git add packages/zigeffect/test/runtime_test.zig packages/zigeffect/test/fiber_test.zig packages/zigeffect/test/layer_test.zig packages/zigeffect/test/schedule_test.zig
git commit -m "test(zigeffect): use shared causal assertions"
```

---

### Task 5: Documentation And Roadmap Updates

**Files:**
- Modify: `packages/zigeffect/docs/causal-scenarios.md`
- Modify: `packages/zigeffect/docs/agent-guide.md`
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] **Step 1: Update causal scenarios docs**

Add `zig build causal-test-matrix` to the command list near
`causal-catalog`:

````md
Print the scenario coverage matrix:

```sh
zig build causal-test-matrix
```
````

Add a "Coverage Matrix" section with the ten domains and status vocabulary:

```md
## Coverage Matrix

`zig build causal-test-matrix` reports causal scenario coverage by domain.
Statuses mean:

- `covered`: at least one scenario and invariant or structural assertion gives
  direct evidence for the domain.
- `partial`: the domain has useful evidence but needs a named invariant,
  dedicated scenario, or tighter assertion before it is complete.
- `missing`: no scenario declares the domain yet.
```

Add the failure graduation guide from the design doc.

- [ ] **Step 2: Update README and agent guide**

In `packages/zigeffect/README.md`, add a short command entry:

```md
- `zig build causal-test-matrix` prints the causal coverage matrix for service,
  layer, scope, fiber, schedule, config, resource, retry, cause, and
  observability domains.
```

In `packages/zigeffect/docs/agent-guide.md`, add:

```md
Before proposing a new scenario, run `zig build causal-test-matrix` and check
whether the failure belongs to an uncovered domain, a partial domain, or an
existing scenario/invariant.
```

- [ ] **Step 3: Update roadmap docs**

In `packages/zigeffect/docs/roadmap.md` and the master roadmap, mark M2 as the
active branch until the implementation is verified. After verification, update
the ledger to say:

```md
- M2 causal test matrix delivered:
  - coverage-domain metadata in the scenario registry;
  - `zig build causal-test-matrix`;
  - shared structural causal assertion helpers;
  - `causal-readiness` registered for observability coverage.
```

- [ ] **Step 4: Run docs/check verification**

Run:

```sh
git diff --check HEAD
zig build causal-test-matrix
zig build causal-catalog
```

Expected: PASS.

- [ ] **Step 5: Commit docs**

```sh
git add packages/zigeffect/docs/causal-scenarios.md packages/zigeffect/docs/agent-guide.md packages/zigeffect/README.md packages/zigeffect/docs/roadmap.md docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md
git commit -m "docs(zigeffect): document causal test matrix"
```

---

### Task 6: Final Verification And Merge

**Files:**
- No intended file edits unless verification exposes a bug.

- [ ] **Step 1: Run branch verification**

Run:

```sh
git diff --check HEAD
zig build causal-test-matrix
zig build causal-catalog
zig build causal-run -- causal-readiness
zig build examples
zig build test --summary none
bun run check
bun run zig:test
```

Expected: all PASS.

- [ ] **Step 2: Inspect git status**

Run:

```sh
git status --short --branch
```

Expected:

- branch is `codex/zigeffect-causal-test-matrix`;
- only intentional files are committed;
- unrelated `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
  remains untracked and unstaged.

- [ ] **Step 3: Merge to master**

Run:

```sh
git switch master
git merge --ff-only codex/zigeffect-causal-test-matrix
```

Expected: fast-forward merge succeeds.

- [ ] **Step 4: Run post-merge verification**

Run:

```sh
git diff --check HEAD
zig build causal-test-matrix
zig build causal-catalog
zig build examples
zig build test --summary none
bun run check
bun run zig:test
```

Expected: all PASS on `master`.

- [ ] **Step 5: Delete merged branch**

Run:

```sh
git branch -d codex/zigeffect-causal-test-matrix
```

Expected: branch deleted only after successful merge and verification.
