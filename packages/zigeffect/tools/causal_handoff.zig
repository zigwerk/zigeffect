const std = @import("std");
const causal_run = @import("causal_run");
const causal_advice = @import("causal_advice");
const causal_compare = @import("causal_compare");

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

    const verdict = try formatCiVerdictJson(allocator, artifacts.items, advice_reports.items);
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

const ActionCounts = struct {
    actions: usize = 0,
    new_actions: usize = 0,
    persisting_actions: usize = 0,
    observed_actions: usize = 0,
};

fn countAdviceActions(advice_report: []const u8) ActionCounts {
    var counts = ActionCounts{};
    var lines = std.mem.splitScalar(u8, advice_report, '\n');
    while (lines.next()) |line| {
        if (!std.mem.startsWith(u8, line, "- action ")) continue;
        counts.actions += 1;
        if (std.mem.indexOf(u8, line, " status=new ") != null) {
            counts.new_actions += 1;
        } else if (std.mem.indexOf(u8, line, " status=persisting ") != null) {
            counts.persisting_actions += 1;
        } else if (std.mem.indexOf(u8, line, " status=observed ") != null) {
            counts.observed_actions += 1;
        }
    }
    return counts;
}

fn addCounts(total: *ActionCounts, item: ActionCounts) void {
    total.actions += item.actions;
    total.new_actions += item.new_actions;
    total.persisting_actions += item.persisting_actions;
    total.observed_actions += item.observed_actions;
}

fn verdictStatus(counts: ActionCounts) []const u8 {
    return if (counts.actions == 0) "clear" else "attention";
}

fn verdictNextAction(counts: ActionCounts) []const u8 {
    if (counts.new_actions > 0) return "inspect-new-advice";
    if (counts.observed_actions > 0) return "inspect-observed-advice";
    if (counts.persisting_actions > 0) return "inspect-persisting-advice";
    return "none";
}

fn appendJsonString(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: []const u8) !void {
    try output.append(allocator, '"');
    for (value) |byte| {
        switch (byte) {
            '"' => try output.appendSlice(allocator, "\\\""),
            '\\' => try output.appendSlice(allocator, "\\\\"),
            '\n' => try output.appendSlice(allocator, "\\n"),
            '\r' => try output.appendSlice(allocator, "\\r"),
            '\t' => try output.appendSlice(allocator, "\\t"),
            0...7,
            11,
            12,
            14...31,
            => {
                const hex = "0123456789abcdef";
                try output.appendSlice(allocator, "\\u00");
                try output.append(allocator, hex[@intCast(byte >> 4)]);
                try output.append(allocator, hex[@intCast(byte & 0x0f)]);
            },
            else => try output.append(allocator, byte),
        }
    }
    try output.append(allocator, '"');
}

fn formatOptionalJsonString(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: ?[]const u8) !void {
    if (value) |text| {
        try appendJsonString(allocator, output, text);
    } else {
        try output.appendSlice(allocator, "null");
    }
}

fn formatCiVerdictJson(
    allocator: std.mem.Allocator,
    artifacts: []const HandoffArtifact,
    advice_reports: []const []const u8,
) ![]const u8 {
    if (artifacts.len != advice_reports.len) return error.MismatchedVerdictInputs;

    const artifact_counts = try allocator.alloc(ActionCounts, artifacts.len);
    defer allocator.free(artifact_counts);

    var total_counts = ActionCounts{};
    for (artifacts, 0..) |_, index| {
        const counts = countAdviceActions(advice_reports[index]);
        artifact_counts[index] = counts;
        addCounts(&total_counts, counts);
    }

    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try output.appendSlice(allocator, "  \"schema\": \"zigeffect.causal.ci-verdict.v1\",\n");
    try output.appendSlice(allocator, "  \"schema_version\": 1,\n");
    try output.print(allocator, "  \"status\": \"{s}\",\n", .{verdictStatus(total_counts)});
    try output.print(allocator, "  \"next_action\": \"{s}\",\n", .{verdictNextAction(total_counts)});
    try output.print(allocator, "  \"json_artifacts\": {d},\n", .{artifacts.len});
    try output.print(allocator, "  \"baseline_pairs\": {d},\n", .{baselinePairCount(artifacts)});
    try output.print(allocator, "  \"actions\": {d},\n", .{total_counts.actions});
    try output.print(allocator, "  \"new_actions\": {d},\n", .{total_counts.new_actions});
    try output.print(allocator, "  \"persisting_actions\": {d},\n", .{total_counts.persisting_actions});
    try output.print(allocator, "  \"observed_actions\": {d},\n", .{total_counts.observed_actions});
    if (artifacts.len == 0) {
        try output.appendSlice(allocator, "  \"artifacts\": []\n");
    } else {
        try output.appendSlice(allocator, "  \"artifacts\": [\n");
        for (artifacts, 0..) |artifact, index| {
            const counts = artifact_counts[index];
            try output.appendSlice(allocator, "    {\n");
            try output.appendSlice(allocator, "      \"json_path\": ");
            try appendJsonString(allocator, &output, artifact.json_path);
            try output.appendSlice(allocator, ",\n");
            try output.appendSlice(allocator, "      \"baseline_path\": ");
            try formatOptionalJsonString(allocator, &output, artifact.baseline_path);
            try output.appendSlice(allocator, ",\n");
            try output.appendSlice(allocator, "      \"advice_report_path\": ");
            try appendJsonString(allocator, &output, artifact.advice_report_path);
            try output.appendSlice(allocator, ",\n");
            try output.appendSlice(allocator, "      \"compare_report_path\": ");
            try formatOptionalJsonString(allocator, &output, artifact.compare_report_path);
            try output.appendSlice(allocator, ",\n");
            try output.print(allocator, "      \"actions\": {d},\n", .{counts.actions});
            try output.print(allocator, "      \"new_actions\": {d},\n", .{counts.new_actions});
            try output.print(allocator, "      \"persisting_actions\": {d},\n", .{counts.persisting_actions});
            try output.print(allocator, "      \"observed_actions\": {d}\n", .{counts.observed_actions});
            try output.appendSlice(allocator, "    }");
            if (index + 1 < artifacts.len) try output.append(allocator, ',');
            try output.append(allocator, '\n');
        }
        try output.appendSlice(allocator, "  ]\n");
    }
    try output.appendSlice(allocator, "}\n");

    return output.toOwnedSlice(allocator);
}

fn writeArtifact(io: std.Io, path: []const u8, contents: []const u8) !void {
    const slash = std.mem.lastIndexOfScalar(u8, path, '/') orelse return error.InvalidArtifactPath;
    const cwd = std.Io.Dir.cwd();
    try cwd.createDirPath(io, path[0..slash]);
    try cwd.writeFile(io, .{ .sub_path = path, .data = contents });
}

const advice_persisting_text =
    \\zigeffect causal advice report
    \\artifact: .zig-cache/causal-artifacts/persisting.json
    \\actions: 1
    \\- action provide-missing-service status=persisting event=3 kind=service_required label=Config
    \\
;

const advice_new_text =
    \\zigeffect causal advice report
    \\artifact: .zig-cache/causal-artifacts/new.json
    \\actions: 2
    \\- action inspect-command-failure status=new event=9 kind=assertion_recorded label=package-tests
    \\- action close-resource status=observed event=4 kind=resource_acquired label=db
    \\
;

test "verdict summarizes advice action statuses" {
    const artifacts: []const HandoffArtifact = &.{
        .{
            .json_path = ".zig-cache/causal-artifacts/persisting.json",
            .advice_report_path = ".zig-cache/causal-artifacts/persisting-advice.txt",
            .baseline_path = ".zig-cache/causal-artifacts/before.json",
            .compare_report_path = ".zig-cache/causal-artifacts/persisting-ci-compare.txt",
        },
        .{
            .json_path = ".zig-cache/causal-artifacts/new.json",
            .advice_report_path = ".zig-cache/causal-artifacts/new-advice.txt",
        },
    };
    const advice_reports: []const []const u8 = &.{ advice_persisting_text, advice_new_text };
    const verdict = try formatCiVerdictJson(std.testing.allocator, artifacts, advice_reports);
    defer std.testing.allocator.free(verdict);

    try std.testing.expect(std.mem.indexOf(u8, verdict, "\"schema\": \"zigeffect.causal.ci-verdict.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, verdict, "\"status\": \"attention\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, verdict, "\"next_action\": \"inspect-new-advice\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, verdict, "\"json_artifacts\": 2") != null);
    try std.testing.expect(std.mem.indexOf(u8, verdict, "\"baseline_pairs\": 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, verdict, "\"actions\": 3") != null);
    try std.testing.expect(std.mem.indexOf(u8, verdict, "\"new_actions\": 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, verdict, "\"persisting_actions\": 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, verdict, "\"observed_actions\": 1") != null);
}

test "verdict is clear when no artifacts exist" {
    const verdict = try formatCiVerdictJson(std.testing.allocator, &.{}, &.{});
    defer std.testing.allocator.free(verdict);

    try std.testing.expect(std.mem.indexOf(u8, verdict, "\"status\": \"clear\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, verdict, "\"next_action\": \"none\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, verdict, "\"artifacts\": []") != null);
}

test "verdict escapes JSON path strings" {
    const artifacts: []const HandoffArtifact = &.{
        .{
            .json_path = ".zig-cache/causal-artifacts/control\x01.json",
            .advice_report_path = ".zig-cache/causal-artifacts/control-advice.txt",
        },
    };
    const advice_reports: []const []const u8 = &.{""};
    const verdict = try formatCiVerdictJson(std.testing.allocator, artifacts, advice_reports);
    defer std.testing.allocator.free(verdict);

    try std.testing.expect(std.mem.indexOf(u8, verdict, "control\\u0001.json") != null);
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
