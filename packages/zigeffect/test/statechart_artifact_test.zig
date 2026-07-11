const std = @import("std");
const fx = @import("zigeffect");

const State = enum { idle, running, done };
const Event = union(enum) { start: struct { secret: []const u8 }, finish };
const Context = struct { secret: [18]u8 };
const Command = union(enum) { call: struct { secret: []const u8 } };
const Def = fx.statechart.Definition(State, Event, Context, Command);
const Runtime = fx.statechart.Machine(Def);
const Artifacts = fx.statechart.Artifacts(Def);

const definition = Def.init(.{
    .id = "agent.artifacts",
    .version = 1,
    .initial = .idle,
    .description = "Human-visible agent logic",
    .states = &.{
        .{ .id = .idle, .description = "Waiting for a \"start\" event" },
        .{ .id = .running },
        .{ .id = .done, .kind = .final },
    },
    .transitions = &.{
        .{ .id = "start", .source = .idle, .event = .start, .target = .running },
        .{ .id = "finish", .source = .running, .event = .finish, .target = .done },
    },
});

test "native statechart definition artifact is versioned deterministic valid JSON" {
    const allocator = std.testing.allocator;
    const left = try Artifacts.formatDefinitionJson(allocator, &definition);
    defer allocator.free(left);
    const right = try Artifacts.formatDefinitionJson(allocator, &definition);
    defer allocator.free(right);

    try std.testing.expectEqualStrings(left, right);
    try std.testing.expect(std.mem.indexOf(u8, left, "zigeffect.statechart.definition.v2") != null);
    try std.testing.expect(std.mem.indexOf(u8, left, "agent.artifacts") != null);
    try std.testing.expect(std.mem.indexOf(u8, left, "Waiting for a \\\"start\\\" event") != null);

    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, left, .{});
    defer parsed.deinit();
    try std.testing.expect(parsed.value == .object);
}

test "snapshot and execution artifacts redact context event and command payloads" {
    const allocator = std.testing.allocator;
    const secret = "super-secret-value";
    const snapshot = Runtime.initial(&definition, .{ .secret = secret.* }, 81);

    const snapshot_json = try Artifacts.formatSnapshotJson(allocator, snapshot);
    defer allocator.free(snapshot_json);
    try std.testing.expect(std.mem.indexOf(u8, snapshot_json, secret) == null);
    try std.testing.expect(std.mem.indexOf(u8, snapshot_json, "<redacted>") != null);

    const decision = try Runtime.step(&definition, snapshot, .{ .start = .{ .secret = secret } });
    const execution_json = try Artifacts.formatDecisionJson(allocator, &decision, Def.EventTag.start);
    defer allocator.free(execution_json);
    try std.testing.expect(std.mem.indexOf(u8, execution_json, secret) == null);
    try std.testing.expect(std.mem.indexOf(u8, execution_json, "\"event\":\"start\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, execution_json, "\"transition_id\":\"start\"") != null);
}

test "public statechart artifacts encode every u64 identity as a decimal string" {
    const allocator = std.testing.allocator;
    const snapshot = Runtime.initial(&definition, .{ .secret = [_]u8{0} ** 18 }, std.math.maxInt(u64));
    const snapshot_json = try Artifacts.formatSnapshotJson(allocator, snapshot);
    defer allocator.free(snapshot_json);

    try std.testing.expect(std.mem.indexOf(u8, snapshot_json, "\"instance_id\":\"18446744073709551615\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, snapshot_json, "\"definition_fingerprint\":\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, snapshot_json, "\"revision\":\"0\"") != null);
}

test "statechart artifacts bound output and escape hostile metadata" {
    const hostile = Def.init(.{
        .id = "agent.hostile",
        .version = 1,
        .initial = .idle,
        .description = "</script>\n\x00\\\" must remain inert",
        .states = &.{
            .{ .id = .idle, .description = "<img src=x onerror=alert(1)>" },
            .{ .id = .running },
            .{ .id = .done, .kind = .final },
        },
        .transitions = &.{},
    });
    const json = try Artifacts.formatDefinitionJson(std.testing.allocator, &hostile);
    defer std.testing.allocator.free(json);
    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, json, .{});
    defer parsed.deinit();
    try std.testing.expect(std.mem.indexOf(u8, json, "\\u0000") != null);
    try std.testing.expectError(error.ArtifactSizeLimitExceeded, Artifacts.formatDefinitionJsonLimited(std.testing.allocator, &hostile, 32));
}

test "statechart artifact formatting is allocation-failure safe" {
    const Harness = struct {
        fn run(allocator: std.mem.Allocator) !void {
            const json = try Artifacts.formatDefinitionJson(allocator, &definition);
            defer allocator.free(json);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Harness.run, .{});
}

test "statechart exports XState Mermaid and DOT projections" {
    const allocator = std.testing.allocator;
    const xstate = try Artifacts.formatXStateJson(allocator, &definition);
    defer allocator.free(xstate);
    const mermaid = try Artifacts.formatMermaid(allocator, &definition);
    defer allocator.free(mermaid);
    const dot = try Artifacts.formatDot(allocator, &definition);
    defer allocator.free(dot);

    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, xstate, .{});
    defer parsed.deinit();
    try std.testing.expect(parsed.value == .object);
    try std.testing.expect(std.mem.indexOf(u8, xstate, "\"initial\":\"idle\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, xstate, "\"start\":{\"target\":\"running\"") != null);

    try std.testing.expect(std.mem.startsWith(u8, mermaid, "stateDiagram-v2\n"));
    try std.testing.expect(std.mem.indexOf(u8, mermaid, "idle --> running : start") != null);
    try std.testing.expect(std.mem.indexOf(u8, mermaid, "done --> [*]") != null);

    try std.testing.expect(std.mem.startsWith(u8, dot, "digraph statechart"));
    try std.testing.expect(std.mem.indexOf(u8, dot, "\"idle\" -> \"running\"") != null);
}

test "statechart artifact schema constants publish v2 with explicit legacy identifiers" {
    try std.testing.expectEqualStrings("zigeffect.statechart.definition.v2", fx.statechart.statechart_definition_schema);
    try std.testing.expectEqualStrings("zigeffect.statechart.snapshot.v2", fx.statechart.statechart_snapshot_schema);
    try std.testing.expectEqualStrings("zigeffect.statechart.execution.v2", fx.statechart.statechart_execution_schema);
    try std.testing.expectEqualStrings("zigeffect.statechart.coverage.v2", fx.statechart.statechart_coverage_schema);
    try std.testing.expectEqual(@as(u32, 2), fx.statechart.statechart_artifact_schema_version);
    try std.testing.expectEqualStrings("zigeffect.statechart.definition.v1", fx.statechart.statechart_definition_legacy_schema);
}

test "XState projection preserves compound parallel and history structure" {
    const HierState = enum { root, work, left, left_idle, left_done, right, right_idle, right_done, history, cancelled };
    const HierEvent = enum { advance, cancel, @"resume" };
    const HierDef = fx.statechart.Definition(HierState, HierEvent, void, void);
    const HierArtifacts = fx.statechart.Artifacts(HierDef);
    const hierarchical = HierDef.init(.{
        .id = "agent.hierarchical-export",
        .version = 1,
        .initial = .root,
        .states = &.{
            .{ .id = .root, .kind = .compound, .initial = .work },
            .{ .id = .work, .kind = .parallel, .parent = .root },
            .{ .id = .left, .kind = .compound, .parent = .work, .initial = .left_idle },
            .{ .id = .left_idle, .parent = .left },
            .{ .id = .left_done, .kind = .final, .parent = .left },
            .{ .id = .right, .kind = .compound, .parent = .work, .initial = .right_idle },
            .{ .id = .right_idle, .parent = .right },
            .{ .id = .right_done, .kind = .final, .parent = .right },
            .{ .id = .history, .kind = .history_deep, .parent = .root },
            .{ .id = .cancelled, .parent = .root },
        },
        .transitions = &.{
            .{ .id = "advance-left", .source = .left_idle, .event = .advance, .target = .left_done },
            .{ .id = "advance-right", .source = .right_idle, .event = .advance, .target = .right_done },
            .{ .id = "cancel", .source = .left_idle, .event = .cancel, .target = .cancelled },
            .{ .id = "resume", .source = .cancelled, .event = .@"resume", .target = .history },
            .{ .id = "history-default", .source = .history, .target = .work },
        },
    });

    const allocator = std.testing.allocator;
    const xstate = try HierArtifacts.formatXStateJson(allocator, &hierarchical);
    defer allocator.free(xstate);
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, xstate, .{});
    defer parsed.deinit();

    const root = parsed.value.object.get("states").?.object.get("root").?;
    try std.testing.expectEqualStrings("work", root.object.get("initial").?.string);
    const work = root.object.get("states").?.object.get("work").?;
    try std.testing.expectEqualStrings("parallel", work.object.get("type").?.string);
    try std.testing.expect(work.object.get("states").?.object.get("left") != null);
    const history = root.object.get("states").?.object.get("history").?;
    try std.testing.expectEqualStrings("history", history.object.get("type").?.string);
    try std.testing.expectEqualStrings("deep", history.object.get("history").?.string);
    try std.testing.expect(std.mem.indexOf(u8, xstate, "\"target\":\"#cancelled\"") != null);

    const ConfigRuntime = fx.statechart.ConfigurationMachine(HierDef);
    const ConfigArtifacts = fx.statechart.ConfigurationArtifacts(HierDef);
    const snapshot = try ConfigRuntime.initial(&hierarchical, {}, 7001);
    const snapshot_json = try ConfigArtifacts.formatSnapshotJson(allocator, snapshot);
    defer allocator.free(snapshot_json);
    try std.testing.expect(std.mem.indexOf(u8, snapshot_json, "\"configuration\":[\"root\",\"work\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, snapshot_json, "\"active_atomic_states\":[\"left_idle\",\"right_idle\"]") != null);

    const decision = try ConfigRuntime.step(&hierarchical, snapshot, .advance);
    const execution_json = try ConfigArtifacts.formatDecisionJson(allocator, &decision, HierDef.EventTag.advance);
    defer allocator.free(execution_json);
    try std.testing.expect(std.mem.indexOf(u8, execution_json, "\"transition_ids\":[\"advance-left\",\"advance-right\"]") != null);
    try std.testing.expect(std.mem.indexOf(u8, execution_json, "\"to_configuration\":[\"left_done\",\"right_done\"]") != null);
}
