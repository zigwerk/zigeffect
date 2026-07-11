const std = @import("std");
const fx = @import("zigeffect");

const State = enum { idle, working, dead_end, orphan, done };
const Event = enum { start, finish };
const Context = struct {};
const Command = enum { noop };
const Def = fx.statechart.Definition(State, Event, Context, Command);
const Analyzer = fx.statechart.Analyzer(Def);

const definition = Def.init(.{
    .id = "agent.analysis",
    .version = 1,
    .initial = .idle,
    .states = &.{
        .{ .id = .idle },
        .{ .id = .working },
        .{ .id = .dead_end },
        .{ .id = .orphan },
        .{ .id = .done, .kind = .final },
    },
    .transitions = &.{
        .{ .id = "start", .source = .idle, .event = .start, .target = .working },
        .{ .id = "ambiguous-start", .source = .idle, .event = .start, .target = .dead_end },
        .{ .id = "finish", .source = .working, .event = .finish, .target = .done },
    },
});

test "statechart analysis reports unreachable dead-end and ambiguous logic" {
    const report = Analyzer.analyze(&definition);

    try std.testing.expect(report.has(.unreachable_state));
    try std.testing.expect(report.hasState(.unreachable_state, .orphan));
    try std.testing.expect(report.has(.non_final_dead_end));
    try std.testing.expect(report.hasState(.non_final_dead_end, .dead_end));
    try std.testing.expect(report.has(.ambiguous_unguarded_transition));

    for (report.findings()) |finding| {
        try std.testing.expect(finding.id != 0);
        try std.testing.expect(finding.message.len != 0);
    }
}

test "statechart shortest paths are deterministic and bounded" {
    const paths = Analyzer.shortestPaths(&definition);
    try std.testing.expect(paths.isReachable(.done));
    try std.testing.expectEqual(@as(usize, 2), paths.distanceTo(.done).?);

    var storage: [8][]const u8 = undefined;
    const path = try paths.pathTo(.done, &storage);
    try std.testing.expectEqual(@as(usize, 2), path.len);
    try std.testing.expectEqualStrings("start", path[0]);
    try std.testing.expectEqualStrings("finish", path[1]);
    try std.testing.expect(!paths.isReachable(.orphan));
}

const CycleState = enum { a, b, stable };
const CycleEvent = enum { tick };
const CycleDef = fx.statechart.Definition(CycleState, CycleEvent, Context, Command);
const CycleAnalyzer = fx.statechart.Analyzer(CycleDef);
const cycle_definition = CycleDef.init(.{
    .id = "agent.analysis-cycle",
    .version = 1,
    .initial = .a,
    .states = &.{
        .{ .id = .a },
        .{ .id = .b },
        .{ .id = .stable },
    },
    .transitions = &.{
        .{ .id = "a-b", .source = .a, .target = .b },
        .{ .id = "b-a", .source = .b, .target = .a },
    },
});

test "statechart analysis detects potential eventless cycles without executing guards" {
    const report = CycleAnalyzer.analyze(&cycle_definition);
    try std.testing.expect(report.has(.eventless_cycle));
    try std.testing.expect(report.hasState(.unreachable_state, .stable));
}

test "hierarchical analysis expands compound and parallel initial configurations" {
    const HierState = enum { root, work, left, left_idle, left_done, right, right_idle, right_done, orphan };
    const HierEvent = enum { advance };
    const HierDef = fx.statechart.Definition(HierState, HierEvent, void, void);
    const HierAnalyzer = fx.statechart.Analyzer(HierDef);
    const hierarchical = HierDef.init(.{
        .id = "agent.hierarchy-analysis",
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
            .{ .id = .orphan, .parent = .root },
        },
        .transitions = &.{
            .{ .id = "advance-left", .source = .left_idle, .event = .advance, .target = .left_done },
            .{ .id = "advance-right", .source = .right_idle, .event = .advance, .target = .right_done },
        },
    });

    const paths = HierAnalyzer.shortestPaths(&hierarchical);
    try std.testing.expect(paths.isReachable(.root));
    try std.testing.expect(paths.isReachable(.work));
    try std.testing.expect(paths.isReachable(.left_idle));
    try std.testing.expect(paths.isReachable(.right_idle));
    try std.testing.expectEqual(@as(usize, 0), paths.distanceTo(.left_idle).?);
    try std.testing.expectEqual(@as(usize, 1), paths.distanceTo(.left_done).?);
    try std.testing.expect(!paths.isReachable(.orphan));

    const report = HierAnalyzer.analyze(&hierarchical);
    try std.testing.expect(report.hasState(.unreachable_state, .orphan));
    try std.testing.expect(!report.hasState(.non_final_dead_end, .root));
    try std.testing.expect(!report.hasState(.non_final_dead_end, .work));
}
