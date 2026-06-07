const std = @import("std");
const causal_run = @import("causal_run");
const causal_advice = @import("causal_advice");
const causal_compare = @import("causal_compare");
const causal_verdict = @import("causal_verdict");

pub const handoff_report_path = causal_run.artifact_dir ++ "/zigeffect-causal-ci-handoff.txt";
pub const verdict_report_path = causal_run.artifact_dir ++ "/zigeffect-causal-ci-verdict.json";

const HandoffArtifact = struct {
    json_path: []const u8,
    advice_report_path: []const u8,
    baseline_path: ?[]const u8 = null,
    compare_report_path: ?[]const u8 = null,
};

pub fn formatCiHandoffReport(allocator: std.mem.Allocator, artifacts: []const HandoffArtifact) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect causal CI handoff\n");
    try output.print(allocator, "artifact dir: {s}\n", .{causal_run.artifact_dir});
    try output.print(allocator, "handoff: {s}\n", .{handoff_report_path});
    try output.print(allocator, "verdict: {s}\n", .{verdict_report_path});
    try output.print(allocator, "json artifacts: {d}\n", .{artifacts.len});
    try output.print(allocator, "baseline pairs: {d}\n", .{baselinePairCount(artifacts)});
    try output.append(allocator, '\n');

    if (artifacts.len == 0) {
        try output.appendSlice(allocator, "- no causal JSON artifacts found\n");
    } else {
        for (artifacts) |artifact| {
            try output.print(allocator, "- artifact {s}\n", .{artifact.json_path});
            if (artifact.baseline_path) |baseline_path| {
                const compare_report_path = artifact.compare_report_path orelse return error.MissingCompareReportPath;
                try output.print(allocator, "  baseline: {s}\n", .{baseline_path});
                try output.print(allocator, "  compare report: {s}\n", .{compare_report_path});
                try output.print(allocator, "  advice report: {s}\n", .{artifact.advice_report_path});
                try output.print(allocator, "  compare: zig build causal-compare -- {s} {s}\n", .{ baseline_path, artifact.json_path });
                try output.print(allocator, "  advice: zig build causal-advice -- --before {s} --file {s}\n", .{ baseline_path, artifact.json_path });
            } else {
                try output.print(allocator, "  advice report: {s}\n", .{artifact.advice_report_path});
                try output.print(allocator, "  advice: zig build causal-advice -- --file {s}\n", .{artifact.json_path});
            }
            try output.print(allocator, "  snapshot: zig build causal-query -- --file {s} snapshot\n", .{artifact.json_path});
        }
    }

    try output.appendSlice(allocator, "\nretention:\n");
    try output.appendSlice(allocator, "- CI uploads only causal .txt, .json, and .dot artifacts\n");
    try output.appendSlice(allocator, "- do not upload the rest of .zig-cache\n");
    try output.appendSlice(allocator, "- start with the verdict, then inspect this handoff, advice, and query reports\n");

    return output.toOwnedSlice(allocator);
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    var candidates = try candidateJsonArtifactPaths(allocator);
    defer deinitOwnedPaths(allocator, &candidates);

    var existing_paths = std.ArrayList([]const u8).empty;
    defer existing_paths.deinit(allocator);
    for (candidates.items) |path| {
        if (try artifactExists(init.io, path)) {
            try existing_paths.append(allocator, path);
        }
    }

    var artifacts = try describeArtifacts(init.io, allocator, existing_paths.items);
    defer deinitArtifacts(allocator, &artifacts);

    var advice_reports = try writeGeneratedReportsForArtifacts(init.io, allocator, artifacts.items);
    defer deinitAdviceReports(allocator, &advice_reports);

    const verdict_inputs = try verdictInputsFromHandoffArtifacts(allocator, artifacts.items);
    defer allocator.free(verdict_inputs);
    const verdict = try causal_verdict.formatVerdictJson(
        allocator,
        "zigeffect.causal.ci-verdict.v1",
        verdict_inputs,
        advice_reports.items,
    );
    defer allocator.free(verdict);
    try writeArtifact(init.io, verdict_report_path, verdict);

    const report = try formatCiHandoffReport(allocator, artifacts.items);
    defer init.gpa.free(report);
    try writeArtifact(init.io, handoff_report_path, report);
    std.debug.print("{s}", .{report});
}

fn baselinePairCount(artifacts: []const HandoffArtifact) usize {
    var count: usize = 0;
    for (artifacts) |artifact| {
        if (artifact.baseline_path != null) count += 1;
    }
    return count;
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
    if (std.mem.endsWith(u8, json_path, "-after.json")) {
        return std.fmt.allocPrint(
            allocator,
            "{s}-advice.txt",
            .{json_path[0 .. json_path.len - "-after.json".len]},
        );
    }
    if (!std.mem.endsWith(u8, json_path, ".json")) return error.InvalidJsonArtifactPath;
    return std.fmt.allocPrint(allocator, "{s}-advice.txt", .{json_path[0 .. json_path.len - ".json".len]});
}

fn compareReportPathForJsonArtifact(allocator: std.mem.Allocator, json_path: []const u8) ![]const u8 {
    if (std.mem.endsWith(u8, json_path, "-after.json")) {
        return std.fmt.allocPrint(
            allocator,
            "{s}-compare.txt",
            .{json_path[0 .. json_path.len - "-after.json".len]},
        );
    }
    if (!std.mem.endsWith(u8, json_path, ".json")) return error.InvalidJsonArtifactPath;
    return std.fmt.allocPrint(allocator, "{s}-ci-compare.txt", .{json_path[0 .. json_path.len - ".json".len]});
}

fn baselinePathForJsonArtifact(allocator: std.mem.Allocator, json_path: []const u8) !?[]const u8 {
    const dir = causal_run.artifact_dir ++ "/";
    if (std.mem.eql(u8, json_path, dir ++ "zigeffect-causal-dogfood.json")) {
        return try std.fmt.allocPrint(allocator, "{s}zigeffect-causal-ci-baseline-dogfood.json", .{dir});
    }
    if (std.mem.eql(u8, json_path, dir ++ "zigeffect-causal-package-tests.json")) {
        return try std.fmt.allocPrint(allocator, "{s}zigeffect-causal-ci-baseline-package-tests.json", .{dir});
    }
    if (std.mem.endsWith(u8, json_path, "-after.json")) {
        return try std.fmt.allocPrint(
            allocator,
            "{s}-before.json",
            .{json_path[0 .. json_path.len - "-after.json".len]},
        );
    }
    return null;
}

fn describeArtifacts(
    io: std.Io,
    allocator: std.mem.Allocator,
    json_artifact_paths: []const []const u8,
) !std.ArrayList(HandoffArtifact) {
    var artifacts = std.ArrayList(HandoffArtifact).empty;
    errdefer deinitArtifacts(allocator, &artifacts);

    for (json_artifact_paths) |path| {
        const json_path = try allocator.dupe(u8, path);
        errdefer allocator.free(json_path);

        const advice_report_path = try adviceReportPathForJsonArtifact(allocator, path);
        errdefer allocator.free(advice_report_path);

        var baseline_path: ?[]const u8 = null;
        errdefer if (baseline_path) |owned| allocator.free(owned);
        var compare_report_path: ?[]const u8 = null;
        errdefer if (compare_report_path) |owned| allocator.free(owned);

        const candidate_baseline_path = try baselinePathForJsonArtifact(allocator, path);
        if (candidate_baseline_path) |owned_baseline_path| {
            if (try artifactExists(io, owned_baseline_path)) {
                baseline_path = owned_baseline_path;
                compare_report_path = try compareReportPathForJsonArtifact(allocator, path);
            } else {
                allocator.free(owned_baseline_path);
            }
        }

        try artifacts.append(allocator, .{
            .json_path = json_path,
            .advice_report_path = advice_report_path,
            .baseline_path = baseline_path,
            .compare_report_path = compare_report_path,
        });
    }

    return artifacts;
}

fn deinitArtifacts(allocator: std.mem.Allocator, artifacts: *std.ArrayList(HandoffArtifact)) void {
    for (artifacts.items) |artifact| {
        allocator.free(artifact.json_path);
        allocator.free(artifact.advice_report_path);
        if (artifact.baseline_path) |path| allocator.free(path);
        if (artifact.compare_report_path) |path| allocator.free(path);
    }
    artifacts.deinit(allocator);
}

fn writeGeneratedReportsForArtifacts(io: std.Io, allocator: std.mem.Allocator, artifacts: []const HandoffArtifact) !std.ArrayList([]const u8) {
    var advice_reports = std.ArrayList([]const u8).empty;
    errdefer deinitAdviceReports(allocator, &advice_reports);

    for (artifacts) |artifact| {
        const json = try std.Io.Dir.cwd().readFileAlloc(io, artifact.json_path, allocator, .limited(1024 * 1024));
        defer allocator.free(json);

        if (artifact.baseline_path) |baseline_path| {
            const compare_report_path = artifact.compare_report_path orelse return error.MissingCompareReportPath;
            const baseline_json = try std.Io.Dir.cwd().readFileAlloc(io, baseline_path, allocator, .limited(1024 * 1024));
            defer allocator.free(baseline_json);

            const compare_report = try causal_compare.runCompare(allocator, baseline_json, json);
            defer allocator.free(compare_report);
            try writeArtifact(io, compare_report_path, compare_report);

            const advice_report = try causal_advice.buildAdviceReportWithBaseline(allocator, baseline_json, baseline_path, json, artifact.json_path);
            errdefer allocator.free(advice_report);
            try writeArtifact(io, artifact.advice_report_path, advice_report);
            try advice_reports.append(allocator, advice_report);
        } else {
            const advice_report = try causal_advice.buildAdviceReport(allocator, json, artifact.json_path);
            errdefer allocator.free(advice_report);
            try writeArtifact(io, artifact.advice_report_path, advice_report);
            try advice_reports.append(allocator, advice_report);
        }
    }

    return advice_reports;
}

fn deinitAdviceReports(allocator: std.mem.Allocator, advice_reports: *std.ArrayList([]const u8)) void {
    for (advice_reports.items) |report| allocator.free(report);
    advice_reports.deinit(allocator);
}

fn verdictInputsFromHandoffArtifacts(
    allocator: std.mem.Allocator,
    artifacts: []const HandoffArtifact,
) ![]causal_verdict.ArtifactVerdictInput {
    const verdict_inputs = try allocator.alloc(causal_verdict.ArtifactVerdictInput, artifacts.len);
    for (artifacts, 0..) |artifact, index| {
        verdict_inputs[index] = .{
            .json_path = artifact.json_path,
            .baseline_path = artifact.baseline_path,
            .advice_report_path = artifact.advice_report_path,
            .compare_report_path = artifact.compare_report_path,
        };
    }
    return verdict_inputs;
}

fn writeArtifact(io: std.Io, path: []const u8, contents: []const u8) !void {
    const slash = std.mem.lastIndexOfScalar(u8, path, '/') orelse return error.InvalidArtifactPath;
    const cwd = std.Io.Dir.cwd();
    try cwd.createDirPath(io, path[0..slash]);
    try cwd.writeFile(io, .{ .sub_path = path, .data = contents });
}

test "handoff report lists artifacts and exact follow-up commands" {
    const artifacts: []const HandoffArtifact = &.{
        .{
            .json_path = ".zig-cache/causal-artifacts/zigeffect-causal-package-tests.json",
            .advice_report_path = ".zig-cache/causal-artifacts/zigeffect-causal-package-tests-advice.txt",
            .baseline_path = ".zig-cache/causal-artifacts/zigeffect-causal-ci-baseline-package-tests.json",
            .compare_report_path = ".zig-cache/causal-artifacts/zigeffect-causal-package-tests-ci-compare.txt",
        },
        .{
            .json_path = ".zig-cache/causal-artifacts/zigeffect-causal-missing-service-compile-fail.json",
            .advice_report_path = ".zig-cache/causal-artifacts/zigeffect-causal-missing-service-compile-fail-advice.txt",
        },
    };
    const report = try formatCiHandoffReport(std.testing.allocator, artifacts);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect causal CI handoff") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "handoff: .zig-cache/causal-artifacts/zigeffect-causal-ci-handoff.txt") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "verdict: .zig-cache/causal-artifacts/zigeffect-causal-ci-verdict.json") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "json artifacts: 2") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "baseline pairs: 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "artifact .zig-cache/causal-artifacts/zigeffect-causal-package-tests.json") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "baseline: .zig-cache/causal-artifacts/zigeffect-causal-ci-baseline-package-tests.json") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "compare report: .zig-cache/causal-artifacts/zigeffect-causal-package-tests-ci-compare.txt") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "advice report: .zig-cache/causal-artifacts/zigeffect-causal-package-tests-advice.txt") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-compare -- .zig-cache/causal-artifacts/zigeffect-causal-ci-baseline-package-tests.json .zig-cache/causal-artifacts/zigeffect-causal-package-tests.json") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-advice -- --before .zig-cache/causal-artifacts/zigeffect-causal-ci-baseline-package-tests.json --file .zig-cache/causal-artifacts/zigeffect-causal-package-tests.json") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-advice -- --file .zig-cache/causal-artifacts/zigeffect-causal-missing-service-compile-fail.json") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-query -- --file .zig-cache/causal-artifacts/zigeffect-causal-package-tests.json snapshot") != null);
}

test "advice report path is derived from JSON artifact path" {
    const path = try adviceReportPathForJsonArtifact(std.testing.allocator, ".zig-cache/causal-artifacts/zigeffect-causal-dogfood.json");
    defer std.testing.allocator.free(path);

    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/zigeffect-causal-dogfood-advice.txt", path);
}

test "advice report path reuses local dev-loop advice naming for after artifacts" {
    const path = try adviceReportPathForJsonArtifact(std.testing.allocator, ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-after.json");
    defer std.testing.allocator.free(path);

    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-advice.txt", path);
}

test "ci baseline path resolves for dogfood and package test artifacts" {
    const dogfood = try baselinePathForJsonArtifact(
        std.testing.allocator,
        ".zig-cache/causal-artifacts/zigeffect-causal-dogfood.json",
    );
    defer if (dogfood) |path| std.testing.allocator.free(path);
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-ci-baseline-dogfood.json",
        dogfood.?,
    );

    const package_tests = try baselinePathForJsonArtifact(
        std.testing.allocator,
        ".zig-cache/causal-artifacts/zigeffect-causal-package-tests.json",
    );
    defer if (package_tests) |path| std.testing.allocator.free(path);
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-ci-baseline-package-tests.json",
        package_tests.?,
    );
}

test "local after artifact resolves to matching before artifact" {
    const before = try baselinePathForJsonArtifact(
        std.testing.allocator,
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-after.json",
    );
    defer if (before) |path| std.testing.allocator.free(path);
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-before.json",
        before.?,
    );
}

test "unpaired artifact has no baseline path" {
    const baseline = try baselinePathForJsonArtifact(
        std.testing.allocator,
        ".zig-cache/causal-artifacts/zigeffect-causal-missing-service-compile-fail.json",
    );
    try std.testing.expectEqual(@as(?[]const u8, null), baseline);
}

test "handoff report is explicit when no JSON artifacts exist" {
    const report = try formatCiHandoffReport(std.testing.allocator, &.{});
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "json artifacts: 0") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "no causal JSON artifacts found") != null);
}
