const std = @import("std");
const fx = @import("zigeffect");

const State = enum { idle, running, done };
const Event = enum { start, finish, reset };
const Def = fx.statechart.Definition(State, Event, void, void);
const Runtime = fx.statechart.Machine(Def);
const Coverage = fx.statechart.Coverage(Def);

const definition = Def.init(.{
    .id = "agent.coverage",
    .version = 1,
    .initial = .idle,
    .states = &.{ .{ .id = .idle }, .{ .id = .running }, .{ .id = .done, .kind = .final } },
    .transitions = &.{
        .{ .id = "start", .source = .idle, .event = .start, .target = .running },
        .{ .id = "finish", .source = .running, .event = .finish, .target = .done },
    },
});

test "coverage records states events and transitions from accepted and ignored decisions" {
    var coverage = try Coverage.init(&definition);
    var snapshot = Runtime.initial(&definition, {}, 1);
    const ignored = try Runtime.step(&definition, snapshot, .reset);
    try coverage.recordDecision(&definition, &ignored, .reset);
    const started = try Runtime.step(&definition, snapshot, .start);
    try coverage.recordDecision(&definition, &started, .start);
    snapshot = started.next;
    const finished = try Runtime.step(&definition, snapshot, .finish);
    try coverage.recordDecision(&definition, &finished, .finish);

    const summary = coverage.summary();
    try std.testing.expectEqual(@as(usize, 3), summary.visited_states);
    try std.testing.expectEqual(@as(usize, 2), summary.visited_transitions);
    try std.testing.expectEqual(@as(usize, 3), summary.observed_events);
    try std.testing.expectEqual(@as(u64, 1), coverage.transitionCount("start"));
    try std.testing.expectEqual(@as(u64, 1), coverage.eventCount(.reset));
}

test "coverage artifacts are deterministic versioned and contain no context" {
    var coverage = try Coverage.init(&definition);
    const snapshot = Runtime.initial(&definition, {}, 2);
    const decision = try Runtime.step(&definition, snapshot, .start);
    try coverage.recordDecision(&definition, &decision, .start);

    const allocator = std.testing.allocator;
    const json = try coverage.formatJsonAlloc(allocator, &definition);
    defer allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "zigeffect.statechart.coverage.v2") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"id\":\"start\",\"count\":\"1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "context") == null);
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, json, .{});
    defer parsed.deinit();
}
