const std = @import("std");
const causal_run = @import("causal_run");

const EventClassification = struct {
    disappeared: []u64,
    persisting: []u64,
    appeared: []u64,
    missing: []u64,

    fn deinit(self: *EventClassification, allocator: std.mem.Allocator) void {
        allocator.free(self.disappeared);
        allocator.free(self.persisting);
        allocator.free(self.appeared);
        allocator.free(self.missing);
    }
};

fn defaultAuditChainJsonPath() []const u8 {
    return causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-audit-chain.json";
}

fn defaultAuditChainTextPath() []const u8 {
    return causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-audit-chain.txt";
}

fn scenarioAuditChainJsonPath(allocator: std.mem.Allocator, scenario_slug: []const u8) ![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "{s}/zigeffect-causal-dev-loop-{s}-audit-chain.json",
        .{ causal_run.artifact_dir, scenario_slug },
    );
}

fn scenarioAuditChainTextPath(allocator: std.mem.Allocator, scenario_slug: []const u8) ![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "{s}/zigeffect-causal-dev-loop-{s}-audit-chain.txt",
        .{ causal_run.artifact_dir, scenario_slug },
    );
}

fn classifyEventIds(
    allocator: std.mem.Allocator,
    before_event_ids: []const u64,
    after_event_ids: []const u64,
    evidence_event_ids: []const u64,
) !EventClassification {
    var disappeared = std.ArrayList(u64).empty;
    errdefer disappeared.deinit(allocator);
    var persisting = std.ArrayList(u64).empty;
    errdefer persisting.deinit(allocator);
    var appeared = std.ArrayList(u64).empty;
    errdefer appeared.deinit(allocator);
    var missing = std.ArrayList(u64).empty;
    errdefer missing.deinit(allocator);

    for (evidence_event_ids) |event_id| {
        const in_before = containsEventId(before_event_ids, event_id);
        const in_after = containsEventId(after_event_ids, event_id);
        if (in_before and !in_after) {
            try disappeared.append(allocator, event_id);
        } else if (in_before and in_after) {
            try persisting.append(allocator, event_id);
        } else if (!in_before and in_after) {
            try appeared.append(allocator, event_id);
        } else {
            try missing.append(allocator, event_id);
        }
    }

    return .{
        .disappeared = try disappeared.toOwnedSlice(allocator),
        .persisting = try persisting.toOwnedSlice(allocator),
        .appeared = try appeared.toOwnedSlice(allocator),
        .missing = try missing.toOwnedSlice(allocator),
    };
}

fn containsEventId(event_ids: []const u64, event_id: u64) bool {
    for (event_ids) |candidate| {
        if (candidate == event_id) return true;
    }
    return false;
}

fn parseFindingDelta(report: []const u8) ?isize {
    var lines = std.mem.splitScalar(u8, report, '\n');
    while (lines.next()) |line| {
        const prefix = "finding delta:";
        if (!std.mem.startsWith(u8, line, prefix)) continue;
        const value = std.mem.trim(u8, line[prefix.len..], " \t\r");
        if (value.len == 0) return null;
        return std.fmt.parseInt(isize, value, 10) catch null;
    }
    return null;
}

test "audit-chain default and scenario paths are deterministic" {
    try std.testing.expectEqualStrings(
        causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-audit-chain.json",
        defaultAuditChainJsonPath(),
    );
    try std.testing.expectEqualStrings(
        causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-audit-chain.txt",
        defaultAuditChainTextPath(),
    );

    const scenario_json = try scenarioAuditChainJsonPath(std.testing.allocator, "causal-scoped-fiber");
    defer std.testing.allocator.free(scenario_json);
    const scenario_text = try scenarioAuditChainTextPath(std.testing.allocator, "causal-scoped-fiber");
    defer std.testing.allocator.free(scenario_text);

    try std.testing.expectEqualStrings(
        causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-causal-scoped-fiber-audit-chain.json",
        scenario_json,
    );
    try std.testing.expectEqualStrings(
        causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-causal-scoped-fiber-audit-chain.txt",
        scenario_text,
    );
}

test "classifyEventIds splits disappeared persisting appeared and missing evidence" {
    const before = [_]u64{ 1, 2, 4 };
    const after = [_]u64{ 2, 3, 4 };
    const evidence = [_]u64{ 1, 2, 3, 5 };

    var classification = try classifyEventIds(std.testing.allocator, &before, &after, &evidence);
    defer classification.deinit(std.testing.allocator);

    try std.testing.expectEqualSlices(u64, &.{1}, classification.disappeared);
    try std.testing.expectEqualSlices(u64, &.{2}, classification.persisting);
    try std.testing.expectEqualSlices(u64, &.{3}, classification.appeared);
    try std.testing.expectEqualSlices(u64, &.{5}, classification.missing);
}

test "parseFindingDelta reads signed compare report delta" {
    const negative =
        \\zigeffect causal compare report
        \\before findings: 2
        \\after findings: 1
        \\finding delta: -1
        \\
    ;
    const positive =
        \\zigeffect causal compare report
        \\finding delta: +2
        \\
    ;
    const none =
        \\zigeffect causal compare report
        \\event delta: +0
        \\
    ;

    try std.testing.expectEqual(@as(?isize, -1), parseFindingDelta(negative));
    try std.testing.expectEqual(@as(?isize, 2), parseFindingDelta(positive));
    try std.testing.expectEqual(@as(?isize, null), parseFindingDelta(none));
}
