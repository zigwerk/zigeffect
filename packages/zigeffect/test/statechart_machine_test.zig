const std = @import("std");
const fx = @import("zigeffect");

const State = enum { idle, running, done };
const Event = union(enum) {
    start: struct { request_id: u64 },
    finish,
    touch,
};
const Context = struct {
    value: u32 = 1,
    allow: bool = false,
};
const Command = union(enum) {
    started: u64,
    finished,
};

const Def = fx.statechart.Definition(State, Event, Context, Command);
const Runtime = fx.statechart.Machine(Def);

fn never(_: *const Context, _: *const Event) bool {
    return false;
}

fn allowed(context: *const Context, _: *const Event) bool {
    return context.allow;
}

fn exitIdle(context: *Context, _: *const Event, _: *Def.CommandSink) anyerror!void {
    context.value += 1;
}

fn startWork(context: *Context, event: *const Event, commands: *Def.CommandSink) anyerror!void {
    context.value *= 3;
    try commands.emit(.{ .started = event.start.request_id });
}

fn enterRunning(context: *Context, _: *const Event, _: *Def.CommandSink) anyerror!void {
    context.value += 5;
}

fn touch(context: *Context, _: *const Event, _: *Def.CommandSink) anyerror!void {
    context.value += 10;
}

fn failAfterMutation(context: *Context, _: *const Event, commands: *Def.CommandSink) anyerror!void {
    context.value = 999;
    try commands.emit(.finished);
    return error.DeliberateActionFailure;
}

const exit_idle = Def.Action{ .id = "exit-idle", .execute = exitIdle };
const start_work = Def.Action{ .id = "start-work", .execute = startWork };
const enter_running = Def.Action{ .id = "enter-running", .execute = enterRunning };
const touch_action = Def.Action{ .id = "touch", .execute = touch };
const fail_action = Def.Action{ .id = "fail", .execute = failAfterMutation };

fn definitionWithStartAction(comptime action: Def.Action) Def {
    return Def.init(.{
        .id = "agent.runtime",
        .version = 1,
        .initial = .idle,
        .states = &.{
            .{ .id = .idle, .exit_actions = &.{exit_idle} },
            .{ .id = .running, .entry_actions = &.{enter_running} },
            .{ .id = .done, .kind = .final },
        },
        .transitions = &.{
            .{
                .id = "start-blocked",
                .source = .idle,
                .event = .start,
                .target = .running,
                .guard = .{ .id = "never", .evaluate = never },
            },
            .{
                .id = "start",
                .source = .idle,
                .event = .start,
                .target = .running,
                .guard = .{ .id = "allowed", .evaluate = allowed },
                .actions = &.{action},
            },
            .{
                .id = "touch",
                .source = .running,
                .event = .touch,
                .actions = &.{touch_action},
            },
            .{
                .id = "restart",
                .source = .running,
                .event = .start,
                .target = .running,
                .reenter = true,
                .actions = &.{start_work},
            },
            .{
                .id = "finish",
                .source = .running,
                .event = .finish,
                .target = .done,
            },
        },
    });
}

test "flat machine initialization executes initial entry and invocation actions transactionally" {
    const initialization_definition = Def.init(.{
        .id = "agent.flat-initialization",
        .version = 1,
        .initial = .idle,
        .states = &.{
            .{
                .id = .idle,
                .entry_actions = &.{touch_action},
                .invocations = &.{.{
                    .id = "worker",
                    .start = .{ .id = "start-worker", .execute = startWork },
                }},
            },
            .{ .id = .running },
            .{ .id = .done, .kind = .final },
        },
        .transitions = &.{},
    });

    const initialized = try Runtime.initialize(
        &initialization_definition,
        .{ .value = 2, .allow = true },
        51,
        .{ .start = .{ .request_id = 9 } },
    );
    try std.testing.expect(Runtime.requiresInitializationEvent(&initialization_definition));
    try std.testing.expectEqual(@as(u32, 36), initialized.snapshot.context.value);
    try std.testing.expectEqualSlices(Command, &.{.{ .started = 9 }}, initialized.commands());
    try std.testing.expectEqualSlices(
        Runtime.ActionPhase,
        &.{ .entry, .invoke_start },
        &.{ initialized.actions()[0].phase, initialized.actions()[1].phase },
    );
}

test "statechart kernel selects ordered guards and applies exit transition entry actions" {
    const definition = definitionWithStartAction(start_work);
    const snapshot = Runtime.initial(&definition, .{ .allow = true }, 41);
    const event = Event{ .start = .{ .request_id = 77 } };

    const decision = try Runtime.step(&definition, snapshot, event);

    try std.testing.expectEqual(Runtime.DecisionOutcome.transitioned, decision.outcome);
    try std.testing.expectEqualStrings("start", decision.selected_transition_id);
    try std.testing.expectEqual(State.running, decision.next.state);
    try std.testing.expectEqual(@as(u32, 11), decision.next.context.value);
    try std.testing.expectEqual(@as(u64, 1), decision.next.revision);
    try std.testing.expectEqual(@as(usize, 1), decision.commands().len);
    try std.testing.expectEqual(@as(u64, 77), decision.commands()[0].started);
    try std.testing.expectEqualSlices(
        Runtime.ActionPhase,
        &.{ .exit, .transition, .entry },
        &.{ decision.actions()[0].phase, decision.actions()[1].phase, decision.actions()[2].phase },
    );
    try std.testing.expectEqualStrings("exit-idle", decision.actions()[0].action_id);
    try std.testing.expectEqualStrings("start-work", decision.actions()[1].action_id);
    try std.testing.expectEqualStrings("enter-running", decision.actions()[2].action_id);
}

test "targetless transition updates context without leaving and reentering state" {
    const definition = definitionWithStartAction(start_work);
    const running = Runtime.Snapshot{
        .definition_fingerprint = definition.fingerprint(),
        .instance_id = 1,
        .state = .running,
        .context = .{ .value = 2, .allow = true },
        .status = .active,
        .revision = 4,
    };

    const decision = try Runtime.step(&definition, running, .touch);
    try std.testing.expectEqual(State.running, decision.next.state);
    try std.testing.expectEqual(@as(u32, 12), decision.next.context.value);
    try std.testing.expectEqual(@as(usize, 1), decision.actions().len);
    try std.testing.expectEqual(Runtime.ActionPhase.transition, decision.actions()[0].phase);
}

test "explicit self reentry runs exit and entry actions" {
    const definition = definitionWithStartAction(start_work);
    const running = Runtime.Snapshot{
        .definition_fingerprint = definition.fingerprint(),
        .instance_id = 1,
        .state = .running,
        .context = .{ .value = 2, .allow = true },
        .status = .active,
        .revision = 0,
    };

    const decision = try Runtime.step(&definition, running, .{ .start = .{ .request_id = 8 } });
    try std.testing.expectEqual(@as(usize, 2), decision.actions().len);
    try std.testing.expectEqual(Runtime.ActionPhase.transition, decision.actions()[0].phase);
    try std.testing.expectEqual(Runtime.ActionPhase.entry, decision.actions()[1].phase);
    try std.testing.expectEqual(@as(u32, 11), decision.next.context.value);
}

test "action failure rolls back context and typed commands" {
    const definition = definitionWithStartAction(fail_action);
    const snapshot = Runtime.initial(&definition, .{ .allow = true }, 9);

    try std.testing.expectError(
        error.ActionFailed,
        Runtime.step(&definition, snapshot, .{ .start = .{ .request_id = 1 } }),
    );
    try std.testing.expectEqual(@as(u32, 1), snapshot.context.value);
    try std.testing.expectEqual(State.idle, snapshot.state);
    try std.testing.expectEqual(@as(u64, 0), snapshot.revision);
}

test "ignored events do not change snapshot revision" {
    const definition = definitionWithStartAction(start_work);
    const snapshot = Runtime.initial(&definition, .{ .allow = false }, 2);

    const decision = try Runtime.step(&definition, snapshot, .{ .start = .{ .request_id = 1 } });
    try std.testing.expectEqual(Runtime.DecisionOutcome.ignored, decision.outcome);
    try std.testing.expectEqual(@as(u64, 0), decision.next.revision);
    try std.testing.expectEqual(@as(usize, 0), decision.commands().len);
    try std.testing.expectEqual(@as(usize, 0), decision.actions().len);
}

test "entering a final state completes the snapshot" {
    const definition = definitionWithStartAction(start_work);
    var running = Runtime.initial(&definition, .{ .allow = true }, 2);
    running.state = .running;

    const decision = try Runtime.step(&definition, running, .finish);
    try std.testing.expectEqual(Runtime.SnapshotStatus.done, decision.next.status);
    try std.testing.expectEqual(State.done, decision.next.state);
}

test "decision fingerprints are deterministic" {
    const definition = definitionWithStartAction(start_work);
    const snapshot = Runtime.initial(&definition, .{ .allow = true }, 2);
    const event = Event{ .start = .{ .request_id = 99 } };

    const left = try Runtime.step(&definition, snapshot, event);
    const right = try Runtime.step(&definition, snapshot, event);
    try std.testing.expect(left.fingerprint != 0);
    try std.testing.expectEqual(left.fingerprint, right.fingerprint);
}
