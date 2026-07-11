const std = @import("std");
const fx = @import("zigeffect");

const State = enum { idle, done };
const Event = enum { run };
const Context = struct { value: u64 = 0 };
const Def = fx.statechart.Definition(State, Event, Context, void);
const Runtime = fx.statechart.Machine(Def);
const Audit = fx.statechart.FlatDeterminismAudit(Def);

fn deterministic(context: *Context, _: *const Event, _: *Def.CommandSink) anyerror!void {
    context.value += 1;
}
var unsafe_global_counter: u64 = 1;

fn globalDependent(context: *Context, _: *const Event, _: *Def.CommandSink) anyerror!void {
    context.value = unsafe_global_counter;
    unsafe_global_counter += 1;
}

const deterministic_definition = Def.init(.{
    .id = "audit.deterministic",
    .version = 1,
    .initial = .idle,
    .states = &.{ .{ .id = .idle }, .{ .id = .done, .kind = .final } },
    .transitions = &.{.{ .id = "run", .source = .idle, .event = .run, .target = .done, .actions = &.{.{ .id = "increment", .execute = deterministic }} }},
});

const unsafe_definition = Def.init(.{
    .id = "audit.global-dependent",
    .version = 1,
    .initial = .idle,
    .states = &.{ .{ .id = .idle }, .{ .id = .done, .kind = .final } },
    .transitions = &.{.{ .id = "run", .source = .idle, .event = .run, .target = .done, .actions = &.{.{ .id = "global", .execute = globalDependent }} }},
});

test "determinism audit accepts replay-stable reducers" {
    const snapshot = Runtime.initial(&deterministic_definition, .{}, 80);
    const report = try Audit.step(&deterministic_definition, snapshot, .run);
    try std.testing.expect(report.deterministic);
}

test "determinism audit rejects output that depends on mutable global state" {
    unsafe_global_counter = 1;
    const snapshot = Runtime.initial(&unsafe_definition, .{}, 81);
    try std.testing.expectError(error.NondeterministicExecution, Audit.step(&unsafe_definition, snapshot, .run));
}
