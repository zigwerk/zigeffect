const std = @import("std");
const causal_test = @import("causal_test");
const causal_compare = @import("causal_compare");
const causal_run = @import("causal_run");

const Phase = enum {
    baseline,
    after,
};

const PackageStatus = enum {
    pass,
    failure,
};

const LoopPaths = struct {
    before_json_path: []const u8,
    after_json_path: []const u8,
    compare_report_path: []const u8,
};

const SummaryInput = struct {
    phase: Phase,
    dogfood_findings: usize,
    package_status: PackageStatus,
    paths: LoopPaths,
    compare_report: ?[]const u8,
};

fn loopPaths() LoopPaths {
    return .{
        .before_json_path = causal_test.artifact_dir ++ "/zigeffect-causal-dev-loop-before.json",
        .after_json_path = causal_test.artifact_dir ++ "/zigeffect-causal-dev-loop-after.json",
        .compare_report_path = causal_test.artifact_dir ++ "/zigeffect-causal-dev-loop-compare.txt",
    };
}

fn formatSummary(allocator: std.mem.Allocator, input: SummaryInput) std.mem.Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect causal dev loop\n");
    try output.print(allocator, "phase: {s}\n", .{@tagName(input.phase)});
    try output.print(allocator, "dogfood findings: {d}\n", .{input.dogfood_findings});

    switch (input.phase) {
        .baseline => {
            try output.print(allocator, "before json: {s}\n", .{input.paths.before_json_path});
            try output.print(allocator, "package-tests: {s}\n", .{@tagName(input.package_status)});
            try output.appendSlice(allocator, "next: zig build causal-dev-loop -- after\n");
        },
        .after => {
            try output.print(allocator, "after json: {s}\n", .{input.paths.after_json_path});
            try output.print(allocator, "compare report: {s}\n", .{input.paths.compare_report_path});
            try output.print(allocator, "package-tests: {s}\n", .{@tagName(input.package_status)});
            if (input.compare_report) |report| {
                try output.appendSlice(allocator, "compare summary:\n");
                try output.appendSlice(allocator, report);
                if (report.len == 0 or report[report.len - 1] != '\n') try output.append(allocator, '\n');
            }
            try output.appendSlice(allocator, "next queries:\n");
            try output.print(allocator, "- zig build causal-query -- --file {s} cause 3\n", .{input.paths.after_json_path});
            try output.print(allocator, "- zig build causal-query -- --file {s} resources 1\n", .{input.paths.after_json_path});
            try output.print(allocator, "- zig build causal-query -- --file {s} fibers pending\n", .{input.paths.after_json_path});
            try output.print(allocator, "- zig build causal-query -- --file {s} retries 1\n", .{input.paths.after_json_path});
        },
    }

    return output.toOwnedSlice(allocator);
}

fn exitCodeForPackageStatus(status: PackageStatus) u8 {
    return switch (status) {
        .pass => 0,
        .failure => 1,
    };
}

fn writeArtifact(io: std.Io, path: []const u8, contents: []const u8) !void {
    const slash = std.mem.lastIndexOfScalar(u8, path, '/') orelse return error.InvalidArtifactPath;
    const cwd = std.Io.Dir.cwd();
    try cwd.createDirPath(io, path[0..slash]);
    try cwd.writeFile(io, .{ .sub_path = path, .data = contents });
}

fn writeDogfoodArtifacts(io: std.Io, artifacts: causal_test.ArtifactSet) !void {
    try writeArtifact(io, artifacts.report_path, artifacts.report);
    try writeArtifact(io, artifacts.json_path, artifacts.json);
    try writeArtifact(io, artifacts.dot_path, artifacts.dot);
}

fn writeCommandArtifacts(io: std.Io, artifacts: causal_run.CommandArtifacts) !void {
    try writeArtifact(io, artifacts.report_path, artifacts.report);
    try writeArtifact(io, artifacts.json_path, artifacts.json);
    try writeArtifact(io, artifacts.dot_path, artifacts.dot);
}

fn captureDogfood(io: std.Io, allocator: std.mem.Allocator, target_json_path: []const u8) !usize {
    const artifacts = try causal_test.buildDogfoodArtifacts(allocator);
    defer artifacts.deinit(allocator);

    try writeDogfoodArtifacts(io, artifacts);
    try writeArtifact(io, target_json_path, artifacts.json);

    return artifacts.finding_count;
}

fn commandFailed(term: std.process.Child.Term) bool {
    return switch (term) {
        .exited => |code| code != 0,
        else => true,
    };
}

fn runPackageTests(io: std.Io, allocator: std.mem.Allocator) !PackageStatus {
    const scenario = try causal_run.scenarioByName("package-tests");
    const result = std.process.run(allocator, io, .{
        .argv = scenario.argv,
        .stdout_limit = .limited(64 * 1024),
        .stderr_limit = .limited(64 * 1024),
    }) catch |err| {
        const artifacts = try causal_run.buildFailureArtifacts(allocator, scenario, .{
            .term = .{ .unknown = 0 },
            .stdout = "",
            .stderr = @errorName(err),
        });
        defer artifacts.deinit(allocator);
        try writeCommandArtifacts(io, artifacts);
        return .failure;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (commandFailed(result.term)) {
        const artifacts = try causal_run.buildFailureArtifacts(allocator, scenario, .{
            .term = result.term,
            .stdout = result.stdout,
            .stderr = result.stderr,
        });
        defer artifacts.deinit(allocator);
        try writeCommandArtifacts(io, artifacts);
        return .failure;
    }

    return .pass;
}

fn runBaseline(init: std.process.Init) !u8 {
    const allocator = init.gpa;
    const paths = loopPaths();
    const dogfood_findings = try captureDogfood(init.io, allocator, paths.before_json_path);
    const package_status = try runPackageTests(init.io, allocator);
    const summary = try formatSummary(allocator, .{
        .phase = .baseline,
        .dogfood_findings = dogfood_findings,
        .package_status = package_status,
        .paths = paths,
        .compare_report = null,
    });
    defer allocator.free(summary);
    std.debug.print("{s}", .{summary});
    return exitCodeForPackageStatus(package_status);
}

fn readLoopArtifact(io: std.Io, allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    return std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(1024 * 1024)) catch |err| switch (err) {
        error.FileNotFound => error.MissingBaselineArtifact,
        else => return err,
    };
}

fn runAfter(init: std.process.Init) !u8 {
    const allocator = init.gpa;
    const paths = loopPaths();
    const before = try readLoopArtifact(init.io, allocator, paths.before_json_path);
    defer allocator.free(before);

    const dogfood_findings = try captureDogfood(init.io, allocator, paths.after_json_path);
    const after = try readLoopArtifact(init.io, allocator, paths.after_json_path);
    defer allocator.free(after);

    const compare_report = try causal_compare.runCompare(allocator, before, after);
    defer allocator.free(compare_report);
    try writeArtifact(init.io, paths.compare_report_path, compare_report);

    const package_status = try runPackageTests(init.io, allocator);
    const summary = try formatSummary(allocator, .{
        .phase = .after,
        .dogfood_findings = dogfood_findings,
        .package_status = package_status,
        .paths = paths,
        .compare_report = compare_report,
    });
    defer allocator.free(summary);
    std.debug.print("{s}", .{summary});
    return exitCodeForPackageStatus(package_status);
}

fn parsePhase(arg: []const u8) ?Phase {
    if (std.mem.eql(u8, arg, "baseline")) return .baseline;
    if (std.mem.eql(u8, arg, "after")) return .after;
    return null;
}

fn usage() []const u8 {
    return "usage: zig build causal-dev-loop -- <baseline|after>\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-dev-loop error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 2) failUsage(error.MissingPhase);

    const phase = parsePhase(args[1]) orelse failUsage(error.UnknownPhase);
    const exit_code = switch (phase) {
        .baseline => try runBaseline(init),
        .after => runAfter(init) catch |err| switch (err) {
            error.MissingBaselineArtifact => failUsage(err),
            else => return err,
        },
    };
    if (exit_code != 0) std.process.exit(exit_code);
}

test "dev loop paths are stable" {
    const paths = loopPaths();
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-before.json",
        paths.before_json_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-after.json",
        paths.after_json_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-compare.txt",
        paths.compare_report_path,
    );
}

test "baseline summary points to after phase" {
    const paths = loopPaths();
    const summary = try formatSummary(std.testing.allocator, .{
        .phase = .baseline,
        .dogfood_findings = 4,
        .package_status = .pass,
        .paths = paths,
        .compare_report = null,
    });
    defer std.testing.allocator.free(summary);

    try std.testing.expect(std.mem.indexOf(u8, summary, "zigeffect causal dev loop") != null);
    try std.testing.expect(std.mem.indexOf(u8, summary, "phase: baseline") != null);
    try std.testing.expect(std.mem.indexOf(u8, summary, "package-tests: pass") != null);
    try std.testing.expect(std.mem.indexOf(u8, summary, "next: zig build causal-dev-loop -- after") != null);
}

test "after summary includes compare path and query hints" {
    const paths = loopPaths();
    const summary = try formatSummary(std.testing.allocator, .{
        .phase = .after,
        .dogfood_findings = 4,
        .package_status = .pass,
        .paths = paths,
        .compare_report = "zigeffect causal compare report\nfinding delta: +0\n",
    });
    defer std.testing.allocator.free(summary);

    try std.testing.expect(std.mem.indexOf(u8, summary, "phase: after") != null);
    try std.testing.expect(std.mem.indexOf(u8, summary, "compare report: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-compare.txt") != null);
    try std.testing.expect(std.mem.indexOf(u8, summary, "zig build causal-query -- --file .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-after.json cause 3") != null);
}

test "package failure status exits nonzero" {
    try std.testing.expectEqual(@as(u8, 0), exitCodeForPackageStatus(.pass));
    try std.testing.expectEqual(@as(u8, 1), exitCodeForPackageStatus(.failure));
}
