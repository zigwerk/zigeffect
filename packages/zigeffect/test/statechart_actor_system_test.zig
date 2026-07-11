const std = @import("std");
const fx = @import("zigeffect");

const State = enum { idle, running };
const Event = enum { start, tick };
const Context = struct { ticks: u32 = 0 };
const Command = void;
const Def = fx.statechart.Definition(State, Event, Context, Command);
const System = fx.statechart.ActorSystem(Def);

fn tick(context: *Context, _: *const Event, _: *Def.CommandSink) anyerror!void {
    context.ticks += 1;
}

const definition = Def.init(.{
    .id = "agent.actor-system",
    .version = 1,
    .initial = .idle,
    .states = &.{ .{ .id = .idle }, .{ .id = .running } },
    .transitions = &.{
        .{ .id = "start", .source = .idle, .event = .start, .target = .running },
        .{ .id = "tick-idle", .source = .idle, .event = .tick, .actions = &.{.{ .id = "tick", .execute = tick }} },
        .{ .id = "tick-running", .source = .running, .event = .tick, .actions = &.{.{ .id = "tick", .execute = tick }} },
    },
});

test "actor system owns addressable parent child trees and cascades interruption" {
    var system = try System.init(std.testing.allocator, &definition, .{ .capacity = 4, .dead_letter_capacity = 4 });
    defer system.deinit();

    try system.spawn(.{}, .{ .instance_id = 1, .name = "coordinator" });
    try system.spawn(.{}, .{ .instance_id = 2, .name = "researcher", .parent_instance_id = 1 });
    try std.testing.expectEqual(System.SendDisposition.delivered, try system.send("researcher", .tick, .{
        .sender_instance_id = 1,
        .correlation_id = 91,
        .trace_id = 1001,
        .boundary_id = 2001,
    }));
    const processed = try system.process("researcher");
    try std.testing.expectEqual(@as(u32, 1), processed.snapshot.context.ticks);
    try std.testing.expectEqual(@as(u64, 91), processed.envelope.correlation_id);
    try std.testing.expectEqual(@as(u64, 1001), processed.envelope.trace_id);

    try system.stop(1);
    try std.testing.expectEqual(fx.statechart.ActorStatus.stopped, system.status(1).?);
    try std.testing.expectEqual(fx.statechart.ActorStatus.stopped, system.status(2).?);
}

test "actor system checkpoints and restores actor tree snapshots mailboxes and fences" {
    var original = try System.init(std.testing.allocator, &definition, .{ .capacity = 4, .dead_letter_capacity = 4 });
    defer original.deinit();
    try original.spawn(.{}, .{ .instance_id = 31, .name = "coordinator" });
    try original.spawn(.{}, .{ .instance_id = 32, .name = "worker", .parent_instance_id = 31 });
    try original.claim(32, "runner-a", 7);
    _ = try original.send("worker", .tick, .{ .correlation_id = 88, .expected_fence_epoch = 7 });

    var checkpoint = try original.checkpoint(std.testing.allocator);
    defer checkpoint.deinit();
    var restored = try System.restore(std.testing.allocator, &definition, &checkpoint, .{ .capacity = 4, .dead_letter_capacity = 4 }, null);
    defer restored.deinit();

    const processed = try restored.processOwned("worker", "runner-a", 7);
    try std.testing.expectEqual(@as(u32, 1), processed.snapshot.context.ticks);
    try std.testing.expectEqual(@as(u64, 88), processed.envelope.correlation_id);
    try restored.stop(31);
    try std.testing.expectEqual(fx.statechart.ActorStatus.stopped, restored.status(31).?);
    try std.testing.expectEqual(fx.statechart.ActorStatus.stopped, restored.status(32).?);
}

test "actor system records bounded dead letters without confusing them with delivery" {
    var system = try System.init(std.testing.allocator, &definition, .{ .capacity = 2, .dead_letter_capacity = 2 });
    defer system.deinit();

    try std.testing.expectEqual(System.SendDisposition.dead_letter, try system.send("missing", .tick, .{ .correlation_id = 7 }));
    var storage: [4]System.DeadLetter = undefined;
    const dead_letters = system.copyDeadLetters(&storage);
    try std.testing.expectEqual(@as(usize, 1), dead_letters.len);
    try std.testing.expectEqualStrings("missing", dead_letters[0].recipient);
    try std.testing.expectEqual(@as(u64, 7), dead_letters[0].envelope.correlation_id);
}

test "actor system fences stale cluster owners before processing" {
    var system = try System.init(std.testing.allocator, &definition, .{ .capacity = 2, .dead_letter_capacity = 2 });
    defer system.deinit();
    try system.spawn(.{}, .{ .instance_id = 8, .name = "durable-review" });
    try system.claim(8, "runner-a", 4);
    _ = try system.send("durable-review", .tick, .{ .expected_fence_epoch = 4 });

    try std.testing.expectError(error.StaleFence, system.processOwned("durable-review", "runner-a", 3));
    try std.testing.expectError(error.NotLeaseOwner, system.processOwned("durable-review", "runner-b", 4));
    const processed = try system.processOwned("durable-review", "runner-a", 4);
    try std.testing.expectEqual(@as(u32, 1), processed.snapshot.context.ticks);

    try system.claim(8, "runner-b", 5);
    try std.testing.expectError(error.StaleFence, system.send("durable-review", .tick, .{ .expected_fence_epoch = 4 }));
}

test "actor system control adapter preserves policy fencing and typed signals" {
    var system = try System.init(std.testing.allocator, &definition, .{ .capacity = 2, .dead_letter_capacity = 2 });
    defer system.deinit();
    try system.spawn(.{}, .{ .instance_id = 9, .name = "controlled" });
    try system.claim(9, "runner-a", 6);

    const Plane = fx.statechart.ControlPlane(Event);
    const Allow = struct {
        fn decide(_: *anyopaque, _: Plane.Request) fx.statechart.ControlDecision {
            return .allow;
        }
    };
    var policy_context: u8 = 0;
    var plane = Plane.init(system.controlAdapter());
    plane.policy = .{ .context = &policy_context, .decide_fn = Allow.decide };
    const receipt = try plane.execute(.{
        .request_id = "signal-controlled",
        .machine_id = definition.id,
        .instance_id = 9,
        .operation = .signal,
        .expected_definition_fingerprint = definition.fingerprint(),
        .expected_fence_epoch = 6,
        .reason = "verified operator signal",
        .event = .tick,
        .correlation_id = 91,
    });
    try std.testing.expectEqual(fx.statechart.ControlStatus.applied, receipt.status);
    const processed = try system.processOwned("controlled", "runner-a", 6);
    try std.testing.expectEqual(@as(u32, 1), processed.snapshot.context.ticks);
    try std.testing.expectEqual(@as(u64, 91), processed.envelope.correlation_id);
}

const SuperState = enum { idle, running };
const SuperEvent = enum { start };
const SuperCommand = enum { work };
const SuperDef = fx.statechart.Definition(SuperState, SuperEvent, void, SuperCommand);
const SuperSystem = fx.statechart.ActorSystem(SuperDef);

fn emitWork(_: *void, _: *const SuperEvent, sink: *SuperDef.CommandSink) anyerror!void {
    try sink.emit(.work);
}

const supervision_definition = SuperDef.init(.{
    .id = "agent.supervision",
    .version = 1,
    .initial = .idle,
    .states = &.{ .{ .id = .idle }, .{ .id = .running } },
    .transitions = &.{.{ .id = "start", .source = .idle, .event = .start, .target = .running, .actions = &.{.{ .id = "work", .execute = emitWork }} }},
});

const FailingExecutor = struct {
    fn execute(_: *anyopaque, _: SuperCommand) anyerror!void {
        return error.SimulatedChildFailure;
    }
};

test "actor supervision supports resume restart and escalation policies" {
    var executor_context: u8 = 0;
    const executor = fx.statechart.Actor(SuperDef).CommandExecutor{ .context = &executor_context, .execute_fn = FailingExecutor.execute };

    var resumed = try SuperSystem.init(std.testing.allocator, &supervision_definition, .{});
    defer resumed.deinit();
    try resumed.spawn({}, .{ .instance_id = 20, .name = "resumed", .executor = executor, .supervision = .@"resume" });
    _ = try resumed.send("resumed", .start, .{});
    try std.testing.expectError(error.CommandExecutionFailed, resumed.process("resumed"));
    try std.testing.expectEqual(fx.statechart.ActorStatus.running, resumed.status(20).?);

    var restarted = try SuperSystem.init(std.testing.allocator, &supervision_definition, .{});
    defer restarted.deinit();
    try restarted.spawn({}, .{ .instance_id = 21, .name = "restarted", .executor = executor, .supervision = .restart });
    _ = try restarted.send("restarted", .start, .{});
    try std.testing.expectError(error.CommandExecutionFailed, restarted.process("restarted"));
    try std.testing.expectEqual(fx.statechart.ActorStatus.running, restarted.status(21).?);

    var escalated = try SuperSystem.init(std.testing.allocator, &supervision_definition, .{});
    defer escalated.deinit();
    try escalated.spawn({}, .{ .instance_id = 22, .name = "parent" });
    try escalated.spawn({}, .{ .instance_id = 23, .name = "child", .parent_instance_id = 22, .executor = executor, .supervision = .escalate });
    _ = try escalated.send("child", .start, .{});
    try std.testing.expectError(error.CommandExecutionFailed, escalated.process("child"));
    try std.testing.expectEqual(fx.statechart.ActorStatus.stopped, escalated.status(22).?);
    try std.testing.expectEqual(fx.statechart.ActorStatus.stopped, escalated.status(23).?);
}
