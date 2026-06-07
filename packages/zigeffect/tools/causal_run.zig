const std = @import("std");
const fx = @import("zigeffect");

pub const artifact_dir = ".zig-cache/causal-artifacts";

pub const Expectation = enum {
    expected_pass,
    expected_failure,
};

pub const RuntimeSubsystem = enum {
    command_harness,
    service_resolution,
    scope_lifecycle,
    fiber_runtime,
    schedule_retry,
    package,
};

pub const ExpectedFindingsPolicy = enum {
    none_when_command_passes,
    failure_artifact_on_command_failure,
    expected_failure_command_emits_assertion,
};

pub const Invariant = struct {
    id: []const u8,
    subsystem: RuntimeSubsystem,
    finding_kind: ?fx.CausalFindingKind,
    rule: []const u8,
    detection_query: []const u8,
};

pub const Scenario = struct {
    slug: []const u8,
    label: []const u8,
    expectation: Expectation,
    owner: RuntimeSubsystem,
    purpose: []const u8,
    finding_policy: ExpectedFindingsPolicy,
    invariant_ids: []const []const u8,
    argv: []const []const u8,
};

pub const CommandResult = struct {
    term: std.process.Child.Term,
    stdout: []const u8,
    stderr: []const u8,
};

pub const ArtifactPaths = struct {
    report_path: []const u8,
    json_path: []const u8,
    dot_path: []const u8,

    pub fn deinit(self: ArtifactPaths, allocator: std.mem.Allocator) void {
        allocator.free(self.report_path);
        allocator.free(self.json_path);
        allocator.free(self.dot_path);
    }
};

pub const CommandArtifacts = struct {
    report_path: []const u8,
    json_path: []const u8,
    dot_path: []const u8,
    report: []const u8,
    json: []const u8,
    dot: []const u8,
    finding_count: usize,

    pub fn deinit(self: CommandArtifacts, allocator: std.mem.Allocator) void {
        allocator.free(self.report_path);
        allocator.free(self.json_path);
        allocator.free(self.dot_path);
        allocator.free(self.report);
        allocator.free(self.json);
        allocator.free(self.dot);
    }
};

const missing_service_compile_fail_argv: []const []const u8 = &.{
    "zig",
    "build-exe",
    "--dep",
    "zigeffect",
    "-Mroot=test/compile_fail/missing_service.zig",
    "-Mzigeffect=src/zigeffect.zig",
    "-fno-emit-bin",
    "--cache-dir",
    ".zig-cache/causal-run-compile-fail-cache",
    "--global-cache-dir",
    ".zig-cache/causal-run-global-cache",
};

const package_tests_argv: []const []const u8 = &.{
    "zig",
    "build",
    "--cache-dir",
    ".zig-cache/causal-dev-test-cache",
    "--global-cache-dir",
    ".zig-cache/causal-dev-test-global-cache",
    "test-raw",
};

const package_tests_failure_fixture_argv: []const []const u8 = &.{
    "zig",
    "test",
    "test/fixtures/causal_package_failure.zig",
    "--cache-dir",
    ".zig-cache/causal-run-package-failure-fixture-cache",
    "--global-cache-dir",
    ".zig-cache/causal-run-global-cache",
};

const causal_scoped_fiber_argv: []const []const u8 = &.{
    "zig",
    "test",
    "--dep",
    "zigeffect",
    "-Mroot=examples/causal_scoped_fiber.zig",
    "-Mzigeffect=src/zigeffect.zig",
    "--cache-dir",
    ".zig-cache/causal-run-scoped-fiber-cache",
    "--global-cache-dir",
    ".zig-cache/causal-run-global-cache",
};

const causal_retry_exhaustion_argv: []const []const u8 = &.{
    "zig",
    "test",
    "--dep",
    "zigeffect",
    "-Mroot=examples/causal_retry_exhaustion.zig",
    "-Mzigeffect=src/zigeffect.zig",
    "--cache-dir",
    ".zig-cache/causal-run-retry-exhaustion-cache",
    "--global-cache-dir",
    ".zig-cache/causal-run-global-cache",
};

const causal_cleanup_failure_argv: []const []const u8 = &.{
    "zig",
    "test",
    "--dep",
    "zigeffect",
    "-Mroot=examples/causal_cleanup_failure.zig",
    "-Mzigeffect=src/zigeffect.zig",
    "--cache-dir",
    ".zig-cache/causal-run-cleanup-failure-cache",
    "--global-cache-dir",
    ".zig-cache/causal-run-global-cache",
};

const causal_missing_config_argv: []const []const u8 = &.{
    "zig",
    "test",
    "--dep",
    "zigeffect",
    "-Mroot=examples/causal_missing_config.zig",
    "-Mzigeffect=src/zigeffect.zig",
    "--cache-dir",
    ".zig-cache/causal-run-missing-config-cache",
    "--global-cache-dir",
    ".zig-cache/causal-run-global-cache",
};

const missing_service_invariants: []const []const u8 = &.{
    "command-failure-is-causal-evidence",
    "service-requirement-has-provider",
};

const package_test_invariants: []const []const u8 = &.{
    "package-tests-are-development-gate",
    "command-failure-is-causal-evidence",
};

const scoped_fiber_invariants: []const []const u8 = &.{
    "scoped-fiber-must-finish-before-scope-close",
};

const retry_exhaustion_invariants: []const []const u8 = &.{
    "retry-exhaustion-is-recorded",
};

const cleanup_failure_invariants: []const []const u8 = &.{
    "finalizer-failures-are-causal-evidence",
    "resource-finalized-after-acquire",
};

const missing_config_invariants: []const []const u8 = &.{
    "service-requirement-has-provider",
};

const scenario_registry: []const Scenario = &.{
    .{
        .slug = "missing-service-compile-fail",
        .label = "Missing Service Compile Fail",
        .expectation = .expected_failure,
        .owner = .service_resolution,
        .purpose = "prove missing service diagnostics become causal command evidence",
        .finding_policy = .expected_failure_command_emits_assertion,
        .invariant_ids = missing_service_invariants,
        .argv = missing_service_compile_fail_argv,
    },
    .{
        .slug = "package-tests",
        .label = "Package Tests",
        .expectation = .expected_pass,
        .owner = .package,
        .purpose = "run the broad zigeffect test suite with causal failure capture",
        .finding_policy = .failure_artifact_on_command_failure,
        .invariant_ids = package_test_invariants,
        .argv = package_tests_argv,
    },
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
    .{
        .slug = "causal-scoped-fiber",
        .label = "Causal Scoped Fiber",
        .expectation = .expected_pass,
        .owner = .fiber_runtime,
        .purpose = "verify scoped fiber interruption causal examples stay healthy",
        .finding_policy = .failure_artifact_on_command_failure,
        .invariant_ids = scoped_fiber_invariants,
        .argv = causal_scoped_fiber_argv,
    },
    .{
        .slug = "causal-retry-exhaustion",
        .label = "Causal Retry Exhaustion",
        .expectation = .expected_pass,
        .owner = .schedule_retry,
        .purpose = "verify retry exhaustion causal examples stay healthy",
        .finding_policy = .failure_artifact_on_command_failure,
        .invariant_ids = retry_exhaustion_invariants,
        .argv = causal_retry_exhaustion_argv,
    },
    .{
        .slug = "causal-cleanup-failure",
        .label = "Causal Cleanup Failure",
        .expectation = .expected_pass,
        .owner = .scope_lifecycle,
        .purpose = "verify cleanup failure causal examples stay healthy",
        .finding_policy = .failure_artifact_on_command_failure,
        .invariant_ids = cleanup_failure_invariants,
        .argv = causal_cleanup_failure_argv,
    },
    .{
        .slug = "causal-missing-config",
        .label = "Causal Missing Config",
        .expectation = .expected_pass,
        .owner = .service_resolution,
        .purpose = "verify missing config causal examples stay healthy",
        .finding_policy = .failure_artifact_on_command_failure,
        .invariant_ids = missing_config_invariants,
        .argv = causal_missing_config_argv,
    },
};

const invariant_catalog: []const Invariant = &.{
    .{
        .id = "resource-finalized-after-acquire",
        .subsystem = .scope_lifecycle,
        .finding_kind = fx.CausalFindingKind.resource_acquired_without_finalization,
        .rule = "Every resource_acquired event must have a matching resource_finalized event in the same scope.",
        .detection_query = "causal.resources {scope_id}",
    },
    .{
        .id = "scoped-fiber-must-finish-before-scope-close",
        .subsystem = .fiber_runtime,
        .finding_kind = fx.CausalFindingKind.fiber_pending_after_scope_close,
        .rule = "Scoped fibers must complete, join, or interrupt before their owning scope closes.",
        .detection_query = "causal.fibers pending",
    },
    .{
        .id = "finalizer-failures-are-causal-evidence",
        .subsystem = .scope_lifecycle,
        .finding_kind = fx.CausalFindingKind.finalizer_failure,
        .rule = "Finalizer failures must be preserved in the causal graph rather than hidden by cleanup.",
        .detection_query = "causal.cause {event_id}",
    },
    .{
        .id = "retry-exhaustion-is-recorded",
        .subsystem = .schedule_retry,
        .finding_kind = fx.CausalFindingKind.retry_budget_exhausted,
        .rule = "Retry schedules must record exhaustion decisions with enough evidence for follow-up queries.",
        .detection_query = "causal.retries {run_id}",
    },
    .{
        .id = "service-requirement-has-provider",
        .subsystem = .service_resolution,
        .finding_kind = fx.CausalFindingKind.service_requirement_without_provider,
        .rule = "Required services must have matching providers or explicit missing-service diagnostics.",
        .detection_query = "causal.requirements {run_id}",
    },
    .{
        .id = "command-failure-is-causal-evidence",
        .subsystem = .command_harness,
        .finding_kind = fx.CausalFindingKind.assertion_failure,
        .rule = "Development command failures must emit assertion findings with scenario and command context.",
        .detection_query = "causal.lineage {event_id}",
    },
    .{
        .id = "package-tests-are-development-gate",
        .subsystem = .package,
        .finding_kind = null,
        .rule = "The package test suite remains the broad local regression gate and should be run through causal-dev-test during runtime work.",
        .detection_query = "zig build causal-dev-test",
    },
};

pub fn scenarioRegistry() []const Scenario {
    return scenario_registry;
}

pub fn scenarioByName(name: []const u8) error{UnknownScenario}!Scenario {
    for (scenario_registry) |scenario| {
        if (std.mem.eql(u8, name, scenario.slug)) return scenario;
    }
    return error.UnknownScenario;
}

pub fn invariantCatalog() []const Invariant {
    return invariant_catalog;
}

pub fn invariantById(id: []const u8) error{UnknownInvariant}!Invariant {
    for (invariant_catalog) |invariant| {
        if (std.mem.eql(u8, id, invariant.id)) return invariant;
    }
    return error.UnknownInvariant;
}

pub fn artifactPaths(allocator: std.mem.Allocator, slug: []const u8) std.mem.Allocator.Error!ArtifactPaths {
    const report_path = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-{s}.txt", .{ artifact_dir, slug });
    errdefer allocator.free(report_path);
    const json_path = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-{s}.json", .{ artifact_dir, slug });
    errdefer allocator.free(json_path);
    const dot_path = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-{s}.dot", .{ artifact_dir, slug });
    errdefer allocator.free(dot_path);

    return .{
        .report_path = report_path,
        .json_path = json_path,
        .dot_path = dot_path,
    };
}

pub fn formatCatalog(allocator: std.mem.Allocator) std.mem.Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect causal scenario registry\n");
    try output.print(allocator, "scenarios: {d}\n", .{scenario_registry.len});
    for (scenario_registry) |scenario| {
        const paths = try artifactPaths(allocator, scenario.slug);
        defer paths.deinit(allocator);

        try output.print(allocator, "- scenario {s}\n", .{scenario.slug});
        try output.print(allocator, "  owner: {s}\n", .{@tagName(scenario.owner)});
        try output.print(allocator, "  purpose: {s}\n", .{scenario.purpose});
        try output.print(allocator, "  expectation: {s}\n", .{@tagName(scenario.expectation)});
        try output.print(allocator, "  finding policy: {s}\n", .{@tagName(scenario.finding_policy)});
        try output.print(allocator, "  report: {s}\n", .{paths.report_path});
        try output.print(allocator, "  json: {s}\n", .{paths.json_path});
        try output.print(allocator, "  dot: {s}\n", .{paths.dot_path});
        try output.appendSlice(allocator, "  invariants:");
        for (scenario.invariant_ids) |id| {
            try output.print(allocator, " {s}", .{id});
        }
        try output.append(allocator, '\n');
    }

    try output.appendSlice(allocator, "\ninvariant catalog\n");
    try output.print(allocator, "invariants: {d}\n", .{invariant_catalog.len});
    for (invariant_catalog) |invariant| {
        const finding = if (invariant.finding_kind) |kind| @tagName(kind) else "none";
        try output.print(allocator, "- invariant {s}\n", .{invariant.id});
        try output.print(allocator, "  subsystem: {s}\n", .{@tagName(invariant.subsystem)});
        try output.print(allocator, "  finding: {s}\n", .{finding});
        try output.print(allocator, "  query: {s}\n", .{invariant.detection_query});
        try output.print(allocator, "  rule: {s}\n", .{invariant.rule});
    }

    return output.toOwnedSlice(allocator);
}

pub fn buildCommandArtifacts(
    allocator: std.mem.Allocator,
    scenario: Scenario,
    result: CommandResult,
) std.mem.Allocator.Error!CommandArtifacts {
    const paths = try artifactPaths(allocator, scenario.slug);
    errdefer paths.deinit(allocator);

    var store = fx.CausalStore.init(allocator);
    defer store.deinit();

    const run_id = store.nextRunId();
    const run_started = try store.record(.{
        .kind = .run_started,
        .run_id = run_id,
        .label = scenario.slug,
        .type_name = "CausalCommandScenario",
        .status = "started",
    });
    const command_started = try store.record(.{
        .kind = .effect_started,
        .run_id = run_id,
        .parent_id = run_started,
        .label = scenario.label,
        .type_name = "DevelopmentCommand",
        .status = "started",
        .redacted_detail = scenario.slug,
    });

    if (commandFailed(result.term)) {
        const detail = try commandDetail(allocator, result);
        defer allocator.free(detail);

        const assertion = try store.record(.{
            .kind = .assertion_recorded,
            .run_id = run_id,
            .parent_id = command_started,
            .label = scenario.slug,
            .type_name = "CommandExit",
            .status = "failure",
            .redacted_detail = detail,
        });
        _ = try store.record(.{
            .kind = .exit_recorded,
            .run_id = run_id,
            .parent_id = assertion,
            .label = scenario.slug,
            .type_name = "CausalCommandRun",
            .status = "failure",
            .redacted_detail = "command failure captured for agent analysis",
        });
    } else {
        _ = try store.record(.{
            .kind = .exit_recorded,
            .run_id = run_id,
            .parent_id = command_started,
            .label = scenario.slug,
            .type_name = "CausalCommandRun",
            .status = "success",
            .redacted_detail = "command completed successfully for agent analysis",
        });
    }

    var findings = try store.findings(allocator);
    defer findings.deinit();
    const finding_count = findings.items.len;

    const report_label = try std.fmt.allocPrint(allocator, "zigeffect command: {s}", .{scenario.slug});
    defer allocator.free(report_label);

    const report = try fx.formatCausalCiReport(allocator, report_label, &store);
    errdefer allocator.free(report);
    const json = try fx.formatCausalJson(allocator, &store);
    errdefer allocator.free(json);
    const dot = try fx.formatCausalDot(allocator, &store);
    errdefer allocator.free(dot);

    return .{
        .report_path = paths.report_path,
        .json_path = paths.json_path,
        .dot_path = paths.dot_path,
        .report = report,
        .json = json,
        .dot = dot,
        .finding_count = finding_count,
    };
}

pub fn buildFailureArtifacts(
    allocator: std.mem.Allocator,
    scenario: Scenario,
    result: CommandResult,
) std.mem.Allocator.Error!CommandArtifacts {
    return buildCommandArtifacts(allocator, scenario, result);
}

fn commandDetail(allocator: std.mem.Allocator, result: CommandResult) std.mem.Allocator.Error![]const u8 {
    const output = if (result.stderr.len > 0) result.stderr else result.stdout;
    const excerpt = output[0..@min(output.len, 240)];
    return switch (result.term) {
        .exited => |code| std.fmt.allocPrint(allocator, "command exited with code {d}; output: {s}", .{ code, excerpt }),
        .signal => |signal| std.fmt.allocPrint(allocator, "command terminated by signal {d}; output: {s}", .{ @intFromEnum(signal), excerpt }),
        .stopped => |signal| std.fmt.allocPrint(allocator, "command stopped by signal {d}; output: {s}", .{ @intFromEnum(signal), excerpt }),
        .unknown => |status| std.fmt.allocPrint(allocator, "command ended with unknown status {d}; output: {s}", .{ status, excerpt }),
    };
}

fn commandFailed(term: std.process.Child.Term) bool {
    return switch (term) {
        .exited => |code| code != 0,
        else => true,
    };
}

fn argvContains(args: []const []const u8, expected: []const u8) bool {
    for (args) |arg| {
        if (std.mem.eql(u8, arg, expected)) return true;
    }
    return false;
}

fn shouldWriteArtifacts(scenario: Scenario, term: std.process.Child.Term) bool {
    return commandFailed(term) or scenario.expectation == .expected_failure;
}

fn writeArtifact(io: std.Io, path: []const u8, contents: []const u8) !void {
    const slash = std.mem.lastIndexOfScalar(u8, path, '/') orelse return error.InvalidArtifactPath;
    const cwd = std.Io.Dir.cwd();
    try cwd.createDirPath(io, path[0..slash]);
    try cwd.writeFile(io, .{ .sub_path = path, .data = contents });
}

fn writeArtifacts(io: std.Io, artifacts: CommandArtifacts) !void {
    try writeArtifact(io, artifacts.report_path, artifacts.report);
    try writeArtifact(io, artifacts.json_path, artifacts.json);
    try writeArtifact(io, artifacts.dot_path, artifacts.dot);
}

fn usage() []const u8 {
    return "usage: zig build causal-run -- <catalog|scenario>\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-run error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 2) failUsage(error.MissingScenario);

    if (std.mem.eql(u8, args[1], "catalog")) {
        const catalog = try formatCatalog(allocator);
        defer allocator.free(catalog);
        std.debug.print("{s}", .{catalog});
        return;
    }

    const scenario = scenarioByName(args[1]) catch |err| failUsage(err);

    const result = std.process.run(allocator, init.io, .{
        .argv = scenario.argv,
        .stdout_limit = .limited(64 * 1024),
        .stderr_limit = .limited(64 * 1024),
    }) catch |err| {
        const artifacts = try buildFailureArtifacts(allocator, scenario, .{
            .term = .{ .unknown = 0 },
            .stdout = "",
            .stderr = @errorName(err),
        });
        defer artifacts.deinit(allocator);
        try writeArtifacts(init.io, artifacts);
        std.debug.print(
            "zigeffect causal command artifacts written:\n- {s}\n- {s}\n- {s}\nfindings: {d}\n",
            .{ artifacts.report_path, artifacts.json_path, artifacts.dot_path, artifacts.finding_count },
        );
        return err;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (shouldWriteArtifacts(scenario, result.term)) {
        const artifacts = try buildFailureArtifacts(allocator, scenario, .{
            .term = result.term,
            .stdout = result.stdout,
            .stderr = result.stderr,
        });
        defer artifacts.deinit(allocator);
        try writeArtifacts(init.io, artifacts);
        std.debug.print(
            "zigeffect causal command artifacts written:\n- {s}\n- {s}\n- {s}\nfindings: {d}\n",
            .{ artifacts.report_path, artifacts.json_path, artifacts.dot_path, artifacts.finding_count },
        );
    }

    const failed = commandFailed(result.term);
    switch (scenario.expectation) {
        .expected_pass => {
            if (failed) std.process.exit(1);
        },
        .expected_failure => {
            if (!failed) {
                std.debug.print("causal-run expected scenario '{s}' to fail, but it passed\n", .{scenario.slug});
                std.process.exit(1);
            }
        },
    }
}

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

test "package test failure artifacts use package paths and causal ci report" {
    const scenario = try scenarioByName("package-tests");
    const artifacts = try buildFailureArtifacts(std.testing.allocator, scenario, .{
        .term = .{ .exited = 1 },
        .stdout = "",
        .stderr = "package test failure",
    });
    defer artifacts.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), artifacts.finding_count);
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-package-tests.txt",
        artifacts.report_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-package-tests.json",
        artifacts.json_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-package-tests.dot",
        artifacts.dot_path,
    );
    try std.testing.expect(std.mem.indexOf(u8, artifacts.report, "zigeffect causal ci report") != null);
    try std.testing.expect(std.mem.indexOf(u8, artifacts.report, "program: zigeffect command: package-tests") != null);
    try std.testing.expect(std.mem.indexOf(u8, artifacts.report, "finding event=3 kind=assertion_failure") != null);
    try std.testing.expect(std.mem.indexOf(u8, artifacts.report, "- causal.cause 3") != null);
    try std.testing.expect(std.mem.indexOf(u8, artifacts.json, "\"event_taxonomy_version\": 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, artifacts.json, "package test failure") != null);
}

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

test "scenario registry records owners purposes policies invariants and paths" {
    const scenarios = scenarioRegistry();
    try std.testing.expect(scenarios.len >= 6);

    const missing = try scenarioByName("missing-service-compile-fail");
    try std.testing.expectEqual(RuntimeSubsystem.service_resolution, missing.owner);
    try std.testing.expectEqual(ExpectedFindingsPolicy.expected_failure_command_emits_assertion, missing.finding_policy);
    try std.testing.expect(missing.purpose.len > 0);
    try std.testing.expect(missing.invariant_ids.len >= 2);

    const scoped_fiber = try scenarioByName("causal-scoped-fiber");
    try std.testing.expectEqual(RuntimeSubsystem.fiber_runtime, scoped_fiber.owner);
    try std.testing.expectEqual(Expectation.expected_pass, scoped_fiber.expectation);

    const paths = try artifactPaths(std.testing.allocator, scoped_fiber.slug);
    defer paths.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-causal-scoped-fiber.json",
        paths.json_path,
    );
}

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

test "package test scenario targets raw package test step" {
    const scenario = try scenarioByName("package-tests");
    try std.testing.expect(argvContains(scenario.argv, "test-raw"));
    try std.testing.expect(!argvContains(scenario.argv, "test"));
}

test "invariant catalog maps findings to runtime rules" {
    const invariant = try invariantById("scoped-fiber-must-finish-before-scope-close");
    try std.testing.expectEqual(RuntimeSubsystem.fiber_runtime, invariant.subsystem);
    try std.testing.expectEqual(fx.CausalFindingKind.fiber_pending_after_scope_close, invariant.finding_kind.?);
    try std.testing.expect(std.mem.indexOf(u8, invariant.detection_query, "causal.fibers pending") != null);
}

test "catalog output lists scenarios invariants and artifact paths" {
    const catalog = try formatCatalog(std.testing.allocator);
    defer std.testing.allocator.free(catalog);

    try std.testing.expect(std.mem.indexOf(u8, catalog, "zigeffect causal scenario registry") != null);
    try std.testing.expect(std.mem.indexOf(u8, catalog, "scenario missing-service-compile-fail") != null);
    try std.testing.expect(std.mem.indexOf(u8, catalog, "owner: service_resolution") != null);
    try std.testing.expect(std.mem.indexOf(u8, catalog, "scenario causal-scoped-fiber") != null);
    try std.testing.expect(std.mem.indexOf(u8, catalog, "invariant scoped-fiber-must-finish-before-scope-close") != null);
    try std.testing.expect(std.mem.indexOf(u8, catalog, ".zig-cache/causal-artifacts/zigeffect-causal-causal-scoped-fiber.json") != null);
}
