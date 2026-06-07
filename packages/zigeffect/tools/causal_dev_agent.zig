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
    artifacts: []const Artifact,
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

const LocalReportInput = struct {
    target: []const u8,
    verdict_path: []const u8,
    verdict: Verdict,
};

fn localVerdictPath() []const u8 {
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

fn validateLocalVerdict(verdict: Verdict) !void {
    if (!std.mem.eql(u8, verdict.schema, supported_local_schema)) return error.UnsupportedVerdictSchema;
    if (verdict.schema_version != 1) return error.UnsupportedVerdictSchema;
    if (verdict.artifacts.len == 0) return error.EmptyVerdictArtifacts;
}

fn formatLocalAgentReport(allocator: std.mem.Allocator, input: LocalReportInput) ![]const u8 {
    try validateLocalVerdict(input.verdict);

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
        try output.appendSlice(allocator, "- zig build causal-advice --");
        if (artifact.baseline_path) |baseline_path| try output.print(allocator, " --before {s}", .{baseline_path});
        try output.print(allocator, " --file {s}\n", .{artifact.json_path});
        try output.print(allocator, "- zig build causal-query -- --file {s} snapshot\n", .{artifact.json_path});
        if (artifact.baseline_path) |baseline_path| {
            try output.print(allocator, "- zig build causal-compare -- {s} {s}\n", .{ baseline_path, artifact.json_path });
        }
    }

    return output.toOwnedSlice(allocator);
}

fn usage() []const u8 {
    return "usage: zig build causal-dev-agent -- local [scenario]\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-dev-agent error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

fn readVerdict(io: std.Io, allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    return std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(1024 * 1024)) catch |err| switch (err) {
        error.FileNotFound => error.MissingVerdictArtifact,
        else => return err,
    };
}

fn runLocal(init: std.process.Init, scenario_slug: ?[]const u8) !void {
    const allocator = init.gpa;
    const verdict_path = if (scenario_slug) |slug| try localVerdictPathForScenario(allocator, slug) else localVerdictPath();
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

test "local verdict path is stable for default target" {
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-verdict.json",
        localVerdictPath(),
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
        .artifacts = &.{
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
        },
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

test "usage text names local mode" {
    try std.testing.expectEqualStrings(
        "usage: zig build causal-dev-agent -- local [scenario]\n",
        usage(),
    );
}
