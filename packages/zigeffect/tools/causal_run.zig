const std = @import("std");
const fx = @import("zigeffect");

pub const artifact_dir = ".zig-cache/causal-artifacts";

pub const Expectation = enum {
    expected_pass,
    expected_failure,
};

pub const Scenario = struct {
    slug: []const u8,
    label: []const u8,
    expectation: Expectation,
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
    "test",
};

pub fn scenarioByName(name: []const u8) error{UnknownScenario}!Scenario {
    if (std.mem.eql(u8, name, "missing-service-compile-fail")) {
        return .{
            .slug = "missing-service-compile-fail",
            .label = "Missing Service Compile Fail",
            .expectation = .expected_failure,
            .argv = missing_service_compile_fail_argv,
        };
    }
    if (std.mem.eql(u8, name, "package-tests")) {
        return .{
            .slug = "package-tests",
            .label = "Package Tests",
            .expectation = .expected_pass,
            .argv = package_tests_argv,
        };
    }
    return error.UnknownScenario;
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

pub fn buildFailureArtifacts(
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
    return "usage: zig build causal-run -- <missing-service-compile-fail|package-tests>\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-run error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 2) failUsage(error.MissingScenario);

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
