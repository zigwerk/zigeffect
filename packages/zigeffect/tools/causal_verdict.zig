const std = @import("std");

pub const ArtifactVerdictInput = struct {
    json_path: []const u8,
    baseline_path: ?[]const u8 = null,
    advice_report_path: []const u8,
    compare_report_path: ?[]const u8 = null,
};

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

fn baselinePairCount(artifacts: []const ArtifactVerdictInput) usize {
    var count: usize = 0;
    for (artifacts) |artifact| {
        if (artifact.baseline_path != null) count += 1;
    }
    return count;
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

pub fn formatVerdictJson(
    allocator: std.mem.Allocator,
    schema: []const u8,
    artifacts: []const ArtifactVerdictInput,
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
    try output.appendSlice(allocator, "  \"schema\": ");
    try appendJsonString(allocator, &output, schema);
    try output.appendSlice(allocator, ",\n");
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
    const artifacts: []const ArtifactVerdictInput = &.{
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
    const verdict = try formatVerdictJson(
        std.testing.allocator,
        "zigeffect.causal.ci-verdict.v1",
        artifacts,
        advice_reports,
    );
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
    const verdict = try formatVerdictJson(std.testing.allocator, "zigeffect.causal.ci-verdict.v1", &.{}, &.{});
    defer std.testing.allocator.free(verdict);

    try std.testing.expect(std.mem.indexOf(u8, verdict, "\"status\": \"clear\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, verdict, "\"next_action\": \"none\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, verdict, "\"artifacts\": []") != null);
}

test "verdict escapes JSON path strings" {
    const artifacts: []const ArtifactVerdictInput = &.{
        .{
            .json_path = ".zig-cache/causal-artifacts/control\x01.json",
            .advice_report_path = ".zig-cache/causal-artifacts/control-advice.txt",
        },
    };
    const advice_reports: []const []const u8 = &.{""};
    const verdict = try formatVerdictJson(std.testing.allocator, "zigeffect.causal.ci-verdict.v1", artifacts, advice_reports);
    defer std.testing.allocator.free(verdict);

    try std.testing.expect(std.mem.indexOf(u8, verdict, "control\\u0001.json") != null);
}

test "verdict schema is caller supplied" {
    const verdict = try formatVerdictJson(std.testing.allocator, "zigeffect.causal.dev-loop-verdict.v1", &.{}, &.{});
    defer std.testing.allocator.free(verdict);

    try std.testing.expect(std.mem.indexOf(u8, verdict, "\"schema\": \"zigeffect.causal.dev-loop-verdict.v1\"") != null);
}
