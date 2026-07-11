const std = @import("std");
const fx = @import("zigeffect");

const State = enum { idle, running };
const Event = union(enum) { start: u64, touch };
const Context = struct { total: u64 = 0 };
const Command = union(enum) { execute: u64 };
const Def = fx.statechart.Definition(State, Event, Context, Command);
const Actor = fx.statechart.Actor(Def);

fn start(context: *Context, event: *const Event, sink: *Def.CommandSink) anyerror!void {
    context.total += event.start;
    try sink.emit(.{ .execute = event.start });
}

fn touch(context: *Context, _: *const Event, _: *Def.CommandSink) anyerror!void {
    context.total += 1;
}

const definition = Def.init(.{
    .id = "agent.actor",
    .version = 1,
    .initial = .idle,
    .states = &.{
        .{ .id = .idle },
        .{ .id = .running },
    },
    .transitions = &.{
        .{ .id = "touch-idle", .source = .idle, .event = .touch, .actions = &.{.{ .id = "touch", .execute = touch }} },
        .{ .id = "start", .source = .idle, .event = .start, .target = .running, .actions = &.{.{ .id = "start", .execute = start }} },
        .{ .id = "touch", .source = .running, .event = .touch, .actions = &.{.{ .id = "touch", .execute = touch }} },
    },
});

const ExecutorState = struct {
    calls: usize = 0,
    total: u64 = 0,

    fn execute(opaque_ptr: *anyopaque, command: Command) anyerror!void {
        const self: *ExecutorState = @ptrCast(@alignCast(opaque_ptr));
        self.calls += 1;
        self.total += command.execute;
    }
};

const SubscriberState = struct {
    calls: usize = 0,
    last_revision: u64 = 0,
    last_state: State = .idle,

    fn notify(opaque_ptr: *anyopaque, snapshot: Actor.Snapshot) void {
        const self: *SubscriberState = @ptrCast(@alignCast(opaque_ptr));
        self.calls += 1;
        self.last_revision = snapshot.revision;
        self.last_state = snapshot.state;
    }
};

test "statechart actors process bounded mailboxes execute commands and publish snapshots" {
    const allocator = std.testing.allocator;
    var executor_state = ExecutorState{};
    var actor = try Actor.init(allocator, &definition, .{}, .{
        .instance_id = 41,
        .mailbox_capacity = 4,
        .inspection_capacity = 16,
        .subscriber_capacity = 2,
        .executor = .{ .context = &executor_state, .execute_fn = ExecutorState.execute },
    });
    defer actor.deinit();

    var subscriber_state = SubscriberState{};
    const subscription_id = try actor.subscribe(.{
        .context = &subscriber_state,
        .notify_fn = SubscriberState.notify,
    });
    defer actor.unsubscribe(subscription_id);

    try std.testing.expectEqual(Actor.SendResult.enqueued, try actor.send(.{ .start = 7 }));
    try std.testing.expectEqual(@as(usize, 1), actor.mailboxSize());
    const processed = try actor.processNext();

    try std.testing.expectEqual(Actor.ProcessStatus.processed, processed.status);
    try std.testing.expectEqualStrings("start", processed.transition_id);
    try std.testing.expectEqual(State.running, actor.snapshot().state);
    try std.testing.expectEqual(@as(u64, 7), actor.snapshot().context.total);
    try std.testing.expectEqual(@as(usize, 0), actor.mailboxSize());
    try std.testing.expectEqual(@as(usize, 1), executor_state.calls);
    try std.testing.expectEqual(@as(u64, 7), executor_state.total);
    try std.testing.expectEqual(@as(usize, 1), subscriber_state.calls);
    try std.testing.expectEqual(State.running, subscriber_state.last_state);
    try std.testing.expectEqual(@as(u64, 1), subscriber_state.last_revision);

    var inspection: [32]Actor.InspectionRecord = undefined;
    const records = actor.copyInspection(&inspection);
    try std.testing.expect(records.len >= 4);
    try std.testing.expect(records[0].kind == .actor_started);
    try std.testing.expect(hasInspection(records, .event_enqueued));
    try std.testing.expect(hasInspection(records, .macrostep_committed));
    try std.testing.expect(hasInspection(records, .command_completed));
}

test "statechart actor instances are isolated" {
    const allocator = std.testing.allocator;
    var left = try Actor.init(allocator, &definition, .{}, .{ .instance_id = 1, .mailbox_capacity = 2 });
    defer left.deinit();
    var right = try Actor.init(allocator, &definition, .{}, .{ .instance_id = 2, .mailbox_capacity = 2 });
    defer right.deinit();

    try std.testing.expectEqual(Actor.SendResult.enqueued, try left.send(.touch));
    _ = try left.processNext();
    try std.testing.expectEqual(@as(u64, 0), right.snapshot().revision);
    try std.testing.expectEqual(State.idle, right.snapshot().state);
}

test "flat actors require typed initialization when initial entry actions exist" {
    const initialized_definition = Def.init(.{
        .id = "agent.actor.initialized",
        .version = 1,
        .initial = .idle,
        .states = &.{
            .{ .id = .idle, .entry_actions = &.{.{ .id = "touch", .execute = touch }} },
            .{ .id = .running },
        },
        .transitions = &.{},
    });
    try std.testing.expectError(
        error.MissingInitializationEvent,
        Actor.init(std.testing.allocator, &initialized_definition, .{}, .{ .instance_id = 100 }),
    );
    var actor = try Actor.initWithEvent(
        std.testing.allocator,
        &initialized_definition,
        .{},
        .touch,
        .{ .instance_id = 100 },
    );
    defer actor.deinit();
    try std.testing.expectEqual(@as(u64, 1), actor.snapshot().context.total);
}

test "statechart mailbox overflow policies are explicit" {
    const allocator = std.testing.allocator;
    var rejecting = try Actor.init(allocator, &definition, .{}, .{
        .instance_id = 3,
        .mailbox_capacity = 1,
        .overflow_policy = .reject,
    });
    defer rejecting.deinit();
    _ = try rejecting.send(.touch);
    try std.testing.expectError(error.MailboxFull, rejecting.send(.touch));

    var dropping = try Actor.init(allocator, &definition, .{}, .{
        .instance_id = 4,
        .mailbox_capacity = 1,
        .overflow_policy = .drop_oldest,
    });
    defer dropping.deinit();
    _ = try dropping.send(.touch);
    try std.testing.expectEqual(Actor.SendResult.replaced_oldest, try dropping.send(.{ .start = 2 }));
    try std.testing.expectEqual(@as(usize, 1), dropping.mailboxSize());
}

test "stopped statechart actors reject new events" {
    const allocator = std.testing.allocator;
    var actor = try Actor.init(allocator, &definition, .{}, .{ .instance_id = 9 });
    defer actor.deinit();
    actor.stop();
    try std.testing.expectEqual(Actor.Status.stopped, actor.status());
    try std.testing.expectError(error.ActorStopped, actor.send(.touch));
}

test "statechart actors reject mutation from a foreign executor thread" {
    var actor = try Actor.init(std.testing.allocator, &definition, .{}, .{ .instance_id = 10 });
    defer actor.deinit();
    var observed_error: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, struct {
        fn run(target: *Actor, error_slot: *?anyerror) void {
            _ = target.send(.touch) catch |err| {
                error_slot.* = err;
                return;
            };
        }
    }.run, .{ &actor, &observed_error });
    thread.join();

    try std.testing.expect(observed_error != null);
    try std.testing.expect(observed_error.? == error.WrongExecutor);
    try std.testing.expectEqual(@as(usize, 0), actor.mailboxSize());
}

fn hasInspection(records: []const Actor.InspectionRecord, kind: Actor.InspectionKind) bool {
    for (records) |record| if (record.kind == kind) return true;
    return false;
}
