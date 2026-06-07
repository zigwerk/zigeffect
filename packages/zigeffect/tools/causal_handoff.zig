const std = @import("std");
const causal_run = @import("causal_run");
const causal_advice = @import("causal_advice");

pub const handoff_report_path = causal_run.artifact_dir ++ "/zigeffect-causal-ci-handoff.txt";

pub fn formatCiHandoffReport(allocator: std.mem.Allocator, json_artifact_paths: []const []const u8) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect causal CI handoff\n");
    try output.print(allocator, "artifact dir: {s}\n", .{causal_run.artifact_dir});
    try output.print(allocator, "handoff: {s}\n", .{handoff_report_path});
    try output.print(allocator, "json artifacts: {d}\n", .{json_artifact_paths.len});
    try output.append(allocator, '\n');

    if (json_artifact_paths.len == 0) {
        try output.appendSlice(allocator, "- no causal JSON artifacts found\n");
    } else {
        for (json_artifact_paths) |path| {
            const advice_report_path = try adviceReportPathForJsonArtifact(allocator, path);
            defer allocator.free(advice_report_path);

            try output.print(allocator, "- artifact {s}\n", .{path});
            try output.print(allocator, "  advice report: {s}\n", .{advice_report_path});
            try output.print(allocator, "  advice: zig build causal-advice -- --file {s}\n", .{path});
            try output.print(allocator, "  snapshot: zig build causal-query -- --file {s} snapshot\n", .{path});
        }
    }

    try output.appendSlice(allocator, "\nretention:\n");
    try output.appendSlice(allocator, "- CI uploads only causal .txt, .json, and .dot artifacts\n");
    try output.appendSlice(allocator, "- do not upload the rest of .zig-cache\n");
    try output.appendSlice(allocator, "- start with this handoff, then inspect advice and query reports\n");

    return output.toOwnedSlice(allocator);
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    var candidates = try candidateJsonArtifactPaths(allocator);
    defer deinitOwnedPaths(allocator, &candidates);

    var existing = std.ArrayList([]const u8).empty;
    defer existing.deinit(allocator);
    for (candidates.items) |path| {
        if (try artifactExists(init.io, path)) {
            try existing.append(allocator, path);
        }
    }

    try writeAdviceReportsForArtifacts(init.io, allocator, existing.items);

    const report = try formatCiHandoffReport(allocator, existing.items);
    defer init.gpa.free(report);
    try writeArtifact(init.io, handoff_report_path, report);
    std.debug.print("{s}", .{report});
}

fn candidateJsonArtifactPaths(allocator: std.mem.Allocator) !std.ArrayList([]const u8) {
    var paths = std.ArrayList([]const u8).empty;
    errdefer deinitOwnedPaths(allocator, &paths);

    try appendOwnedPath(allocator, &paths, causal_run.artifact_dir ++ "/zigeffect-causal-dogfood.json");
    try appendOwnedPath(allocator, &paths, causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-before.json");
    try appendOwnedPath(allocator, &paths, causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-after.json");

    for (causal_run.scenarioRegistry()) |scenario| {
        const scenario_paths = try causal_run.artifactPaths(allocator, scenario.slug);
        defer scenario_paths.deinit(allocator);
        try appendOwnedPath(allocator, &paths, scenario_paths.json_path);
        try appendScenarioLoopJsonCandidates(allocator, &paths, scenario.slug);
    }

    return paths;
}

fn appendScenarioLoopJsonCandidates(allocator: std.mem.Allocator, paths: *std.ArrayList([]const u8), slug: []const u8) !void {
    const before_path = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-dev-loop-{s}-before.json", .{ causal_run.artifact_dir, slug });
    errdefer allocator.free(before_path);
    try paths.append(allocator, before_path);

    const after_path = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-dev-loop-{s}-after.json", .{ causal_run.artifact_dir, slug });
    errdefer allocator.free(after_path);
    try paths.append(allocator, after_path);
}

fn appendOwnedPath(allocator: std.mem.Allocator, paths: *std.ArrayList([]const u8), path: []const u8) !void {
    const owned = try allocator.dupe(u8, path);
    errdefer allocator.free(owned);
    try paths.append(allocator, owned);
}

fn deinitOwnedPaths(allocator: std.mem.Allocator, paths: *std.ArrayList([]const u8)) void {
    for (paths.items) |path| allocator.free(path);
    paths.deinit(allocator);
}

fn artifactExists(io: std.Io, path: []const u8) !bool {
    const file = std.Io.Dir.cwd().openFile(io, path, .{}) catch |err| switch (err) {
        error.FileNotFound => return false,
        else => return err,
    };
    defer file.close(io);
    return true;
}

fn adviceReportPathForJsonArtifact(allocator: std.mem.Allocator, json_path: []const u8) ![]const u8 {
    if (!std.mem.endsWith(u8, json_path, ".json")) return error.InvalidJsonArtifactPath;
    return std.fmt.allocPrint(allocator, "{s}-advice.txt", .{json_path[0 .. json_path.len - ".json".len]});
}

fn writeAdviceReportsForArtifacts(io: std.Io, allocator: std.mem.Allocator, json_artifact_paths: []const []const u8) !void {
    for (json_artifact_paths) |path| {
        const json = try std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(1024 * 1024));
        defer allocator.free(json);

        const advice_report_path = try adviceReportPathForJsonArtifact(allocator, path);
        defer allocator.free(advice_report_path);

        const report = try causal_advice.buildAdviceReport(allocator, json, path);
        defer allocator.free(report);
        try writeArtifact(io, advice_report_path, report);
    }
}

fn writeArtifact(io: std.Io, path: []const u8, contents: []const u8) !void {
    const slash = std.mem.lastIndexOfScalar(u8, path, '/') orelse return error.InvalidArtifactPath;
    const cwd = std.Io.Dir.cwd();
    try cwd.createDirPath(io, path[0..slash]);
    try cwd.writeFile(io, .{ .sub_path = path, .data = contents });
}

test "handoff report lists artifacts and exact follow-up commands" {
    const paths: []const []const u8 = &.{
        ".zig-cache/causal-artifacts/zigeffect-causal-dogfood.json",
        ".zig-cache/causal-artifacts/zigeffect-causal-package-tests.json",
    };
    const report = try formatCiHandoffReport(std.testing.allocator, paths);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect causal CI handoff") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "handoff: .zig-cache/causal-artifacts/zigeffect-causal-ci-handoff.txt") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "json artifacts: 2") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "artifact .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "advice report: .zig-cache/causal-artifacts/zigeffect-causal-dogfood-advice.txt") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-advice -- --file .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-query -- --file .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json snapshot") != null);
}

test "advice report path is derived from JSON artifact path" {
    const path = try adviceReportPathForJsonArtifact(std.testing.allocator, ".zig-cache/causal-artifacts/zigeffect-causal-dogfood.json");
    defer std.testing.allocator.free(path);

    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/zigeffect-causal-dogfood-advice.txt", path);
}

test "handoff report is explicit when no JSON artifacts exist" {
    const report = try formatCiHandoffReport(std.testing.allocator, &.{});
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "json artifacts: 0") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "no causal JSON artifacts found") != null);
}
