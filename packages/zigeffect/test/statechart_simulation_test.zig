const std = @import("std");
const fx = @import("zigeffect");

const State = enum { idle, running, done };
const Event = enum { start, finish, reset };
const Def = fx.statechart.Definition(State, Event, void, void);
const Runtime = fx.statechart.Machine(Def);
const Simulation = fx.statechart.Simulation(Def);

const definition = Def.init(.{
    .id = "agent.simulation",
    .version = 1,
    .initial = .idle,
    .states = &.{ .{ .id = .idle }, .{ .id = .running }, .{ .id = .done, .kind = .final } },
    .transitions = &.{
        .{ .id = "start", .source = .idle, .event = .start, .target = .running },
        .{ .id = "finish", .source = .running, .event = .finish, .target = .done },
    },
});

test "statechart simulation records replayable steps and transition breakpoints" {
    const initial = Runtime.initial(&definition, {}, 71);
    const result = try Simulation.run(&definition, initial, &.{ .start, .finish, .reset }, .{
        .transition_breakpoints = &.{"finish"},
    });

    try std.testing.expectEqual(@as(usize, 2), result.steps().len);
    try std.testing.expectEqual(Simulation.StopReason.breakpoint, result.stop_reason);
    try std.testing.expectEqualStrings("finish", result.steps()[1].transitionIds()[0]);
    try std.testing.expectEqual(State.done, result.final_snapshot.state);
    try std.testing.expectEqual(State.idle, result.snapshotAt(0).?.state);
    try std.testing.expectEqual(State.running, result.snapshotAt(1).?.state);
    try std.testing.expectEqual(State.done, result.snapshotAt(2).?.state);
}

test "statechart temporal invariants prove eventual never precedes and terminal properties" {
    const initial = Runtime.initial(&definition, {}, 72);
    const result = try Simulation.run(&definition, initial, &.{ .start, .finish }, .{});
    const report = Simulation.evaluateInvariants(&result, &.{
        .{ .id = "eventually-done", .kind = .eventually_active, .state = .done },
        .{ .id = "never-idle-again", .kind = .never_active_after_first_step, .state = .idle },
        .{ .id = "running-before-done", .kind = .precedes, .before = .running, .state = .done },
        .{ .id = "terminal", .kind = .terminal },
    });
    try std.testing.expect(report.complete());
    try std.testing.expectEqual(@as(usize, 4), report.results().len);

    const failed = Simulation.evaluateInvariants(&result, &.{
        .{ .id = "idle-eventually", .kind = .eventually_active, .state = .idle },
    });
    try std.testing.expect(!failed.complete());
    try std.testing.expectEqual(Simulation.InvariantStatus.failed, failed.results()[0].status);
}

test "statechart simulation reports exhausted bounds as incomplete" {
    const initial = Runtime.initial(&definition, {}, 73);
    const result = try Simulation.run(&definition, initial, &.{ .start, .finish }, .{ .max_steps = 1 });
    try std.testing.expectEqual(Simulation.StopReason.step_limit, result.stop_reason);
    try std.testing.expect(result.truncated);
}

test "hierarchical statechart simulation preserves active configurations and temporal proofs" {
    const HierState = enum { root, working, idle, done };
    const HierEvent = enum { finish };
    const HierDef = fx.statechart.Definition(HierState, HierEvent, void, void);
    const HierRuntime = fx.statechart.ConfigurationMachine(HierDef);
    const HierSimulation = fx.statechart.ConfigurationSimulation(HierDef);
    const hier_definition = HierDef.init(.{
        .id = "agent.hierarchical-simulation",
        .version = 1,
        .initial = .root,
        .states = &.{
            .{ .id = .root, .kind = .compound, .initial = .working },
            .{ .id = .working, .kind = .compound, .parent = .root, .initial = .idle },
            .{ .id = .idle, .parent = .working },
            .{ .id = .done, .kind = .final, .parent = .working },
        },
        .transitions = &.{.{ .id = "finish", .source = .idle, .event = .finish, .target = .done }},
    });
    const initial = try HierRuntime.initial(&hier_definition, {}, 90);
    var result = try HierSimulation.run(std.testing.allocator, &hier_definition, initial, &.{.finish}, .{ .state_breakpoints = &.{.done} });
    defer result.deinit();
    try std.testing.expectEqual(HierSimulation.StopReason.breakpoint, result.stop_reason);
    try std.testing.expect(result.final_snapshot.isActive(.root));
    try std.testing.expect(result.final_snapshot.isActive(.working));
    try std.testing.expect(result.final_snapshot.isActive(.done));
    const report = HierSimulation.evaluateInvariants(&result, &.{
        .{ .id = "root-always", .kind = .always_active, .state = .root },
        .{ .id = "idle-before-done", .kind = .precedes, .before = .idle, .state = .done },
        .{ .id = "eventually-done", .kind = .eventually_active, .state = .done },
    });
    try std.testing.expect(report.complete());
}
