const std = @import("std");
const fx = @import("zigeffect");

const State = enum { idle, choosing, notified, done };
const Event = union(enum) { start, settle };
const Context = struct { ready: bool = false };
const Command = enum { started, stabilized };

const Def = fx.statechart.Definition(State, Event, Context, Command);
const Runtime = fx.statechart.Machine(Def);
const Macro = fx.statechart.Macrostep(Def);

fn startAction(context: *Context, _: *const Event, sink: *Def.CommandSink) anyerror!void {
    context.ready = true;
    try sink.emit(.started);
    try sink.raise(.settle);
}

fn stabilized(_: *Context, _: *const Event, sink: *Def.CommandSink) anyerror!void {
    try sink.emit(.stabilized);
}

fn ready(context: *const Context, _: *const Event) bool {
    return context.ready;
}

const definition = Def.init(.{
    .id = "agent.macrostep",
    .version = 1,
    .initial = .idle,
    .states = &.{
        .{ .id = .idle },
        .{ .id = .choosing },
        .{ .id = .notified },
        .{ .id = .done, .kind = .final },
    },
    .transitions = &.{
        .{
            .id = "start",
            .source = .idle,
            .event = .start,
            .target = .choosing,
            .actions = &.{.{ .id = "start", .execute = startAction }},
        },
        .{
            .id = "choose",
            .source = .choosing,
            .target = .notified,
            .guard = .{ .id = "ready", .evaluate = ready },
            .actions = &.{.{ .id = "stabilized", .execute = stabilized }},
        },
        .{
            .id = "settle",
            .source = .notified,
            .event = .settle,
            .target = .done,
        },
    },
});

test "macrostep processes eventless transitions before raised internal events" {
    const snapshot = Runtime.initial(&definition, .{}, 5);
    const result = try Macro.run(&definition, snapshot, .start);

    try std.testing.expectEqual(State.done, result.next.state);
    try std.testing.expectEqual(Runtime.SnapshotStatus.done, result.next.status);
    try std.testing.expectEqual(@as(usize, 3), result.microsteps().len);
    try std.testing.expectEqualStrings("start", result.microsteps()[0].transition_id);
    try std.testing.expectEqualStrings("choose", result.microsteps()[1].transition_id);
    try std.testing.expectEqualStrings("settle", result.microsteps()[2].transition_id);
    try std.testing.expectEqualSlices(Command, &.{ .started, .stabilized }, result.commands());
}

const CycleState = enum { a, b };
const CycleEvent = enum { tick };
const CycleContext = struct {};
const CycleCommand = enum { observed };
const CycleDef = fx.statechart.Definition(CycleState, CycleEvent, CycleContext, CycleCommand);
const CycleRuntime = fx.statechart.Machine(CycleDef);
const CycleMacro = fx.statechart.Macrostep(CycleDef);

fn observe(_: *CycleContext, _: *const CycleEvent, sink: *CycleDef.CommandSink) anyerror!void {
    try sink.emit(.observed);
}

const cycle_definition = CycleDef.init(.{
    .id = "agent.eventless-cycle",
    .version = 1,
    .initial = .a,
    .bounds = .{ .max_microsteps = 3 },
    .states = &.{
        .{ .id = .a },
        .{ .id = .b },
    },
    .transitions = &.{
        .{ .id = "a-b", .source = .a, .target = .b, .actions = &.{.{ .id = "observe", .execute = observe }} },
        .{ .id = "b-a", .source = .b, .target = .a, .actions = &.{.{ .id = "observe", .execute = observe }} },
    },
});

test "macrostep stops eventless cycles at the configured bound" {
    const snapshot = CycleRuntime.initial(&cycle_definition, .{}, 8);
    try std.testing.expectError(
        error.MicrostepLimitExceeded,
        CycleMacro.run(&cycle_definition, snapshot, .tick),
    );
    try std.testing.expectEqual(CycleState.a, snapshot.state);
    try std.testing.expectEqual(@as(u64, 0), snapshot.revision);
}

test "macrostep fingerprints are deterministic" {
    const snapshot = Runtime.initial(&definition, .{}, 5);
    const left = try Macro.run(&definition, snapshot, .start);
    const right = try Macro.run(&definition, snapshot, .start);
    try std.testing.expect(left.fingerprint != 0);
    try std.testing.expectEqual(left.fingerprint, right.fingerprint);
}
