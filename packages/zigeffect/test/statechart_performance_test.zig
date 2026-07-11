const std = @import("std");
const fx = @import("zigeffect");

const State = enum { left, right };
const Event = enum { toggle };
const Def = fx.statechart.Definition(State, Event, void, void);
const Runtime = fx.statechart.Machine(Def);
const Actor = fx.statechart.Actor(Def);
const Durable = fx.workflow.DurableStatechart(Def);

const definition = Def.init(.{
    .id = "performance.statechart-toggle",
    .version = 1,
    .initial = .left,
    .states = &.{ .{ .id = .left }, .{ .id = .right } },
    .transitions = &.{
        .{ .id = "left-right", .source = .left, .event = .toggle, .target = .right },
        .{ .id = "right-left", .source = .right, .event = .toggle, .target = .left },
    },
});

test "statechart latency actor throughput and replay cost remain inside production budgets" {
    const step_iterations: usize = 20_000;
    var snapshot = Runtime.initial(&definition, {}, 100);
    const step_start = std.Io.Clock.awake.now(std.testing.io);
    for (0..step_iterations) |_| snapshot = (try Runtime.step(&definition, snapshot, .toggle)).next;
    const step_ns: u64 = @intCast(@max(0, step_start.durationTo(std.Io.Clock.awake.now(std.testing.io)).nanoseconds));
    const average_step_ns = step_ns / step_iterations;
    try std.testing.expect(average_step_ns <= 500_000); // 0.5 ms in Debug

    const actor_iterations: usize = 5_000;
    var actor = try Actor.init(std.testing.allocator, &definition, {}, .{ .instance_id = 101, .mailbox_capacity = 1 });
    defer actor.deinit();
    const actor_start = std.Io.Clock.awake.now(std.testing.io);
    for (0..actor_iterations) |_| {
        _ = try actor.send(.toggle);
        _ = try actor.processNext();
    }
    const actor_ns: u64 = @intCast(@max(0, actor_start.durationTo(std.Io.Clock.awake.now(std.testing.io)).nanoseconds));
    try std.testing.expect(actor_ns / actor_iterations <= 2_000_000); // 2 ms/message in Debug

    const replay_events: usize = 500;
    var memory = Durable.InMemoryJournal.init(std.testing.allocator);
    defer memory.deinit();
    var durable = Durable.init(std.testing.allocator, &definition, memory.store());
    for (0..replay_events) |index| _ = try durable.handle({}, 102, @intCast(index + 1), .toggle);
    const replay_start = std.Io.Clock.awake.now(std.testing.io);
    const restored = (try durable.restore(102)).?;
    const replay_ns: u64 = @intCast(@max(0, replay_start.durationTo(std.Io.Clock.awake.now(std.testing.io)).nanoseconds));
    try std.testing.expect(replay_ns / replay_events <= 1_000_000); // amortized 1 ms/record in Debug
    try std.testing.expectEqual(@as(u64, replay_events), restored.revision);
}
